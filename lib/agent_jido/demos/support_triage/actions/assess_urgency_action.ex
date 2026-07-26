defmodule AgentJido.Demos.SupportTriage.Actions.AssessUrgencyAction do
  @moduledoc """
  Gauges the urgency of the loaded support message from real signals.

  Delegates to `AgentJido.Demos.SupportTriage.Classifier`, which flags a message
  as high urgency when it carries a deadline, a blocking outage, or an angry tone
  (urgency markers or three-plus exclamation marks). The detection is real --
  it inspects the loaded text -- so a calm message stays at normal urgency. No
  LLM is called.
  """

  use Jido.Action,
    name: "assess_urgency",
    description: "Gauges the support message urgency from real anger and deadline signals"

  alias AgentJido.Demos.SupportTriage.Classifier

  @impl true
  def run(_params, %{state: %{incoming_message: message}}) do
    {:ok, %{urgency: Classifier.assess(message)}}
  end
end
