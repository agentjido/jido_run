defmodule AgentJido.Demos.DocumentProcessor.Actions.RouteDocumentAction do
  @moduledoc """
  Routes the document to a destination queue based on its classification.

  Routing is derived for real from the prior steps: a high-value invoice goes to
  an escalation queue, a high-priority ticket to a higher support tier, and an
  unrecognized document to manual triage. No LLM is called.
  """

  use Jido.Action,
    name: "route_document",
    description: "Routes the classified document to a destination queue"

  alias AgentJido.Demos.DocumentProcessor.Classifier

  @impl true
  def run(_params, %{state: state}) do
    %{classification: classification, incoming_document: document} = state
    # Resolve the type from the stored classification, or derive it from the
    # document when ClassifyDocument has not run yet, so this step is
    # self-sufficient.
    effective = Classifier.resolve(classification, document)
    {:ok, %{routing: route(effective, document), classification: effective}}
  end

  defp route("invoice", document) do
    # An invoice at or above the escalation threshold needs reviewer attention.
    total = parse_total(document)

    if total >= 1000 do
      "accounts-payable-escalation (total $#{format_total(total)})"
    else
      "accounts-payable"
    end
  end

  defp route("contract", _document), do: "legal-review"

  defp route("ticket", document) do
    if String.downcase(document) =~ "priority: high" do
      "support-tier-2 (high priority)"
    else
      "support-tier-1"
    end
  end

  defp route(_classification, _document), do: "manual-triage"

  defp parse_total(document) do
    case Regex.run(~r/Total Due:\s*\$?([\d,]+\.\d{2})/i, document, capture: :all_but_first) do
      [raw | _] ->
        raw
        |> String.replace(",", "")
        |> String.to_float()

      _ ->
        0.0
    end
  end

  defp format_total(total) do
    total |> :erlang.float_to_binary(decimals: 2)
  end
end
