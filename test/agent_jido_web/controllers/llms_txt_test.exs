defmodule AgentJidoWeb.LLMSTxtTest do
  use AgentJidoWeb.ConnCase, async: true

  test "GET /llms.txt returns curated LLM guidance", %{conn: conn} do
    conn = get(conn, "/llms.txt")
    body = response(conn, 200)
    endpoint_url = AgentJidoWeb.Endpoint.url()

    assert get_resp_header(conn, "content-type") |> List.first() =~ "text/plain"
    assert body =~ ~r/^# Agent Jido$/m
    assert body =~ "## Preferred retrieval"
    assert body =~ "[Agent Jido](#{endpoint_url})"
    assert body =~ "Append `.md` to canonical public routes"

    assert body =~
             "[Why not just a GenServer?](#{endpoint_url}/docs/reference/why-not-just-a-genserver.md)"

    assert body =~ "[Docs](#{endpoint_url}/docs)"
    assert body =~ "Accept: text/markdown"
    assert body =~ "[Sitemap](#{endpoint_url}/sitemap.xml)"
    assert body =~ "[HTTP endpoint](#{endpoint_url}/mcp/docs)"
    assert body =~ "`search_docs`, `get_doc`, `list_sections`"
    assert body =~ "If source markdown is unavailable"
  end
end
