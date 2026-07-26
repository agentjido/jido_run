defmodule AgentJido.Specs.OperationalControlCopyReviewContractTest do
  use ExUnit.Case, async: true

  # E12-T45: the Website Release Punchlist must carry an operational-control copy
  # review a reviewer runs before release. The task acceptance is that "a reviewer
  # checks the four control questions, claim limits, and proof links." These tests
  # lock that reviewer gate into the runbook so it cannot regress.

  @punchlist_path Path.expand("../../../specs/runbooks/release_punchlist.md", __DIR__)

  # The four control questions Jido answers for every piece of agent work — the
  # canonical short labels used on the home operational-control section and in the
  # backlog's cross-cutting control standard.
  @four_control_questions [
    "Who initiated work",
    "What was allowed",
    "What happened",
    "How failure was handled"
  ]

  # The six bounded terms from positioning.md Claim boundaries — the claim limits
  # the reviewer keeps inside their safe current meaning.
  @claim_limit_terms [
    "identity",
    "authorization",
    "audit",
    "observability",
    "policy",
    "production"
  ]

  describe "the release punchlist exists as the operator checklist" do
    test "specs/runbooks/release_punchlist.md is present" do
      assert File.exists?(@punchlist_path),
             "expected the release punchlist specs/runbooks/release_punchlist.md to exist"
    end
  end

  describe "the operational-control copy review is a named release gate" do
    test "the review section is present" do
      assert copy_review_section() != nil,
             "release_punchlist.md must keep the '## Operational-Control Copy Review' gate"
    end

    test "the Required Hard Gates name the copy review" do
      gates = hard_gates_section()

      assert gates =~ "Operational-control copy review",
             "the Required Hard Gates must name the operational-control copy review as a release gate"
    end
  end

  describe "the review checks the four control questions" do
    test "every control question is named in the review" do
      review = copy_review_section()

      Enum.each(@four_control_questions, fn question ->
        assert review =~ question,
               "the operational-control copy review must name the control question '#{question}'"
      end)
    end
  end

  describe "the review checks claim limits" do
    test "every bounded claim term is named in the review" do
      review = copy_review_section()

      Enum.each(@claim_limit_terms, fn term ->
        assert review =~ ~r/\b#{Regex.escape(term)}\b/i,
               "the operational-control copy review must name the bounded claim term '#{term}'"
      end)
    end

    test "the review keeps the do-not-imply discipline" do
      review = copy_review_section()

      assert review =~ "do not imply",
             "the operational-control copy review must keep the 'do not imply' claim-limit discipline"
    end
  end

  describe "the review checks proof links" do
    test "the review requires proof links for control claims" do
      review = copy_review_section()

      assert review =~ "proof link",
             "the operational-control copy review must require proof links for control claims"

      assert review =~ "`specs/proof.md`",
             "the operational-control copy review must point control claims at the proof inventory specs/proof.md"
    end
  end

  # Returns only the body of the "## Operational-Control Copy Review" section — up to
  # the next "## " heading — so the four-question / claim-limit / proof-link assertions
  # stay specific to the review itself, not the rest of the punchlist. Whitespace is
  # collapsed so prose assertions are not brittle to Markdown line-wrapping.
  defp copy_review_section do
    case String.split(File.read!(@punchlist_path), "## Operational-Control Copy Review", parts: 2) do
      [_, rest] ->
        section =
          case String.split(rest, ~r/\n## /, parts: 2) do
            [section, _] -> section
            [section] -> section
          end

        normalize(section)

      [_] ->
        nil
    end
  end

  # Returns only the "## Required Hard Gates" section body so the gate-naming
  # assertion is specific to the hard-gate list. Whitespace is collapsed so the
  # assertion is not brittle to line-wrapping.
  defp hard_gates_section do
    case String.split(File.read!(@punchlist_path), "## Required Hard Gates", parts: 2) do
      [_, rest] ->
        section =
          case String.split(rest, ~r/\n## /, parts: 2) do
            [section, _] -> section
            [section] -> section
          end

        normalize(section)

      [_] ->
        flunk("release_punchlist.md is missing the '## Required Hard Gates' section")
    end
  end

  defp normalize(text), do: String.replace(text, ~r/\s+/, " ")
end
