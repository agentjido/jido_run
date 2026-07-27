defmodule AgentJidoWeb.JidoEcosystemLiveTest do
  # async: false (like JidoExamplesLiveTest) so the connected LiveView's
  # analytics writes — the ecosystem hub records an `ecosystem_stack_selected`
  # event (jido-e12-t28) when a visitor expands the dependency map or arrives on
  # the ?map=open deep link — share the test's sandbox transaction and roll back,
  # instead of escaping to the shared test database.
  use AgentJidoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias AgentJido.Ecosystem
  alias AgentJido.Ecosystem.{ControlMatrix, Layering, Stacks, SupportLevel}

  test "renders ecosystem package directory and links all public packages", %{conn: conn} do
    # The full catalog lives behind the collapsed dependency map (jido-e09-t38),
    # so open it to assert every public package is linked.
    {:ok, _view, html} = live(conn, "/ecosystem?map=open")

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

    {:ok, view, html} = live(conn, "/ecosystem?map=open")

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
    assert URI.parse(stable_patch).query |> URI.decode_query() == %{"map" => "open", "support_levels" => "stable"}

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
    assert URI.parse(stable_beta_patch).query |> URI.decode_query() == %{"map" => "open", "support_levels" => "stable,beta"}

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
    assert URI.parse(beta_patch).query |> URI.decode_query() == %{"map" => "open", "support_levels" => "beta"}

    beta_html = render(view)
    refute beta_html =~ explorer_card_label(stable_package)
    assert beta_html =~ explorer_card_label(beta_package)

    if experimental_package do
      refute beta_html =~ explorer_card_label(experimental_package)
    end

    view
    |> element("#support-level-beta")
    |> render_click()

    assert_patch(view, "/ecosystem?map=open")

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

    {:ok, view, html} = live(conn, "/ecosystem?map=open")

    assert html =~ explorer_card_label(foundation_package)
    assert html =~ explorer_card_label(app_package)

    view
    |> element("#layer-filter-foundation")
    |> render_click()

    foundation_patch = assert_patch(view)
    assert URI.parse(foundation_patch).path == "/ecosystem"
    assert URI.parse(foundation_patch).query |> URI.decode_query() == %{"layer" => "foundation", "map" => "open"}

    foundation_html = render(view)
    assert foundation_html =~ explorer_card_label(foundation_package)
    refute foundation_html =~ explorer_card_label(app_package)

    view
    |> element("#layer-filter-foundation")
    |> render_click()

    assert_patch(view, "/ecosystem?map=open")
  end

  test "compare table pins jido first and renders icon links", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/ecosystem?map=open")

    {jido_index, _} = :binary.match(html, ~s(id="compare-row-jido"))
    {action_index, _} = :binary.match(html, ~s(id="compare-row-jido_action"))

    assert jido_index < action_index
    assert html =~ ~s(aria-label="Open HexDocs for Jido")
    assert html =~ ~s(aria-label="Open Hex.pm for Jido")
    assert html =~ ~s(aria-label="Open GitHub for Jido")
  end

  test "orbit payload marks chat adapters as moons of jido_chat", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/ecosystem?map=open")

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

  describe "operational-control capability matrix (jido-e09-t49)" do
    # Acceptance condition: a reader can compare context, authorization hooks,
    # policy, quotas, history, observation, export, approval, and integration
    # duties. The matrix is the one consolidated view that exposes all nine
    # dimensions as rows across the control packages and the host application,
    # with a grounded role on every cell.

    test "renders the nine dimensions and every column in one comparison view", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/ecosystem")

      assert html =~ "OPERATIONAL CONTROL"
      assert html =~ "capability matrix"

      # Every dimension the backlog names is a row.
      for capability <- ControlMatrix.capabilities() do
        assert html =~ ~s(id="control-row-#{capability.key}")
        assert html =~ capability.label
      end
    end

    test "package columns link to their ecosystem page; the host column does not", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/ecosystem")

      for column <- ControlMatrix.columns(), column.kind == :package do
        assert html =~ ~s(href="#{column.path}"),
               "expected the #{column.key} column header to link to #{column.path}"
      end

      assert html =~ "Host application"
    end

    test "every cell renders a grounded role tag, in order per row", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/ecosystem")
      rows = control_matrix_rows(html)

      # One row per capability, keyed by capability atom.
      assert Map.keys(rows) |> MapSet.new() == MapSet.new(ControlMatrix.capability_keys())

      for matrix_row <- ControlMatrix.matrix() do
        row = Map.fetch!(rows, matrix_row.key)

        # One cell per column, in display order, each carrying its role.
        roles =
          row
          |> Floki.find("td[data-control-role]")
          |> Enum.map(&(Floki.attribute(&1, "data-control-role") |> List.first()))

        assert roles ==
                 Enum.map(ControlMatrix.columns(), fn column ->
                   matrix_row.cells[column.key].role |> to_string()
                 end)
      end
    end

    test "approval is entirely application-owned — no package overstates an approval control", %{
      conn: conn
    } do
      {:ok, _view, html} = live(conn, "/ecosystem")
      rows = control_matrix_rows(html)
      approval = Map.fetch!(rows, :approval)

      for cell <- Floki.find(approval, "td[data-control-role]") do
        assert Floki.attribute(cell, "data-control-role") |> List.first() == "app"
      end
    end

    test "the legend names all three roles", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/ecosystem")

      assert html =~ "Legend:"
      assert html =~ ControlMatrix.role_label(:supplies)
      assert html =~ ControlMatrix.role_label(:preserves)
      assert html =~ ControlMatrix.role_label(:app)
    end

    test "links the claim boundaries and states the release-basis caveat", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/ecosystem")

      assert html =~ ~s(href="/docs/operations/security-and-governance")
      assert html =~ "Release basis."
    end

    test "the hero deep-links to the matrix", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/ecosystem")

      assert html =~ ~s(href="#operational-control")
      assert html =~ "OPERATIONAL CONTROL ↓"
    end
  end

  describe "dependency map starts collapsed (jido-e09-t38)" do
    # Acceptance condition: new users see recommended stacks before all 47
    # packages. The full catalog — explorer, orbit, and compare — is collapsed
    # behind the dependency-map disclosure by default; the recommended stacks
    # stay first and expanded until the builder opens the map.

    test "the full catalog is collapsed on first load; stacks render first", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/ecosystem")

      # Recommended stacks and operational control are what a new user sees.
      assert html =~ "STACK COMPATIBILITY"
      assert html =~ "OPERATIONAL CONTROL"

      # The dependency-map disclosure is present and collapsed.
      assert html =~ "DEPENDENCY MAP"
      assert html =~ ~s(id="toggle-dependency-map")
      assert html =~ ~s(aria-expanded="false")
      assert html =~ "SHOW ALL"
      assert html =~ "collapsed"

      # The full 47-package catalog is not dumped on the new user.
      refute html =~ "PACKAGE EXPLORER"
      refute html =~ "COMPARE PACKAGES"
      refute html =~ ~s(id="ecosystem-orbit")

      hidden_package = hd(Ecosystem.public_packages())
      refute html =~ explorer_card_label(hidden_package)
    end

    test "stacks render before the dependency-map disclosure", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/ecosystem")

      # The hero deep-link also reads "DEPENDENCY MAP", so anchor on the
      # disclosure's toggle button to locate the actual map section.
      {stacks_index, _} = :binary.match(html, "STACK COMPATIBILITY")
      {disclosure_index, _} = :binary.match(html, ~s(id="toggle-dependency-map"))
      assert stacks_index < disclosure_index
    end

    test "expanding the map reveals the full catalog, then collapsing hides it", %{conn: conn} do
      {:ok, view, collapsed} = live(conn, "/ecosystem")
      refute collapsed =~ "PACKAGE EXPLORER"

      view |> element("#toggle-dependency-map") |> render_click()

      open_patch = assert_patch(view)
      assert URI.parse(open_patch).path == "/ecosystem"
      assert URI.parse(open_patch).query |> URI.decode_query() == %{"map" => "open"}

      expanded = render(view)
      assert expanded =~ "PACKAGE EXPLORER"
      assert expanded =~ "COMPARE PACKAGES"
      assert expanded =~ ~s(id="ecosystem-orbit")
      assert expanded =~ ~s(aria-expanded="true")

      for pkg <- Ecosystem.public_packages() do
        assert expanded =~ ~s(href="/ecosystem/#{pkg.id}")
      end

      # Collapsing again hides the catalog and restores the stacks-first view.
      view |> element("#toggle-dependency-map") |> render_click()
      assert_patch(view, "/ecosystem")
      hidden = render(view)
      refute hidden =~ "PACKAGE EXPLORER"
      assert hidden =~ "STACK COMPATIBILITY"
    end

    test "the ?map=open deep link opens the catalog", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/ecosystem?map=open")

      assert html =~ "PACKAGE EXPLORER"
      assert html =~ "COMPARE PACKAGES"
      assert html =~ ~s(aria-expanded="true")
    end

    test "clearing filters keeps an open map open", %{conn: conn} do
      {:ok, view, html} = live(conn, "/ecosystem?map=open&layer=foundation")
      assert html =~ "PACKAGE EXPLORER"

      view |> element("#reset-filters") |> render_click()

      reset_patch = assert_patch(view)
      assert URI.parse(reset_patch).path == "/ecosystem"
      assert URI.parse(reset_patch).query |> URI.decode_query() == %{"map" => "open"}

      # The map stays open; the layer filter is cleared.
      reset_html = render(view)
      assert reset_html =~ "PACKAGE EXPLORER"
      refute reset_html =~ ~s(phx-value-layer="foundation" aria-pressed="true")
    end
  end

  defp control_matrix_rows(html) do
    html
    |> Floki.parse_document!()
    |> Floki.find("#operational-control tr[data-capability]")
    |> Map.new(fn row ->
      capability = Floki.attribute(row, "data-capability") |> List.first() |> String.to_atom()
      {capability, row}
    end)
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
