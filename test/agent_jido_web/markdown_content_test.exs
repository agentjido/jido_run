defmodule AgentJidoWeb.MarkdownContentTest do
  use ExUnit.Case, async: true

  alias AgentJidoWeb.MarkdownContent

  describe "release placeholder expansion in markdown delivery (E01-T08, E01-T11)" do
    test "the first-LLM agent markdown payload has no unresolved placeholders" do
      {:ok, markdown} =
        MarkdownContent.resolve(
          "/docs/getting-started/first-llm-agent",
          "https://jido.run/docs/getting-started/first-llm-agent"
        )

      refute markdown =~ ~r/\{\{/,
             "public markdown must not contain unresolved {{...}} placeholders"

      # The expanded payload carries real dependency requirements, not tokens.
      assert markdown =~ "{:jido,"
      assert markdown =~ "{:jido_ai,"
    end
  end

  describe "compare markdown delivery (E10-T10)" do
    test "compare detail pages and the hub resolve to markdown" do
      assert {:ok, _} =
               MarkdownContent.resolve(
                 "/compare/semantic-kernel",
                 "https://jido.run/compare/semantic-kernel"
               )

      assert {:ok, _} =
               MarkdownContent.resolve("/compare", "https://jido.run/compare")
    end
  end

  describe "skills markdown delivery (E10-T09)" do
    test "the skills hub resolves to markdown (the .md route promised by llms.txt)" do
      assert {:ok, markdown} =
               MarkdownContent.resolve("/skills", "https://jido.run/skills")

      assert markdown =~ "Skills"
    end
  end
end
