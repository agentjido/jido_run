%{
  title: "Runic AI Research Studio",
  description: "Five-stage Runic workflow for research and writing, backed by a real deterministic `Jido.Runic.Strategy` pipeline.",
  tags: ["primary", "showcase", "ai", "l2", "ai-tool-use", "runic", "workflow"],
  category: :ai,
  emoji: "🧪",
  related_resources: [
    %{
      path: "/docs/learn/ai-agent-with-tools",
      kind: "Tutorial",
      description: "Build tool-using AI agent loops in Jido.",
      include_livebook: true
    },
    %{
      path: "/docs/learn/reasoning-strategies-compared",
      kind: "Concept",
      description: "Understand strategy tradeoffs for multi-step agent behavior.",
      include_livebook: true
    },
    %{
      type: :external,
      label: "jido_runic repository",
      href: "https://github.com/agentjido/jido_runic",
      kind: "Source",
      description: "Upstream Runic integration package and examples."
    }
  ],
  source_files: [
    "lib/agent_jido/demos/runic_research_studio/fixtures.ex",
    "lib/agent_jido/demos/runic_research_studio/actions.ex",
    "lib/agent_jido/demos/runic_research_studio/orchestrator_agent.ex",
    "lib/agent_jido/demos/runic_research_studio/runtime_demo.ex",
    "lib/agent_jido_web/examples/runic_research_studio_live.ex"
  ],
  live_view_module: "AgentJidoWeb.Examples.RunicResearchStudioLive",
  difficulty: :intermediate,
  status: :live,
  scenario_cluster: :ai_tool_use,
  wave: :l2,
  journey_stage: :evaluation,
  content_intent: :tutorial,
  capability_theme: :ai_intelligence,
  evidence_surface: :runnable_example,
  demo_mode: :real,
  sort_order: 14,
  outcome: "Five-stage Runic workflow for research and writing, backed by a real deterministic `Jido.Runic.Strategy` pipeline.",
  packages: ["jido", "jido_ai", "req_llm"],
  package_maturity: "Beta",
  prerequisites: ["Elixir 1.18+", "OTP 27+", "Jido installed", "an LLM provider key"],
  expected_result: "The agent reasons over the prompt using the configured provider and key.",
  run_command: "Run the interactive demo on /examples/runic-ai-research-studio."
}
---

## What you'll learn

- How a 5-node Runic DAG can drive a complete research-to-article workflow
- How `Jido.Runic.Strategy` can execute the pipeline in one-shot auto mode
- How to inspect deterministic node inputs, outputs, graph state, and final article artifacts without any provider setup

## Pipeline topology

```text
PlanQueries -> SimulateSearch -> BuildOutline -> DraftArticle -> EditAndAssemble
```

This example uses the real Runic command surface in the workbench UI. The actions are deterministic local fixtures, so the page does not need API keys, network calls, or browser automation.

## Source references

- [studio_demo.exs](https://github.com/agentjido/jido_runic/blob/main/lib/examples/studio_demo.exs)
- [orchestrator_agent.ex](https://github.com/agentjido/jido_runic/blob/main/lib/examples/studio/orchestrator_agent.ex)

## Run command (upstream package)

```bash
mix run lib/examples/studio_demo.exs
```

## Local demo note

The site demo runs a real local Runic workflow with deterministic action outputs. No LLM provider, browser session, or remote network call is required.
