defmodule AgentJidoWeb.LegacyRedirectsTest do
  use AgentJidoWeb.ConnCase, async: true

  alias AgentJidoWeb.LegacyRedirects

  test "loads manual redirects from the redirect manifest" do
    assert LegacyRedirects.destination("/ecosystem/matrix") == "/ecosystem#compare"
    assert LegacyRedirects.destination("/ecosystem/package-matrix") == "/ecosystem#compare"
    assert LegacyRedirects.destination("/ecosystem/jido_memory_os") == "/ecosystem/jido_memory"
    assert LegacyRedirects.destination("/blog/jido-2-0-release") == "/blog/jido-2-0-is-here"

    assert LegacyRedirects.destination("/docs/reference/architecture") ==
             "/docs/reference/behavior-first-architecture"
  end

  test "keeps automatic markdown variants" do
    assert LegacyRedirects.destination("/ecosystem/matrix.md") == "/ecosystem.md#compare"
  end

  test "includes documentation redirects" do
    assert LegacyRedirects.destination("/docs/core-concepts") == "/docs/concepts"

    assert LegacyRedirects.destination("/training/production-readiness") ==
             "/docs/learn/production-readiness"

    assert LegacyRedirects.destination("/docs/reference/concepts/reasoning-strategies") ==
             "/docs/learn/reasoning-strategies-compared"
  end

  test "runs before router content type checks", %{conn: conn} do
    conn =
      conn
      |> put_req_header("accept", "application/pdf")
      |> get("/ecosystem/matrix")

    assert redirected_to(conn, 301) == "/ecosystem#compare"
  end
end
