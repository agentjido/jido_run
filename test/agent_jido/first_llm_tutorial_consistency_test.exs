defmodule AgentJido.FirstLLMTutorialConsistencyTest do
  @moduledoc """
  Regression coverage for the Elixir Forum first-LLM failure
  (https://forum.elixirforum.com/t/trying-first-llm-example-in-livebook-fails/76075).

  The first LLM tutorial configures an OpenAI key but previously selected the
  `:fast` model alias, which resolves to an Anthropic model. The request then
  failed authentication. This test holds the fix: the configured key provider
  and the selected model provider must match, and the model must be explicit.
  See `jido-e01` (E01-T01, E01-T06).
  """
  use ExUnit.Case, async: true

  @livebook_path "priv/pages/docs/getting-started/first-llm-agent.livemd"

  test "the first LLM tutorial uses an explicit openai model matching the OpenAI key" do
    source = File.read!(@livebook_path)

    assert source =~ "ReqLLM.put_key(:openai_api_key,",
           "the tutorial must configure an OpenAI key"

    assert source =~ ~r/model:\s*"openai:[a-z0-9._-]+"/,
           "the tutorial must select an explicit openai: model that matches the OpenAI key"

    refute source =~ ~r/model:\s*:(fast|capable|reasoning|thinking|planning|image|embedding)\b/,
           "the first-LLM tutorial must not use a model alias, because each alias " <>
             "resolves to one fixed provider and can silently mismatch the configured key"
  end
end
