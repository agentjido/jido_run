defmodule AgentJidoWeb.JidoEcosystemLiveTest do
  use AgentJidoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias AgentJido.Ecosystem
  alias AgentJido.Ecosystem.{Layering, SupportLevel}

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
