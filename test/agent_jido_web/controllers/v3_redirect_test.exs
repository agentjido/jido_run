defmodule AgentJidoWeb.V3RedirectTest do
  use AgentJidoWeb.ConnCase, async: true

  test "permanently redirects the retired V3 showcase to the home page", %{conn: conn} do
    conn = get(conn, "/v3")

    assert redirected_to(conn, 301) == ~p"/"
  end
end
