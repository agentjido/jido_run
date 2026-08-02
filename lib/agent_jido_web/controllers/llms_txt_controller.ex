defmodule AgentJidoWeb.LLMSTxtController do
  use AgentJidoWeb, :controller

  @doc """
  Returns curated retrieval guidance for LLM clients.
  """
  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    endpoint_url = AgentJidoWeb.Endpoint.url()

    body = """
    # Agent Jido

    [Agent Jido](#{endpoint_url}) is a site for building reliable multi-agent systems on Elixir/OTP.

    ## Preferred retrieval
    - Append `.md` to canonical public routes to request markdown directly.
      - Example: [Why not just a GenServer?](#{endpoint_url}/docs/reference/why-not-just-a-genserver.md)
    - Public routes with markdown support:
      - `/`
      - `/docs*`
      - `/blog*`
      - `/ecosystem*`
      - `/skills`
      - `/features*`
      - `/build*`
      - `/community*`
      - `/getting-started`
      - `/examples*`
    - For clients that do content negotiation, the canonical route also supports:
      - `Accept: text/markdown`

    ## Primary content hubs
    - [Docs](#{endpoint_url}/docs)
    - [Blog](#{endpoint_url}/blog)
    - [Ecosystem](#{endpoint_url}/ecosystem)
    - [Skills](#{endpoint_url}/skills)
    - [Features](#{endpoint_url}/features)
    - [Build](#{endpoint_url}/build)
    - [Community](#{endpoint_url}/community)
    - [Examples](#{endpoint_url}/examples)

    ## Discovery
    - [Sitemap](#{endpoint_url}/sitemap.xml)
    - [Feed](#{endpoint_url}/feed)

    ## MCP docs server
    - [HTTP endpoint](#{endpoint_url}/mcp/docs)
    - Tools: `search_docs`, `get_doc`, `list_sections`
    - Scope: published docs only

    ## Rendered fallback pattern
    - If source markdown is unavailable, request the canonical route with:
      - `Accept: text/markdown`
    """

    conn
    |> put_resp_content_type("text/plain", "utf-8")
    |> send_resp(200, body)
  end
end
