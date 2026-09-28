defmodule AgentJido.MCP.StdioTest do
  use ExUnit.Case, async: false

  @moduletag timeout: 45_000

  test "stdio transport serves newline-delimited MCP JSON-RPC" do
    mix = System.find_executable("mix") || flunk("mix executable not found")
    cwd = File.cwd!()

    port =
      Port.open(
        {:spawn_executable, mix},
        [
          :binary,
          :exit_status,
          {:cd, String.to_charlist(cwd)},
          {:env,
           [
             {~c"MIX_ENV", ~c"test"},
             {~c"CONTENTOPS_CHAT_ENABLED", ~c"false"},
             {~c"ARCANA_GRAPH_ENABLED", ~c"false"}
           ]},
          {:args, ["mcp.docs"]}
        ]
      )

    on_exit(fn ->
      try do
        Port.close(port)
      rescue
        _ -> :ok
      end
    end)

    send_json(port, %{
      "jsonrpc" => "2.0",
      "id" => 1,
      "method" => "initialize",
      "params" => %{"protocolVersion" => "2025-11-25", "clientInfo" => %{"name" => "stdio-test"}}
    })

    # The first reply includes Mix and application startup in the child process.
    init_response = receive_json(port, 30_000)
    assert init_response["result"]["serverInfo"]["name"] == "agent_jido_docs"

    send_json(port, %{"jsonrpc" => "2.0", "method" => "notifications/initialized"})

    send_json(port, %{
      "jsonrpc" => "2.0",
      "id" => 2,
      "method" => "tools/list",
      "params" => %{}
    })

    tools_response = receive_json(port)
    assert Enum.map(tools_response["result"]["tools"], & &1["name"]) == ["search_docs", "get_doc", "list_sections"]
  end

  defp send_json(port, payload) do
    Port.command(port, Jason.encode!(payload) <> "\n")
  end

  defp receive_json(port, timeout \\ 5_000) do
    receive do
      {^port, {:data, data}} ->
        data
        |> String.trim()
        |> Jason.decode!()

      {^port, {:exit_status, status}} ->
        flunk("stdio server exited before replying with status #{status}")
    after
      timeout -> flunk("timed out waiting for stdio response")
    end
  end
end
