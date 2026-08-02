defmodule AgentJidoWeb.RobotsTxtControllerTest do
  use AgentJidoWeb.ConnCase, async: false

  setup do
    previous_value = Application.fetch_env(:agent_jido, :site_indexable)

    on_exit(fn -> restore_site_indexable(previous_value) end)
  end

  test "public sites advertise the sitemap", %{conn: conn} do
    Application.put_env(:agent_jido, :site_indexable, true)

    conn = get(conn, "/robots.txt")
    body = response(conn, 200)

    assert body =~ "Allow: /"
    assert body =~ "Sitemap: #{AgentJidoWeb.Endpoint.url()}/sitemap.xml"
    assert get_resp_header(conn, "x-robots-tag") == []
  end

  test "non-public sites add noindex headers and omit the sitemap", %{conn: conn} do
    Application.put_env(:agent_jido, :site_indexable, false)

    robots_conn = get(conn, "/robots.txt")
    body = response(robots_conn, 200)

    assert body =~ "Allow: /"
    refute body =~ "Sitemap:"
    assert get_resp_header(robots_conn, "x-robots-tag") == ["noindex, nofollow"]

    page_conn = get(recycle(conn), "/docs/learn/agent-fundamentals")
    assert response(page_conn, 200)
    assert get_resp_header(page_conn, "x-robots-tag") == ["noindex, nofollow"]
  end

  defp restore_site_indexable({:ok, value}) do
    Application.put_env(:agent_jido, :site_indexable, value)
  end

  defp restore_site_indexable(:error) do
    Application.delete_env(:agent_jido, :site_indexable)
  end
end
