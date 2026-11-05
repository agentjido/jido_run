defmodule AgentJido.Demos.SignalRoutingAgentTest do
  use ExUnit.Case, async: false

  alias AgentJido.Demos.SignalRouting.{
    IncrementAction,
    RecordEventAction,
    SetNameAction
  }

  alias AgentJido.Demos.SignalRoutingAgent
  alias Jido.AgentServer
  alias Jido.Signal

  describe "SignalRoutingAgent.cmd/2" do
    test "increment updates counter" do
      agent = SignalRoutingAgent.new()
      {agent, _directives} = SignalRoutingAgent.cmd(agent, {IncrementAction, %{amount: 3}})
      assert agent.state.counter == 3
    end

    test "set_name updates name" do
      agent = SignalRoutingAgent.new()
      {agent, _directives} = SignalRoutingAgent.cmd(agent, {SetNameAction, %{name: "Router"}})
      assert agent.state.name == "Router"
    end

    test "record_event prepends event with payload" do
      agent = SignalRoutingAgent.new()

      {agent, _directives} =
        SignalRoutingAgent.cmd(agent, {RecordEventAction, %{event_type: "checkpoint", payload: %{step: 1}}})

      assert length(agent.state.events) == 1
      [event] = agent.state.events
      assert event.type == "checkpoint"
      assert event.payload == %{step: 1}
    end
  end

  describe "AgentServer signal routing" do
    test "call sequence interleaves signal types correctly" do
      {:ok, pid} = start_demo_server()

      {:ok, _agent} = AgentServer.call(pid, Signal.new!("increment", %{amount: 5}, source: "/test"))
      {:ok, _agent} = AgentServer.call(pid, Signal.new!("set_name", %{name: "Counter"}, source: "/test"))

      {:ok, _agent} =
        AgentServer.call(
          pid,
          Signal.new!("record_event", %{event_type: "checkpoint", payload: %{source: "test"}}, source: "/test")
        )

      {:ok, _agent} = AgentServer.call(pid, Signal.new!("increment", %{amount: 3}, source: "/test"))
      {:ok, server_state} = AgentServer.state(pid)

      assert server_state.agent.state.counter == 8
      assert server_state.agent.state.name == "Counter"
      assert length(server_state.agent.state.events) == 1
    end

    test "cast burst converges to expected counter" do
      {:ok, pid} = start_demo_server()

      for _step <- 1..5 do
        :ok = AgentServer.cast(pid, Signal.new!("increment", %{amount: 1}, source: "/test"))
      end

      assert_eventually(fn ->
        {:ok, server_state} = AgentServer.state(pid)
        server_state.agent.state.counter == 5
      end)
    end
  end

  defp start_demo_server do
    {:ok, pid} =
      AgentServer.start_link(
        jido: AgentJido.Jido,
        agent: SignalRoutingAgent,
        id: "signal-routing-test-#{System.unique_integer([:positive])}"
      )

    on_exit(fn ->
      AgentJido.TestProcess.stop(pid)
    end)

    {:ok, pid}
  end

  defp assert_eventually(fun, attempts \\ 40)

  defp assert_eventually(fun, attempts) when attempts > 0 do
    if fun.() do
      :ok
    else
      Process.sleep(25)
      assert_eventually(fun, attempts - 1)
    end
  end

  defp assert_eventually(_fun, 0), do: flunk("expected condition to become true")
end
