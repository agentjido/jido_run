%{
  title: "Counter Agent",
  description: "A real Jido agent that counts up and down using Actions, Signals, and signal routing. Demonstrates the core agent pattern: immutable state, validated actions, and LiveView integration.",
  tags: ["getting-started", "state", "actions", "signals"],
  category: :core,
  emoji: "🔢",
  related_resources: [
    %{
      path: "/docs/getting-started/first-agent",
      kind: "Guide",
      description: "Define typed state and run your first command.",
      include_livebook: true
    },
    %{
      path: "/docs/concepts/actions",
      kind: "Concept",
      description: "Understand action contracts, validation, and composition."
    },
    %{
      path: "/docs/learn/first-workflow",
      kind: "Next",
      description: "Chain actions into a multi-step workflow.",
      include_livebook: true
    }
  ],
  source_files: [
    "lib/agent_jido/demos/counter/counter_agent.ex",
    "lib/agent_jido/demos/counter/actions/increment_action.ex",
    "lib/agent_jido/demos/counter/actions/decrement_action.ex",
    "lib/agent_jido/demos/counter/actions/reset_action.ex",
    "lib/agent_jido_web/examples/counter_agent_live.ex"
  ],
  live_view_module: "AgentJidoWeb.Examples.CounterAgentLive",
  difficulty: :beginner,
  status: :live,
  sort_order: 10,
  outcome: "A supervised Jido agent that counts up and down via validated Actions and Signals.",
  packages: ["jido"],
  package_maturity: "Beta",
  prerequisites: ["Elixir 1.18+", "OTP 27+", "Jido installed"],
  expected_result: "The counter increments and decrements deterministically; no API key required.",
  run_command: "Run the interactive demo on /examples/counter-agent, or: mix test test/agent_jido/demos/counter_agent_test.exs"
}
---

## What you'll learn

- How to define a Jido Agent with a typed schema
- How to write Actions with validated parameters
- How signal routing connects events to actions
- How to drive a LiveView from real agent state

## How it works

This example shows the foundational Jido pattern. The `CounterAgent` is defined as an **immutable data structure** — not a process. Each operation creates a new agent struct with updated state.

### The Agent

The counter agent declares its state schema and signal routes:

```elixir
use Jido.Agent,
  name: "counter_agent",
  schema: [
    count: [type: :integer, default: 0]
  ]

def signal_routes do
  [
    {"counter.increment", IncrementAction},
    {"counter.decrement", DecrementAction},
    {"counter.reset", ResetAction}
  ]
end
```

### Actions

Each action is a separate module with validated params and a `run/2` callback. The increment action receives the current state via context:

```elixir
use Jido.Action,
  name: "increment",
  schema: [
    by: [type: :integer, default: 1, doc: "Amount to increment by"]
  ]

def run(%{by: amount}, context) do
  current = Map.get(context.state, :count, 0)
  {:ok, %{count: current + amount}}
end
```

### LiveView Integration

The LiveView creates a new agent, then dispatches actions on each button click:

```elixir
agent = CounterAgent.new()
{new_agent, _directives} = CounterAgent.cmd(agent, {IncrementAction, %{by: 1}})
```

The agent is always an immutable struct — there's no GenServer, no PID. The LiveView holds the agent in socket assigns and re-renders when state changes.

## Key concepts

**Agents are data, not processes.** `CounterAgent.new()` returns a struct. `CounterAgent.cmd/2` returns a new struct. You choose when and how to manage the lifecycle.

**Actions are validated.** The `schema` option on each action defines parameter types and defaults. Invalid params are rejected before `run/2` is called.

**Signal routing is declarative.** The `signal_routes/0` callback maps signal types to action modules. This decouples "what happened" from "what to do about it."
