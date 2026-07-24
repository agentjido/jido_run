%{
  title: "Runic Delegating Orchestrator",
  description: "Parent Runic workflow that executes early stages locally and delegates drafting/editing stages through the real child-worker handoff strategy path.",
  tags: ["primary", "showcase", "ai", "l2", "coordination", "runic", "multi-agent"],
  category: :ai,
  emoji: "🛰",
  related_resources: [
    %{
      path: "/docs/learn/multi-agent-orchestration",
      kind: "Tutorial",
      description: "Coordination patterns for parent/child agent systems.",
      include_livebook: true
    },
    %{
      type: :external,
      label: "delegating demo source",
      href: "https://github.com/agentjido/jido_runic/blob/main/lib/examples/delegating_demo.exs",
      kind: "Source",
      description: "End-to-end delegating pipeline script."
    },
    %{
      type: :external,
      label: "delegating orchestrator module",
      href: "https://github.com/agentjido/jido_runic/blob/main/lib/examples/delegating/delegating_orchestrator.ex",
      kind: "Source",
      description: "ActionNode executor tags and child handoff flow."
    }
  ],
  source_files: [
    "lib/agent_jido/demos/runic_research_studio/fixtures.ex",
    "lib/agent_jido/demos/runic_research_studio/actions.ex",
    "lib/agent_jido/demos/runic_delegating_orchestrator/orchestrator_agent.ex",
    "lib/agent_jido/demos/runic_delegating_orchestrator/runtime_demo.ex",
    "lib/agent_jido_web/examples/runic_delegating_orchestrator_live.ex"
  ],
  live_view_module: "AgentJidoWeb.Examples.RunicDelegatingOrchestratorLive",
  difficulty: :intermediate,
  status: :live,
  scenario_cluster: :coordination,
  wave: :l2,
  journey_stage: :evaluation,
  content_intent: :tutorial,
  capability_theme: :coordination_orchestration,
  evidence_surface: :runnable_example,
  demo_mode: :real,
  sort_order: 18,
  outcome: "Parent Runic workflow that executes early stages locally and delegates drafting/editing stages through the real child-worker handoff strategy path.",
  packages: ["jido", "jido_ai", "req_llm"],
  package_maturity: "Beta",
  prerequisites: ["Elixir 1.18+", "OTP 27+", "Jido installed", "an LLM provider key"],
  expected_result: "The agent reasons over the prompt using the configured provider and key.",
  run_command: "Run the interactive demo on /examples/runic-delegating-orchestrator."
}
---

## What you'll learn

- How to mix local node execution with delegated child-agent nodes
- How `executor: {:child, tag}` affects workflow dispatch behavior
- How to surface parent/child handoff traces in a deterministic demo UI without starting external services

## Delegated stages

`DraftArticle` and `EditAndAssemble` are delegated to specialized child workers while early planning nodes run locally.

## Demo note

This page runs the real Runic delegation strategy path locally. The child-worker outputs are deterministic fixtures, but the handoff states, delegated runnable execution, and final article artifact come from the actual workflow and strategy commands.
