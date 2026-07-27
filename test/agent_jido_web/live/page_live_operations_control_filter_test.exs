defmodule AgentJidoWeb.PageLiveOperationsControlFilterTest do
  @moduledoc """
  jido-e06-t37 — Docs filters for operational-control content.

  Acceptance: "A reader can find pages for identity context, authorization,
  policy, history, observation, approval, and redaction."

  The operations section page carries a control-type filter so a reader can
  narrow its page list to the surface they are operating. Each operations page
  that documents a control surface also labels it in its header. These tests
  lock both surfaces: the filter renders a chip for every control type, a chip
  narrows the list to the pages that carry it, All restores the list, and a
  control-bearing page shows its control badges.
  """

  use AgentJidoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias AgentJido.Pages

  @moduletag :flaky

  # The seven control surfaces the acceptance condition names.
  @acceptance_control_types ~w(identity_context authorization policy history observation approval redaction)

  describe "the operations control-type filter renders (jido-e06-t37)" do
    test "the operations section renders a filter chip per control type plus All", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/docs/operations")

      assert html =~ ~s(id="operations-control-filter")
      assert html =~ ~s(phx-value-control-type="all")

      for control_type <- @acceptance_control_types do
        assert html =~ ~s(phx-value-control-type="#{control_type}"),
               "missing the #{control_type} control-type filter chip"
      end
    end

    test "the default (All) view lists every operations page", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/docs/operations")

      for page <- Pages.operations_pages_for_control_type(nil) do
        assert has_element?(view, "#operations-control-page-#{page.id}"),
               "expected operations page #{page.id} in the default list"
      end
    end
  end

  describe "selecting a control type narrows the operations list" do
    test "the Authorization chip shows authorization pages and marks itself active", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/docs/operations")

      render_click(view, "select_operations_control_filter", %{"control_type" => "authorization"})

      # A page that documents authorization stays visible.
      security = Pages.get_page_by_path!("/docs/operations/security-and-governance")
      assert :authorization in security.control_types
      assert has_element?(view, "#operations-control-page-#{security.id}")

      # A page with no control surface is filtered out.
      supervision = Pages.get_page_by_path!("/docs/operations/supervision-and-failure-boundaries")
      assert supervision.control_types == []
      refute has_element?(view, "#operations-control-page-#{supervision.id}")

      html = render(view)

      # The Authorization chip is the active affordance; All is no longer pressed.
      assert html =~ ~s(phx-value-control-type="authorization" aria-pressed="true")
      assert html =~ ~s(phx-value-control-type="all" aria-pressed="false")
    end

    test "selecting Identity context narrows to pages that carry principal/tenant context", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/docs/operations")

      render_click(view, "select_operations_control_filter", %{"control_type" => "identity_context"})

      for page <- Pages.operations_pages_for_control_type(:identity_context) do
        assert has_element?(view, "#operations-control-page-#{page.id}")
      end

      html = render(view)
      assert html =~ ~s(phx-value-control-type="identity_context" aria-pressed="true")
    end

    test "selecting All restores the full list", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/docs/operations")

      render_click(view, "select_operations_control_filter", %{"control_type" => "authorization"})
      render_click(view, "select_operations_control_filter", %{"control_type" => "all"})

      for page <- Pages.operations_pages_for_control_type(nil) do
        assert has_element?(view, "#operations-control-page-#{page.id}")
      end
    end

    test "an unknown control type falls back to All instead of emptying the list", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/docs/operations")

      html =
        render_click(view, "select_operations_control_filter", %{"control_type" => "bogus"})

      assert html =~ ~s(phx-value-control-type="all" aria-pressed="true")
    end
  end

  describe "control-bearing operations pages label their control surfaces" do
    test "the telemetry page shows its observation and redaction badges", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/docs/operations/telemetry-and-traces")

      assert html =~ "Observation"
      assert html =~ "Redaction"
    end
  end
end
