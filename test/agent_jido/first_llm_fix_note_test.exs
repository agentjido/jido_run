defmodule AgentJido.FirstLLMFixNoteTest do
  @moduledoc """
  Locks the public fix note for the Elixir Forum first-LLM fault (jido-e11, E11-T13).

  Acceptance condition: "The note states cause, correction, and regression
  protection." This test enforces that the published note names all three, cites
  the public source, and points at the corrected tutorial and the regression
  test that holds the fix.

  The fault itself is locked by `first_llm_tutorial_consistency_test.exs`; this
  test locks the *note* about it so the public record cannot drift away from
  cause / correction / regression protection.
  """

  use ExUnit.Case, async: true

  alias AgentJido.Blog

  @note_id "fix-first-llm-tutorial-provider-mismatch"
  @note_path "priv/blog/2026/07-27-fix-first-llm-tutorial-provider-mismatch.md"
  @tutorial_path "/docs/getting-started/first-llm-agent"
  @forum_thread "https://forum.elixirforum.com/t/trying-first-llm-example-in-livebook-fails/76075"
  @regression_test_path "test/agent_jido/first_llm_tutorial_consistency_test.exs"

  test "the fix note is published and parses as a blog post" do
    post = Blog.get_post_by_id!(@note_id)

    assert post.id == @note_id
    assert post.author == "Mike Hostetler"
    assert post.source_path =~ @note_path
    assert "fix-note" in (post.tags || [])
  end

  describe "the note states cause, correction, and regression protection" do
    setup do
      [source: File.read!(@note_path)]
    end

    test "states the cause: the OpenAI key was paired with an alias that resolved to another provider",
         %{source: source} do
      # The fault is a provider/key mismatch, not a generic "it broke".
      assert source =~ ~r/Cause/,
             "the note must have a Cause section"

      assert source =~ "ReqLLM.put_key(:openai_api_key,",
             "the note must name the configured OpenAI key"

      assert source =~ ":fast",
             "the note must name the alias that caused the mismatch"

      assert source =~ "Anthropic",
             "the note must state which provider the alias resolved to"

      assert source =~ "mismatch",
             "the note must name the mismatch as the cause"
    end

    test "states the correction: an explicit openai: model that matches the key",
         %{source: source} do
      assert source =~ ~r/Correction/,
             "the note must have a Correction section"

      assert source =~ "openai:gpt-4o-mini",
             "the note must name the explicit model the guide now uses"

      assert source =~ "explicit",
             "the note must state that the model is now explicit, not an alias"
    end

    test "states the regression protection: the test that holds the fix",
         %{source: source} do
      assert source =~ ~r/Regression protection/,
             "the note must have a Regression protection section"

      assert source =~ @regression_test_path,
             "the note must point at the regression test file"

      assert source =~ "alias",
             "the note must state that the test forbids the alias"
    end
  end

  test "the note cites the public source and points at the corrected tutorial" do
    source = File.read!(@note_path)

    assert source =~ @forum_thread,
           "the note must cite the Elixir Forum thread"

    assert source =~ @tutorial_path,
           "the note must link to the corrected tutorial"
  end
end
