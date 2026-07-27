defmodule AgentJidoWeb.MCPDocsControllerTest do
  use AgentJidoWeb.ConnCase, async: false

  alias AgentJido.Analytics.RateLimiter

  defmodule RetrievalStub do
    alias AgentJido.ContentAssistant.Result

    def query_with_status(_query, _opts) do
      {:ok,
       [
         %Result{
           title: "Architecture",
           snippet: "Jido architecture overview.",
           url: "/docs/reference/architecture",
           source_type: :docs,
           score: 0.95
         }
       ], :success}
    end
  end

  setup do
    original = Application.get_env(:agent_jido, AgentJido.MCP, [])
    :ok = RateLimiter.reset!()

    on_exit(fn ->
      Application.put_env(:agent_jido, AgentJido.MCP, original)
      RateLimiter.reset!()
    end)

    Application.put_env(
      :agent_jido,
      AgentJido.MCP,
      Keyword.merge(original,
        tool_opts: [retrieval_module: RetrievalStub],
        http_rate_limit_max_requests: 60,
        http_rate_limit_window_seconds: 60
      )
    )

    :ok
  end

  test "POST /mcp/docs initialize returns tools capability metadata", %{conn: conn} do
    conn =
      post(conn, "/mcp/docs", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "initialize",
        "params" => %{
          "protocolVersion" => "2025-11-25",
          "clientInfo" => %{"name" => "test-client", "version" => "1.0.0"}
        }
      })

    response = json_response(conn, 200)

    assert get_resp_header(conn, "mcp-protocol-version") == ["2025-11-25"]
    assert response["result"]["capabilities"]["tools"]["listChanged"] == false
    assert response["result"]["serverInfo"]["name"] == "agent_jido_docs"
  end

  test "POST /mcp/docs tools/list works over stateless HTTP", %{conn: conn} do
    conn =
      post(conn, "/mcp/docs", %{
        "jsonrpc" => "2.0",
        "id" => 2,
        "method" => "tools/list",
        "params" => %{}
      })

    response = json_response(conn, 200)

    assert Enum.map(response["result"]["tools"], & &1["name"]) == [
             "search_docs",
             "get_doc",
             "list_sections",
             "get_operational_control",
             "get_example"
           ]
  end

  test "POST /mcp/docs search_docs returns structured docs results", %{conn: conn} do
    conn =
      post(conn, "/mcp/docs", %{
        "jsonrpc" => "2.0",
        "id" => 3,
        "method" => "tools/call",
        "params" => %{
          "name" => "search_docs",
          "arguments" => %{"query" => "architecture"}
        }
      })

    response = json_response(conn, 200)

    assert response["result"]["isError"] == false
    assert response["result"]["structuredContent"]["query"] == "architecture"
    assert hd(response["result"]["structuredContent"]["results"])["path"] == "/docs/reference/architecture"
  end

  test "POST /mcp/docs get_doc returns canonical markdown for docs paths", %{conn: conn} do
    conn =
      post(conn, "/mcp/docs", %{
        "jsonrpc" => "2.0",
        "id" => 4,
        "method" => "tools/call",
        "params" => %{
          "name" => "get_doc",
          "arguments" => %{"path" => "/docs/chat-response"}
        }
      })

    response = json_response(conn, 200)

    assert response["result"]["structuredContent"]["path"] == "/docs/guides/cookbook/chat-response"
    assert response["result"]["structuredContent"]["legacy_resolution"]["resolution"] == "legacy"
  end

  test "POST /mcp/docs rejects malformed tools/call params", %{conn: conn} do
    conn =
      post(conn, "/mcp/docs", %{
        "jsonrpc" => "2.0",
        "id" => 5,
        "method" => "tools/call",
        "params" => %{
          "name" => "search_docs",
          "arguments" => "bad"
        }
      })

    response = json_response(conn, 200)

    assert response["error"]["code"] == -32_602
  end

  test "GET /mcp/docs is rejected", %{conn: conn} do
    conn = get(conn, "/mcp/docs")
    response = json_response(conn, 405)

    assert response["error"]["message"] =~ "Only POST"
  end

  test "POST /mcp/docs enforces rate limits per client", %{conn: conn} do
    Application.put_env(
      :agent_jido,
      AgentJido.MCP,
      Keyword.merge(Application.get_env(:agent_jido, AgentJido.MCP, []),
        http_rate_limit_max_requests: 1,
        http_rate_limit_window_seconds: 60
      )
    )

    request = %{
      "jsonrpc" => "2.0",
      "id" => 6,
      "method" => "tools/list",
      "params" => %{}
    }

    conn1 =
      conn
      |> put_req_header("x-forwarded-for", "203.0.113.10")
      |> post("/mcp/docs", request)

    assert json_response(conn1, 200)["result"]["tools"] != []

    conn2 =
      build_conn()
      |> put_req_header("x-forwarded-for", "203.0.113.10")
      |> post("/mcp/docs", request)

    response = json_response(conn2, 429)
    assert response["error"]["code"] == -32_029
  end
end
