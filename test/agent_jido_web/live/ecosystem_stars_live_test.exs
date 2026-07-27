defmodule AgentJidoWeb.EcosystemStarsLiveTest do
  use AgentJidoWeb.ConnCase, async: false

  @moduletag :slow

  import Phoenix.LiveViewTest

  alias AgentJido.GithubStarsTracker

  defmodule StaticFetcher do
    @behaviour GithubStarsTracker.Fetcher

    @impl true
    def fetch_repo_stars("agentjido", "jido", _opts), do: {:ok, 1_234}
    def fetch_repo_stars("agentjido", "req_llm", _opts), do: {:ok, 432}
    def fetch_repo_stars("agentjido", "jido_action", _opts), do: {:ok, 55}
    def fetch_repo_stars(_owner, _repo, _opts), do: {:error, :missing_fixture}
  end

  setup context do
    if context[:with_tracker] do
      start_supervised!({GithubStarsTracker, repos: repos(), fetcher: StaticFetcher, refresh_interval_ms: :timer.hours(24)})

      assert :ok = GithubStarsTracker.refresh()
    end

    :ok
  end

  @tag with_tracker: true
  test "ecosystem index renders github star labels when cached stars exist", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/ecosystem?map=open")

    assert html =~ ~s(href="https://github.com/agentjido/jido")
    assert html =~ "github ★1.2k"
  end

  @tag with_tracker: true
  test "ecosystem package detail renders github star label when cached stars exist", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/ecosystem/jido")

    assert html =~ ~s(href="https://github.com/agentjido/jido")
    assert html =~ "github ★1.2k"
  end

  @tag with_tracker: true
  test "ecosystem compare section renders github star labels when cached stars exist", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/ecosystem?map=open")

    assert html =~ ~s(href="https://github.com/agentjido/jido")
    assert html =~ "github ★1.2k"
  end

  test "all ecosystem pages fall back to existing github labels when no cached stars exist", %{conn: conn} do
    {:ok, _view, ecosystem_html} = live(conn, "/ecosystem?map=open")
    {:ok, _view, detail_html} = live(recycle(conn), "/ecosystem/jido")

    assert ecosystem_html =~ "github"
    assert detail_html =~ "github"

    refute ecosystem_html =~ "github ★"
    refute detail_html =~ "github ★"
  end

  defp repos do
    %{
      "jido" => %{
        owner: "agentjido",
        repo: "jido",
        github_url: "https://github.com/agentjido/jido"
      },
      "req_llm" => %{
        owner: "agentjido",
        repo: "req_llm",
        github_url: "https://github.com/agentjido/req_llm"
      },
      "jido_action" => %{
        owner: "agentjido",
        repo: "jido_action",
        github_url: "https://github.com/agentjido/jido_action"
      }
    }
  end
end
