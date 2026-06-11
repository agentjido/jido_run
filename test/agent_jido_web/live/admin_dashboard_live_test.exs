defmodule AgentJidoWeb.AdminDashboardLiveTest do
  use AgentJidoWeb.ConnCase, async: false

  import AgentJido.AccountsFixtures
  import Phoenix.LiveViewTest

  alias AgentJido.QueryLogs

  setup %{conn: conn} do
    admin_conn = log_in_user(conn, admin_user_fixture())
    %{admin_conn: admin_conn}
  end

  test "redirects unauthenticated users to log in", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, "/dashboard")
  end

  test "blocks authenticated non-admin users", %{conn: conn} do
    conn = log_in_user(conn, user_fixture())

    assert {:error, {:redirect, %{to: "/"}}} = live(conn, "/dashboard")
  end

  test "renders admin control-plane links for authenticated admins", %{admin_conn: admin_conn} do
    {:ok, view, html} = live(admin_conn, "/dashboard")

    assert html =~ "Admin Control Plane"
    assert has_element?(view, "#admin-shell")
    assert has_element?(view, "#admin-sidebar")
    assert has_element?(view, "a[data-admin-nav-path='/dashboard'][data-admin-nav-active='true']", "Dashboard")
    assert has_element?(view, "a[data-admin-nav-path='/dashboard/analytics']", "Analytics")
    assert has_element?(view, "a[data-admin-nav-path='/dashboard/ecosystem-analytics']", "Ecosystem Analytics")
    assert has_element?(view, "a[data-admin-nav-path='/dashboard/content-ingestion']", "Content Ingestion")
    assert has_element?(view, "a[data-admin-nav-path='/dashboard/chatops']", "ChatOps")
    assert has_element?(view, "a[data-admin-nav-path='/arcana']", "Arcana")
    assert has_element?(view, "a[href='/arcana']", "Open Arcana dashboard")
    assert has_element?(view, "a[href='/dev/jido']", "Open Jido Studio")

    assert has_element?(view, "a[href='/dashboard/content-ingestion']", "Open Content Ingestion")
    assert has_element?(view, "a[href='/dashboard/ecosystem-analytics']", "Open ecosystem analytics")
    assert has_element?(view, "a[href='/dashboard/analytics']", "Open analytics dashboard")
    assert has_element?(view, "#dashboard-live-presence", "Live Presence")
    assert has_element?(view, "#dashboard-query-tracking", "Query Tracking")
    assert has_element?(view, "#dashboard-analytics-summary", "Learning Analytics")
    assert has_element?(view, "#dashboard-ecosystem-analytics", "Ecosystem Analytics")
    assert has_element?(view, "#dashboard-content-ingest", "Content Ingestion")
  end

  test "updates live presence counts when another visitor connects", %{admin_conn: admin_conn} do
    {:ok, dashboard_view, _html} = live(admin_conn, "/dashboard")
    {initial_visitors, initial_sessions} = live_presence_counts(dashboard_view)

    assert initial_visitors >= 1
    assert initial_sessions >= 1

    {:ok, other_view, _html} = live(build_conn(), "/")

    assert_eventually(fn ->
      {next_visitors, next_sessions} = live_presence_counts(dashboard_view)
      next_visitors >= initial_visitors + 1 and next_sessions >= initial_sessions + 1
    end)

    close_browser(other_view)
  end

  test "shows tracked content assistant queries", %{admin_conn: admin_conn} do
    {:ok, _} =
      QueryLogs.create_query_log(%{
        source: "content_assistant",
        channel: "content_assistant_modal",
        query: "agent supervision",
        status: "success",
        results_count: 4
      })

    {:ok, _} =
      QueryLogs.create_query_log(%{
        source: "content_assistant",
        channel: "content_assistant_page",
        query: "what is cmd/2?",
        status: "no_results",
        results_count: 0
      })

    {:ok, view, html} = live(admin_conn, "/dashboard")

    assert html =~ "Query Tracking"
    assert html =~ "agent supervision"
    assert html =~ "what is cmd/2?"
    assert has_element?(view, "button[phx-click='refresh_query_tracking']", "Refresh query logs")
  end

  defp close_browser(view) do
    GenServer.stop(view.pid)
  rescue
    _ -> :ok
  end

  defp live_presence_counts(view) do
    html = render(view)
    {:ok, document} = Floki.parse_document(html)

    [presence_node] = Floki.find(document, "#dashboard-live-presence")

    visitors =
      presence_node
      |> Floki.attribute("data-active-visitors")
      |> List.first()
      |> String.to_integer()

    sessions =
      presence_node
      |> Floki.attribute("data-active-sessions")
      |> List.first()
      |> String.to_integer()

    {visitors, sessions}
  end

  defp assert_eventually(fun, attempts \\ 30)

  defp assert_eventually(fun, attempts) when attempts > 0 do
    if fun.() do
      :ok
    else
      Process.sleep(40)
      assert_eventually(fun, attempts - 1)
    end
  end

  defp assert_eventually(_fun, 0), do: flunk("expected condition to become true")
end
