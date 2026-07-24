%{
  title: "Coding Assistant",
  description: "File analysis, patch recommendation, and test guidance shown through a deterministic coding workflow.",
  tags: ["primary", "showcase", "simulated", "ai", "l1", "ai-tool-use", "coding"],
  category: :ai,
  emoji: "💻",
  related_resources: [
    %{
      path: "/docs/getting-started/first-llm-agent",
      kind: "Guide",
      description: "Set up your first LLM-powered agent."
    },
    %{
      path: "/docs/learn/ai-agent-with-tools",
      kind: "Tutorial",
      description: "Build a tool-using AI agent loop.",
      include_livebook: true
    },
    %{
      path: "/docs/learn/reasoning-strategies-compared",
      kind: "Concept",
      description: "Compare strategy tradeoffs for AI decision loops.",
      include_livebook: true
    }
  ],
  source_files: [
    "lib/agent_jido_web/examples/simulated_showcase_live.ex"
  ],
  live_view_module: "AgentJidoWeb.Examples.SimulatedShowcaseLive",
  difficulty: :beginner,
  status: :draft,
  scenario_cluster: :ai_tool_use,
  wave: :l1,
  journey_stage: :evaluation,
  content_intent: :tutorial,
  capability_theme: :ai_intelligence,
  evidence_surface: :runnable_example,
  demo_mode: :simulated,
  sort_order: 3,
  outcome: "File analysis, patch recommendation, and test guidance shown through a deterministic coding workflow.",
  packages: ["jido", "jido_ai", "req_llm"],
  package_maturity: "Beta",
  prerequisites: ["Elixir 1.18+", "OTP 27+", "Jido installed", "an LLM provider key"],
  expected_result: "The agent reasons over the prompt using the configured provider and key.",
  run_command: "Run the interactive demo on /examples/coding-assistant."
}
---

## What you'll learn

- How to represent a coding-agent workflow without remote model dependencies
- How to show step-by-step reasoning artifacts in a predictable UI trace
- How to keep demos production-safe while preserving product narrative

## Demo note

This example replays a fixed execution trace and patch plan. No LLM providers are called.

