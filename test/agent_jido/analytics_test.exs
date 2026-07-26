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
  end
end
