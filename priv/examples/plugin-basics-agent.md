%{
  title: "Plugin Basics Agent",
  description: "Focused example showing plugin mount state, plugin signal routes, and plugin-owned state updates.",
  tags: ["plugins", "composition", "signals", "coordination", "l1"],
  category: :core,
  emoji: "🧩",
  related_resources: [
    %{
      path: "/docs/concepts/plugins",
      kind: "Concept",
      description: "Understand plugin state, hooks, and route composition."
    },
    %{
      path: "/docs/concepts/signals",
      kind: "Concept",
      description: "Review signal dispatch to plugin routes."
    },
    %{
      path: "/docs/learn/plugins-and-composable-agents",
      kind: "Next",
      description: "Build larger systems from composable plugins.",
      include_livebook: true
    }
  ],
  source_files: [
    "lib/agent_jido/demos/plugin_basics/plugin_basics_agent.ex",
    "lib/agent_jido/demos/plugin_basics/notes_plugin.ex",
    "lib/agent_jido/demos/plugin_basics/actions/add_note_action.ex",
    "lib/agent_jido/demos/plugin_basics/actions/clear_notes_action.ex",
    "lib/agent_jido_web/examples/plugin_basics_agent_live.ex"
  ],
  live_view_module: "AgentJidoWeb.Examples.PluginBasicsAgentLive",
  difficulty: :beginner,
  status: :live,
  scenario_cluster: :coordination,
  wave: :l1,
  journey_stage: :activation,
  content_intent: :tutorial,
  capability_theme: :coordination_orchestration,
  evidence_surface: :runnable_example,
  demo_mode: :real,
  sort_order: 25,
  outcome: "An agent composed from a plugin that contributes state and signal routes.",
  packages: ["jido"],
  package_maturity: "Beta",
  prerequisites: ["Elixir 1.18+", "OTP 27+", "Jido installed"],
  expected_result: "Plugin state and routes are mounted on the agent; no API key required.",
  run_command: "Run the interactive demo on /examples/plugin-basics-agent, or: mix test test/agent_jido/demos/plugin_basics_agent_test.exs"
}
---

## What you'll learn

- How plugin `mount/2` initializes plugin-owned state.
- How plugin `signal_routes` contribute handlers to the agent.
- How plugin actions update a plugin state slice.

## How it works

The `NotesPlugin` owns the `:notes` state key and exposes two routed signals:

- `notes.add`
- `notes.clear`

The LiveView sends these signals through `AgentServer.call/2` and renders the
plugin state after each call.
