defmodule AgentJidoWeb.JidoHomeLiveTest do
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  @endpoint AgentJidoWeb.Endpoint

  setup_all do
    Enum.each(
      [:telemetry, :phoenix_pubsub, :phoenix, :phoenix_live_view, :jido_action, :jido_browser],
      &ensure_started/1
    )

    if Process.whereis(AgentJido.PubSub) == nil do
      start_supervised!({Phoenix.PubSub, name: AgentJido.PubSub})
    end

    if Process.whereis(AgentJidoWeb.Endpoint) == nil do
      start_supervised!(AgentJidoWeb.Endpoint)
    end

    :ok
  end

  setup do
    {:ok, conn: build_conn()}
  end

  describe "home hero" do
    test "secondary proof CTA links to the runnable failure-drill example", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "RUN A FAILURE DRILL"
      assert html =~ ~s(href="/examples/failure-drill-agent")
    end
  end

  describe "home adoption message (E04-T09)" do
    test "the lowest-risk adoption message appears directly after the hero", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      # The adoption heading is present on the home page.
      assert {adoption_idx, _} = :binary.match(html, "Start with one Agent")

      # It sits after the hero headline...
      assert {hero_idx, _} = :binary.match(html, "Build long-running agents")
      assert adoption_idx > hero_idx

      # ...and before the deeper sections (the quick-start "first proof"),
      # so the lowest-risk adoption message appears early.
      assert {quick_start_idx, _} = :binary.match(html, "Quick start")
      assert adoption_idx < quick_start_idx
    end

    test "the adoption message links to one-agent integration guidance", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "Lowest-risk way to start"
      assert html =~ ~s(href="/features/start-small")
    end
  end

  describe "home Agent model section (E04-T10)" do
    test "renders the four-part Agent model section after the first proof", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ ~s(id="agent-model")
      assert html =~ "How an agent is built"

      # It follows the quick-start proof, not before it.
      assert {quick_start_idx, _} = :binary.match(html, ~s(id="quick-start"))
      assert {model_idx, _} = :binary.match(html, ~s(id="agent-model"))
      assert model_idx > quick_start_idx
    end

    test "each of the four parts is present", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      for part <- ["State", "Lifecycle", "Typed boundaries", "Visible effects"] do
        assert html =~ part
      end
    end

    test "each card maps to a named Jido concept", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      # The acceptance condition: every card maps to one of these concepts.
      for concept <- ["Agent", "AgentServer", "Action / Signal", "Directive"] do
        assert html =~ "maps to #{concept}"
      end
    end

    test "each part maps to exactly its concept", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      # Parse each model card and pair its part with the concept it maps to.
      cards =
        html
        |> Floki.parse_document!()
        |> Floki.find("#agent-model article[data-agent-model-part]")
        |> Map.new(fn card ->
          {Floki.attribute(card, "data-agent-model-part") |> hd(), Floki.attribute(card, "data-maps-to") |> hd()}
        end)

      assert cards == %{
               "State" => "Agent",
               "Lifecycle" => "AgentServer",
               "Typed boundaries" => "Action / Signal",
               "Visible effects" => "Directive"
             }
    end
  end

  describe "home use-case cards (E04-T21)" do
    test "every card links to a unique scoped destination, not the unfiltered index", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      hrefs =
        html
        |> Floki.parse_document!()
        |> Floki.find("#what-you-can-build a.home-pillar-card")
        |> Floki.attribute("href")

      # Six cards, each with a destination.
      assert length(hrefs) == 6

      # Acceptance condition: no two cards default to the same unfiltered index.
      # Each destination is unique...
      assert length(Enum.uniq(hrefs)) == 6
      # ...and none is the bare unfiltered /examples index.
      refute "/examples" in hrefs

      # Every destination is scoped to its own use case.
      for href <- hrefs do
        assert String.starts_with?(href, "/examples?use_case=")
      end

      scopes = Enum.map(hrefs, &String.replace_prefix(&1, "/examples?use_case=", ""))

      assert Enum.sort(scopes) ==
               Enum.sort(~w(coding research documents support devops data-pipelines))
    end
  end

  defp ensure_started(app) do
    case Application.ensure_all_started(app) do
      {:ok, _apps} -> :ok
      {:error, {:already_started, _app}} -> :ok
      {:error, reason} -> raise "failed to start #{inspect(app)}: #{inspect(reason)}"
    end
  end
end
