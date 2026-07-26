defmodule AgentJido.ContentAssistant.ResultTest do
  use ExUnit.Case, async: true

  alias AgentJido.ContentAssistant.Result

  describe "classify_content_type/1" do
    # The five content types a user must be able to distinguish (jido-e10-t28).
    test "docs concept pages classify as a definition" do
      assert Result.classify_content_type(
               source_type: :docs,
               path: "/docs/concepts/agents",
               url: "/docs/concepts/agents"
             ) == :definition
    end

    test "docs guide pages classify as a guide" do
      assert Result.classify_content_type(
               source_type: :docs,
               path: "/docs/guides/error-handling-and-recovery"
             ) == :guide

      assert Result.classify_content_type(
               source_type: :docs,
               url: "/docs/getting-started/first-agent"
             ) == :guide
    end

    test "ecosystem and ecosystem_docs surfaces classify as a package" do
      assert Result.classify_content_type(source_type: :ecosystem, url: "/ecosystem/jido") ==
               :package

      assert Result.classify_content_type(
               source_type: :ecosystem_docs,
               url: "https://hexdocs.pm/jido/Jido.Agent.html",
               page_kind: :module
             ) == :package
    end

    test "examples classify as an example" do
      assert Result.classify_content_type(source_type: :examples, url: "/examples/controlled-agent") ==
               :example
    end

    test "blog case-study posts classify as a case study via any taxonomy signal" do
      for signal <- [:post_type, :content_intent, :evidence_surface] do
        signals = [{:source_type, :blog}, {:url, "/blog/acme"}, {signal, "case_study"}]

        assert Result.classify_content_type(signals) == :case_study
      end

      assert Result.classify_content_type(
               source_type: :blog,
               url: "/blog/acme",
               content_intent: :case_study
             ) == :case_study
    end

    test "non-case-study blog posts classify as an article" do
      assert Result.classify_content_type(
               source_type: :blog,
               url: "/blog/release-notes",
               post_type: "release"
             ) == :article
    end

    test "skills classify as a skill" do
      assert Result.classify_content_type(source_type: :skills, url: "/skills/router") == :skill
    end

    test "other docs pages fall back to reference" do
      assert Result.classify_content_type(source_type: :docs, url: "/features/tools") == :reference
    end

    test "accepts a map of signals" do
      assert Result.classify_content_type(%{source_type: :examples, url: "/examples/x"}) == :example
    end

    test "an explicitly declared content type overrides inference" do
      assert Result.classify_content_type(
               source_type: :docs,
               url: "/docs/concepts/agents",
               content_type: "case_study"
             ) == :case_study
    end
  end

  describe "proof_level_for/1" do
    test "maps content types onto the proof-level ladder from the style guide" do
      assert Result.proof_level_for(:case_study) == :production_evidence
      assert Result.proof_level_for(:example) == :tested_behavior
      assert Result.proof_level_for(:package) == :tested_behavior
      assert Result.proof_level_for(:skill) == :tested_behavior
      assert Result.proof_level_for(:reference) == :tested_behavior
      assert Result.proof_level_for(:guide) == :design_intent
      assert Result.proof_level_for(:definition) == :design_intent
      assert Result.proof_level_for(:article) == :design_intent
      assert Result.proof_level_for(nil) == nil
    end
  end

  describe "normalize_content_type/1" do
    test "passes canonical atoms through" do
      for type <- [:definition, :guide, :package, :example, :case_study, :skill, :article, :reference] do
        assert Result.normalize_content_type(type) == type
      end
    end

    test "coerces recognized strings" do
      assert Result.normalize_content_type("definition") == :definition
      assert Result.normalize_content_type("Case study") == :case_study
      assert Result.normalize_content_type("CASE_STUDY") == :case_study
    end

    test "rejects unknown values" do
      assert Result.normalize_content_type("nope") == nil
      assert Result.normalize_content_type(nil) == nil
    end
  end
end
