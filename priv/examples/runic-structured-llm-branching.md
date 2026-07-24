%{
  title: "Runic Structured LLM Branching",
  description: "Two-phase Runic orchestrator that makes a real deterministic route decision, hot-swaps the branch DAG, and executes the selected workflow locally.",
  tags: ["primary", "showcase", "ai", "l2", "ai-tool-use", "runic", "branching"],
  category: :ai,
  emoji: "🌿",
  related_resources: [
    %{
      path: "/docs/learn/reasoning-strategies-compared",
      kind: "Concept",
      description: "Reasoning patterns for branch-heavy decision paths.",
      include_livebook: true
    },
    %{
      type: :external,
      label: "branching demo source",
      href: "https://github.com/agentjido/jido_runic/blob/main/lib/examples/branching_demo.exs",
      kind: "Source",
      description: "Structured route output and branch execution walkthrough."
    },
    %{
      type: :external,
      label: "branching orchestrator module",
      href: "https://github.com/agentjido/jido_runic/blob/main/lib/examples/branching/llm_branching_orchestrator.ex",
      kind: "Source",
      description: "Route extraction, workflow swap, and phase 2 execution."
    }
  ],
  source_files: [
    "lib/agent_jido/demos/runic_structured_branching/fixtures.ex",
    "lib/agent_jido/demos/runic_structured_branching/actions.ex",
    "lib/agent_jido/demos/runic_structured_branching/orchestrator_agent.ex",
    "lib/agent_jido/demos/runic_structured_branching/runtime_demo.ex",
    "lib/agent_jido_web/examples/runic_structured_branching_live.ex"
  ],
  live_view_module: "AgentJidoWeb.Examples.RunicStructuredBranchingLive",
  difficulty: :intermediate,
  status: :live,
  scenario_cluster: :ai_tool_use,
  wave: :l2,
  journey_stage: :evaluation,
  content_intent: :tutorial,
  capability_theme: :ai_intelligence,
  evidence_surface: :runnable_example,
  demo_mode: :real,
  sort_order: 17,
  outcome: "Two-phase Runic orchestrator that makes a real deterministic route decision, hot-swaps the branch DAG, and executes the selected workflow locally.",
  packages: ["jido", "jido_ai", "req_llm"],
  package_maturity: "Beta",
  prerequisites: ["Elixir 1.18+", "OTP 27+", "Jido installed", "an LLM provider key"],
  expected_result: "The agent reasons over the prompt using the configured provider and key.",
  run_command: "Run the interactive demo on /examples/runic-structured-llm-branching."
}
---

## What you'll learn

- How a phase-1 Runic router can select a phase-2 DAG with real `runic.set_workflow` calls
- How route metadata (`route`, `detail_level`, `confidence`) can drive both branch choice and UI evidence
- How to expose direct, analysis, and safe outcomes without any provider or network dependency

## Route outcomes

- `:direct` -> quick answer branch
- `:analysis` -> plan + synthesis branch
- `:safe` -> fallback response branch

## Workflow shape

```text
RouteQuestion -> runic.set_workflow(route) -> DirectAnswer | AnalysisPlan -> AnalysisAnswer | SafeResponse
```

The page runs the actual Runic command surface in-process. The route decision is deterministic fixture data, but the branch selection, workflow swap, node execution, and final outputs are real local workflow transitions.

## Demo note

No LLM provider, browser session, or remote network call is required. The source tab shows the real local orchestrator, actions, and LiveView used by this page.
