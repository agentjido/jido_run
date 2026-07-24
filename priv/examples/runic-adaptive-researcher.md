%{
  title: "Runic Adaptive Researcher",
  description: "Dynamic two-phase Runic workflow that hot-swaps between full and slim writing DAGs based on deterministic research richness.",
  tags: ["primary", "showcase", "ai", "l2", "ai-tool-use", "runic", "adaptive"],
  category: :ai,
  emoji: "🧭",
  related_resources: [
    %{
      path: "/docs/learn/ai-agent-with-tools",
      kind: "Tutorial",
      description: "Build tool-aware workflows and orchestration loops.",
      include_livebook: true
    },
    %{
      type: :external,
      label: "adaptive demo source",
      href: "https://github.com/agentjido/jido_runic/blob/main/lib/examples/adaptive_demo.exs",
      kind: "Source",
      description: "Two-phase adaptive runner script."
    },
    %{
      type: :external,
      label: "adaptive researcher module",
      href: "https://github.com/agentjido/jido_runic/blob/main/lib/examples/adaptive/adaptive_researcher.ex",
      kind: "Source",
      description: "Dynamic phase selection and runic.set_workflow usage."
    }
  ],
  source_files: [
    "lib/agent_jido/demos/runic_adaptive_researcher/fixtures.ex",
    "lib/agent_jido/demos/runic_adaptive_researcher/actions.ex",
    "lib/agent_jido/demos/runic_adaptive_researcher/orchestrator_agent.ex",
    "lib/agent_jido/demos/runic_adaptive_researcher/runtime_demo.ex",
    "lib/agent_jido_web/examples/runic_adaptive_researcher_live.ex"
  ],
  live_view_module: "AgentJidoWeb.Examples.RunicAdaptiveResearcherLive",
  difficulty: :intermediate,
  status: :live,
  scenario_cluster: :ai_tool_use,
  wave: :l2,
  journey_stage: :evaluation,
  content_intent: :tutorial,
  capability_theme: :ai_intelligence,
  evidence_surface: :runnable_example,
  demo_mode: :real,
  sort_order: 16,
  outcome: "Dynamic two-phase Runic workflow that hot-swaps between full and slim writing DAGs based on deterministic research richness.",
  packages: ["jido", "jido_ai", "req_llm"],
  package_maturity: "Beta",
  prerequisites: ["Elixir 1.18+", "OTP 27+", "Jido installed", "an LLM provider key"],
  expected_result: "The agent reasons over the prompt using the configured provider and key.",
  run_command: "Run the interactive demo on /examples/runic-adaptive-researcher."
}
---

## What you'll learn

- How to split orchestration into phase 1 research and phase 2 writing
- How deterministic research richness can decide between full and slim phase-2 workflows
- How `runic.set_workflow` can hot-swap the DAG while keeping the example fully local and repeatable

## Branch behavior

- `full`: `BuildOutline -> DraftArticle -> EditAndAssemble`
- `slim`: `DraftArticle -> EditAndAssemble`

Selection is based on deterministic research summary length in the local phase-1 workflow.

## Demo note

This page now runs a real local Runic workflow. The research summaries and article outputs are deterministic fixtures, but the phase selection, workflow swap, node execution, and final artifacts all come from the real strategy pipeline.
