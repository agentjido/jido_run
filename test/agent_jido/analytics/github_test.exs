defmodule AgentJido.Analytics.GitHubTest do
  use AgentJido.DataCase, async: false

  alias AgentJido.Analytics.GitHub
  alias AgentJido.Analytics.GitHub.Collector

  defmodule TestClient do
    @behaviour Collector.Client

    @impl true
    def fetch_repo_traffic("agentjido", "jido", _opts) do
      {:ok,
       %{
         "views" => [%{"timestamp" => "2026-06-01T00:00:00Z", "count" => 10, "uniques" => 4}],
         "clones" => [%{"timestamp" => "2026-06-01T00:00:00Z", "count" => 3, "uniques" => 2}],
         "referrers" => [%{"referrer" => "github.com", "count" => 7, "uniques" => 5}],
         "paths" => [%{"path" => "/agentjido/jido", "title" => "agentjido/jido", "count" => 9, "uniques" => 6}]
       }}
    end
  end

  describe "GitHub traffic analytics" do
    test "collector persists repo, referrer, and path traffic" do
      assert {:ok, snapshot} = Collector.collect_repo("agentjido/jido", client: TestClient)

      assert [%{repo: "agentjido/jido", views: 10, unique_visitors: 4, clones: 3, unique_cloners: 2}] =
               snapshot.repo_daily

      assert [%{referrer: "github.com", views: 7, uniques: 5}] = snapshot.referrers
      assert [%{path: "/agentjido/jido", title: "agentjido/jido", views: 9, uniques: 6}] = snapshot.paths
    end

    test "upsert_repo_daily replaces an existing daily row" do
      fetched_at = DateTime.utc_now()
      date = ~D[2026-06-01]

      assert {:ok, _row} =
               GitHub.upsert_repo_daily(%{
                 date: date,
                 repo: "agentjido/jido",
                 views: 1,
                 unique_visitors: 1,
                 clones: 1,
                 unique_cloners: 1,
                 fetched_at: fetched_at
               })

      assert {:ok, row} =
               GitHub.upsert_repo_daily(%{
                 date: date,
                 repo: "agentjido/jido",
                 views: 12,
                 unique_visitors: 8,
                 clones: 5,
                 unique_cloners: 3,
                 fetched_at: fetched_at
               })

      assert row.views == 12
      assert [%{views: 12, unique_visitors: 8, clones: 5, unique_cloners: 3}] = GitHub.list_repo_daily("agentjido/jido")
    end
  end
end
