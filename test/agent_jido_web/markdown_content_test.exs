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
end
