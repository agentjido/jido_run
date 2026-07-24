%{
  title: "Jido.AI Weather Reasoning Strategy Suite",
  description: "Deterministic comparison lab for choosing between ReAct, CoD, AoT, CoT, ToT, GoT, TRM, and Adaptive weather reasoning strategies.",
  tags: ["primary", "showcase", "ai", "l2", "ai-tool-use", "weather", "reasoning", "jido_ai", "comparison", "reference"],
  category: :ai,
  emoji: "🧠",
  related_resources: [
    %{
      path: "/docs/learn/reasoning-strategies-compared",
      kind: "Concept",
      description: "Detailed strategy tradeoff guide and examples.",
      include_livebook: true
    },
    %{
      type: :external,
      label: "weather strategy overview module",
      href: "https://github.com/agentjido/jido_ai/blob/main/lib/examples/weather/overview.ex",
      kind: "Source",
      description: "Upstream strategy-to-module mapping and CLI examples."
    }
  ],
  source_files: [
    "lib/agent_jido/demos/weather_reasoning_strategy_suite/fixtures.ex",
    "lib/agent_jido/demos/weather_reasoning_strategy_suite/comparison_lab.ex",
    "lib/agent_jido_web/examples/weather_reasoning_strategy_suite_live.ex"
  ],
  live_view_module: "AgentJidoWeb.Examples.WeatherReasoningStrategySuiteLive",
  difficulty: :advanced,
  status: :live,
  scenario_cluster: :ai_tool_use,
  wave: :l2,
  journey_stage: :evaluation,
  content_intent: :reference,
  capability_theme: :ai_intelligence,
  evidence_surface: :docs_reference,
  demo_mode: :real,
  sort_order: 25,
  outcome: "Deterministic comparison lab for choosing between ReAct, CoD, AoT, CoT, ToT, GoT, TRM, and Adaptive weather reasoning strategies.",
  packages: ["jido", "jido_ai", "req_llm"],
  package_maturity: "Beta",
  prerequisites: ["Elixir 1.18+", "OTP 27+", "Jido installed", "an LLM provider key"],
  expected_result: "The agent reasons over the prompt using the configured provider and key.",
  run_command: "Run the interactive demo on /examples/jido-ai-weather-reasoning-strategy-suite."
}
---

## What you'll learn

- How the same weather prompt shifts across eight reasoning strategies
- How to choose between transparent, fast, exploratory, and self-review-heavy reasoning surfaces
- How to frame this page as a strategy comparison reference instead of a single runnable example

## What this page is

This page is a deterministic comparison lab. It helps you decide which reasoning strategy to build around for a weather scenario, but it is not one copy-pasteable weather agent implementation.

The interactive tab compares fixed scenario presets, recommended strategy fits, and deterministic reference snippets. The source tab shows the actual comparison harness that powers those cards.

## Strategy set

ReAct, CoD, AoT, CoT, ToT, GoT, TRM, and Adaptive.

## How to use the comparison

Start with the preset that best matches your use case:

- short single-answer decisions like commute calls
- multi-option planning questions like trips and packing
- higher-stakes operational calls where self-review matters

Then use the comparison cards to decide whether you want:

- a transparent single path
- a quick draft
- a branching planner
- a reflected safety-first answer
- or an adaptive router that chooses for you

## Demo note

No live model or weather API call runs here. The page uses deterministic fixtures and a dedicated comparison harness so the framing matches the product surface.
