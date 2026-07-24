%{
  title: "Signal Routing Agent",
  description: "Interactive Jido example showing how signal type routing maps into actions and executes through AgentServer.call/2 and AgentServer.cast/2.",
  tags: ["signals", "routing", "agent-server", "core-mechanics", "l1"],
  category: :core,
  emoji: "📡",
  related_resources: [
    %{
      path: "/docs/concepts/signals",
      kind: "Concept",
      description: "Understand signal anatomy, routing, and dispatch.",
      include_livebook: true
    },
    %{
      path: "/docs/concepts/actions",
      kind: "Concept",
      description: "Review action contracts and validated input schemas."
    },
    %{
      path: "/docs/learn/first-workflow",
      kind: "Next",
      description: "Chain routed steps into a larger workflow.",
      include_livebook: true
    }
  ],
  source_files: [
    "lib/agent_jido/demos/signal_routing/signal_routing_agent.ex",
    "lib/agent_jido/demos/signal_routing/actions/increment_action.ex",
    "lib/agent_jido/demos/signal_routing/actions/set_name_action.ex",
    "lib/agent_jido/demos/signal_routing/actions/record_event_action.ex",
    "lib/agent_jido_web/examples/signal_routing_agent_live.ex"
  ],
  live_view_module: "AgentJidoWeb.Examples.SignalRoutingAgentLive",
  difficulty: :beginner,
  status: :live,
  scenario_cluster: :core_mechanics,
  wave: :l1,
  journey_stage: :activation,
  content_intent: :tutorial,
  capability_theme: :runtime_foundations,
  evidence_surface: :runnable_example,
  demo_mode: :real,
  sort_order: 22,
  outcome: "A route table sends each Signal type to the right Action so behavior is explicit and testable.",
  packages: ["jido", "jido_signal"],
  package_maturity: "Beta",
  prerequisites: ["Elixir 1.18+", "OTP 27+", "Jido installed"],
  expected_result: "Each Signal type triggers its mapped Action deterministically; no API key required.",
  run_command: "Run the interactive demo on /examples/signal-routing-agent, or: mix test test/agent_jido/demos/signal_routing_agent_test.exs"
}
---

## What you'll learn

- How `signal_routes/1` maps signal types to action modules.
- How `AgentServer.call/2` handles request/response style updates.
- How `AgentServer.cast/2` queues async routing while state converges.
- How to inspect execution history with before/after state snapshots.

## How signal routing works

The `SignalRoutingAgent` declares three routes:

- `"increment"` → `IncrementAction`
- `"set_name"` → `SetNameAction`
- `"record_event"` → `RecordEventAction`

Each route is validated by the action schema and then applied to immutable
agent state. The LiveView keeps a running view of `counter`, `name`, and
recorded events so you can inspect behavior after every signal.

## call vs cast behavior

- **call** executes synchronously and returns the updated agent immediately.
- **cast** enqueues signals asynchronously and returns `:ok` immediately.

In this demo:

1. `call` controls let you increment, set name, and record typed events.
2. `cast burst` sends `1..N` increment signals and then shows converged state.
3. The execution log captures mode, signal type, payload, and before/after state.
