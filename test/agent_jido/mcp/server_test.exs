defmodule AgentJido.MCP.ServerTest do
  use ExUnit.Case, async: true

  alias AgentJido.MCP.Server

  defmodule StubTools do
    def tools do
      [
        %{
          "name" => "search_docs",
          "description" => "stub search",
          "inputSchema" => %{"type" => "object"}
        }
      ]
    end

    def call_tool("search_docs", %{"query" => query}, _opts) do
      {:ok,
       %{
         "content" => [%{"type" => "text", "text" => "Found 1 result for #{query}"}],
         "structuredContent" => %{
           "query" => query,
           "retrieval_status" => "success",
           "results" => [
             %{
               "title" => "Stub Result",
               "path" => "/docs/reference/architecture",
               "canonical_url" => "https://jido.run/docs/reference/architecture",
               "section" => "reference",
               "snippet" => "Stub snippet"
             }
           ]
         },
         "isError" => false
       }}
    end

    def call_tool(_name, _arguments, _opts) do
      {:error, %{"code" => "unknown_tool", "message" => "Unknown tool"}}
    end
  end

  test "initialize advertises tools-only MCP capabilities" do
    request = %{
      "jsonrpc" => "2.0",
      "id" => 1,
      "method" => "initialize",
      "params" => %{
        "protocolVersion" => "2025-11-25",
        "clientInfo" => %{"name" => "test-client", "version" => "1.0.0"},
        "capabilities" => %{}
      }
    }

    {:reply, response, state} = Server.handle_message(request, Server.new(), tools_module: StubTools)

    assert response["result"]["protocolVersion"] == "2025-11-25"
    assert response["result"]["capabilities"]["tools"]["listChanged"] == false
    assert response["result"]["serverInfo"]["name"] == "agent_jido_docs"
    assert state.initialized?
  end

  test "initialize instructions state the v1 docs-only scope explicitly" do
    request = %{
      "jsonrpc" => "2.0",
      "id" => 1,
      "method" => "initialize",
      "params" => %{"protocolVersion" => "2025-11-25"}
    }

    {:reply, response, _state} = Server.handle_message(request, Server.new(), tools_module: StubTools)

    instructions = response["result"]["instructions"]

    # Product copy and tool scope must agree (jido-e10-t17): the public
    # description returned to every MCP client must state the docs-only scope.
    assert instructions =~ "docs only"
    assert instructions =~ "search_docs, get_doc, list_sections"
    assert instructions =~ "examples"
    assert instructions =~ "/docs/**"
  end

  test "instructions/0 is the single docs-only scope source of truth" do
    instructions = Server.instructions()

    assert instructions =~ "docs only"
    assert instructions =~ "/docs/**"
    assert instructions =~ "Available tools: search_docs, get_doc, list_sections"
    # The operational-control query path is advertised by name so a client
    # knows it can retrieve the control overview without a text guess
    # (jido-e10-t30).
    assert instructions =~ "get_operational_control"
  end

  test "tools/list requires initialization on stateful transports" do
    request = %{"jsonrpc" => "2.0", "id" => 2, "method" => "tools/list", "params" => %{}}

    {:reply, response, _state} = Server.handle_message(request, Server.new(), tools_module: StubTools)

    assert response["error"]["code"] == -32_002
  end

  test "tools/list returns the shared tool catalog after initialize" do
    init = %{"jsonrpc" => "2.0", "id" => 1, "method" => "initialize", "params" => %{"protocolVersion" => "2025-11-25"}}
    {:reply, _response, state} = Server.handle_message(init, Server.new(), tools_module: StubTools)

    request = %{"jsonrpc" => "2.0", "id" => 2, "method" => "tools/list", "params" => %{}}
    {:reply, response, _state} = Server.handle_message(request, state, tools_module: StubTools)

    assert [%{"name" => "search_docs"}] = response["result"]["tools"]
  end

  test "tools/call validates arguments before dispatch" do
    init = %{"jsonrpc" => "2.0", "id" => 1, "method" => "initialize", "params" => %{"protocolVersion" => "2025-11-25"}}
    {:reply, _response, state} = Server.handle_message(init, Server.new(), tools_module: StubTools)

    request = %{
      "jsonrpc" => "2.0",
      "id" => 3,
      "method" => "tools/call",
      "params" => %{"name" => "search_docs", "arguments" => "not-an-object"}
    }

    {:reply, response, _state} = Server.handle_message(request, state, tools_module: StubTools)

    assert response["error"]["code"] == -32_602
    assert response["error"]["message"] =~ "arguments must be an object"
  end

  test "tools/call returns structured tool results" do
    init = %{"jsonrpc" => "2.0", "id" => 1, "method" => "initialize", "params" => %{"protocolVersion" => "2025-11-25"}}
    {:reply, _response, state} = Server.handle_message(init, Server.new(), tools_module: StubTools)

    request = %{
      "jsonrpc" => "2.0",
      "id" => 4,
      "method" => "tools/call",
      "params" => %{"name" => "search_docs", "arguments" => %{"query" => "architecture"}}
    }

    {:reply, response, _state} = Server.handle_message(request, state, tools_module: StubTools)

    assert response["result"]["isError"] == false
    assert response["result"]["structuredContent"]["query"] == "architecture"
    assert hd(response["result"]["structuredContent"]["results"])["path"] == "/docs/reference/architecture"
  end

  test "unknown tools return MCP tool errors" do
    init = %{"jsonrpc" => "2.0", "id" => 1, "method" => "initialize", "params" => %{"protocolVersion" => "2025-11-25"}}
    {:reply, _response, state} = Server.handle_message(init, Server.new(), tools_module: StubTools)

    request = %{
      "jsonrpc" => "2.0",
      "id" => 5,
      "method" => "tools/call",
      "params" => %{"name" => "missing_tool", "arguments" => %{}}
    }

    {:reply, response, _state} = Server.handle_message(request, state, tools_module: StubTools)

    assert response["result"]["isError"] == true
    assert response["result"]["structuredContent"]["error"]["code"] == "unknown_tool"
  end

  test "notifications/initialized is acknowledged without a response" do
    init = %{"jsonrpc" => "2.0", "id" => 1, "method" => "initialize", "params" => %{"protocolVersion" => "2025-11-25"}}
    {:reply, _response, state} = Server.handle_message(init, Server.new(), tools_module: StubTools)

    request = %{"jsonrpc" => "2.0", "method" => "notifications/initialized"}

    assert {:noreply, %Server.State{initialized?: true}} =
             Server.handle_message(request, state, tools_module: StubTools)
  end
end
