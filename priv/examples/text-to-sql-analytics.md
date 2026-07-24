%{
  title: "Text-to-SQL Analytics",
  description: "Natural language analytics flow that compiles deterministic SQL and result summaries.",
  tags: ["primary", "showcase", "simulated", "ai", "l1", "ai-tool-use", "sql"],
  category: :ai,
  emoji: "📊",
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
  sort_order: 5,
  outcome: "Natural language analytics flow that compiles deterministic SQL and result summaries.",
  packages: ["jido", "jido_ai", "req_llm"],
  package_maturity: "Beta",
  prerequisites: ["Elixir 1.18+", "OTP 27+", "Jido installed", "an LLM provider key"],
  expected_result: "The agent reasons over the prompt using the configured provider and key.",
  run_command: "Run the interactive demo on /examples/text-to-sql-analytics."
}
---

## What you'll learn

- How to demo NL-to-SQL intent parsing and query generation with fixtures
- How to surface deterministic SQL output and keep the demo reproducible
- How to frame analytics demos without database credentials

## Demo note

The generated SQL and chart payload are deterministic fixture outputs, not live query execution.

