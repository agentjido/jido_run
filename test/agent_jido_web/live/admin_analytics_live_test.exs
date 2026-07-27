defmodule AgentJidoWeb.AdminAnalyticsLiveTest do
  use AgentJidoWeb.ConnCase, async: false

  import AgentJido.AccountsFixtures
  import Phoenix.LiveViewTest

  alias AgentJido.Accounts.Scope
  alias AgentJido.Analytics
  alias AgentJido.QueryLogs

  setup %{conn: conn} do
    admin_conn = log_in_user(conn, admin_user_fixture())
    %{admin_conn: admin_conn}
  end

  test "redirects unauthenticated users to log in", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, "/dashboard/analytics")
  end

  test "blocks authenticated non-admin users", %{conn: conn} do
    conn = log_in_user(conn, user_fixture())
    assert {:error, {:redirect, %{to: "/"}}} = live(conn, "/dashboard/analytics")
  end

  test "renders analytics sections for admins", %{admin_conn: admin_conn} do
    seed_analytics_data()

    {:ok, view, html} = live(admin_conn, "/dashboard/analytics")

    assert has_element?(view, "#admin-shell")
    assert has_element?(view, "#admin-sidebar")
    assert has_element?(view, "a[data-admin-nav-path='/dashboard/analytics'][data-admin-nav-active='true']", "Analytics")
    assert has_element?(view, "a[data-admin-nav-path='/dashboard']", "Dashboard")
    assert has_element?(view, "a[data-admin-nav-path='/dashboard/content-generator']", "Content Generator")
    assert has_element?(view, "a[data-admin-nav-path='/dashboard/chatops']", "ChatOps")
    assert html =~ "First-Party Analytics"
    assert html =~ "Top demand topics"
    assert html =~ "High Demand, Low Success"
    assert html =~ "Reformulation leaderboard"
    assert html =~ "Docs search no-results"
    assert html =~ "Docs search reformulations"
    assert html =~ "Collector Health"
    assert html =~ "Recent Search Messages"
    assert html =~ "Feedback breakdown"
    assert html =~ "Recent feedback (helpful + not helpful)"
    assert html =~ "GitHub traffic"
    assert html =~ "Search Console"
    assert html =~ "agent supervision"
    assert html =~ "Need more docs"
    assert html =~ "Great answer"
    assert html =~ "Not helpful"
    assert html =~ "Helpful"
    assert has_element?(view, "a[href='/dashboard/analytics/export/gaps.csv?days=7']", "Export gaps CSV")
    assert has_element?(view, "a[href='/dashboard/analytics/export/feedback.csv?days=7']", "Export feedback CSV")
  end

  test "renders the home-to-onboarding conversion section for admins (jido-e12-t21)", %{
    admin_conn: admin_conn
  } do
    actor = user_fixture()
    scope = Scope.for_user(actor)

    # Seed clicks on the hero and a section CTA so the paths render as rows.
    Analytics.track_event_safe(scope, %{
      event: "cta_clicked",
      source: "home",
      channel: "home_hero",
      path: "/",
      section_id: "hero",
      target_url: "/docs/getting-started",
      visitor_id: "admin-conv-visitor",
      session_id: "admin-conv-session"
    })

    Analytics.track_event_safe(scope, %{
      event: "cta_clicked",
      source: "home",
      channel: "home_quickstart",
      path: "/",
      section_id: "quick-start",
      target_url: "/docs/getting-started",
      visitor_id: "admin-conv-visitor",
      session_id: "admin-conv-session"
    })

    {:ok, view, html} = live(admin_conn, "/dashboard/analytics")

    # The section is present and the hero CTA path is visible as a labeled row.
    assert has_element?(view, "h2", "Home → onboarding conversion")
    assert html =~ "Hero CTA"
    assert html =~ "hero"
    assert html =~ "Quick start"
  end

  test "renders the first Livebook open section for admins (jido-e12-t22)", %{
    admin_conn: admin_conn
  } do
    actor = user_fixture()
    scope = Scope.for_user(actor)

    # A first Livebook open on each activation surface so both rows render.
    Analytics.track_event_safe(scope, %{
      event: "livebook_run_clicked",
      source: "docs",
      channel: "quick_links",
      path: "/docs/concepts/agents",
      target_url: "https://example.com/docs-livebook",
      visitor_id: "admin-open-docs",
      session_id: "admin-open-docs-session"
    })

    Analytics.track_event_safe(scope, %{
      event: "livebook_run_clicked",
      source: "example",
      channel: "related_livebook",
      path: "/examples/counter-agent",
      target_url: "https://example.com/example-livebook",
      visitor_id: "admin-open-example",
      session_id: "admin-open-example-session"
    })

    {:ok, view, html} = live(admin_conn, "/dashboard/analytics")

    # The section is present and each activation surface is visible as a row.
    assert has_element?(view, "h2", "First Livebook open")
    assert html =~ "Docs — Run in Livebook CTA"
    assert html =~ "Example — companion notebook"
  end

  test "renders the first core Agent success section for admins (jido-e12-t23)", %{
    admin_conn: admin_conn
  } do
    actor = user_fixture()
    scope = Scope.for_user(actor)

    # A first core Agent success on the Counter Agent demo so the row renders.
    Analytics.track_event_safe(scope, %{
      event: "agent_run_succeeded",
      source: "example",
      channel: "interactive_demo",
      path: "/examples/counter-agent",
      section_id: "counter-agent",
      target_url: "/examples/counter-agent",
      visitor_id: "admin-agent-visitor",
      session_id: "admin-agent-session",
      metadata: %{surface: "example_demo", example: "counter-agent", action: "IncrementAction"}
    })

    {:ok, view, html} = live(admin_conn, "/dashboard/analytics")

    # The section is present and the Counter Agent success is visible as a row.
    assert has_element?(view, "h2", "First core Agent success")
    assert html =~ "Counter Agent"
    assert html =~ "counter-agent"
  end

  test "renders the first LLM request outcome section for admins (jido-e12-t24)", %{
    admin_conn: admin_conn
  } do
    actor = user_fixture()
    scope = Scope.for_user(actor)

    # A first LLM request that fails because the provider is not configured, and
    # one that succeeds, so both rows render.
    Analytics.track_event_safe(scope, %{
      event: "llm_request_outcome",
      source: "content_assistant",
      channel: "content_assistant_page",
      path: "/search",
      visitor_id: "admin-llm-unconfigured",
      session_id: "admin-llm-unconfigured-session",
      metadata: %{surface: "content_assistant_page", outcome: "failed", reason: "provider_unconfigured"}
    })

    Analytics.track_event_safe(scope, %{
      event: "llm_request_outcome",
      source: "content_assistant",
      channel: "content_assistant_page",
      path: "/search",
      visitor_id: "admin-llm-succeeded",
      session_id: "admin-llm-succeeded-session",
      metadata: %{surface: "content_assistant_page", outcome: "succeeded", reason: "succeeded"}
    })

    {:ok, view, html} = live(admin_conn, "/dashboard/analytics")

    # The section is present and each categorized outcome is visible as a row —
    # the provider setup problem stays distinct from the generic success.
    assert has_element?(view, "h2", "First LLM request outcome")
    assert html =~ "Provider not configured"
    assert html =~ "provider_unconfigured"
    assert html =~ "Succeeded"
    assert html =~ "succeeded"
  end

  test "renders the example filter use section for admins (jido-e12-t25)", %{
    admin_conn: admin_conn
  } do
    actor = user_fixture()
    scope = Scope.for_user(actor)

    # A first example filter on the coding use case and one on research, so both
    # rows render.
    Analytics.track_event_safe(scope, %{
      event: "example_filter_used",
      source: "examples",
      channel: "use_case_filter",
      path: "/examples",
      section_id: "coding",
      visitor_id: "admin-filter-coding",
      session_id: "admin-filter-coding-session",
      metadata: %{surface: "examples_catalog", use_case: "coding", label: "Coding agents"}
    })

    Analytics.track_event_safe(scope, %{
      event: "example_filter_used",
      source: "examples",
      channel: "use_case_filter",
      path: "/examples",
      section_id: "research",
      visitor_id: "admin-filter-research",
      session_id: "admin-filter-research-session",
      metadata: %{surface: "examples_catalog", use_case: "research", label: "Research and synthesis"}
    })

    {:ok, view, html} = live(admin_conn, "/dashboard/analytics")

    # The section is present and each use-case filter is visible as a row — the
    # human-readable label and the slug both render.
    assert has_element?(view, "h2", "Example filter use")
    assert html =~ "Coding agents"
    assert html =~ "coding"
    assert html =~ "Research and synthesis"
    assert html =~ "research"
  end

  test "renders the example source and local-run engagement section for admins (jido-e12-t26)",
       %{admin_conn: admin_conn} do
    actor = user_fixture()
    scope = Scope.for_user(actor)

    # One visitor's first move into source, one into the local run (demo), so
    # both surfaces render as rows.
    Analytics.track_event_safe(scope, %{
      event: "example_tab_viewed",
      source: "examples",
      channel: "example_tab",
      path: "/examples/counter-agent",
      section_id: "source",
      visitor_id: "admin-engagement-source",
      session_id: "admin-engagement-source-session",
      metadata: %{surface: "example_show", example: "counter-agent", target: "source"}
    })

    Analytics.track_event_safe(scope, %{
      event: "example_tab_viewed",
      source: "examples",
      channel: "example_tab",
      path: "/examples/counter-agent",
      section_id: "demo",
      visitor_id: "admin-engagement-demo",
      session_id: "admin-engagement-demo-session",
      metadata: %{surface: "example_show", example: "counter-agent", target: "demo"}
    })

    {:ok, view, html} = live(admin_conn, "/dashboard/analytics")

    # The section is present and each proof surface is visible as a row — the
    # human-readable label and the target slug both render.
    assert has_element?(view, "h2", "Example → source and local run")
    assert html =~ "Source code"
    assert html =~ "source"
    assert html =~ "Interactive demo (local run)"
    assert html =~ "demo"
  end

  test "renders the onboarding to Operate long-running path section for admins (jido-e12-t27)",
       %{admin_conn: admin_conn} do
    actor = user_fixture()
    scope = Scope.for_user(actor)

    # One visitor's first step onto the long-running path at the operations hub,
    # one entering directly on the telemetry page, so both surfaces render.
    Analytics.track_event_safe(scope, %{
      event: "long_running_path_entered",
      source: "operate",
      channel: "long_running_path",
      path: "/docs/operations",
      section_id: "operations",
      visitor_id: "admin-operate-hub",
      session_id: "admin-operate-hub-session",
      metadata: %{surface: "operations", page: "operations"}
    })

    Analytics.track_event_safe(scope, %{
      event: "long_running_path_entered",
      source: "operate",
      channel: "long_running_path",
      path: "/docs/operations/telemetry-and-traces",
      section_id: "telemetry-and-traces",
      visitor_id: "admin-operate-telemetry",
      session_id: "admin-operate-telemetry-session",
      metadata: %{surface: "operations", page: "telemetry-and-traces"}
    })

    {:ok, view, html} = live(admin_conn, "/dashboard/analytics")

    # The section is present and each entry surface is visible as a row — the
    # human-readable label and the page slug both render.
    assert has_element?(view, "h2", "Onboarding → Operate (long-running path)")
    assert html =~ "Operations hub"
    assert html =~ "operations"
    assert html =~ "Telemetry and traces"
    assert html =~ "telemetry-and-traces"
  end

  test "renders the home control message to proof section for admins (jido-e12-t46)",
       %{admin_conn: admin_conn} do
    actor = user_fixture()
    scope = Scope.for_user(actor)

    # Two visitors start evaluating the supervision claim, one starts evaluating
    # the typed-actions claim, so both control claims render as rows.
    Analytics.track_event_safe(scope, %{
      event: "control_proof_viewed",
      source: "home",
      channel: "home_operational_control",
      path: "/",
      section_id: "supervision",
      target_url: "/features/agents-that-self-heal",
      visitor_id: "admin-control-a",
      session_id: "admin-control-a-session",
      metadata: %{surface: "home_operational_control", claim: "supervision"}
    })

    Analytics.track_event_safe(scope, %{
      event: "control_proof_viewed",
      source: "home",
      channel: "home_operational_control",
      path: "/",
      section_id: "supervision",
      target_url: "/features/agents-that-self-heal",
      visitor_id: "admin-control-b",
      session_id: "admin-control-b-session",
      metadata: %{surface: "home_operational_control", claim: "supervision"}
    })

    Analytics.track_event_safe(scope, %{
      event: "control_proof_viewed",
      source: "home",
      channel: "home_operational_control",
      path: "/",
      section_id: "typed-actions",
      target_url: "/docs/concepts/actions",
      visitor_id: "admin-control-c",
      session_id: "admin-control-c-session",
      metadata: %{surface: "home_operational_control", claim: "typed-actions"}
    })

    {:ok, view, html} = live(admin_conn, "/dashboard/analytics")

    # The section is present and each control claim is visible as a row — the
    # human-readable label and the proof-link slug both render.
    assert has_element?(view, "h2", "Home control message → proof")
    assert html =~ "Supervision (self-heal)"
    assert html =~ "supervision"
    assert html =~ "Typed Actions"
    assert html =~ "typed-actions"
  end

  test "renders the controlled-Agent example completion section for admins (jido-e12-t47)",
       %{admin_conn: admin_conn} do
    actor = user_fixture()
    scope = Scope.for_user(actor)

    # One visitor starts the demo and runs the allowed path; another opens source
    # and the local run, so several completion steps render as rows.
    Analytics.track_event_safe(scope, %{
      event: "controlled_agent_engagement",
      source: "examples",
      channel: "controlled_agent_demo",
      path: "/examples/controlled-agent",
      section_id: "start",
      visitor_id: "admin-controlled-start",
      session_id: "admin-controlled-start-session",
      metadata: %{surface: "controlled_agent_demo", example: "controlled-agent", step: "start"}
    })

    Analytics.track_event_safe(scope, %{
      event: "controlled_agent_engagement",
      source: "examples",
      channel: "controlled_agent_demo",
      path: "/examples/controlled-agent",
      section_id: "allowed_path",
      visitor_id: "admin-controlled-start",
      session_id: "admin-controlled-start-session",
      metadata: %{surface: "controlled_agent_demo", example: "controlled-agent", step: "allowed_path"}
    })

    Analytics.track_event_safe(scope, %{
      event: "controlled_agent_engagement",
      source: "examples",
      channel: "controlled_agent_example",
      path: "/examples/controlled-agent",
      section_id: "source_open",
      visitor_id: "admin-controlled-source",
      session_id: "admin-controlled-source-session",
      metadata: %{surface: "controlled_agent_example", example: "controlled-agent", step: "source_open"}
    })

    {:ok, view, html} = live(admin_conn, "/dashboard/analytics")

    # The section is present and each completion step is visible as a row — the
    # human-readable label and the step slug both render.
    assert has_element?(view, "h2", "Controlled-Agent example completion")
    assert html =~ "Started the demo"
    assert html =~ "start"
    assert html =~ "Ran the allowed path"
    assert html =~ "allowed_path"
    assert html =~ "Opened source code"
    assert html =~ "source_open"
  end

  test "renders the ecosystem stack selection section for admins (jido-e12-t28)",
       %{admin_conn: admin_conn} do
    actor = user_fixture()
    scope = Scope.for_user(actor)

    # Two visitors pick the Core stack, one picks the AI stack, and two expand
    # the full catalog — so the recommended stacks and the full catalog both
    # render as rows the team can compare.
    Analytics.track_event_safe(scope, %{
      event: "ecosystem_stack_selected",
      source: "ecosystem",
      channel: "stack_compatibility",
      path: "/ecosystem",
      section_id: "core",
      visitor_id: "admin-eco-a",
      session_id: "admin-eco-a-session",
      metadata: %{surface: "ecosystem_hub", selection: "core"}
    })

    Analytics.track_event_safe(scope, %{
      event: "ecosystem_stack_selected",
      source: "ecosystem",
      channel: "stack_compatibility",
      path: "/ecosystem",
      section_id: "core",
      visitor_id: "admin-eco-b",
      session_id: "admin-eco-b-session",
      metadata: %{surface: "ecosystem_hub", selection: "core"}
    })

    Analytics.track_event_safe(scope, %{
      event: "ecosystem_stack_selected",
      source: "ecosystem",
      channel: "stack_compatibility",
      path: "/ecosystem",
      section_id: "ai",
      visitor_id: "admin-eco-c",
      session_id: "admin-eco-c-session",
      metadata: %{surface: "ecosystem_hub", selection: "ai"}
    })

    Analytics.track_event_safe(scope, %{
      event: "ecosystem_stack_selected",
      source: "ecosystem",
      channel: "dependency_map",
      path: "/ecosystem",
      section_id: "full_catalog",
      visitor_id: "admin-eco-d",
      session_id: "admin-eco-d-session",
      metadata: %{surface: "ecosystem_hub", selection: "full_catalog"}
    })

    {:ok, view, html} = live(admin_conn, "/dashboard/analytics")

    # The section is present and both halves of the comparison render — the
    # recommended stacks (Core, AI) and the full catalog — each with its label
    # and its slug.
    assert has_element?(view, "h2", "Ecosystem stack selection")
    assert html =~ "Recommended — Core stack"
    assert html =~ "core"
    assert html =~ "Recommended — AI stack"
    assert html =~ "ai"
    assert html =~ "Full catalog (browse all)"
    assert html =~ "full_catalog"
  end

  test "renders docs search no-results and reformulation sections backed by user language (jido-e12-t29)", %{
    admin_conn: admin_conn
  } do
    actor = user_fixture()
    scope = Scope.for_user(actor)
    identity = %{visitor_id: "admin-gap-visitor", session_id: "admin-gap-session", path: "/docs", referrer_host: "jido.run"}

    # A no-result query surfaces its user language as a content gap.
    {:ok, _no_result} =
      QueryLogs.create_query_log(scope, identity, %{
        source: "content_assistant",
        channel: "content_assistant_page",
        query: "how do I retry a failed agent",
        status: "no_results",
        results_count: 0
      })

    # A second query in the same session rephrases the gap, forming a
    # reformulation transition (from -> to) backed by user language.
    {:ok, _rephrase} =
      QueryLogs.create_query_log(scope, identity, %{
        source: "content_assistant",
        channel: "content_assistant_page",
        query: "agent retry strategies",
        status: "success",
        results_count: 3
      })

    {:ok, view, html} = live(admin_conn, "/dashboard/analytics")

    assert has_element?(view, "h2", "Docs search no-results")
    assert has_element?(view, "h2", "Docs search reformulations")
    # Both halves are backed by the visitor's own phrasing.
    assert html =~ "how do I retry a failed agent"
    assert html =~ "agent retry strategies"
  end

  defp seed_analytics_data do
    actor = user_fixture()
    scope = Scope.for_user(actor)
    identity = %{visitor_id: "admin-seed-visitor", session_id: "admin-seed-session", path: "/search", referrer_host: "jido.run"}

    {:ok, query_log} =
      QueryLogs.create_query_log(scope, identity, %{
        source: "content_assistant",
        channel: "content_assistant_page",
        query: "agent supervision",
        status: "no_results",
        results_count: 0
      })

    Analytics.track_event_safe(scope, %{
      event: "content_assistant_submitted",
      source: "content_assistant",
      channel: "content_assistant_page",
      path: "/search",
      query_log_id: query_log.id,
      visitor_id: "admin-seed-visitor",
      session_id: "admin-seed-session",
      metadata: %{surface: "content_assistant"}
    })

    Analytics.track_feedback_safe(scope, %{
      event: "feedback_submitted",
      source: "content_assistant",
      channel: "content_assistant_no_results",
      path: "/search",
      feedback_value: "not_helpful",
      feedback_note: "Need more docs",
      query_log_id: query_log.id,
      visitor_id: "admin-seed-visitor",
      session_id: "admin-seed-session",
      metadata: %{surface: "content_assistant"}
    })

    Analytics.track_feedback_safe(scope, %{
      event: "feedback_submitted",
      source: "content_assistant",
      channel: "content_assistant_modal",
      path: "/",
      feedback_value: "helpful",
      feedback_note: "Great answer",
      query_log_id: query_log.id,
      visitor_id: "admin-seed-visitor",
      session_id: "admin-seed-session",
      metadata: %{surface: "content_assistant"}
    })
  end
end
