defmodule AgentJidoWeb.LLMSTxtController do
  use AgentJidoWeb, :controller

  @doc """
  Returns curated retrieval guidance for LLM clients.
  """
  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    endpoint_url = AgentJidoWeb.Endpoint.url()

    body = """
    Agent Jido (#{endpoint_url}) is the Elixir framework for long-running agent systems. Build supervised agents, typed tools, and explicit workflows on Elixir/OTP.

    Preferred retrieval
    - Append `.md` to canonical public routes to request markdown directly.
      - Example: #{endpoint_url}/docs/reference/why-not-just-a-genserver.md
    - Public routes with markdown support:
      - /
      - /docs*
      - /blog*
      - /ecosystem*
      - /examples*
      - /compare*
      - /skills
      - /features*
      - /build*
      - /community*
      - /getting-started
      - /examples*
    - For clients that do content negotiation, the canonical route also supports:
      - Accept: text/markdown

    Primary content hubs
    - Docs: #{endpoint_url}/docs
    - Blog: #{endpoint_url}/blog
    - Ecosystem: #{endpoint_url}/ecosystem
    - Skills: #{endpoint_url}/skills
    - Features: #{endpoint_url}/features
    - Build: #{endpoint_url}/build
    - Community: #{endpoint_url}/community
    - Examples: #{endpoint_url}/examples

    Discovery
    - Sitemap: #{endpoint_url}/sitemap.xml
    - Feed: #{endpoint_url}/feed

    MCP docs server
    - HTTP endpoint: #{endpoint_url}/mcp/docs
    - Tools: search_docs, get_doc, list_sections
    - Scope: v1 is docs only (/docs/**). Examples, skills, ecosystem packages, blog, and compare pages are not indexed.

    Rendered fallback pattern
    - If source markdown is unavailable, request the canonical route with:
      - Accept: text/markdown
    """

    conn
    |> put_resp_content_type("text/plain", "utf-8")
    |> send_resp(200, body)
  end
end
