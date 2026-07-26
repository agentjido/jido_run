defmodule AgentJido.Demos.DocumentProcessor.Classifier do
  @moduledoc """
  Shared, deterministic document classifier.

  Scores a document against invoice, contract, and ticket signal phrases and
  selects the highest-scoring category. Used by the `ClassifyDocument` action
  and -- when the pipeline has not classified yet -- derived lazily by the
  `ExtractFields` and `RouteDocument` actions so each step is self-sufficient.

  Signals are explicit string phrases (not a `~w` sigil) so multi-word phrases
  such as `"total due"` and `"effective date"` match as one phrase rather than
  being split into fragments.
  """

  # Deliberately a list of full phrases, not ~w(): ~w("total due") would split
  # the quotes into literal fragments and pollute the score.
  @signals %{
    "invoice" => ["invoice", "subtotal", "total due", "amount due", "due date", "bill to"],
    "contract" => [
      "agreement",
      "terms and conditions",
      "hereby",
      "parties",
      "party",
      "effective date",
      "between"
    ],
    "ticket" => ["support ticket", "ticket #", "issue", "priority", "reported by", "subject"]
  }

  @doc """
  Classify a document string, or `nil` to resolve the type from a stored
  classification when one is already present.
  """
  @spec classify(String.t()) :: String.t()
  def classify(""), do: "unknown"

  def classify(document) do
    downcased = String.downcase(document)

    scores =
      Map.new(@signals, fn {type, phrases} ->
        {type, Enum.count(phrases, &String.contains?(downcased, &1))}
      end)

    max_score = scores |> Map.values() |> Enum.max(fn -> 0 end)

    case max_score do
      0 -> "unknown"
      _ -> Enum.find(scores, fn {_type, score} -> score == max_score end) |> elem(0)
    end
  end

  @doc """
  Resolve the effective classification for a step: use the stored classification
  when present, otherwise derive it from the document so a step that runs before
  `ClassifyDocument` still has a type to work from.
  """
  @spec resolve(String.t(), String.t()) :: String.t()
  def resolve("", document), do: classify(document)
  def resolve(stored, _document), do: stored
end
