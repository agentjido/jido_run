defmodule AgentJidoWeb.LLMSTxtTest do
  use AgentJidoWeb.ConnCase, async: true

  test "GET /llms.txt returns curated LLM guidance", %{conn: conn} do
    conn = get(conn, "/llms.txt")
    body = response(conn, 200)
    endpoint_url = AgentJidoWeb.Endpoint.url()

    assert get_resp_header(conn, "content-type") |> List.first() =~ "text/plain"
    assert body =~ "Preferred retrieval"
    assert body =~ "Append `.md` to canonical public routes"
    assert body =~ "#{endpoint_url}/docs/reference/why-not-just-a-genserver.md"
    assert body =~ "Accept: text/markdown"
    assert body =~ "#{endpoint_url}/sitemap.xml"
    assert body =~ "#{endpoint_url}/mcp/docs"
    assert body =~ "search_docs, get_doc, list_sections"
    # The operational-control query path is advertised to LLM clients so they
    # can retrieve the control overview by name (jido-e10-t30).
    assert body =~ "get_operational_control"
    assert body =~ "Security and governance"
    # Product copy and tool scope must agree (jido-e10-t17): the MCP scope line
    # must state the v1 docs-only scope explicitly.
    assert body =~ "Scope: v1 is docs only (/docs/**)"
    assert body =~ "If source markdown is unavailable"
  end
end
