defmodule AgentJido.ContentClaimLinterTest do
  @moduledoc """
  Restricted-claim linter over published pages (jido-e12 E12-T01/T02/T37).

  Scans public (non-draft) page sources for claims the E02 canon restricts,
  asserting them only when stated POSITIVELY. Negated or prohibiting sentences
  ("do not claim X", "not a guarantee of X") are allowed, because naming a term
  to prohibit it is how the canon is enforced. Compare pages are excluded because
  they describe competitors. Fenced code is stripped first.
  """
  use ExUnit.Case, async: true

  alias AgentJido.Pages

  @banned_claims [
    "no downtime",
    "uptime guarantees",
    "observe everything",
    "10,000+ supervised agents",
    "production-grade autonomous",
    "secure by default",
    "compliance-ready",
    "enterprise governance",
    "complete audit trail"
  ]

  # Words that flip a match from a claim into a prohibition/negation.
  @negators [
    "not",
    "no ",
    "avoid",
    "without",
    "never",
    "don't",
    "cannot",
    "isn't",
    "aren't",
    "prohibit",
    "restrict",
    "do not",
    "rather than",
    "instead of"
  ]

  test "public pages make no positive restricted claims" do
    offenders =
      for page <- Pages.all_pages(),
          page.category != :compare,
          source_path = source_path(page),
          is_binary(source_path) and File.regular?(source_path),
          content = strip_code(File.read!(source_path)),
          sentence <- sentences(content),
          claim <- @banned_claims,
          String.contains?(sentence, claim),
          not negated?(sentence),
          do: {page.path, claim}

    assert offenders == [],
           "positive restricted claims found on public pages: #{inspect(offenders)}"
  end

  defp source_path(page) do
    Map.get(page, :source_path) || Map.get(page, "source_path")
  end

  defp strip_code(text) do
    text
    |> String.replace(~r/```.*?```/s, "")
    |> String.replace(~r/~~~.*?~~~/s, "")
  end

  defp sentences(text) do
    String.split(text, ~r/(?<=[.!?\n])\s+/)
  end

  defp negated?(sentence) do
    lower = String.downcase(sentence)
    Enum.any?(@negators, &String.contains?(lower, &1))
  end
end
