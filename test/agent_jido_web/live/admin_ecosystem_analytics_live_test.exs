defmodule AgentJidoWeb.AdminEcosystemAnalyticsLiveTest do
  use AgentJidoWeb.ConnCase, async: false

  import AgentJido.AccountsFixtures
  import Phoenix.LiveViewTest

  alias AgentJido.Analytics.Ingestion.GitHubPathSnapshot
  alias AgentJido.Analytics.Ingestion.GitHubReferrerSnapshot
  alias AgentJido.Analytics.Ingestion.GitHubRepoDaily
  alias AgentJido.Analytics.Ingestion.HexPackageDaily
  alias AgentJido.Analytics.Ingestion.IngestionRun
  alias AgentJido.Analytics.Ingestion.PlausibleDimensionDaily
  alias AgentJido.Analytics.Ingestion.PlausibleSiteDaily
  alias AgentJido.Analytics.Ingestion.SearchConsoleDaily
  alias AgentJido.Analytics.Ingestion.TrackedHexPackage
  alias AgentJido.Analytics.Ingestion.TrackedRepository
  alias AgentJido.QueryLogs
  alias AgentJido.Repo

  setup %{conn: conn} do
    admin_conn = log_in_user(conn, admin_user_fixture())
    %{admin_conn: admin_conn}
  end

  test "redirects unauthenticated users to log in", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, "/dashboard/ecosystem-analytics")
  end

  test "blocks authenticated non-admin users", %{conn: conn} do
    conn = log_in_user(conn, user_fixture())
    assert {:error, {:redirect, %{to: "/"}}} = live(conn, "/dashboard/ecosystem-analytics")
  end

  test "renders ecosystem analytics for admins", %{admin_conn: admin_conn} do
    seed_ecosystem_data()

    {:ok, view, html} = live(admin_conn, "/dashboard/ecosystem-analytics")

    assert has_element?(view, "#admin-shell")

    assert has_element?(
             view,
             "a[data-admin-nav-path='/dashboard/ecosystem-analytics'][data-admin-nav-active='true']",
             "Ecosystem Analytics"
           )

    assert html =~ "Ecosystem Analytics"
    assert html =~ "Acquisition Sources"
    assert html =~ "Collection Coverage"
    assert html =~ "Search Landing Pages"
    assert html =~ "Repo Interest"
    assert html =~ "Package Adoption"
    assert html =~ "GitHub Paths"
    assert html =~ "GitHub Referrers"
    assert html =~ "jido agents"
    assert html =~ "agentjido/jido"
    assert html =~ "jido_ai"
    assert html =~ "/docs"
    assert html =~ "Google"

    html = render_click(view, "set_window", %{"days" => "7"})
    assert html =~ "7d"
  end

  defp seed_ecosystem_data do
    today = Date.utc_today()
    started_at = DateTime.utc_now()

    repository =
      Repo.insert!(%TrackedRepository{
        provider: "github",
        owner: "agentjido",
        name: "jido",
        full_name: "agentjido/jido",
        active: true
      })

    package =
      Repo.insert!(%TrackedHexPackage{
        package_name: "jido_ai",
        display_name: "jido_ai",
        active: true
      })

    Repo.insert!(%IngestionRun{
      source: "github_traffic",
      status: "completed",
      started_at: started_at,
      finished_at: started_at,
      rows_count: 8,
      tracked_repository_id: repository.id
    })

    Repo.insert!(%IngestionRun{
      source: "plausible",
      status: "completed",
      started_at: started_at,
      finished_at: started_at,
      rows_count: 4
    })

    Repo.insert!(%IngestionRun{
      source: "search_console",
      status: "completed",
      started_at: started_at,
      finished_at: started_at,
      rows_count: 4
    })

    Repo.insert!(%IngestionRun{
      source: "hex",
      status: "completed",
      started_at: started_at,
      finished_at: started_at,
      rows_count: 2
    })

    Repo.insert!(%GitHubRepoDaily{
      tracked_repository_id: repository.id,
      day: today,
      views_count: 120,
      views_uniques: 54,
      clones_count: 32,
      clones_uniques: 20
    })

    Repo.insert!(%GitHubPathSnapshot{
      tracked_repository_id: repository.id,
      snapshot_date: today,
      rank: 1,
      path: "/agentjido/jido",
      path_key: "repo-root",
      title: "agentjido/jido",
      count: 60,
      uniques: 28
    })

    Repo.insert!(%GitHubReferrerSnapshot{
      tracked_repository_id: repository.id,
      snapshot_date: today,
      rank: 1,
      referrer: "Google",
      count: 41,
      uniques: 18
    })

    Repo.insert!(%PlausibleSiteDaily{
      site_id: "jido.run",
      day: today,
      visitors: 90,
      visits: 110,
      pageviews: 180,
      events: 12,
      bounce_rate: 42.0,
      visit_duration: 95
    })

    Repo.insert!(%PlausibleDimensionDaily{
      site_id: "jido.run",
      day: today,
      dimension: "visit:source",
      value: "Google",
      value_key: "google",
      visitors: 64,
      visits: 70,
      pageviews: 120,
      events: 8
    })

    Repo.insert!(%PlausibleDimensionDaily{
      site_id: "jido.run",
      day: today,
      dimension: "event:page",
      value: "/docs",
      value_key: "docs",
      visitors: 50,
      visits: 58,
      pageviews: 96,
      events: 4,
      bounce_rate: 35.0
    })

    Repo.insert!(%SearchConsoleDaily{
      site_url: "sc-domain:jido.run",
      day: today,
      dimension_set: "date",
      dimension_key: Date.to_iso8601(today),
      search_type: "web",
      clicks: 12,
      impressions: 400,
      ctr: 0.03,
      position: 5.4
    })

    Repo.insert!(%SearchConsoleDaily{
      site_url: "sc-domain:jido.run",
      day: today,
      dimension_set: "date+query",
      dimension_key: "jido agents",
      search_type: "web",
      query: "jido agents",
      clicks: 2,
      impressions: 120,
      ctr: 0.016,
      position: 7.2
    })

    Repo.insert!(%SearchConsoleDaily{
      site_url: "sc-domain:jido.run",
      day: today,
      dimension_set: "date+page",
      dimension_key: "https://jido.run/docs",
      search_type: "web",
      page: "https://jido.run/docs",
      clicks: 5,
      impressions: 180,
      ctr: 0.027,
      position: 6.0
    })

    Repo.insert!(%HexPackageDaily{
      tracked_hex_package_id: package.id,
      package_name: "jido_ai",
      day: today,
      latest_version: "2.2.0",
      downloads_day: 42,
      downloads_week: 300,
      downloads_recent: 1_200,
      downloads_all: 8_000
    })

    {:ok, _query_log} =
      QueryLogs.create_query_log(%{
        source: "content_assistant",
        channel: "content_assistant_page",
        query: "build a jido agent",
        status: "no_results",
        results_count: 0
      })
  end
end
