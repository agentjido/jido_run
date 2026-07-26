defmodule AgentJidoWeb.JidoEcosystemLiveTest do
  use AgentJidoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias AgentJido.Ecosystem
  alias AgentJido.Ecosystem.{Layering, Stacks, SupportLevel}

  test "renders ecosystem package directory and links all public packages", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/ecosystem")

    assert html =~ "PACKAGE ECOSYSTEM"
    assert html =~ "SUPPORT LEVELS"
    assert html =~ "Select one or more support levels."
    assert html =~ "Stable"
    assert html =~ "Beta"
    assert html =~ "Experimental"
    refute html =~ "Ongoing maintenance, compatibility work, and careful API evolution."
    assert html =~ "PACKAGE EXPLORER"
    assert html =~ "ECOSYSTEM MAP"
    assert html =~ "COMPARE PACKAGES"
    assert html =~ "Support Level"
    refute html =~ "GitHub Stars"
    assert html =~ ~s(id="ecosystem-orbit")
    assert html =~ ~s(phx-hook="EcosystemOrbit")
    refute html =~ "DEPENDENCY GRAPH"
    refute html =~ "jido_coder"
    refute html =~ ~s(href="/ecosystem/matrix")
    refute html =~ "LAYERED ECOSYSTEM MAP"
    assert html =~ ~s(href="/docs/contributors/package-support-levels")
    assert html =~ ~s(type="application/ld+json")
    assert html =~ ~s("ItemList")

    for pkg <- Ecosystem.public_packages() do
      assert html =~ pkg.name
      assert html =~ ~s(href="/ecosystem/#{pkg.id}")
    end
  end

  test "shows public package count in page stats", %{conn: conn} do
    package_count = length(Ecosystem.public_packages())

    {:ok, _view, html} = live(conn, "/ecosystem")

    assert html =~ ~r/#{package_count}\s*<\/span>\s*<span class="text-muted-foreground text-xs">packages<\/span>/
  end

  test "support level cards filter the ecosystem statefully", %{conn: conn} do
    stable_package = package_for_support_level!(:stable)
    beta_package = package_for_support_level!(:beta)
    experimental_package = package_for_support_level(:experimental)

    {:ok, view, html} = live(conn, "/ecosystem")

    assert html =~ explorer_card_label(stable_package)
    assert html =~ explorer_card_label(beta_package)

    if experimental_package do
      assert html =~ explorer_card_label(experimental_package)
    end

    view
    |> element("#support-level-stable")
    |> render_click()

    stable_patch = assert_patch(view)
    assert URI.parse(stable_patch).path == "/ecosystem"
    assert URI.parse(stable_patch).query |> URI.decode_query() == %{"support_levels" => "stable"}

    stable_html = render(view)
    assert stable_html =~ explorer_card_label(stable_package)
    refute stable_html =~ explorer_card_label(beta_package)

    if experimental_package do
      refute stable_html =~ explorer_card_label(experimental_package)
    end

    view
    |> element("#support-level-beta")
    |> render_click()

    stable_beta_patch = assert_patch(view)
    assert URI.parse(stable_beta_patch).path == "/ecosystem"
    assert URI.parse(stable_beta_patch).query |> URI.decode_query() == %{"support_levels" => "stable,beta"}

    stable_beta_html = render(view)
    assert stable_beta_html =~ explorer_card_label(stable_package)
    assert stable_beta_html =~ explorer_card_label(beta_package)

    if experimental_package do
      refute stable_beta_html =~ explorer_card_label(experimental_package)
    end

    view
    |> element("#support-level-stable")
    |> render_click()

    beta_patch = assert_patch(view)
    assert URI.parse(beta_patch).path == "/ecosystem"
    assert URI.parse(beta_patch).query |> URI.decode_query() == %{"support_levels" => "beta"}

    beta_html = render(view)
    refute beta_html =~ explorer_card_label(stable_package)
    assert beta_html =~ explorer_card_label(beta_package)

    if experimental_package do
      refute beta_html =~ explorer_card_label(experimental_package)
    end

    view
    |> element("#support-level-beta")
    |> render_click()

    assert_patch(view, "/ecosystem")

    reset_html = render(view)
    assert reset_html =~ explorer_card_label(stable_package)
    assert reset_html =~ explorer_card_label(beta_package)

    if experimental_package do
      assert reset_html =~ explorer_card_label(experimental_package)
    end
  end

  test "layer filters patch the URL and update the ecosystem explorer statefully", %{conn: conn} do
    foundation_package = package_for_layer!(:foundation)
    app_package = package_for_layer!(:app)

    {:ok, view, html} = live(conn, "/ecosystem")

    assert html =~ explorer_card_label(foundation_package)
    assert html =~ explorer_card_label(app_package)

    view
    |> element("#layer-filter-foundation")
    |> render_click()

    assert_patch(view, "/ecosystem?layer=foundation")

    foundation_html = render(view)
    assert foundation_html =~ explorer_card_label(foundation_package)
    refute foundation_html =~ explorer_card_label(app_package)

    view
    |> element("#layer-filter-foundation")
    |> render_click()

    assert_patch(view, "/ecosystem")
  end

  test "compare table pins jido first and renders icon links", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/ecosystem")

    {jido_index, _} = :binary.match(html, ~s(id="compare-row-jido"))
    {action_index, _} = :binary.match(html, ~s(id="compare-row-jido_action"))

    assert jido_index < action_index
    assert html =~ ~s(aria-label="Open HexDocs for Jido")
    assert html =~ ~s(aria-label="Open Hex.pm for Jido")
    assert html =~ ~s(aria-label="Open GitHub for Jido")
  end

  test "orbit payload marks chat adapters as moons of jido_chat", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/ecosystem")

    assert html =~ "jido_chat_discord"
    assert html =~ "jido_chat_mattermost"
    assert html =~ "jido_chat_telegram"
    assert html =~ ~s(orbit_parent&quot;:&quot;jido_chat&quot;)
  end

  describe "stack compatibility matrix (jido-e09-t36)" do
    # Acceptance condition: supported package ranges are explicit. The matrix is
    # the consolidated view of the three recommended stacks, with each package's
    # explicit supported range derived from the same registry as the home
    # dependency blocks, so the two never drift.

    test "renders the three stacks with an explicit range for every package", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/ecosystem")

      assert html =~ "STACK COMPATIBILITY"
      assert html =~ "Supported range"

      rows = stack_matrix_rows(html)
      matrix = Stacks.matrix()

      # One row per stack package, keyed by stack + package name.
      assert Map.keys(rows) |> MapSet.new() ==
               MapSet.new(for s <- matrix, p <- s.packages, do: {s.key, p.name})

      for stack <- matrix, pkg <- stack.packages do
        row = Map.fetch!(rows, {stack.key, pkg.name})

        # The supported range is explicit and matches the registry derivation.
        # Read it from the rendered <code> text (entity-decoded) so the `>` in a
        # Hex pin like "~> 2.0" compares cleanly.
        range_text = row |> Floki.find("code") |> Floki.text() |> String.trim()

        assert range_text == pkg.range,
               "expected #{pkg.name} to show range #{inspect(pkg.range)}, got #{inspect(range_text)}"

        # Every package links to its own detail page.
        href = row |> Floki.find("a") |> Floki.attribute("href") |> List.first()
        assert href == "/ecosystem/#{pkg.name}"
      end
    end

    test "published packages resolve to a Hex major pin and unreleased to GitHub", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/ecosystem")
      rows = stack_matrix_rows(html)

      for %{key: key, packages: packages} <- Stacks.matrix(),
          pkg <- packages do
        range = rows[{key, pkg.name}] |> Floki.find("code") |> Floki.text() |> String.trim()

        case pkg.source do
          :hex ->
            assert range =~ ~r/^~> \d+\.0$/,
                   "expected a Hex major range for #{pkg.name}, got #{inspect(range)}"

          :github ->
            assert range =~ ~r/^github: "/,
                   "expected a GitHub pin for #{pkg.name}, got #{inspect(range)}"
        end
      end
    end

    test "ranges match the home dependency block derivation (no drift)", %{conn: conn} do
      {:ok, _view, _ecosystem_html} = live(conn, "/ecosystem")
      {:ok, _view, home_html} = live(conn, "/")

      # The home page renders each stack's deps block from the same shared
      # module, so every range asserted in the matrix must also appear verbatim
      # in the matching home block (extracted text, so HTML entities resolve).
      home_blocks = home_stack_deps_text(home_html)

      for stack <- Stacks.matrix() do
        block = Map.fetch!(home_blocks, stack.key)

        for pkg <- stack.packages do
          assert block =~ pkg.range,
                 "the #{stack.key} home block does not contain #{pkg.name}'s range #{inspect(pkg.range)}"
        end
      end
    end
  end

  defp stack_matrix_rows(html) do
    html
    |> Floki.parse_document!()
    |> Floki.find("#stack-compatibility tbody[data-stack]")
    |> Enum.flat_map(fn tbody ->
      key = Floki.attribute(tbody, "data-stack") |> List.first()

      for row <- Floki.find(tbody, "tr[data-stack-package]") do
        name = Floki.attribute(row, "data-stack-package") |> List.first()
        {{key, name}, row}
      end
    end)
    |> Map.new()
  end

  defp home_stack_deps_text(html) do
    html
    |> Floki.parse_document!()
    |> Floki.find("#home-ecosystem-section article[data-stack]")
    |> Map.new(fn card ->
      key = Floki.attribute(card, "data-stack") |> List.first()
      snippet = card |> Floki.find(".home-ecosystem-stack-deps-code") |> Floki.text()
      {key, snippet}
    end)
  end

  defp package_for_support_level!(support_level) do
    Ecosystem.public_packages()
    |> Enum.find(&(SupportLevel.normalize(&1.support_level) == support_level))
    |> case do
      nil -> flunk("expected a public package with support level #{inspect(support_level)}")
      pkg -> pkg
    end
  end

  defp package_for_support_level(support_level) do
    Ecosystem.public_packages()
    |> Enum.find(&(SupportLevel.normalize(&1.support_level) == support_level))
  end

  defp package_for_layer!(layer) do
    Ecosystem.public_packages()
    |> Enum.find(&(Layering.layer_for(&1) == layer))
    |> case do
      nil -> flunk("expected a public package in layer #{inspect(layer)}")
      pkg -> pkg
    end
  end

  defp explorer_card_label(pkg), do: ~s(aria-label="View #{pkg.name} package details")
end
