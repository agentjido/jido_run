%{
  title: "Jido.AI Weather Multi-Turn Context",
  description: "Local weather assistant demo showing real city context carryover, deterministic tool calls, and one intentional retry/backoff event across turns.",
  tags: ["primary", "showcase", "ai", "l2", "ai-tool-use", "weather", "jido_ai"],
  category: :ai,
  emoji: "🌦",
  related_resources: [
    %{
      path: "/docs/learn/reasoning-strategies-compared",
      kind: "Concept",
      description: "Reasoning strategy context for weather assistants.",
      include_livebook: true
    },
    %{
      type: :external,
      label: "weather multi-turn demo script",
      href: "https://github.com/agentjido/jido_ai/blob/main/lib/examples/scripts/demo/weather_multi_turn_context_demo.exs",
      kind: "Source",
      description: "Upstream script with retry/backoff helpers and semantic checks."
    }
  ],
  source_files: [
    "lib/agent_jido/demos/weather_multi_turn_context/fixtures.ex",
    "lib/agent_jido/demos/weather_multi_turn_context/forecast_action.ex",
    "lib/agent_jido/demos/weather_multi_turn_context/weather_assistant.ex",
    "lib/agent_jido/demos/weather_multi_turn_context/runtime_demo.ex",
    "lib/agent_jido_web/examples/weather_multi_turn_context_live.ex"
  ],
  live_view_module: "AgentJidoWeb.Examples.WeatherMultiTurnContextLive",
  difficulty: :intermediate,
  status: :live,
  scenario_cluster: :ai_tool_use,
  wave: :l2,
  journey_stage: :evaluation,
  content_intent: :tutorial,
  capability_theme: :ai_intelligence,
  evidence_surface: :runnable_example,
  demo_mode: :real,
  sort_order: 21,
  outcome: "Local weather assistant demo showing real city context carryover, deterministic tool calls, and one intentional retry/backoff event across turns.",
  packages: ["jido", "jido_ai", "req_llm"],
  package_maturity: "Beta",
  prerequisites: ["Elixir 1.18+", "OTP 27+", "Jido installed", "an LLM provider key"],
  expected_result: "The agent reasons over the prompt using the configured provider and key.",
  run_command: "Run the interactive demo on /examples/jido-ai-weather-multi-turn-context."
}
---

## What you'll learn

- How multi-turn prompts preserve location context across follow-ups without repeating the city
- How a local weather tool can trigger deterministic retry/backoff behavior on a transient busy response
- How to inspect preserved context, retry events, and tool-call payloads from a real local example

## Demo note

This page now runs a real local weather assistant workflow. The weather data is deterministic and local, but the turn execution, context carryover, retry handling, and transcript are all produced by the shipped demo modules rather than a replayed transcript.
