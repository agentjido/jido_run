defmodule AgentJido.CategoryVocabularyLintTest do
  @moduledoc """
  Framework/runtime/platform category-vocabulary gate (jido-e12-t08).

  The positioning canon (`specs/positioning.md` §1, E02-T01) fixes Jido's public
  category as "the Elixir framework for long-running agent systems" and
  explicitly supersedes the former category "Reliable Multi-Agent Runtime
  Platform." Sliding back to the deprecated "Runtime Platform" category label is
  category drift. This gate makes that drift a blocking warning, so new drift
  cannot ship without failing CI.

  Scope: published Pages bodies (`priv/pages/*`), code fences stripped. The words
  "runtime" and "platform" stay valid in their non-category senses — BEAM
  runtime, application/platform responsibility, deployment platform, etc. —
  because only the deprecated *category compound* is blocked, not the bare nouns.
  """
  use ExUnit.Case, async: true

  alias AgentJido.Pages

  # Deprecated strategic-category labels, superseded by the "framework" canon.
  # Each entry is {drift_phrase, canonical_replacement}.
  @category_drift [
    {"runtime platform", "the Elixir framework for long-running agent systems"}
  ]

  # Legitimate, non-category contexts that should never be flagged even if they
  # happen to contain a drift substring. None today; kept so the gate stays
  # precise as vocabulary rules are added.
  @allow_contexts []

  test "public pages do not use the deprecated Runtime Platform category label" do
    offenders =
      for page <- Pages.all_pages(),
          path = source_path(page),
          is_binary(path) and File.regular?(path),
          content = strip_code(File.read!(path)),
          {drift, canonical} <- find_drift(content),
          do: {page.path, drift, canonical}

    assert offenders == [],
           "pages use a deprecated category label (superseded by the \"framework\" " <>
             "canon — specs/positioning.md §1, E02-T01): #{inspect(offenders)}"
  end

  # Positive control (jido-e12-t08): proves NEW category drift trips the gate.
  test "newly introduced category drift is flagged" do
    new_drift =
      "Strategic category | Runtime platform for reliable multi-agent systems"

    assert find_drift(new_drift) != [],
           "the gate must block newly introduced category drift"
  end

  # Negative control: the bare nouns "runtime"/"platform" in their legitimate,
  # non-category senses must not produce false positives.
  test "legitimate non-category uses of runtime/platform are not flagged" do
    legit = [
      "Jido is the Elixir framework for long-running agent systems.",
      "Jido runs on the Elixir/OTP platform.",
      "Authentication is an application or platform responsibility.",
      "Reliable multi-agent runtime behavior on the BEAM."
    ]

    for body <- legit do
      assert find_drift(body) == [],
             "false positive on legitimate copy: #{inspect(body)}"
    end
  end

  defp find_drift(content) do
    lower = String.downcase(content)

    for {drift, canonical} <- @category_drift,
        String.contains?(lower, drift),
        not allowed?(lower) do
      {drift, canonical}
    end
  end

  defp allowed?(lower) do
    Enum.any?(@allow_contexts, &String.contains?(lower, &1))
  end

  defp source_path(page), do: Map.get(page, :source_path) || Map.get(page, "source_path")

  defp strip_code(text) do
    text |> String.replace(~r/```.*?```/s, "") |> String.replace(~r/~~~.*?~~~/s, "")
  end
end
