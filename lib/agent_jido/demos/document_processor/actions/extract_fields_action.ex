defmodule AgentJido.Demos.DocumentProcessor.Actions.ExtractFieldsAction do
  @moduledoc """
  Extracts structured fields from the loaded document for real.

  The field set is derived from the prior classification: an invoice yields its
  number, total, and due date; a contract its parties and effective date; a
  ticket its subject and priority. Each value is pulled from the loaded text
  with a real pattern match, so an unrecognized document reports no fields
  honestly. No LLM is called.
  """

  use Jido.Action,
    name: "extract_fields",
    description: "Extracts structured fields from the loaded document by type"

  alias AgentJido.Demos.DocumentProcessor.Classifier

  @impl true
  def run(_params, %{state: %{incoming_document: document, classification: classification}}) do
    # Resolve the type from the stored classification, or derive it from the
    # document when ClassifyDocument has not run yet, so this step is
    # self-sufficient.
    effective = Classifier.resolve(classification, document)
    {:ok, %{extracted_fields: extract(effective, document), classification: effective}}
  end

  defp extract("invoice", document) do
    [
      {"Invoice number", field(document, ~r/Invoice #:\s*([A-Z0-9-]+)/i)},
      {"Total due", field(document, ~r/Total Due:\s*\$?([\d,]+\.\d{2})/i)},
      {"Due date", field(document, ~r/Due Date:\s*([\d-]+)/i)}
    ]
    |> render_fields()
  end

  defp extract("contract", document) do
    [
      {"Effective date", field(document, ~r/Effective Date:\s*([\d-]+)/i)},
      {"Parties", parties(document)}
    ]
    |> render_fields()
  end

  defp extract("ticket", document) do
    [
      {"Ticket number", field(document, ~r/Ticket #:\s*([A-Z0-9-]+)/i)},
      {"Subject", field(document, ~r/Subject:\s*(.+)/i)},
      {"Priority", field(document, ~r/Priority:\s*(\w+)/i)}
    ]
    |> render_fields()
  end

  defp extract(_classification, _document) do
    "No extractable fields (document type unrecognized)."
  end

  defp field(document, regex) do
    case Regex.run(regex, document, capture: :all_but_first) do
      [value | _] -> String.trim(value)
      _ -> "(not found)"
    end
  end

  # Contracts name two parties as `Name ("Role")`. Capture each capitalized
  # name (one or more Capitalized words) that immediately precedes a ` ("` so
  # surrounding prose and the role decoration are both stripped.
  defp parties(document) do
    names =
      Regex.scan(~r/([A-Z][A-Za-z.&]+(?:\s+[A-Z][A-Za-z.&]+)*)\s*\("/, document, capture: :all_but_first)
      |> List.flatten()
      |> Enum.map(&String.trim/1)

    case names do
      [a, b | _] -> "#{a} / #{b}"
      _ -> "(not found)"
    end
  end

  defp render_fields(fields) do
    Enum.map_join(fields, "\n", fn {label, value} -> "- #{label}: #{value}" end)
  end
end
