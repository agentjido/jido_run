defmodule AgentJidoWeb.RobotsTxtController do
  use AgentJidoWeb, :controller

  @doc """
  Returns robots directives with a runtime-derived sitemap URL.
  """
  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    body = robots_body(AgentJido.Site.indexable?())

    conn
    |> put_resp_content_type("text/plain", "utf-8")
    |> send_resp(200, body)
  end

  defp robots_body(true) do
    """
    User-agent: *
    Allow: /

    Sitemap: #{AgentJidoWeb.Endpoint.url()}/sitemap.xml
    """
  end

  defp robots_body(false) do
    """
    User-agent: *
    Allow: /
    """
  end
end
