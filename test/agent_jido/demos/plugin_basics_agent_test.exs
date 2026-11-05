defmodule AgentJido.Demos.PluginBasicsAgentTest do
  use ExUnit.Case, async: false

  alias AgentJido.Demos.PluginBasics.AddNoteAction
  alias AgentJido.Demos.PluginBasicsAgent
  alias Jido.AgentServer
  alias Jido.Signal

  test "new agent initializes plugin state" do
    agent = PluginBasicsAgent.new()

    assert agent.state.notes.label == "demo"
    assert agent.state.notes.entries == []
  end

  test "plugin signal routes handle add/clear note" do
    {:ok, pid} = start_server()

    {:ok, _agent} = AgentServer.call(pid, Signal.new!("notes.add", %{text: "first"}, source: "/test"))
    {:ok, _agent} = AgentServer.call(pid, Signal.new!("notes.add", %{text: "second"}, source: "/test"))

    {:ok, state} = AgentServer.state(pid)
    assert length(state.agent.state.notes.entries) == 2

    {:ok, agent} = AgentServer.call(pid, Signal.new!("notes.clear", %{}, source: "/test"))
    assert agent.state.notes.entries == []
  end

  test "cmd can invoke plugin action directly" do
    agent = PluginBasicsAgent.new()
    {agent, []} = PluginBasicsAgent.cmd(agent, {AddNoteAction, %{text: "from cmd"}})

    assert length(agent.state.notes.entries) == 1
  end

  defp start_server do
    {:ok, pid} =
      AgentServer.start_link(
        jido: AgentJido.Jido,
        agent: PluginBasicsAgent,
        id: "plugin-test-#{System.unique_integer([:positive])}"
      )

    on_exit(fn ->
      AgentJido.TestProcess.stop(pid)
    end)

    {:ok, pid}
  end
end
