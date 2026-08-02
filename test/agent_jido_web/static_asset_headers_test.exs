defmodule AgentJidoWeb.StaticAssetHeadersTest do
  use ExUnit.Case, async: true

  alias AgentJidoWeb.StaticAssetHeaders

  test "sets immutable caching for content-hashed esbuild chunks" do
    conn = %Plug.Conn{request_path: "/assets/module-LGNKRBGW.js"}

    assert StaticAssetHeaders.headers(conn) == [
             {"cache-control", "public, max-age=31536000, immutable"}
           ]
  end

  test "keeps default caching for logical asset paths" do
    conn = %Plug.Conn{request_path: "/assets/app.js"}

    assert StaticAssetHeaders.headers(conn) == []
  end
end
