defmodule AgentJido.Demos.SupportTriage.Actions.ClassifyIntentAction do
  @moduledoc """
  Classifies the loaded support message by real keyword signals.

  Delegates to `AgentJido.Demos.SupportTriage.Classifier`, which scores the
  message text against billing, bug, and how-to intent phrases and selects the
  highest-scoring intent. The matching is real -- it counts actual occurrences
  in the loaded text -- so a message with none of the signals classifies as
  `unknown` instead of always guessing. No LLM is called.
  """

  use Jido.Action,
    name: "classify_intent",
    description: "Classifies the support message intent from real keyword signals"

  alias AgentJido.Demos.SupportTriage.Classifier

  @impl true
  def run(_params, %{state: %{incoming_message: message}}) do
    {:ok, %{intent: Classifier.classify(message)}}
  end
end
