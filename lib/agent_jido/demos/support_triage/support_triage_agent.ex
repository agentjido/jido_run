defmodule AgentJido.Demos.SupportTriage do
  @moduledoc """
  A deterministic customer-support triage agent.

  It demonstrates a support-triage workflow on the real Jido runtime: load an
  inbound customer message, classify its intent with a typed `ClassifyIntent`
  action, gauge its urgency with a typed `AssessUrgency` action, and draft a
  routed reply with a typed `Respond` action. No LLM provider is called -- the
  classification, urgency, and reply are real keyword and pattern matching on
  the message text, so the demo is fully deterministic and needs no API key.
  """

  use Jido.Agent,
    name: "support_triage_agent",
    description: "Classifies inbound support messages, gauges urgency, and drafts a routed reply",
    schema: [
      incoming_message: [type: :string, default: ""],
      intent: [type: :string, default: ""],
      urgency: [type: :string, default: ""],
      response: [type: :string, default: ""]
    ],
    signal_routes: [
      {"support.load", AgentJido.Demos.SupportTriage.Actions.LoadMessageAction},
      {"support.classify", AgentJido.Demos.SupportTriage.Actions.ClassifyIntentAction},
      {"support.assess", AgentJido.Demos.SupportTriage.Actions.AssessUrgencyAction},
      {"support.respond", AgentJido.Demos.SupportTriage.Actions.RespondAction}
    ]

  alias AgentJido.Demos.SupportTriage.Actions.{
    AssessUrgencyAction,
    ClassifyIntentAction,
    LoadMessageAction,
    RespondAction
  }

  @doc """
  Loads a named fixture message into agent state.

  `which` selects the fixture (`:billing`, `:bug`, `:howto`, or `:thanks`); a
  fresh load clears any prior intent, urgency, and response.
  """
  @spec load_message(Jido.Agent.t(), :billing | :bug | :howto | :thanks | atom()) ::
          Jido.Agent.cmd_result()
  def load_message(agent, which) do
    cmd(agent, {LoadMessageAction, %{which: which}})
  end

  @doc """
  Classifies the loaded message's intent from real keyword signals.
  """
  @spec classify(Jido.Agent.t()) :: Jido.Agent.cmd_result()
  def classify(agent) do
    cmd(agent, ClassifyIntentAction)
  end

  @doc """
  Gauges the loaded message's urgency from real anger and deadline signals.
  """
  @spec assess(Jido.Agent.t()) :: Jido.Agent.cmd_result()
  def assess(agent) do
    cmd(agent, AssessUrgencyAction)
  end

  @doc """
  Drafts a routed reply to the classified message.
  """
  @spec respond(Jido.Agent.t()) :: Jido.Agent.cmd_result()
  def respond(agent) do
    cmd(agent, RespondAction)
  end
end
