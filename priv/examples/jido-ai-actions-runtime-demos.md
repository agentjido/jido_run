%{
  title: "Jido.AI Actions Runtime Demos",
  description: "Deterministic `Jido.Exec.run/3` walkthrough for LLM envelopes, tool execution, planning, reasoning, retrieval, and quota flows.",
  tags: ["primary", "showcase", "ai", "l2", "ai-tool-use", "jido_ai", "actions", "runtime"],
  category: :ai,
  emoji: "🧰",
  related_resources: [
    %{
      path: "/docs/learn/ai-agent-with-tools",
      kind: "Tutorial",
      description: "Understand tool-calling loops and runtime integration.",
      include_livebook: true
    },
    %{
      type: :external,
      label: "actions demo scripts",
      href: "https://github.com/agentjido/jido_ai/tree/main/lib/examples/scripts/demo",
      kind: "Source",
      description: "Upstream action runtime scripts across action families."
    }
  ],
  source_files: [
    "lib/agent_jido/demos/actions_runtime/runtime_demo.ex",
    "lib/agent_jido/demos/actions_runtime/fixture_actions.ex",
    "lib/agent_jido/demos/actions_runtime/convert_temperature_action.ex",
    "lib/agent_jido_web/examples/actions_runtime_demo_live.ex"
  ],
  live_view_module: "AgentJidoWeb.Examples.ActionsRuntimeDemoLive",
  difficulty: :intermediate,
  status: :live,
  scenario_cluster: :ai_tool_use,
  wave: :l2,
  journey_stage: :evaluation,
  content_intent: :reference,
  capability_theme: :ai_intelligence,
  evidence_surface: :runnable_example,
  demo_mode: :real,
  sort_order: 19,
  outcome: "Deterministic `Jido.Exec.run/3` walkthrough for LLM envelopes, tool execution, planning, reasoning, retrieval, and quota flows.",
  packages: ["jido", "jido_ai", "req_llm"],
  package_maturity: "Beta",
  prerequisites: ["Elixir 1.18+", "OTP 27+", "Jido installed", "an LLM provider key"],
  expected_result: "The agent reasons over the prompt using the configured provider and key.",
  run_command: "Run the interactive demo on /examples/jido-ai-actions-runtime-demos."
}
---

## What you'll learn

- When to use direct action runtime calls instead of long-lived agent loops
- How the core action families map to practical workflows
- How to keep a runtime demo deterministic without external API keys or network access
- How to swap fixture-backed families to `Jido.AI.Actions.*` modules in your own app

## Covered action families

- LLM envelopes: fixture-backed `chat`, `complete`, and `generate_object`
- Tool calling: shipped `list_tools` / `execute_tool` plus one deterministic `call_with_tools` companion
- Planning: deterministic `plan`, `decompose`, and `prioritize`
- Reasoning: deterministic `analyze`, `infer`, `explain`, and `run_strategy`
- Retrieval: shipped `upsert_memory`, `recall_memory`, and `clear_memory`
- Quota: shipped `get_status` and `reset`

## How this demo stays deterministic

This page runs **real `Jido.Exec.run/3` calls** on every button press.

- Retrieval and quota use the shipped `Jido.AI.Actions.*` modules directly.
- Tool discovery and direct tool execution use the shipped tool-calling actions directly.
- The LLM-backed families use local fixture actions in this repo so the site demo never depends on provider credentials.

That keeps the public example truthful: the runtime surface is real, the code is local, and the outputs stay repeatable.

## Pull the pattern into your own app

In your own project, keep the same `Jido.Exec.run/3` shape and swap the fixture-backed families to the production modules from `Jido.AI.Actions.*`.

- Keep retrieval and quota as-is if the in-process stores fit your needs.
- Replace the fixture tool with your own tool Action modules.
- Replace the fixture LLM/planning/reasoning actions with the shipped `Jido.AI.Actions.*` modules once provider credentials are configured.
