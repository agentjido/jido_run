defmodule AgentJido.Demos.CodingAssistant do
  @moduledoc """
  A deterministic coding-assistant agent.

  It demonstrates the coding-agent workflow on the real Jido runtime: read a
  fixture module, detect a nil-handling defect with a typed `AnalyzeCode`
  action, and propose a guarded patch with a typed `ProposePatch` action. No LLM
  provider is called -- the analysis is real static scanning of fixture source,
  so the demo is fully deterministic and needs no API key.
  """

  use Jido.Agent,
    name: "coding_assistant_agent",
    description: "Reads fixture code, detects a nil-handling defect, and proposes a guarded patch",
    schema: [
      source: [type: :string, default: ""],
      findings: [type: :string, default: ""],
      patch: [type: :string, default: ""]
    ],
    signal_routes: [
      {"coding.read_source", AgentJido.Demos.CodingAssistant.Actions.ReadSourceAction},
      {"coding.analyze", AgentJido.Demos.CodingAssistant.Actions.AnalyzeCodeAction},
      {"coding.propose_patch", AgentJido.Demos.CodingAssistant.Actions.ProposePatchAction}
    ]

  alias AgentJido.Demos.CodingAssistant.Actions.{
    AnalyzeCodeAction,
    ProposePatchAction,
    ReadSourceAction
  }

  @doc """
  Loads the fixture parser source into agent state.
  """
  @spec read_source(Jido.Agent.t()) :: Jido.Agent.cmd_result()
  def read_source(agent) do
    cmd(agent, ReadSourceAction)
  end

  @doc """
  Scans the loaded source for nil-handling defects.
  """
  @spec analyze(Jido.Agent.t()) :: Jido.Agent.cmd_result()
  def analyze(agent) do
    cmd(agent, AnalyzeCodeAction)
  end

  @doc """
  Builds a guarded patch from the detected findings.
  """
  @spec propose_patch(Jido.Agent.t()) :: Jido.Agent.cmd_result()
  def propose_patch(agent) do
    cmd(agent, ProposePatchAction)
  end
end
