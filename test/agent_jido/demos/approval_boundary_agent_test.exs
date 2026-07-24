defmodule AgentJido.Demos.ApprovalBoundaryAgentTest do
  @moduledoc """
  Human-approval boundary (jido-e07-T43/T23): a high-impact publish effect
  waits for an explicit confirm decision and records who decided.
  """
  use ExUnit.Case, async: true

  alias AgentJido.Demos.ApprovalBoundary.{ConfirmPublishAction, RequestPublishAction}
  alias AgentJido.Demos.ApprovalBoundaryAgent

  test "a publish request pauses; only a confirm runs the effect and records the decision" do
    agent = ApprovalBoundaryAgent.new()

    {agent, _} = ApprovalBoundaryAgent.cmd(agent, {RequestPublishAction, %{topic: "release-9"}})
    assert agent.state.pending == true
    assert agent.state.pending_topic == "release-9"
    assert agent.state.published_count == 0

    {agent, _} = ApprovalBoundaryAgent.cmd(agent, {ConfirmPublishAction, %{by: "alice"}})
    assert agent.state.published_count == 1
    assert agent.state.last_decided_by == "alice"
    assert agent.state.pending == false
  end

  test "confirming without a prior request is rejected (fail closed)" do
    agent = ApprovalBoundaryAgent.new()

    {agent, directives} = ApprovalBoundaryAgent.cmd(agent, {ConfirmPublishAction, %{by: "alice"}})

    assert agent.state.published_count == 0
    assert Enum.any?(directives, &(&1.__struct__ == Jido.Agent.Directive.Error))
  end
end
