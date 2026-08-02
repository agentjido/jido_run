defmodule AgentJido.VocabularyCanonLintTest do
  @moduledoc """
  Public category scan for framework, runtime, platform, infrastructure, and
  ecosystem vocabulary.
  """

  use ExUnit.Case, async: true

  alias AgentJido.Pages

  @style_guide "specs/style-voice.md"

  @misuse_patterns [
    {~r/\bJido is (?:a|the) (?:runtime|platform|infrastructure)\b/i, "Jido must use framework as its public category"},
    {~r/\bevaluating Jido as (?:a |the )?(?:runtime|platform|infrastructure)\b/i, "evaluation copy must use the framework category"},
    {~r/\bJido (?:runtime )?platform\b/i, "Jido is not a separate platform"},
    {~r/\bJido infrastructure\b/i, "Jido is not infrastructure"},
    {~r/\b(?:requires?|must install) the (?:full )?Jido ecosystem\b/i, "the ecosystem is optional"}
  ]

  test "the style guide defines all five product vocabulary boundaries (jido-e03-t26)" do
    guide = File.read!(@style_guide)

    assert guide =~ "### Product vocabulary boundaries"
    assert guide =~ "| **framework** |"
    assert guide =~ "| **runtime** |"
    assert guide =~ "| **platform** |"
    assert guide =~ "| **infrastructure** |"
    assert guide =~ "| **ecosystem** |"
    assert guide =~ "Jido is not a separate deployment platform."
    assert guide =~ "without installing the full ecosystem"
  end

  test "published page source does not use a superseded product category" do
    offenders =
      for page <- Pages.all_pages(),
          source_path = Map.get(page, :source_path),
          is_binary(source_path) and File.regular?(source_path),
          source = File.read!(source_path),
          {pattern, reason} <- @misuse_patterns,
          Regex.match?(pattern, source),
          do: "#{page.path}: #{reason} (#{inspect(pattern)})"

    assert offenders == [],
           "public vocabulary scan found category misuse:\n" <>
             Enum.map_join(offenders, "\n", &"  - #{&1}")
  end
end
