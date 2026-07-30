defmodule AgentJidoWeb.JidoFeaturesLiveTest do
  use AgentJidoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders features landing content", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/features")

    assert html =~ "How Jido"
    assert html =~ "features-category-explorer"
    assert html =~ ~s(href="/docs/getting-started")
  end

  test "introduces operational control without a compliance claim (jido-e03-t28)", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/features")

    assert html =~ "operational-control-introduction"
    assert html =~ "Supervise, constrain, and inspect Agent work"
    assert html =~ ~s(href="/docs/operations/supervision-and-failure-boundaries")
    assert html =~ ~s(href="/docs/concepts/actions")
    assert html =~ ~s(href="/docs/operations/security-and-governance")
    assert html =~ ~s(href="/docs/concepts/signals")
    assert html =~ ~s(href="/docs/operations/telemetry-and-traces")
    assert html =~ "Telemetry is operational observation; it is not an audit log."
    refute html =~ "compliance-ready"
  end

  test "legacy partners route returns branded 404 page", %{conn: conn} do
    conn = get(conn, "/partners")
    body = response(conn, 404)

    assert body =~ "Page not found"
    assert body =~ "/partners"
  end
end
