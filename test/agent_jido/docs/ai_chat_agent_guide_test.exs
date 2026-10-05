defmodule AgentJido.Docs.AIChatAgentGuideTest do
  use ExUnit.Case, async: false

  alias Jido.AgentServer
  @jido_registry AgentJido.Jido.Registry

  defmodule GuideChatAgent do
    use Jido.AI.Agent,
      name: "guide_chat_agent",
      description: "Guide fixture for multi-turn chat agent docs",
      tools: [],
      model: :fast,
      max_iterations: 1,
      system_prompt: """
      You are a concise, friendly chat assistant.
      Ask short clarifying questions when the user is ambiguous.
      Keep answers under 6 sentences unless asked to be detailed.
      """

    @impl true
    def on_before_cmd(agent, {:ai_react_start, params}) when is_map(params) do
      user_message =
        Map.get(params, :query) ||
          Map.get(params, :prompt) ||
          Map.get(params, :message)

      history = Map.get(agent.state, :history, [])
      prompt = build_prompt(history, user_message)
      updated_params = put_prompt(params, prompt)

      updated_state =
        if is_binary(user_message) do
          Map.put(agent.state, :history, history ++ [%{role: "user", content: user_message}])
        else
          agent.state
        end

      updated_state = Map.put_new(updated_state, :requests, %{})

      super(%{agent | state: updated_state}, {:ai_react_start, updated_params})
    end

    @impl true
    def on_before_cmd(agent, action), do: super(agent, action)

    @impl true
    def on_after_cmd(agent, {:ai_react_start, _params} = action, directives) do
      snap = strategy_snapshot(agent)

      updated_state =
        if snap.done? and is_binary(snap.result) do
          history = Map.get(agent.state, :history, [])
          result = snap.result

          history =
            case List.last(history) do
              %{role: "assistant", content: ^result} -> history
              _ -> history ++ [%{role: "assistant", content: result}]
            end

          Map.put(agent.state, :history, history)
        else
          agent.state
        end

      super(%{agent | state: updated_state}, action, directives)
    end

    @impl true
    def on_after_cmd(agent, action, directives), do: super(agent, action, directives)

    defp build_prompt(history, message) when is_list(history) and is_binary(message) do
      history_block =
        history
        |> Enum.map_join("\n", fn %{role: role, content: content} -> "#{role}: #{content}" end)

      """
      Conversation so far:
      #{history_block}

      user: #{message}
      assistant:
      """
    end

    defp build_prompt(_history, message), do: message

    defp put_prompt(params, prompt) do
      params
      |> Map.put(:query, prompt)
      |> Map.put(:prompt, prompt)
    end
  end

  setup_all do
    ensure_jido_started()
    :ok
  end

  test "guide lifecycle hook pattern compiles and preserves request tracking" do
    agent = GuideChatAgent.new()

    assert {:ok, updated_agent, {:ai_react_start, updated_params}} =
             GuideChatAgent.on_before_cmd(agent, {:ai_react_start, %{query: "hello"}})

    assert [%{role: "user", content: "hello"}] = updated_agent.state.history
    assert is_binary(updated_agent.state.last_request_id)

    assert %{status: :pending, query: tracked_query} =
             updated_agent.state.requests[updated_agent.state.last_request_id]

    assert tracked_query == updated_params.query
    assert updated_params.prompt == tracked_query
    assert tracked_query =~ "Conversation so far:"
    assert tracked_query =~ "user: hello"
  end

  test "guide streaming pattern polls snapshots through AgentServer.status/1" do
    {:ok, pid} =
      AgentServer.start_link(
        jido: AgentJido.Jido,
        agent: GuideChatAgent,
        id: "guide-chat-agent-#{System.unique_integer([:positive])}"
      )

    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid, :normal, 5_000) end)

    assert {:ok, status} = AgentServer.status(pid)
    assert status.pid == pid
    assert match?(%Jido.Agent.Strategy.Snapshot{}, status.snapshot)
  end

  defp ensure_jido_started do
    case Process.whereis(@jido_registry) do
      pid when is_pid(pid) ->
        {:ok, pid}

      nil ->
        start_supervised!({Jido, name: AgentJido.Jido})
        wait_for_registry(50)
    end
  end

  defp wait_for_registry(0), do: raise("AgentJido.Jido.Registry did not start in time")

  defp wait_for_registry(attempts_left) do
    case Process.whereis(@jido_registry) do
      pid when is_pid(pid) ->
        {:ok, pid}

      nil ->
        Process.sleep(10)
        wait_for_registry(attempts_left - 1)
    end
  end
end
