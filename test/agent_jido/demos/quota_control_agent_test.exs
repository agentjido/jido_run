defmodule AgentJido.Demos.QuotaControlAgentTest do
  @moduledoc """
  Quota/cost-control (jido-e07-T42 / jido-e05-T38 / jido-e08-T41): calls
  succeed up to the budget, then the next call is rejected with an observable
  result.
  """
  use ExUnit.Case, async: true

  alias AgentJido.Demos.QuotaControl.BilledAction
  alias AgentJido.Demos.QuotaControlAgent
  alias Jido.Agent.Directive

  test "calls succeed up to the quota, then the next is rejected" do
    agent = QuotaControlAgent.new(max_calls: 3)

    {agent, []} = QuotaControlAgent.cmd(agent, {BilledAction, %{item: "a"}})
    {agent, []} = QuotaControlAgent.cmd(agent, {BilledAction, %{item: "b"}})
    {agent, []} = QuotaControlAgent.cmd(agent, {BilledAction, %{item: "c"}})
    assert agent.state.calls == 3

    {agent, directives} = QuotaControlAgent.cmd(agent, {BilledAction, %{item: "d"}})
    # Rejected: state unchanged and an error directive is produced.
    assert agent.state.calls == 3
    assert Enum.any?(directives, &match?(%Directive.Error{}, &1))
  end
end
