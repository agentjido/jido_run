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

  describe "home use-case card status labels (E04-T22)" do
    # Acceptance condition: a visitor can distinguish a runnable example from a
    # planned pattern. Every card carries a status that matches whether a public
    # example actually exists, so the label tracks reality as examples land.

    test "each card shows a runnable or planned status", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      status_by_use_case = use_case_statuses(html)

      # All six cards carry a status label.
      assert map_size(status_by_use_case) == 6

      statuses = Map.values(status_by_use_case)

      assert Enum.all?(statuses, &(&1 in ~w(runnable planned)))
      # Both kinds are visible, so the two states are distinguishable on the page.
      assert "runnable" in statuses
      assert "planned" in statuses
    end

    test "the status matches whether a public example exists", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      status_by_use_case = use_case_statuses(html)

      expected =
        AgentJido.Examples.UseCases.all()
        |> Map.new(fn %{slug: slug} ->
          {slug, if(AgentJido.Examples.UseCases.available?(slug), do: "runnable", else: "planned")}
        end)

      # The rendered label is derived from the same source of truth as the scoped
      # examples destination, so a card never says "runnable" over an empty scope.
      assert status_by_use_case == expected
    end

    test "runnable and planned cards render distinct, human-readable labels", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      label_by_use_case =
        html
        |> Floki.parse_document!()
        |> Floki.find("#what-you-can-build a.home-pillar-card")
        |> Map.new(fn card ->
          use_case = Floki.attribute(card, "data-use-case") |> hd()
          label = card |> Floki.find(".home-use-case-status") |> Floki.text() |> String.trim()
          {use_case, label}
        end)

      # The copy maps 1:1 to the acceptance condition language and tracks the
      # same source of truth as the status, so a runnable card never reads
      # "Planned pattern" and vice versa.
      for %{slug: slug} <- AgentJido.Examples.UseCases.all() do
        expected =
          if AgentJido.Examples.UseCases.available?(slug),
            do: "Runnable example",
            else: "Planned pattern"

        assert label_by_use_case[slug] == expected
      end

      # Both labels are present on the page, so the two states are distinguishable.
      labels = MapSet.new(Map.values(label_by_use_case))

      assert MapSet.subset?(
               MapSet.new(["Runnable example", "Planned pattern"]),
               labels
             )
    end
  end

  describe "home ecosystem starting stacks (E04-T24)" do
    # Acceptance condition: the first view is Core, AI, and Operate — three
    # named, explained starting stacks — not nine unexplained package names.

    test "renders three recommended starting stacks named Core, AI, and Operate in order", %{
      conn: conn
    } do
      {:ok, _view, html} = live(conn, "/")

      stacks = home_ecosystem_stacks(html)

      assert Enum.map(stacks, &elem(&1, 0)) == ~w(core ai operate)
      assert Enum.map(stacks, fn {_key, stack} -> stack.name end) == ~w(Core AI Operate)
    end

    test "each stack explains what it is for, so the names are not unexplained", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      for {key, %{purpose: purpose}} <- home_ecosystem_stacks(html) do
        assert is_binary(purpose) and byte_size(purpose) > 0,
               "expected the #{key} stack to carry a one-line purpose"
      end
    end

    test "the Core stack is marked as the recommended place to start", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      stacks = Map.new(home_ecosystem_stacks(html))

      assert stacks["core"].start
      refute stacks["ai"].start
      refute stacks["operate"].start
    end

    test "the old vague category headers are gone", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      refute html =~ "Add AI when ready"
      refute html =~ "Integrate and extend"
    end
  end

  defp home_ecosystem_stacks(html) do
    html
    |> Floki.parse_document!()
    |> Floki.find("#home-ecosystem-section article[data-stack]")
    |> Enum.map(fn card ->
      key = Floki.attribute(card, "data-stack") |> hd()
      name = card |> Floki.find(".home-ecosystem-row-title") |> Floki.text() |> String.trim()
      purpose = card |> Floki.find(".home-ecosystem-stack-purpose") |> Floki.text() |> String.trim()
      has_start = card |> Floki.find(".home-ecosystem-start-badge") |> Enum.any?()
      {key, %{name: name, purpose: purpose, start: has_start}}
    end)
  end

  defp use_case_statuses(html) do
    html
    |> Floki.parse_document!()
    |> Floki.find("#what-you-can-build a.home-pillar-card")
    |> Map.new(fn card ->
      use_case = Floki.attribute(card, "data-use-case") |> hd()
      status = Floki.attribute(card, "data-status") |> hd()
      {use_case, status}
    end)
  end

  defp ensure_started(app) do
    case Application.ensure_all_started(app) do
      {:ok, _apps} -> :ok
      {:error, {:already_started, _app}} -> :ok
      {:error, reason} -> raise "failed to start #{inspect(app)}: #{inspect(reason)}"
    end
  end
end
