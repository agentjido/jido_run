defmodule AgentJidoWeb.LLMResponsePlugTest do
  use AgentJidoWeb.ConnCase, async: true

  @moduletag :flaky

  test "html response includes LLM discovery headers for supported routes", %{conn: conn} do
    conn = get(conn, "/docs")
    assert response(conn, 200)

    vary = get_resp_header(conn, "vary") |> List.first()
    link = get_resp_header(conn, "link") |> List.first()

    assert vary =~ "Accept"
    assert link =~ ~s(</llms.txt>; rel="alternate"; type="text/plain")
    assert link =~ "<#{AgentJidoWeb.Endpoint.url()}/docs.md>; rel=\"alternate\"; type=\"text/markdown\""
  end

  test "markdown negotiation returns the generated docs hub inventory with discovery and SEO headers", %{conn: conn} do
    conn =
      conn
      |> put_req_header("accept", "text/markdown")
      |> get("/docs")

    body = response(conn, 200)
    vary = get_resp_header(conn, "vary") |> List.first()
    link = get_resp_header(conn, "link") |> List.first()

    assert get_resp_header(conn, "content-type") |> List.first() =~ "text/markdown"
    assert get_resp_header(conn, "x-robots-tag") == ["noindex"]
    assert vary =~ "Accept"
    assert link =~ ~s(</llms.txt>; rel="alternate"; type="text/plain")
    assert link =~ "<#{AgentJidoWeb.Endpoint.url()}/docs.md>; rel=\"alternate\"; type=\"text/markdown\""
    assert link =~ "<#{AgentJidoWeb.Endpoint.url()}/docs>; rel=\"canonical\""
    # The hub markdown is generated from the same content records as the browser
    # hub (E06-T22), not the hand-written index page body.
    assert body =~ "# Documentation"
    assert body =~ "generated from the same content records as the rendered Docs hub"
    assert body =~ "**[Get Started](/docs/getting-started)**"
  end

  test "explicit .md routes return markdown without accept header", %{conn: conn} do
    conn = get(conn, "/docs.md")

    body = response(conn, 200)
    link = get_resp_header(conn, "link") |> List.first()

    assert get_resp_header(conn, "content-type") |> List.first() =~ "text/markdown"
    assert get_resp_header(conn, "x-robots-tag") == ["noindex"]
    assert link =~ "<#{AgentJidoWeb.Endpoint.url()}/docs.md>; rel=\"alternate\"; type=\"text/markdown\""
    assert link =~ "<#{AgentJidoWeb.Endpoint.url()}/docs>; rel=\"canonical\""
    assert body =~ "# Documentation"
    assert body =~ "generated from the same content records as the rendered Docs hub"
  end

  test "leaf docs .md routes return the underlying source markdown", %{conn: conn} do
    conn = get(conn, "/docs/concepts/agents.md")

    body = response(conn, 200)
    link = get_resp_header(conn, "link") |> List.first()

    assert get_resp_header(conn, "content-type") |> List.first() =~ "text/markdown"
    assert link =~ "<#{AgentJidoWeb.Endpoint.url()}/docs/concepts/agents.md>; rel=\"alternate\"; type=\"text/markdown\""
    assert link =~ "<#{AgentJidoWeb.Endpoint.url()}/docs/concepts/agents>; rel=\"canonical\""
    assert body =~ ~s(title: "Agents")
    assert body =~ "## Agents are pure data"
  end

  test "legacy docs redirects remain unchanged even with markdown accept header", %{conn: conn} do
    conn =
      conn
      |> put_req_header("accept", "text/markdown")
      |> get("/docs/core-concepts")

    assert redirected_to(conn, 301) == "/docs/concepts"
  end

  test "legacy markdown routes redirect to canonical markdown routes", %{conn: conn} do
    conn = get(conn, "/docs/core-concepts.md")
    assert redirected_to(conn, 301) == "/docs/concepts.md"
  end

  test "excluded routes do not negotiate markdown", %{conn: conn} do
    conn =
      conn
      |> put_req_header("accept", "text/markdown")
      |> get("/sitemap.xml")

    assert response(conn, 200)
    assert get_resp_header(conn, "content-type") |> List.first() =~ "application/xml"
  end

  test "auth routes do not negotiate markdown", %{conn: conn} do
    conn =
      conn
      |> put_req_header("accept", "text/markdown")
      |> get("/users/log-in")

    assert response(conn, 200)
    assert get_resp_header(conn, "content-type") |> List.first() =~ "text/html"
  end

  test "supported routes without direct source return deterministic markdown fallback", %{conn: conn} do
    conn =
      conn
      |> put_req_header("accept", "text/markdown")
      |> get("/features")

    body = response(conn, 200)
    link = get_resp_header(conn, "link") |> List.first()

    assert get_resp_header(conn, "content-type") |> List.first() =~ "text/markdown"
    assert get_resp_header(conn, "x-robots-tag") == ["noindex"]
    assert link =~ "<#{AgentJidoWeb.Endpoint.url()}/features.md>; rel=\"alternate\"; type=\"text/markdown\""
    assert link =~ "<#{AgentJidoWeb.Endpoint.url()}/features>; rel=\"canonical\""
    assert body =~ "# Jido Features"
    assert body =~ "Canonical URL: #{AgentJidoWeb.Endpoint.url()}/features"
    refute body =~ "Markdown URL:"
  end

  test "community showcase markdown route resolves to deterministic fallback", %{conn: conn} do
    conn = get(conn, "/community/showcase.md")

    body = response(conn, 200)
    link = get_resp_header(conn, "link") |> List.first()

    assert get_resp_header(conn, "content-type") |> List.first() =~ "text/markdown"
    assert get_resp_header(conn, "x-robots-tag") == ["noindex"]
    assert link =~ "<#{AgentJidoWeb.Endpoint.url()}/community/showcase.md>; rel=\"alternate\"; type=\"text/markdown\""
    assert link =~ "<#{AgentJidoWeb.Endpoint.url()}/community/showcase>; rel=\"canonical\""
    assert body =~ "# Built with Jido Showcase"
  end
end
