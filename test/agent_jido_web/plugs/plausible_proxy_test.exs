defmodule AgentJidoWeb.Plugs.PlausibleProxyTest do
  use ExUnit.Case, async: true

  import Plug.Conn
  import Plug.Test

  alias AgentJidoWeb.Plugs.PlausibleProxy

  defmodule FakeClient do
    @behaviour AgentJidoWeb.Plugs.PlausibleProxy.Client

    @impl true
    def request(method, url, headers, body, options) do
      send(self(), {:proxy_request, method, url, headers, body, options})
      Process.get({__MODULE__, :response}, {:error, :missing_fake_response})
    end
  end

  @settings [
    enabled: true,
    client: FakeClient,
    site_domain: "jido.run",
    script_path: "/_q/s.js",
    event_path: "/_q/e",
    script_url: "https://plausible.io/js/site.js",
    event_url: "https://plausible.io/api/event"
  ]

  setup do
    Process.delete({FakeClient, :response})
    :ok
  end

  test "does not claim proxy paths when analytics are disabled" do
    conn =
      :get
      |> conn("/_q/s.js")
      |> PlausibleProxy.call(Keyword.put(@settings, :enabled, false))

    refute conn.halted
    assert conn.state == :unset
    refute_received {:proxy_request, _, _, _, _, _}
  end

  test "forwards and caches the tracker script" do
    fake_response(%Finch.Response{
      status: 200,
      headers: [
        {"content-type", "application/javascript"},
        {"cache-control", "public, max-age=60"},
        {"etag", ~s("tracker-v1")},
        {"set-cookie", "not-forwarded=true"}
      ],
      body: "window.plausible = function () {};"
    })

    conn =
      :get
      |> conn("/_q/s.js")
      |> put_req_header("if-none-match", ~s("tracker-v0"))
      |> PlausibleProxy.call(@settings)

    assert conn.halted
    assert conn.status == 200
    assert conn.resp_body == "window.plausible = function () {};"
    assert get_resp_header(conn, "content-type") == ["application/javascript"]
    assert get_resp_header(conn, "cache-control") == ["public, max-age=60"]
    assert get_resp_header(conn, "etag") == [~s("tracker-v1")]
    assert get_resp_header(conn, "set-cookie") == []

    assert_received {:proxy_request, :get, "https://plausible.io/js/site.js", headers, "", options}

    assert {"if-none-match", ~s("tracker-v0")} in headers
    assert options[:pool_timeout] == 2_000
    assert options[:receive_timeout] == 5_000
  end

  test "forwards valid events with browser identity and no cookies" do
    fake_response(%Finch.Response{
      status: 202,
      headers: [
        {"content-type", "application/json"},
        {"x-plausible-dropped", "0"},
        {"set-cookie", "not-forwarded=true"}
      ],
      body: "{}"
    })

    body =
      Jason.encode!(%{
        "n" => "pageview",
        "d" => "jido.run",
        "u" => "https://jido.run/docs"
      })

    conn =
      :post
      |> conn("/_q/e", body)
      |> put_req_header("content-type", "text/plain;charset=UTF-8")
      |> put_req_header("user-agent", "Test Browser/1.0")
      |> put_req_header("fly-client-ip", "203.0.113.42")
      |> put_req_header("cookie", "private=value")
      |> PlausibleProxy.call(@settings)

    assert conn.halted
    assert conn.status == 202
    assert conn.resp_body == "{}"
    assert get_resp_header(conn, "x-plausible-dropped") == ["0"]
    assert get_resp_header(conn, "set-cookie") == []

    assert_received {:proxy_request, :post, "https://plausible.io/api/event", headers, ^body, _options}

    assert {"content-type", "text/plain;charset=UTF-8"} in headers
    assert {"user-agent", "Test Browser/1.0"} in headers
    assert {"x-forwarded-for", "203.0.113.42"} in headers
    refute Enum.any?(headers, fn {name, _value} -> name == "cookie" end)
  end

  test "prefers the original Cloudflare client IP over the Fly proxy IP" do
    fake_response(%Finch.Response{status: 202, headers: [], body: "{}"})

    body = Jason.encode!(%{"n" => "pageview", "d" => "jido.run"})

    :post
    |> conn("/_q/e", body)
    |> put_req_header("content-type", "text/plain")
    |> put_req_header("user-agent", "Test Browser/1.0")
    |> put_req_header("cf-connecting-ip", "198.51.100.24")
    |> put_req_header("fly-client-ip", "203.0.113.42")
    |> PlausibleProxy.call(@settings)

    assert_received {:proxy_request, :post, "https://plausible.io/api/event", headers, ^body, _options}

    assert {"x-forwarded-for", "198.51.100.24"} in headers
    refute {"x-forwarded-for", "203.0.113.42"} in headers
  end

  test "rejects events for another Plausible site" do
    body = Jason.encode!(%{"n" => "pageview", "d" => "other.example"})

    conn =
      :post
      |> conn("/_q/e", body)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("user-agent", "Test Browser/1.0")
      |> PlausibleProxy.call(@settings)

    assert conn.halted
    assert conn.status == 400
    assert conn.resp_body == "Invalid event site"
    refute_received {:proxy_request, _, _, _, _, _}
  end

  test "rejects an unsupported event content type" do
    conn =
      :post
      |> conn("/_q/e", "not json")
      |> put_req_header("content-type", "application/x-www-form-urlencoded")
      |> put_req_header("user-agent", "Test Browser/1.0")
      |> PlausibleProxy.call(@settings)

    assert conn.halted
    assert conn.status == 415
    refute_received {:proxy_request, _, _, _, _, _}
  end

  test "returns a gateway error without exposing the upstream failure" do
    fake_response({:error, :timeout})

    conn =
      :get
      |> conn("/_q/s.js")
      |> PlausibleProxy.call(@settings)

    assert conn.halted
    assert conn.status == 502
    assert conn.resp_body == "Tracker unavailable"
  end

  defp fake_response(response) do
    Process.put({FakeClient, :response}, normalize_fake_response(response))
  end

  defp normalize_fake_response({:error, _reason} = response), do: response
  defp normalize_fake_response(%Finch.Response{} = response), do: {:ok, response}
end
