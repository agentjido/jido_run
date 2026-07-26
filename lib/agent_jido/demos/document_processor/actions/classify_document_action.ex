defmodule AgentJido.Demos.DocumentProcessor.Actions.ClassifyDocumentAction do
  @moduledoc """
  Classifies the loaded document by real keyword signals.

  Delegates to `AgentJido.Demos.DocumentProcessor.Classifier`, which scores the
  document text against invoice, contract, and ticket signal phrases and selects
  the highest-scoring category. The matching is real -- it counts actual
  occurrences in the loaded text -- so a document with none of the signals
  classifies as `unknown` instead of always guessing. No LLM is called.
  """

  use Jido.Action,
    name: "classify_document",
    description: "Classifies the loaded document type from real keyword signals"

  alias AgentJido.Demos.DocumentProcessor.Classifier

  @impl true
  def run(_params, %{state: %{incoming_document: document}}) do
    {:ok, %{classification: Classifier.classify(document)}}
  end
end
