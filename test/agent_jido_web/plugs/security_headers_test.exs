defmodule AgentJidoWeb.Plugs.SecurityHeadersTest do
  use AgentJidoWeb.ConnCase, async: true

  test "browser responses use a nonce-based content security policy", %{conn: conn} do
    conn = get(conn, "/")
    body = html_response(conn, 200)

    assert [policy] = get_resp_header(conn, "content-security-policy")
    assert [nonce] = Regex.run(~r/'nonce-([^']+)'/, policy, capture: :all_but_first)
    assert policy =~ "object-src 'none'"
    assert policy =~ "script-src 'self' 'nonce-#{nonce}'"

    scripts = body |> Floki.parse_document!() |> Floki.find("script")
    assert scripts != []

    assert Enum.all?(scripts, fn {"script", attributes, _children} ->
             List.keyfind(attributes, "nonce", 0) == {"nonce", nonce}
           end)
  end

  test "browser responses enable HSTS and origin isolation", %{conn: conn} do
    conn = get(conn, "/")

    assert get_resp_header(conn, "strict-transport-security") == [
             "max-age=31536000; includeSubDomains"
           ]

    assert get_resp_header(conn, "cross-origin-opener-policy") == ["same-origin"]
  end
end
