defmodule AgentJido.AnalyticsTest do
  use AgentJido.DataCase, async: false

  import AgentJido.AccountsFixtures

  alias AgentJido.Accounts.Scope
  alias AgentJido.Analytics
  alias AgentJido.Analytics.AnalyticsEvent
  alias AgentJido.Analytics.Ingestion
  alias AgentJido.Analytics.Ingestion.IngestionRun
  alias AgentJido.Analytics.RateLimiter
  alias AgentJido.Analytics.Redactor
  alias AgentJido.QueryLogs
  alias AgentJido.QueryLogs.QueryLog
  alias AgentJido.Repo

  describe "redaction" do
    test "normalizes, redacts, and hashes query text" do
      raw = "  Contact me at mike@example.com and call +1 (555) 123-4567  "

      assert Redactor.normalize_query(raw) == "Contact me at mike@example.com and call +1 (555) 123-4567"

      redacted = Redactor.redact_query(raw)
      assert redacted =~ "[email]"
      assert redacted =~ "[phone]"

      hash = Redactor.query_hash(raw)
      assert is_binary(hash)
      assert byte_size(hash) == 64
      assert hash == Redactor.query_hash(raw)
    end
  end

  describe "event tracking" do
    test "tracks event with server-side user identity and preserves metadata" do
      user = user_fixture()
      scope = Scope.for_user(user)

      attrs = %{
        event: "code_copied",
        source: "docs",
        channel: "copy_button",
        path: "/docs/concepts/agents",
        visitor_id: "visitor-123456",
        session_id: "session-123456",
        metadata: %{surface: "docs_page"},
        user_id: Ecto.UUID.generate()
      }

      assert {:ok, %AnalyticsEvent{} = event} = Analytics.track_event(scope, attrs)
      assert event.user_id == user.id
      assert event.event == "code_copied"
      assert event.metadata["surface"] == "docs_page"
    end

    test "excludes admin-scoped analytics events" do
      admin = admin_user_fixture()
      scope = Scope.for_user(admin)
      before_count = Repo.aggregate(AnalyticsEvent, :count, :id)

      attrs = %{
        event: "code_copied",
        source: "docs",
        channel: "copy_button",
        path: "/docs/concepts/agents",
        visitor_id: "visitor-admin",
        session_id: "session-admin",
        metadata: %{surface: "docs_page"}
      }

      assert {:ok, :excluded_admin} = Analytics.track_event(scope, attrs)
      assert Repo.aggregate(AnalyticsEvent, :count, :id) == before_count
    end

    test "returns content gaps and reformulations in dashboard snapshot" do
      admin = admin_user_fixture()
      admin_scope = Scope.for_user(admin)
      actor = user_fixture()
      scope = Scope.for_user(actor)
      identity = %{visitor_id: "visitor-gap", session_id: "session-gap", path: "/docs", referrer_host: "jido.run"}
      base_time = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

      {:ok, first} =
        QueryLogs.create_query_log(scope, identity, %{
          source: "content_assistant",
          channel: "content_assistant_page",
          query: "agent retries",
          status: "no_results"
        })

      from(q in QueryLog, where: q.id == ^first.id) |> Repo.update_all(set: [inserted_at: base_time])
      QueryLogs.finalize_query_safe(first.id, %{status: "no_results", results_count: 0})

      {:ok, second} =
        QueryLogs.create_query_log(scope, identity, %{
          source: "content_assistant",
          channel: "content_assistant_page",
          query: "agent retry strategies",
          status: "success",
          results_count: 3
        })

      from(q in QueryLog, where: q.id == ^second.id)
      |> Repo.update_all(set: [inserted_at: NaiveDateTime.add(base_time, 1, :second)])

      QueryLogs.finalize_query_safe(second.id, %{status: "success", results_count: 3})

      Analytics.track_feedback_safe(scope, %{
        event: "feedback_submitted",
        source: "content_assistant",
        channel: "content_assistant_no_results",
        path: "/search",
        feedback_value: "not_helpful",
        feedback_note: "I wanted retry docs",
        query_log_id: first.id,
        visitor_id: "visitor-gap",
        session_id: "session-gap",
        metadata: %{surface: "content_assistant"}
      })

      Analytics.track_feedback_safe(scope, %{
        event: "feedback_submitted",
        source: "content_assistant",
        channel: "content_assistant_modal",
        path: "/",
        feedback_value: "helpful",
        feedback_note: "Great summary",
        query_log_id: second.id,
        visitor_id: "visitor-gap",
        session_id: "session-gap",
        metadata: %{surface: "content_assistant"}
      })

      snapshot = Analytics.dashboard_snapshot(admin_scope, 7, top_limit: 5, gap_limit: 5, reform_limit: 5)

      assert snapshot.authorized?
      assert Enum.any?(snapshot.content_gaps, &(&1.query =~ "agent"))
      assert Enum.any?(snapshot.reformulations, &(&1.query == second.query))
      assert Enum.any?(snapshot.feedback_breakdown, &(&1.feedback_value == "not_helpful"))
      assert Enum.any?(snapshot.feedback_breakdown, &(&1.feedback_value == "helpful"))
      assert Enum.any?(snapshot.recent_feedback, &(&1.feedback_note == "I wanted retry docs"))
      assert Enum.any?(snapshot.recent_feedback, &(&1.feedback_note == "Great summary"))
      assert snapshot.local_search.summary.total_messages == 2
      assert Enum.any?(snapshot.local_search.recent_messages, &(&1.query == "agent retry strategies"))
    end

    test "includes external collector health in the dashboard snapshot" do
      admin = admin_user_fixture()
      admin_scope = Scope.for_user(admin)

      {:ok, repo} =
        Ingestion.upsert_tracked_repository(%{
          owner: "agentjido",
          name: "jido",
          label: "Jido"
        })

      traffic_day = Date.utc_today() |> Date.add(-1)
      snapshot_date = Date.utc_today()

      assert 1 =
               Ingestion.upsert_github_traffic(repo, %{
                 daily: [
                   %{
                     day: traffic_day,
                     views_count: 10,
                     views_uniques: 4,
                     clones_count: 3,
                     clones_uniques: 2
                   }
                 ],
                 referrers: [],
                 paths: [],
                 snapshot_date: snapshot_date
               })

      run = Ingestion.start_run("github_traffic", date_from: traffic_day, date_to: snapshot_date)
      assert %IngestionRun{} = Ingestion.complete_run(run, 1)

      snapshot = Analytics.dashboard_snapshot(admin_scope, 30)
      github = Enum.find(snapshot.ingestion.sources, &(&1.source == "github_traffic"))

      assert github.tracked_count == 1
      assert github.rows_count == 1
      assert github.latest_day == traffic_day
      assert github.latest_run.status == "completed"
    end

    test "rate limiter blocks after threshold" do
      RateLimiter.reset!()

      visitor_id = "visitor-rate"
      event = "code_copied"

      Enum.each(1..120, fn _ ->
        assert RateLimiter.allow?(visitor_id, event)
      end)

      refute RateLimiter.allow?(visitor_id, event)
    end

    test "dashboard snapshot surfaces home-to-onboarding CTA paths (jido-e12-t21)" do
      admin = admin_user_fixture()
      admin_scope = Scope.for_user(admin)
      actor = user_fixture()
      scope = Scope.for_user(actor)

      # Two clicks on the hero CTA, one on a section CTA — the home ->
      # onboarding conversion paths the acceptance condition wants visible.
      for _ <- 1..2 do
        assert {:ok, _} =
                 Analytics.track_event(scope, %{
                   event: "cta_clicked",
                   source: "home",
                   channel: "home_hero",
                   path: "/",
                   section_id: "hero",
                   target_url: "/docs/getting-started",
                   visitor_id: "visitor-conversion",
                   session_id: "session-conversion"
                 })
      end

      assert {:ok, _} =
               Analytics.track_event(scope, %{
                 event: "cta_clicked",
                 source: "home",
                 channel: "home_quickstart",
                 path: "/",
                 section_id: "quick-start",
                 target_url: "/docs/getting-started",
                 visitor_id: "visitor-conversion",
                 session_id: "session-conversion"
               })

      # A non-home CTA and a non-CTA event must not bleed into the home funnel.
      assert {:ok, _} =
               Analytics.track_event(scope, %{
                 event: "cta_clicked",
                 source: "docs",
                 channel: "docs_hero",
                 path: "/docs",
                 section_id: "hero",
                 target_url: "/docs/getting-started",
                 visitor_id: "visitor-conversion",
                 session_id: "session-conversion"
               })

      assert {:ok, _} =
               Analytics.track_event(scope, %{
                 event: "code_copied",
                 source: "home",
                 channel: "copy_button",
                 path: "/",
                 visitor_id: "visitor-conversion",
                 session_id: "session-conversion",
                 metadata: %{surface: "docs_page"}
               })

      snapshot = Analytics.dashboard_snapshot(admin_scope, 7)

      # The hero and section CTA paths are visible as rows in the snapshot.
      rows = Map.new(snapshot.home_conversion, fn row -> {row.section_id, row.clicks} end)

      assert rows["hero"] == 2
      assert rows["quick-start"] == 1
      # Only home-sourced cta_clicked events count — the docs-sourced CTA and
      # the code_copied event are excluded.
      refute Map.has_key?(rows, "docs")
      assert Enum.all?(snapshot.home_conversion, fn row -> row.clicks >= 1 end)
    end

    test "dashboard snapshot surfaces where first Livebook open happens (jido-e12-t22)" do
      admin = admin_user_fixture()
      admin_scope = Scope.for_user(admin)
      actor = user_fixture()
      scope = Scope.for_user(actor)

      # Visitor A first opens a Livebook from the docs CTA, then later from an
      # example page — activation starts on docs (their earliest surface).
      assert {:ok, _} =
               Analytics.track_event(scope, %{
                 event: "livebook_run_clicked",
                 source: "docs",
                 channel: "quick_links",
                 path: "/docs/concepts/agents",
                 target_url: "https://example.com/docs-livebook",
                 visitor_id: "visitor-first-docs",
                 session_id: "session-first-docs"
               })

      assert {:ok, _} =
               Analytics.track_event(scope, %{
                 event: "livebook_run_clicked",
                 source: "example",
                 channel: "related_livebook",
                 path: "/examples/counter-agent",
                 target_url: "https://example.com/example-livebook",
                 visitor_id: "visitor-first-docs",
                 session_id: "session-first-docs"
               })

      # Visitor B's first (and only) open is from an example page.
      assert {:ok, _} =
               Analytics.track_event(scope, %{
                 event: "livebook_run_clicked",
                 source: "example",
                 channel: "related_livebook",
                 path: "/examples/counter-agent",
                 target_url: "https://example.com/example-livebook",
                 visitor_id: "visitor-first-example",
                 session_id: "session-first-example"
               })

      # Visitor C opens the docs Livebook twice — still a single activation on
      # docs. Repeat opens by the same visitor must never re-count as a new
      # activation.
      for _ <- 1..2 do
        assert {:ok, _} =
                 Analytics.track_event(scope, %{
                   event: "livebook_run_clicked",
                   source: "docs",
                   channel: "quick_links",
                   path: "/docs/concepts/agents",
                   target_url: "https://example.com/docs-livebook",
                   visitor_id: "visitor-repeat-docs",
                   session_id: "session-repeat-docs"
                 })
      end

      # A non-Livebook event must not bleed into the activation breakdown.
      assert {:ok, _} =
               Analytics.track_event(scope, %{
                 event: "cta_clicked",
                 source: "home",
                 channel: "home_hero",
                 path: "/",
                 section_id: "hero",
                 target_url: "/docs/getting-started",
                 visitor_id: "visitor-not-livebook",
                 session_id: "session-not-livebook"
               })

      snapshot = Analytics.dashboard_snapshot(admin_scope, 7)

      rows = Map.new(snapshot.first_livebook_open, fn row -> {row.source, row.activations} end)

      # Activation starts on docs for visitor A (their earliest surface) and
      # visitor C (a repeat), and on example for visitor B — one activation per
      # visitor, attributed to where they first opened a Livebook.
      assert rows["docs"] == 2
      assert rows["example"] == 1

      # Three distinct visitors opened a Livebook, so there are exactly three
      # first opens total — the repeat and the non-Livebook event are excluded.
      total = Enum.sum(Enum.map(snapshot.first_livebook_open, & &1.activations))
      assert total == 3
    end

    test "dashboard snapshot surfaces first core Agent success by example (jido-e12-t23)" do
      admin = admin_user_fixture()
      admin_scope = Scope.for_user(admin)
      actor = user_fixture()
      scope = Scope.for_user(actor)

      # Visitor A's first core Agent success is on the Counter Agent demo; they
      # then run another action successfully — still a single first success.
      assert {:ok, _} =
               Analytics.track_event(scope, %{
                 event: "agent_run_succeeded",
                 source: "example",
                 channel: "interactive_demo",
                 path: "/examples/counter-agent",
                 section_id: "counter-agent",
                 target_url: "/examples/counter-agent",
                 visitor_id: "visitor-first-counter",
                 session_id: "session-first-counter",
                 metadata: %{surface: "example_demo", example: "counter-agent", action: "IncrementAction"}
               })

      for action <- ["DecrementAction", "ResetAction"] do
        assert {:ok, _} =
                 Analytics.track_event(scope, %{
                   event: "agent_run_succeeded",
                   source: "example",
                   channel: "interactive_demo",
                   path: "/examples/counter-agent",
                   section_id: "counter-agent",
                   target_url: "/examples/counter-agent",
                   visitor_id: "visitor-first-counter",
                   session_id: "session-first-counter",
                   metadata: %{surface: "example_demo", example: "counter-agent", action: action}
                 })
      end

      # Visitor B's first (and only) success is also on the Counter Agent.
      assert {:ok, _} =
               Analytics.track_event(scope, %{
                 event: "agent_run_succeeded",
                 source: "example",
                 channel: "interactive_demo",
                 path: "/examples/counter-agent",
                 section_id: "counter-agent",
                 target_url: "/examples/counter-agent",
                 visitor_id: "visitor-single-counter",
                 session_id: "session-single-counter",
                 metadata: %{surface: "example_demo", example: "counter-agent", action: "IncrementAction"}
               })

      # A non-agent event (a Livebook open) must not bleed into the success
      # breakdown — success does not depend only on page views or other events.
      assert {:ok, _} =
               Analytics.track_event(scope, %{
                 event: "livebook_run_clicked",
                 source: "example",
                 channel: "related_livebook",
                 path: "/examples/counter-agent",
                 target_url: "https://example.com/example-livebook",
                 visitor_id: "visitor-not-agent-success",
                 session_id: "session-not-agent-success"
               })

      snapshot = Analytics.dashboard_snapshot(admin_scope, 7)

      rows = Map.new(snapshot.first_core_agent_success, fn row -> {row.section_id, row.successes} end)

      # Two distinct visitors reached a first core Agent success on the Counter
      # Agent — visitor A's repeat successes never re-count as a new success.
      assert rows["counter-agent"] == 2

      # The Livebook-open visitor is excluded from the success breakdown.
      refute Map.has_key?(rows, "livebook")

      # Exactly two first successes total — the repeats and non-agent event are
      # excluded.
      total = Enum.sum(Enum.map(snapshot.first_core_agent_success, & &1.successes))
      assert total == 2
    end

    test "dashboard snapshot surfaces first LLM request outcome by categorized reason (jido-e12-t24)" do
      admin = admin_user_fixture()
      admin_scope = Scope.for_user(admin)
      actor = user_fixture()
      scope = Scope.for_user(actor)

      # Visitor A's first LLM request fails because the provider is not
      # configured — a provider setup problem. They retry and succeed; the
      # retry never re-counts (their first outcome is the failure).
      assert {:ok, _} =
               Analytics.track_event(scope, %{
                 event: "llm_request_outcome",
                 source: "content_assistant",
                 channel: "content_assistant_page",
                 path: "/search",
                 visitor_id: "visitor-setup-failure",
                 session_id: "session-setup-failure",
                 metadata: %{surface: "content_assistant_page", outcome: "failed", reason: "provider_unconfigured"}
               })

      assert {:ok, _} =
               Analytics.track_event(scope, %{
                 event: "llm_request_outcome",
                 source: "content_assistant",
                 channel: "content_assistant_page",
                 path: "/search",
                 visitor_id: "visitor-setup-failure",
                 session_id: "session-setup-failure",
                 metadata: %{surface: "content_assistant_page", outcome: "succeeded", reason: "succeeded"}
               })

      # Visitor B's first (and only) request succeeds.
      assert {:ok, _} =
               Analytics.track_event(scope, %{
                 event: "llm_request_outcome",
                 source: "content_assistant",
                 channel: "content_assistant_page",
                 path: "/search",
                 visitor_id: "visitor-succeeded",
                 session_id: "session-succeeded",
                 metadata: %{surface: "content_assistant_page", outcome: "succeeded", reason: "succeeded"}
               })

      # Visitor C's first request fails for a different setup reason (quota).
      assert {:ok, _} =
               Analytics.track_event(scope, %{
                 event: "llm_request_outcome",
                 source: "content_assistant",
                 channel: "content_assistant_page",
                 path: "/search",
                 visitor_id: "visitor-quota",
                 session_id: "session-quota",
                 metadata: %{surface: "content_assistant_page", outcome: "failed", reason: "provider_quota"}
               })

      # A non-LLM event (a core Agent success) must not bleed into the first LLM
      # request breakdown — the outcome does not depend on other events.
      assert {:ok, _} =
               Analytics.track_event(scope, %{
                 event: "agent_run_succeeded",
                 source: "example",
                 channel: "interactive_demo",
                 path: "/examples/counter-agent",
                 section_id: "counter-agent",
                 target_url: "/examples/counter-agent",
                 visitor_id: "visitor-not-llm",
                 session_id: "session-not-llm",
                 metadata: %{surface: "example_demo", example: "counter-agent", action: "IncrementAction"}
               })

      snapshot = Analytics.dashboard_snapshot(admin_scope, 7)

      rows = Map.new(snapshot.first_llm_request, fn row -> {row.reason, row.requests} end)

      # Provider setup problems are categorized distinctly: visitor A's
      # unconfigured failure and visitor C's quota failure land in their own
      # reason buckets, separate from the generic success and from each other.
      assert rows["provider_unconfigured"] == 1
      assert rows["provider_quota"] == 1
      assert rows["succeeded"] == 1

      # The core Agent success visitor is excluded from the LLM request breakdown.
      refute Map.has_key?(rows, "counter-agent")

      # Exactly three first LLM requests total — visitor A's retry never
      # re-counts as a new first request.
      total = Enum.sum(Enum.map(snapshot.first_llm_request, & &1.requests))
      assert total == 3
    end

    test "dashboard snapshot surfaces example filter use by use case (jido-e12-t25)" do
      admin = admin_user_fixture()
      admin_scope = Scope.for_user(admin)
      actor = user_fixture()
      scope = Scope.for_user(actor)

      # Visitor A first scopes the catalog to the coding use case, then later to
      # research — discovery starts on coding (their earliest filter). The later
      # research filter never re-counts as a new first filter.
      assert {:ok, _} =
               Analytics.track_event(scope, %{
                 event: "example_filter_used",
                 source: "examples",
                 channel: "use_case_filter",
                 path: "/examples",
                 section_id: "coding",
                 visitor_id: "visitor-coding-first",
                 session_id: "session-coding-first",
                 metadata: %{surface: "examples_catalog", use_case: "coding", label: "Coding agents"}
               })

      assert {:ok, _} =
               Analytics.track_event(scope, %{
                 event: "example_filter_used",
                 source: "examples",
                 channel: "use_case_filter",
                 path: "/examples",
                 section_id: "research",
                 visitor_id: "visitor-coding-first",
                 session_id: "session-coding-first",
                 metadata: %{
                   surface: "examples_catalog",
                   use_case: "research",
                   label: "Research and synthesis"
                 }
               })

      # Visitor B's first (and only) filter is research.
      assert {:ok, _} =
               Analytics.track_event(scope, %{
                 event: "example_filter_used",
                 source: "examples",
                 channel: "use_case_filter",
                 path: "/examples",
                 section_id: "research",
                 visitor_id: "visitor-research",
                 session_id: "session-research",
                 metadata: %{
                   surface: "examples_catalog",
                   use_case: "research",
                   label: "Research and synthesis"
                 }
               })

      # A non-filter event (a code copy on an example page) must not bleed into
      # the filter breakdown — filter use does not depend on other events.
      assert {:ok, _} =
               Analytics.track_event(scope, %{
                 event: "code_copied",
                 source: "examples",
                 channel: "copy_button",
                 path: "/examples/counter-agent",
                 visitor_id: "visitor-not-filter",
                 session_id: "session-not-filter",
                 metadata: %{surface: "examples_catalog"}
               })

      snapshot = Analytics.dashboard_snapshot(admin_scope, 7)

      rows = Map.new(snapshot.example_filter, fn row -> {row.use_case, row.visitors} end)

      # Each visitor's first filter is counted once — coding (visitor A) and
      # research (visitor B). Visitor A's later research filter never re-counts.
      assert rows["coding"] == 1
      assert rows["research"] == 1

      # The code-copy event is excluded from the filter breakdown.
      refute Map.has_key?(rows, "code_copied")

      # Exactly two first filters total — visitor A's second filter never
      # re-counts as a new first filter.
      total = Enum.sum(Enum.map(snapshot.example_filter, & &1.visitors))
      assert total == 2
    end

    test "dashboard snapshot surfaces movement from examples to source and local run by target (jido-e12-t26)" do
      admin = admin_user_fixture()
      admin_scope = Scope.for_user(admin)
      actor = user_fixture()
      scope = Scope.for_user(actor)

      # Visitor A moves from the counter-agent example into its source code,
      # then re-opens source after poking at another source file — discovery of
      # source starts on the first open; the repeat never re-counts. They also
      # open the interactive demo (a local run), so they engage both surfaces.
      assert {:ok, _} =
               Analytics.track_event(scope, %{
                 event: "example_tab_viewed",
                 source: "examples",
                 channel: "example_tab",
                 path: "/examples/counter-agent",
                 section_id: "source",
                 visitor_id: "visitor-source-and-demo",
                 session_id: "session-source-and-demo",
                 metadata: %{surface: "example_show", example: "counter-agent", target: "source"}
               })

      assert {:ok, _} =
               Analytics.track_event(scope, %{
                 event: "example_tab_viewed",
                 source: "examples",
                 channel: "example_tab",
                 path: "/examples/counter-agent",
                 section_id: "source",
                 visitor_id: "visitor-source-and-demo",
                 session_id: "session-source-and-demo",
                 metadata: %{surface: "example_show", example: "counter-agent", target: "source"}
               })

      assert {:ok, _} =
               Analytics.track_event(scope, %{
                 event: "example_tab_viewed",
                 source: "examples",
                 channel: "example_tab",
                 path: "/examples/counter-agent",
                 section_id: "demo",
                 visitor_id: "visitor-source-and-demo",
                 session_id: "session-source-and-demo",
                 metadata: %{surface: "example_show", example: "counter-agent", target: "demo"}
               })

      # Visitor B only opens the interactive demo (a local run).
      assert {:ok, _} =
               Analytics.track_event(scope, %{
                 event: "example_tab_viewed",
                 source: "examples",
                 channel: "example_tab",
                 path: "/examples/counter-agent",
                 section_id: "demo",
                 visitor_id: "visitor-demo-only",
                 session_id: "session-demo-only",
                 metadata: %{surface: "example_show", example: "counter-agent", target: "demo"}
               })

      # An explanation-tab view (the default reading surface) is not movement to
      # a proof surface, so it is never instrumented as engagement — represent it
      # as a non-engagement event (a code copy) that must not bleed into the
      # breakdown.
      assert {:ok, _} =
               Analytics.track_event(scope, %{
                 event: "code_copied",
                 source: "examples",
                 channel: "copy_button",
                 path: "/examples/counter-agent",
                 visitor_id: "visitor-not-engagement",
                 session_id: "session-not-engagement",
                 metadata: %{surface: "example_show"}
               })

      snapshot = Analytics.dashboard_snapshot(admin_scope, 7)

      rows = Map.new(snapshot.example_engagement, fn row -> {row.target, row.visitors} end)

      # Source engagement counts visitor A once (their repeat source open never
      # re-counts). The local-run (demo) engagement counts both visitor A and
      # visitor B — a visitor who reaches both surfaces counts once in each.
      assert rows["source"] == 1
      assert rows["demo"] == 2

      # The non-engagement event is excluded from the engagement breakdown.
      refute Map.has_key?(rows, "code_copied")

      # Three first engagements total across the two surfaces — visitor A's
      # repeat source open never re-counts as a new engagement.
      total = Enum.sum(Enum.map(snapshot.example_engagement, & &1.visitors))
      assert total == 3
    end
  end

  describe "onboarding to Operate long-running path entry (jido-e12-t27)" do
    test "dashboard snapshot surfaces first movement into the long-running path by entry page (jido-e12-t27)" do
      admin = admin_user_fixture()
      admin_scope = Scope.for_user(admin)
      actor = user_fixture()
      scope = Scope.for_user(actor)

      # Visitor A first steps onto the long-running path at the operations hub,
      # then later opens the telemetry page. Their first entry is the hub, so the
      # later operations page never re-counts as a second conversion.
      assert {:ok, _} =
               Analytics.track_event(scope, %{
                 event: "long_running_path_entered",
                 source: "operate",
                 channel: "long_running_path",
                 path: "/docs/operations",
                 section_id: "operations",
                 visitor_id: "visitor-hub-then-telemetry",
                 session_id: "session-hub-then-telemetry",
                 metadata: %{surface: "operations", page: "operations"}
               })

      assert {:ok, _} =
               Analytics.track_event(scope, %{
                 event: "long_running_path_entered",
                 source: "operate",
                 channel: "long_running_path",
                 path: "/docs/operations/telemetry-and-traces",
                 section_id: "telemetry-and-traces",
                 visitor_id: "visitor-hub-then-telemetry",
                 session_id: "session-hub-then-telemetry",
                 metadata: %{surface: "operations", page: "telemetry-and-traces"}
               })

      # Visitor B enters the long-running path directly on the telemetry page.
      assert {:ok, _} =
               Analytics.track_event(scope, %{
                 event: "long_running_path_entered",
                 source: "operate",
                 channel: "long_running_path",
                 path: "/docs/operations/telemetry-and-traces",
                 section_id: "telemetry-and-traces",
                 visitor_id: "visitor-telemetry-only",
                 session_id: "session-telemetry-only",
                 metadata: %{surface: "operations", page: "telemetry-and-traces"}
               })

      # A non-entry docs event (a docs section view) is not movement into the
      # long-running path, so it must never bleed into the conversion breakdown.
      assert {:ok, _} =
               Analytics.track_event(scope, %{
                 event: "docs_section_viewed",
                 source: "docs",
                 channel: "docs_sidebar",
                 path: "/docs",
                 section_id: "get-started",
                 visitor_id: "visitor-not-entry",
                 session_id: "session-not-entry",
                 metadata: %{surface: "docs_index"}
               })

      snapshot = Analytics.dashboard_snapshot(admin_scope, 7)

      rows = Map.new(snapshot.long_running_path_entry, fn row -> {row.section_id, row.visitors} end)

      # The hub counts visitor A once (their later telemetry view never re-counts
      # as a new conversion). The telemetry page counts visitor B once.
      assert rows["operations"] == 1
      assert rows["telemetry-and-traces"] == 1

      # The non-entry docs event is excluded from the long-running path breakdown.
      refute Map.has_key?(rows, "get-started")

      # Two first conversions total — visitor A's repeat operations-page view
      # never re-counts as a new conversion.
      total = Enum.sum(Enum.map(snapshot.long_running_path_entry, & &1.visitors))
      assert total == 2
    end
  end

  describe "home control message to proof (jido-e12-t46)" do
    test "dashboard snapshot surfaces which control claims visitors start evaluating (jido-e12-t46)" do
      admin = admin_user_fixture()
      admin_scope = Scope.for_user(admin)
      actor = user_fixture()
      scope = Scope.for_user(actor)

      # Visitor A starts evaluating the supervision claim, then follows it again
      # (the same claim), then starts evaluating the typed-actions claim. The
      # repeat supervision follow never re-counts; the two distinct claims each
      # count once for this visitor.
      assert {:ok, _} =
               Analytics.track_event(scope, %{
                 event: "control_proof_viewed",
                 source: "home",
                 channel: "home_operational_control",
                 path: "/",
                 section_id: "supervision",
                 target_url: "/features/agents-that-self-heal",
                 visitor_id: "visitor-a",
                 session_id: "session-a",
                 metadata: %{surface: "home_operational_control", claim: "supervision"}
               })

      assert {:ok, _} =
               Analytics.track_event(scope, %{
                 event: "control_proof_viewed",
                 source: "home",
                 channel: "home_operational_control",
                 path: "/",
                 section_id: "supervision",
                 target_url: "/features/agents-that-self-heal",
                 visitor_id: "visitor-a",
                 session_id: "session-a",
                 metadata: %{surface: "home_operational_control", claim: "supervision"}
               })

      assert {:ok, _} =
               Analytics.track_event(scope, %{
                 event: "control_proof_viewed",
                 source: "home",
                 channel: "home_operational_control",
                 path: "/",
                 section_id: "typed-actions",
                 target_url: "/docs/concepts/actions",
                 visitor_id: "visitor-a",
                 session_id: "session-a",
                 metadata: %{surface: "home_operational_control", claim: "typed-actions"}
               })

      # Visitor B starts evaluating the supervision claim once.
      assert {:ok, _} =
               Analytics.track_event(scope, %{
                 event: "control_proof_viewed",
                 source: "home",
                 channel: "home_operational_control",
                 path: "/",
                 section_id: "supervision",
                 target_url: "/features/agents-that-self-heal",
                 visitor_id: "visitor-b",
                 session_id: "session-b",
                 metadata: %{surface: "home_operational_control", claim: "supervision"}
               })

      # A home CTA click is not a control-claim evaluation, so it must never
      # bleed into the control-proof breakdown.
      assert {:ok, _} =
               Analytics.track_event(scope, %{
                 event: "cta_clicked",
                 source: "home",
                 channel: "home_hero",
                 path: "/",
                 section_id: "hero",
                 target_url: "/docs/getting-started",
                 visitor_id: "visitor-b",
                 session_id: "session-b"
               })

      snapshot = Analytics.dashboard_snapshot(admin_scope, 7)

      rows = Map.new(snapshot.control_proof_evaluation, fn row -> {row.claim, row.visitors} end)

      # Supervision counts both visitors (A and B); typed-actions counts visitor
      # A only. Visitor A's repeat supervision follow never re-counts.
      assert rows["supervision"] == 2
      assert rows["typed-actions"] == 1

      # The home CTA click is excluded from the control-proof breakdown.
      refute Map.has_key?(rows, "hero")

      # Three first evaluations total across the two claims — visitor A's repeat
      # supervision follow never re-counts as a new evaluation.
      total = Enum.sum(Enum.map(snapshot.control_proof_evaluation, & &1.visitors))
      assert total == 3
    end
  end
end
