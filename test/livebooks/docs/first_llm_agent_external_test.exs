defmodule AgentJido.Livebooks.Docs.FirstLLMAgentExternalTest do
  use AgentJido.LivebookCase,
    livebook: "priv/pages/docs/getting-started/first-llm-agent.livemd",
    timeout: 180_000,
    external: true,
    required_any_env: ["OPENAI_API_KEY", "LB_OPENAI_API_KEY"]

  test "the documented OpenAI request completes" do
    assert :ok = run_livebook()
  end
end
