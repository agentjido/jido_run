defmodule AgentJido.Analytics.IngestionWorkersTest do
  use AgentJido.DataCase, async: false
  use Oban.Testing, repo: AgentJido.Repo

  alias AgentJido.Analytics.Ingestion
  alias AgentJido.Analytics.Ingestion.GitHubPathSnapshot
  alias AgentJido.Analytics.Ingestion.GitHubReferrerSnapshot
  alias AgentJido.Analytics.Ingestion.GitHubRepoDaily
  alias AgentJido.Analytics.Ingestion.HexPackageDaily
  alias AgentJido.Analytics.Ingestion.HexReleaseDaily
  alias AgentJido.Analytics.Ingestion.IngestionRun
  alias AgentJido.Analytics.Ingestion.PlausibleDimensionDaily
  alias AgentJido.Analytics.Ingestion.PlausibleSiteDaily
  alias AgentJido.Analytics.Ingestion.SearchConsoleDaily
  alias AgentJido.Analytics.Ingestion.Workers.DispatcherWorker
  alias AgentJido.Analytics.Ingestion.Workers.GitHubTrafficWorker
  alias AgentJido.Analytics.Ingestion.Workers.HexWorker
  alias AgentJido.Analytics.Ingestion.Workers.PlausibleWorker
  alias AgentJido.Analytics.Ingestion.Workers.SearchConsoleWorker

  defmodule GitHubClientStub do
    def fetch(_repository, _opts) do
      {:ok,
       %{
         daily: [%{day: ~D[2026-06-01], views_count: 10, views_uniques: 4, clones_count: 3, clones_uniques: 2}],
         referrers: [%{referrer: "Google", count: 8, uniques: 5}],
         paths: [%{path: "/agentjido/jido", title: "Jido", count: 9, uniques: 6}],
         snapshot_date: ~D[2026-06-02],
         metadata: %{"stubbed" => true}
       }}
    end
  end

  defmodule PlausibleClientStub do
    def fetch(_site_id, opts) do
      Process.put(:plausible_fetch_opts, opts)

      {:ok,
       %{
         daily: [%{day: ~D[2026-06-01], visitors: 100, visits: 120, pageviews: 240, events: 260}],
         dimensions: [%{day: ~D[2026-06-01], dimension: "visit:source", value: "Google", visitors: 40, visits: 45, pageviews: 80, events: 81}]
       }}
    end
  end

  defmodule SearchConsoleClientStub do
    def fetch(_site_url, opts) do
      Process.put(:search_console_fetch_opts, opts)

      {:ok,
       %{
         rows: [
           %{
             day: ~D[2026-06-01],
             dimension_set: "date+query",
             dimension_key: "query-key",
             query: "jido",
             clicks: 12,
             impressions: 120,
             ctr: 0.1,
             position: 2.5
           }
         ]
       }}
    end
  end

  defmodule HexClientStub do
    def fetch(%{package_name: "unpublished_package"}, _opts) do
      {:error, {:hex_package_not_found, "unpublished_package"}}
    end

    def fetch(package, opts) do
      Process.put(:hex_fetch_opts, opts)

      {:ok,
       %{
         package: %{
           day: opts[:snapshot_date],
           package_name: package.package_name,
           latest_version: "2.3.1",
           downloads_day: 10,
           downloads_week: 70,
           downloads_recent: 300,
           downloads_all: 1_000
         },
         releases: [
           %{
             day: opts[:snapshot_date],
             package_name: package.package_name,
             version: "2.3.1",
             downloads_total: 100,
             release_inserted_at: "2026-06-02T16:38:10.301290Z",
             has_docs: true
           }
         ]
       }}
    end
  end

  setup do
    Process.delete(:hex_fetch_opts)
    Process.delete(:plausible_fetch_opts)
    Process.delete(:search_console_fetch_opts)

    original = Application.get_env(:agent_jido, Ingestion)

    Application.put_env(
      :agent_jido,
      Ingestion,
      Keyword.merge(original,
        github_token: "test-github-token",
        plausible_api_key: "test-plausible-key",
        plausible_site_id: "jido.run",
        search_console_site_url: "sc-domain:jido.run",
        search_console_credentials_json: ~s({"client_email":"test@example.test","private_key":"test"}),
        github_client: GitHubClientStub,
        hex_client: HexClientStub,
        plausible_client: PlausibleClientStub,
        search_console_client: SearchConsoleClientStub
      )
    )

    on_exit(fn -> Application.put_env(:agent_jido, Ingestion, original) end)

    {:ok, repo} =
      Ingestion.upsert_tracked_repository(%{
        owner: "agentjido",
        name: "jido",
        label: "Jido"
      })

    {:ok, package} =
      Ingestion.upsert_tracked_hex_package(%{
        package_name: "jido",
        display_name: "Jido"
      })

    %{package: package, repo: repo}
  end

  test "dispatcher enqueues GitHub traffic jobs for tracked repositories", %{repo: repo} do
    assert :ok =
             perform_job(DispatcherWorker, %{
               "date_from" => "2026-06-01",
               "date_to" => "2026-06-02"
             })

    assert_enqueued(
      worker: GitHubTrafficWorker,
      args: %{"tracked_repository_id" => repo.id, "date_from" => "2026-06-01", "date_to" => "2026-06-02"}
    )
  end

  test "GitHub worker stores traffic rows and completes an ingestion run", %{repo: repo} do
    assert :ok =
             perform_job(GitHubTrafficWorker, %{
               "tracked_repository_id" => repo.id,
               "date_from" => "2026-06-01",
               "date_to" => "2026-06-02"
             })

    assert %GitHubRepoDaily{views_count: 10, clones_count: 3} = Repo.one!(GitHubRepoDaily)
    assert %IngestionRun{source: "github_traffic", status: "completed", rows_count: 3} = Repo.one!(IngestionRun)
  end

  test "GitHub worker can rerun the same window without duplicating metric rows", %{repo: repo} do
    args = %{
      "tracked_repository_id" => repo.id,
      "date_from" => "2026-06-01",
      "date_to" => "2026-06-02"
    }

    assert :ok = perform_job(GitHubTrafficWorker, args)
    assert :ok = perform_job(GitHubTrafficWorker, args)

    assert Repo.aggregate(GitHubRepoDaily, :count, :id) == 1
    assert Repo.aggregate(GitHubReferrerSnapshot, :count, :id) == 1
    assert Repo.aggregate(GitHubPathSnapshot, :count, :id) == 1
    assert Repo.aggregate(IngestionRun, :count, :id) == 2
  end

  test "GitHub worker accepts GitHub App auth without a PAT", %{repo: repo} do
    original = Application.get_env(:agent_jido, Ingestion)

    Application.put_env(
      :agent_jido,
      Ingestion,
      Keyword.merge(original,
        github_token: nil,
        github_app_id: "3971655",
        github_app_installation_id: "138216290",
        github_app_private_key: "test-private-key"
      )
    )

    assert :ok =
             perform_job(GitHubTrafficWorker, %{
               "tracked_repository_id" => repo.id,
               "date_from" => "2026-06-01",
               "date_to" => "2026-06-02"
             })

    assert %GitHubRepoDaily{views_count: 10, clones_count: 3} = Repo.one!(GitHubRepoDaily)
  end

  test "Plausible worker stores daily rows" do
    assert :ok =
             perform_job(PlausibleWorker, %{
               "date_from" => "2026-06-01",
               "date_to" => "2026-06-02"
             })

    assert %PlausibleSiteDaily{visitors: 100, pageviews: 240} = Repo.one!(PlausibleSiteDaily)
    assert %IngestionRun{source: "plausible", status: "completed", rows_count: 2} = Repo.one!(IngestionRun)
  end

  test "Plausible worker can rerun the same window without duplicating metric rows" do
    args = %{
      "date_from" => "2026-06-01",
      "date_to" => "2026-06-02"
    }

    assert :ok = perform_job(PlausibleWorker, args)
    assert :ok = perform_job(PlausibleWorker, args)

    assert Repo.aggregate(PlausibleSiteDaily, :count, :id) == 1
    assert Repo.aggregate(PlausibleDimensionDaily, :count, :id) == 1
    assert Repo.aggregate(IngestionRun, :count, :id) == 2
  end

  test "Plausible worker defaults to a rolling configured window" do
    assert :ok = perform_job(PlausibleWorker, %{})

    date_to = Date.add(Date.utc_today(), -1)

    assert Keyword.take(Process.get(:plausible_fetch_opts), [:date_from, :date_to]) == [
             date_from: Date.add(date_to, -29),
             date_to: date_to
           ]
  end

  test "Search Console worker stores bounded rows" do
    assert :ok =
             perform_job(SearchConsoleWorker, %{
               "date_from" => "2026-06-01",
               "date_to" => "2026-06-02"
             })

    assert %SearchConsoleDaily{query: "jido", clicks: 12} = Repo.one!(SearchConsoleDaily)
    assert %IngestionRun{source: "search_console", status: "completed", rows_count: 1} = Repo.one!(IngestionRun)
  end

  test "Search Console worker can rerun the same window without duplicating metric rows" do
    args = %{
      "date_from" => "2026-06-01",
      "date_to" => "2026-06-02"
    }

    assert :ok = perform_job(SearchConsoleWorker, args)
    assert :ok = perform_job(SearchConsoleWorker, args)

    assert Repo.aggregate(SearchConsoleDaily, :count, :id) == 1
    assert Repo.aggregate(IngestionRun, :count, :id) == 2
  end

  test "Search Console worker defaults to a lagged rolling configured window" do
    assert :ok = perform_job(SearchConsoleWorker, %{})

    date_to = Date.add(Date.utc_today(), -3)

    assert Keyword.take(Process.get(:search_console_fetch_opts), [:date_from, :date_to]) == [
             date_from: Date.add(date_to, -13),
             date_to: date_to
           ]
  end

  test "Hex worker stores package and release snapshots", %{package: package} do
    assert :ok =
             perform_job(HexWorker, %{
               "snapshot_date" => "2026-06-05"
             })

    package_id = package.id

    assert %HexPackageDaily{
             tracked_hex_package_id: ^package_id,
             package_name: "jido",
             latest_version: "2.3.1",
             downloads_all: 1_000
           } = Repo.one!(HexPackageDaily)

    assert %HexReleaseDaily{version: "2.3.1", downloads_total: 100, has_docs: true} = Repo.one!(HexReleaseDaily)
    assert %IngestionRun{source: "hex", status: "completed", rows_count: 2} = Repo.one!(IngestionRun)
    assert Keyword.fetch!(Process.get(:hex_fetch_opts), :snapshot_date) == ~D[2026-06-05]
  end

  test "Hex worker can rerun the same snapshot date without duplicating metric rows" do
    args = %{"snapshot_date" => "2026-06-05"}

    assert :ok = perform_job(HexWorker, args)
    assert :ok = perform_job(HexWorker, args)

    assert Repo.aggregate(HexPackageDaily, :count, :id) == 1
    assert Repo.aggregate(HexReleaseDaily, :count, :id) == 1
    assert Repo.aggregate(IngestionRun, :count, :id) == 2
  end

  test "Hex worker skips packages that are not published on Hex" do
    assert {:ok, _package} =
             Ingestion.upsert_tracked_hex_package(%{
               package_name: "unpublished_package",
               display_name: "Unpublished"
             })

    assert :ok = perform_job(HexWorker, %{"snapshot_date" => "2026-06-05"})

    assert Repo.aggregate(HexPackageDaily, :count, :id) == 1
    assert %IngestionRun{source: "hex", status: "completed", rows_count: 2, metadata: metadata} = Repo.one!(IngestionRun)
    assert metadata["skipped_packages"] == ["unpublished_package"]
  end
end
