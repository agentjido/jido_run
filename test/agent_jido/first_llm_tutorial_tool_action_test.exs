defmodule AgentJido.FirstLLMTutorialToolActionTest do
  @moduledoc """
  E05-T20 — the AI onboarding page (Your first LLM agent) used to be model-only:
  it never defined a typed tool Action. This test holds the fix. The onboarding
  must define exactly one typed `Jido.Action` whose schema and effect behavior are
  clear: a typed `schema` (with typed parameters) and a `run/2` effect that the
  page invokes directly so its behavior is observable without an LLM call.
  """
  use ExUnit.Case, async: true

  @livebook_path "priv/pages/docs/getting-started/first-llm-agent.livemd"

  setup do
    {:ok, source: File.read!(@livebook_path)}
  end

  test "defines exactly one typed Jido.Action tool", %{source: source} do
    use_count =
      source
      |> String.split("use Jido.Action,")
      |> length()
      |> Kernel.-(1)

    assert use_count == 1,
           "the AI onboarding should define exactly one typed tool Action " <>
             "(multi-tool ReAct belongs in ai-agent-with-tools), got #{use_count}"
  end

  test "the tool Action declares a typed schema", %{source: source} do
    assert source =~ ~r/schema:\s*\[/s,
           "the tool Action must declare a schema"

    assert source =~ ~r/type:\s*:(string|integer)/,
           "the tool Action schema must declare typed scalar parameters"

    assert source =~ ~r/type:\s*\{:in,\s*\[/,
           "the tool Action schema must demonstrate a typed enum parameter"
  end

  test "the tool Action's effect behavior is declared and invoked", %{source: source} do
    assert source =~ ~r/def run\(%\{[^}]*\},\s*_context\)/,
           "the tool Action must implement a run/2 effect callback"

    assert source =~ ~r/ComposeGreeting\.run\(/,
           "the onboarding must invoke the tool Action directly so its effect " <>
             "behavior is observable without an LLM call"
  end

  test "the first-LLM agent is no longer model-only", %{source: source} do
    assert source =~ "tools: [MyAgentApp.ComposeGreeting]",
           "the first-LLM agent should list the typed tool Action in its tools: " <>
             "instead of staying model-only (tools: [])"
  end
end
