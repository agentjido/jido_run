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
