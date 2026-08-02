defmodule AgentJidoWeb.TrainingRoutesTest do
  use AgentJidoWeb.ConnCase, async: true

  @moduletag :flaky

  test "GET /training is not routable", %{conn: conn} do
    conn = get(conn, "/training")
    body = response(conn, 404)
    assert body =~ "Page not found"
    assert body =~ "/training"
    assert body =~ "training routes"
  end

  test "GET /training/:id redirects to its docs lesson", %{conn: conn} do
    conn = get(conn, "/training/agent-fundamentals")

    assert redirected_to(conn, 301) == "/docs/learn/agent-fundamentals"
  end

  test "GET /search renders the search experience", %{conn: conn} do
    conn = get(conn, "/search")
    body = response(conn, 200)
    assert body =~ "Search and chat"
  end

  test "GET /search pre-fills query from q param", %{conn: conn} do
    conn = get(conn, "/search", q: "agents")
    body = response(conn, 200)

    assert body =~ "Search and chat"
    assert body =~ ~s(value="agents")
  end

  test "GET /premium-support is not routable", %{conn: conn} do
    conn = get(conn, "/premium-support")
    assert response(conn, 404)
  end

  test "GET /benchmarks is not routable", %{conn: conn} do
    conn = get(conn, "/benchmarks")
    assert response(conn, 404)
  end

  test "unknown routes render the branded 404 page", %{conn: conn} do
    conn = get(conn, "/totally-missing-route")
    body = response(conn, 404)

    assert body =~ "Page not found"
    assert body =~ "/totally-missing-route"
    assert body =~ "GET BUILDING"
  end
end
