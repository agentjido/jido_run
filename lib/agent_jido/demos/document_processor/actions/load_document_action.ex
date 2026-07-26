defmodule AgentJido.Demos.DocumentProcessor.Actions.LoadDocumentAction do
  @moduledoc """
  Loads a named fixture document into agent state.

  Selects one of the invoice, contract, ticket, or unknown fixtures by the
  `which` parameter. A fresh load clears any prior classification, extracted
  fields, and routing so the pipeline starts cleanly from a new document.
  """

  use Jido.Action,
    name: "load_document",
    description: "Loads a fixture document into agent state for processing"

  alias AgentJido.Demos.DocumentProcessor.Fixtures

  @impl true
  def run(%{which: which}, _context) when which in [:invoice, :contract, :ticket, :unknown] do
    {:ok,
     %{
       incoming_document: Fixtures.fetch(which),
       classification: "",
       extracted_fields: "",
       routing: ""
     }}
  end

  def run(_params, _context) do
    {:ok,
     %{
       incoming_document: Fixtures.fetch(:invoice),
       classification: "",
       extracted_fields: "",
       routing: ""
     }}
  end
end
