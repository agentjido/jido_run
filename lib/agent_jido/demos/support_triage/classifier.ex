defmodule AgentJido.Demos.SupportTriage.Classifier do
  @moduledoc """
  Shared, deterministic support-message classifier.

  Scores an inbound customer message against billing, bug, and how-to intent
  signals and selects the highest-scoring intent, and gauges urgency from real
  anger and deadline signals. Used by the `ClassifyIntent` and `AssessUrgency`
  actions and -- when an earlier step has not run -- derived lazily by the
  `Respond` action so each step is self-sufficient.

  Intent signals are explicit string phrases (not a `~w` sigil) so multi-word
  intents such as `"how do i"` match as one phrase rather than being split into
  fragments.
  """

  # Deliberately a list of full phrases, not ~w(): ~w("how do i") would split
  # the quotes into literal fragments and pollute the score.
  @intents %{
    "billing" => ["invoice", "charge", "charged", "refund", "subscription", "billing", "payment", "card"],
    "bug" => ["crash", "crashes", "bug", "error", "broken", "exception", "fail", "fix"],
    "how-to" => ["how do i", "how to", "how can i", "where do", "where can", "can i", "invite", "settings", "configure"]
  }

  # Single-word urgency markers, so a ~w sigil is safe here.
  @urgency_markers ~w(asap urgent immediately deadline blocking critical outage down)

  @doc """
  Classify a support message's intent, or `"unknown"` when the message carries
  none of the billing, bug, or how-to signals.
  """
  @spec classify(String.t()) :: String.t()
  def classify(""), do: "unknown"

  def classify(message) do
    downcased = String.downcase(message)

    scores =
      Map.new(@intents, fn {intent, phrases} ->
        {intent, Enum.count(phrases, &String.contains?(downcased, &1))}
      end)

    max_score = scores |> Map.values() |> Enum.max(fn -> 0 end)

    case max_score do
      0 -> "unknown"
      _ -> Enum.find(scores, fn {_intent, score} -> score == max_score end) |> elem(0)
    end
  end

  @doc """
  Resolve the effective intent for a step: use the stored intent when present,
  otherwise derive it from the message so a step that runs before
  `ClassifyIntent` still has an intent to work from.
  """
  @spec resolve(String.t(), String.t()) :: String.t()
  def resolve("", message), do: classify(message)
  def resolve(stored, _message), do: stored

  @doc """
  Gauge a support message's urgency from real signals -- a deadline, a blocking
  outage, or an angry tone (urgency markers or three-plus exclamation marks).
  Returns `"high"` or `"normal"`.
  """
  @spec assess(String.t()) :: String.t()
  def assess(""), do: "normal"

  def assess(message) do
    downcased = String.downcase(message)

    angry? =
      Enum.any?(@urgency_markers, &String.contains?(downcased, &1)) or
        exclamation_count(message) >= 3

    if angry?, do: "high", else: "normal"
  end

  @doc """
  Resolve the effective urgency for a step: use the stored urgency when present,
  otherwise derive it from the message so a step that runs before
  `AssessUrgency` still has an urgency to work from.
  """
  @spec resolve_urgency(String.t(), String.t()) :: String.t()
  def resolve_urgency("", message), do: assess(message)
  def resolve_urgency(stored, _message), do: stored

  defp exclamation_count(message) do
    message |> String.graphemes() |> Enum.count(&(&1 == "!"))
  end
end
