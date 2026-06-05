defmodule AgentJido.Analytics.IngestionTest do
  use AgentJido.DataCase, async: false

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
  alias AgentJido.Analytics.Ingestion.TrackedHexPackage
  alias AgentJido.Analytics.Ingestion.TrackedRepository

  describe "tracked repositories" do
    test "upserts tracked repositories by provider owner and name" do
      assert {:ok, %TrackedRepository{} = repo} =
               Ingestion.upsert_tracked_repository(%{
                 owner: "agentjido",
                 name: "jido",
                 label: "Jido"
               })

      assert repo.full_name == "agentjido/jido"
      assert repo.url == "https://github.com/agentjido/jido"

      assert {:ok, %TrackedRepository{id: same_id} = updated} =
               Ingestion.upsert_tracked_repository(%{
                 owner: "agentjido",
                 name: "jido",
                 label: "Jido Core",
                 metadata: %{"tier" => "core"}
               })

      assert same_id == repo.id
      assert updated.label == "Jido Core"
      assert updated.metadata == %{"tier" => "core"}
      assert Repo.aggregate(TrackedRepository, :count, :id) == 1
    end

    test "syncs default Jido repositories from the ecosystem registry" do
      assert %{inserted_or_updated: count, errors: []} = Ingestion.sync_repositories_from_ecosystem()
      assert count > 2

      names =
        TrackedRepository
        |> select([r], r.full_name)
        |> Repo.all()

      assert "agentjido/jido_run" in names
      assert "agentjido/jido" in names
    end

    test "upserts tracked Hex packages by package name" do
      assert {:ok, %TrackedHexPackage{} = package} =
               Ingestion.upsert_tracked_hex_package(%{
                 package_name: "jido",
                 display_name: "Jido"
               })

      assert package.url == "https://hex.pm/packages/jido"

      assert {:ok, %TrackedHexPackage{id: same_id} = updated} =
               Ingestion.upsert_tracked_hex_package(%{
                 package_name: "jido",
                 display_name: "Jido Core",
                 metadata: %{"tier" => "core"}
               })

      assert same_id == package.id
      assert updated.display_name == "Jido Core"
      assert updated.metadata == %{"tier" => "core"}
      assert Repo.aggregate(TrackedHexPackage, :count, :id) == 1
    end

    test "syncs default Hex packages from the ecosystem registry" do
      assert %{inserted_or_updated: count, errors: []} = Ingestion.sync_hex_packages_from_ecosystem()
      assert count > 2

      names =
        TrackedHexPackage
        |> select([p], p.package_name)
        |> Repo.all()

      assert "jido" in names
      assert "jido_ai" in names
    end
  end

  describe "metric upserts" do
    setup do
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

    test "upserts GitHub daily traffic and replaces ranked snapshots", %{repo: repo} do
      assert 3 =
               Ingestion.upsert_github_traffic(repo, %{
                 daily: [
                   %{day: ~D[2026-06-01], views_count: 10, views_uniques: 4, clones_count: 3, clones_uniques: 2}
                 ],
                 referrers: [%{referrer: "Google", count: 8, uniques: 5}],
                 paths: [%{path: "/agentjido/jido", title: "Jido", count: 9, uniques: 6}],
                 snapshot_date: ~D[2026-06-02]
               })

      assert %GitHubRepoDaily{views_count: 10, clones_count: 3} = Repo.one!(GitHubRepoDaily)
      assert %GitHubReferrerSnapshot{referrer: "Google", rank: 1} = Repo.one!(GitHubReferrerSnapshot)
      assert %GitHubPathSnapshot{path: "/agentjido/jido", rank: 1} = Repo.one!(GitHubPathSnapshot)

      assert 2 =
               Ingestion.upsert_github_traffic(repo, %{
                 daily: [],
                 referrers: [%{referrer: "github.com", count: 2, uniques: 1}],
                 paths: [%{path: "/agentjido/jido/blob/main/README.md", title: "README", count: 4, uniques: 3}],
                 snapshot_date: ~D[2026-06-02]
               })

      assert Repo.aggregate(GitHubReferrerSnapshot, :count, :id) == 1
      assert Repo.one!(GitHubReferrerSnapshot).referrer == "github.com"
      assert Repo.aggregate(GitHubPathSnapshot, :count, :id) == 1
      assert Repo.one!(GitHubPathSnapshot).path == "/agentjido/jido/blob/main/README.md"
    end

    test "upserts Plausible daily and dimension rows" do
      assert 1 =
               Ingestion.upsert_plausible_site_daily("jido.run", [
                 %{
                   day: ~D[2026-06-01],
                   visitors: 100,
                   visits: 120,
                   pageviews: 240,
                   bounce_rate: 42.5,
                   visit_duration: 61,
                   events: 260
                 }
               ])

      assert 1 =
               Ingestion.upsert_plausible_dimension_daily("jido.run", [
                 %{
                   day: ~D[2026-06-01],
                   dimension: "event:page",
                   value: "/docs",
                   visitors: 50,
                   visits: 60,
                   pageviews: 90,
                   events: 92
                 }
               ])

      assert %PlausibleSiteDaily{visitors: 100, bounce_rate: 42.5} = Repo.one!(PlausibleSiteDaily)
      assert %PlausibleDimensionDaily{dimension: "event:page", value: "/docs", visitors: 50} = Repo.one!(PlausibleDimensionDaily)
    end

    test "upserts Search Console rows by dimension key" do
      assert 1 =
               Ingestion.upsert_search_console_daily("sc-domain:jido.run", [
                 %{
                   day: ~D[2026-06-01],
                   dimension_set: "date+query+page",
                   dimension_key: "query-page-key",
                   query: "jido agents",
                   page: "https://jido.run/docs",
                   clicks: 12,
                   impressions: 120,
                   ctr: 0.1,
                   position: 3.2
                 }
               ])

      assert %SearchConsoleDaily{query: "jido agents", clicks: 12, position: 3.2} = Repo.one!(SearchConsoleDaily)
    end

    test "upserts Hex package and release snapshots", %{package: package} do
      assert 2 =
               Ingestion.upsert_hex_package_stats(package, %{
                 package: %{
                   day: ~D[2026-06-05],
                   package_name: "jido",
                   latest_version: "2.3.1",
                   downloads_day: 750,
                   downloads_week: 4_718,
                   downloads_recent: 49_853,
                   downloads_all: 69_747
                 },
                 releases: [
                   %{
                     day: ~D[2026-06-05],
                     package_name: "jido",
                     version: "2.3.1",
                     downloads_total: 344,
                     release_inserted_at: "2026-06-02T16:38:10.301290Z",
                     has_docs: true
                   }
                 ]
               })

      assert %HexPackageDaily{latest_version: "2.3.1", downloads_all: 69_747} = Repo.one!(HexPackageDaily)
      assert %HexReleaseDaily{version: "2.3.1", downloads_total: 344, has_docs: true} = Repo.one!(HexReleaseDaily)
    end
  end

  describe "ingestion runs" do
    test "sanitizes provider response bodies when marking a run failed" do
      run = Ingestion.start_run("plausible")

      assert %IngestionRun{error: ":plausible_unauthorized"} =
               Ingestion.fail_run(run, {:plausible_unauthorized, "provider body"})
    end
  end
end
