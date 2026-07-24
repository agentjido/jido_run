%{
  title: "Deep Research",
  description: "Multi-step information synthesis workflow with deterministic source retrieval and report output.",
  tags: ["primary", "showcase", "simulated", "ai", "l1", "ai-tool-use", "research"],
  category: :ai,
  emoji: "🔬",
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
  sort_order: 2,
  outcome: "Multi-step information synthesis workflow with deterministic source retrieval and report output.",
  packages: ["jido", "jido_ai", "req_llm"],
  package_maturity: "Beta",
  prerequisites: ["Elixir 1.18+", "OTP 27+", "Jido installed", "an LLM provider key"],
  expected_result: "The agent reasons over the prompt using the configured provider and key.",
  run_command: "Run the interactive demo on /examples/deep-research."
}
---

## What you'll learn

- How to structure a research agent demo in stages: collect, synthesize, summarize
- How to provide high-trust UX with explicit simulation disclosures
- How to align AI examples to taxonomy themes (`ai_intelligence`, `ai_tool_use`)

## Demo note

All source retrieval and synthesis output in this demo is deterministic fixture data.

