defmodule AgentJido.Specs.ProofInventoryCouplingContractTest do
  use ExUnit.Case, async: true

  # E12-T35: a PR that adds, removes, or changes any claim must update the
  # claim-to-evidence inventory (specs/proof.md) in the same PR, so claims and
  # evidence cannot drift in separate changes. These tests lock that rule into
  # the Contributor PR checklist and the specs index so it cannot regress.

  @contributor_docs_path Path.expand("../../../specs/contributor-docs.md", __DIR__)
  @specs_readme_path Path.expand("../../../specs/README.md", __DIR__)
  @proof_inventory_path Path.expand("../../../specs/proof.md", __DIR__)

  describe "the proof inventory exists as the canonical claim-to-evidence source" do
    test "specs/proof.md is present" do
      assert File.exists?(@proof_inventory_path),
             "expected the canonical proof inventory specs/proof.md to exist"
    end
  end

  describe "the Contributor PR checklist gates claim changes on specs/proof.md" do
    test "the checklist section is present" do
      assert String.contains?(
               File.read!(@contributor_docs_path),
               "## Contributor PR checklist"
             ),
             "contributor-docs.md must keep the '## Contributor PR checklist' section"
    end

    test "the checklist names specs/proof.md as the claim-change gate" do
      checklist = checklist_section()

      assert checklist =~ "`specs/proof.md`",
             "the Contributor PR checklist must require updating specs/proof.md for claim changes"
    end

    test "the checklist forbids claim PRs from landing without specs/proof.md current" do
      checklist = checklist_section()

      assert checklist =~ "Claim" and checklist =~ "must not land without",
             "the Contributor PR checklist must state that claim PRs must not land without specs/proof.md current"
    end

    test "the checklist keeps the named-proof-level discipline in the gate" do
      checklist = checklist_section()

      assert checklist =~ "named proof level",
             "the Contributor PR checklist must keep claim changes at a named proof level"
    end
  end

  describe "the specs index couples claim changes to specs/proof.md" do
    test "the Proof rule names proof.md for claim changes" do
      readme = File.read!(@specs_readme_path)

      # The README wraps across lines, so match the intact "claims: update" clause
      # rather than the split "If you change / claims:" wording.
      assert readme =~ "claims: update `proof.md`",
             "specs/README.md Proof rule must couple claim changes to updating proof.md"
    end
  end

  # Returns only the tail after the "## Contributor PR checklist" heading so the
  # proof-inventory assertions are specific to the checklist itself, not the
  # whole file.
  defp checklist_section do
    case String.split(File.read!(@contributor_docs_path), "## Contributor PR checklist", parts: 2) do
      [_, checklist] -> checklist
      [_] -> flunk("contributor-docs.md is missing the '## Contributor PR checklist' section")
    end
  end
end
