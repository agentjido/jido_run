defmodule AgentJido.Demos.DocumentProcessor do
  @moduledoc """
  A deterministic document-processing agent.

  It demonstrates the document-processing workflow on the real Jido runtime:
  load an inbound document, classify it with a typed `ClassifyDocument` action,
  extract its fields with a typed `ExtractFields` action, and route it with a
  typed `RouteDocument` action. No LLM provider is called -- the classification,
  extraction, and routing are real keyword and pattern matching on the document
  text, so the demo is fully deterministic and needs no API key.
  """

  use Jido.Agent,
    name: "document_processor_agent",
    description: "Loads, classifies, extracts fields from, and routes inbound documents",
    schema: [
      incoming_document: [type: :string, default: ""],
      classification: [type: :string, default: ""],
      extracted_fields: [type: :string, default: ""],
      routing: [type: :string, default: ""]
    ],
    signal_routes: [
      {"document.load", AgentJido.Demos.DocumentProcessor.Actions.LoadDocumentAction},
      {"document.classify", AgentJido.Demos.DocumentProcessor.Actions.ClassifyDocumentAction},
      {"document.extract", AgentJido.Demos.DocumentProcessor.Actions.ExtractFieldsAction},
      {"document.route", AgentJido.Demos.DocumentProcessor.Actions.RouteDocumentAction}
    ]

  alias AgentJido.Demos.DocumentProcessor.Actions.{
    ClassifyDocumentAction,
    ExtractFieldsAction,
    LoadDocumentAction,
    RouteDocumentAction
  }

  @doc """
  Loads a named fixture document into agent state.

  `which` selects the fixture (`:invoice`, `:contract`, `:ticket`, or
  `:unknown`); a fresh load clears any prior classification, fields, and routing.
  """
  @spec load_document(Jido.Agent.t(), :invoice | :contract | :ticket | :unknown | atom()) ::
          Jido.Agent.cmd_result()
  def load_document(agent, which) do
    cmd(agent, {LoadDocumentAction, %{which: which}})
  end

  @doc """
  Classifies the loaded document from real keyword signals.
  """
  @spec classify(Jido.Agent.t()) :: Jido.Agent.cmd_result()
  def classify(agent) do
    cmd(agent, ClassifyDocumentAction)
  end

  @doc """
  Extracts structured fields from the loaded document by type.
  """
  @spec extract(Jido.Agent.t()) :: Jido.Agent.cmd_result()
  def extract(agent) do
    cmd(agent, ExtractFieldsAction)
  end

  @doc """
  Routes the classified document to a destination queue.
  """
  @spec route(Jido.Agent.t()) :: Jido.Agent.cmd_result()
  def route(agent) do
    cmd(agent, RouteDocumentAction)
  end
end
