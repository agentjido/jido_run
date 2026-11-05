defmodule AgentJido.Demos.EmitDirectiveAgentTest do
  use ExUnit.Case, async: false

  alias AgentJido.Demos.EmitDirective.{
    CreateOrderAction,
    MultiEmitAction
  }

  alias AgentJido.Demos.EmitDirectiveAgent
  alias Jido.Agent.Directive
  alias Jido.AgentServer
  alias Jido.Signal

  test "create_order updates state and emits order.created" do
    agent = EmitDirectiveAgent.new()

    {agent, directives} =
      EmitDirectiveAgent.cmd(agent, {CreateOrderAction, %{order_id: "ORD-1", total: 1500}})

    assert agent.state.last_order_id == "ORD-1"
    assert length(agent.state.orders) == 1

    assert [%Directive.Emit{signal: signal}] = directives
    assert signal.type == "order.created"
    assert signal.data.order_id == "ORD-1"
  end

  test "multi_emit returns multiple emit directives" do
    agent = EmitDirectiveAgent.new()
    {_agent, directives} = EmitDirectiveAgent.cmd(agent, {MultiEmitAction, %{event_count: 3}})

    assert length(directives) == 3
    assert Enum.all?(directives, &match?(%Directive.Emit{}, &1))
  end

  test "server call sequence handles create + payment" do
    {:ok, pid} = start_server()

    {:ok, _agent} =
      AgentServer.call(pid, Signal.new!("create_order", %{order_id: "ORD-2", total: 900}, source: "/test"))

    {:ok, agent} =
      AgentServer.call(
        pid,
        Signal.new!("process_payment", %{order_id: "ORD-2", payment_method: "card"}, source: "/test")
      )

    assert agent.state.last_payment.order_id == "ORD-2"
    assert agent.state.last_payment.status == :success
  end

  defp start_server do
    {:ok, pid} =
      AgentServer.start_link(
        jido: AgentJido.Jido,
        agent: EmitDirectiveAgent,
        id: "emit-test-#{System.unique_integer([:positive])}"
      )

    on_exit(fn ->
      AgentJido.TestProcess.stop(pid)
    end)

    {:ok, pid}
  end
end
