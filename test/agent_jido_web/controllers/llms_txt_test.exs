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

  test "GET /llms.txt states the qualified operational-control position and links to boundaries and proof",
       %{conn: conn} do
    conn = get(conn, "/llms.txt")
    body = response(conn, 200)
    endpoint_url = AgentJidoWeb.Endpoint.url()

    # The canonical qualified position (the "release basis" line mirrored by the
    # browser, Markdown, and MCP surfaces) must appear verbatim so a machine
    # client receives the same bounded claim a reader sees (jido-e10-t32).
    assert body =~
             "experimental or unreleased packages describe their documented boundary only and do not back a general production claim"

    # The position links to the boundary overview and to the proof pages that
    # ground each control claim.
    assert body =~ "#{endpoint_url}/docs/operations/security-and-governance"
    assert body =~ "#{endpoint_url}/docs/operations/rate-limits-and-cost-budgets"
    assert body =~ "#{endpoint_url}/docs/operations/journal-retention-access-and-deletion"
    assert body =~ "#{endpoint_url}/docs/operations/production-readiness-checklist"
    assert body =~ "#{endpoint_url}/docs/operations/incident-playbooks"
    assert body =~ "#{endpoint_url}/docs/getting-started/operational-controls"
  end
end
