%{
  description: "Jido's primitive map - what each building block is, why it exists, and how they fit together.",
  title: "Concepts",
  category: :docs,
  legacy_paths: ["/docs/core-concepts", "/docs/getting-started/core-concepts"],
  tags: [:docs, :concepts],
  order: 20
}
---

This section is the authoritative reference for Jido's primitives. These pages aren't tutorials - they explain *what* each primitive is, *why* it exists, and *how* it fits with the others. Read them in order the first time through; each concept builds on the one before it.

## The core model

Jido separates concerns that most agent frameworks collapse together. Actions are validated, composable units of work that can be pure functions transforming state, or effectful units that perform I/O; the main purity boundary is Agent or Strategy decision logic. Signals are the universal message format, built on CloudEvents, that carry events and commands through the system. Agents are typed state structs with a behavior contract: pass in an action, get back updated state and directives. Directives are declarative descriptions of side effects - the agent never executes them directly. The runtime picks up those directives and executes them inside a supervised GenServer, keeping your domain logic deterministic and testable. Execution, the pipeline that actually runs actions, handles validation, chaining, retry, and compensation so callers don't have to.

Beyond the core, Jido has three cognitive pillars: Thread records what happened (the append-only interaction log), Memory stores what the agent currently believes and intends (the mutable cognitive substrate), and Strategy controls how actions execute. Sensors bridge external events into the signal layer, Plugins package reusable capabilities for composition across agents, and Persistence lets agents survive restarts through hibernate, thaw, and storage adapters.

## Recommended reading order

1. **[Actions](/docs/concepts/actions)** - Pure functions that validate inputs, transform data, and produce results.
2. **[Signals](/docs/concepts/signals)** - Typed event envelopes that carry commands and events through the system.
3. **[Agents](/docs/concepts/agents)** - Immutable state containers with a command interface for predictable transitions.
4. **[Directives](/docs/concepts/directives)** - Declarative descriptions of side effects, returned by actions for the runtime.
5. **[Agent runtime](/docs/concepts/agent-runtime)** - The GenServer layer that executes directives and manages agent lifecycle.
6. **[Sensors](/docs/concepts/sensors)** - Stateless modules that transform external events into signals.
7. **[Strategy](/docs/concepts/strategy)** - Pluggable execution models that control how agents process actions.
8. **[Plugins](/docs/concepts/plugins)** - Composable behavior bundles that extend agents with actions, routes, and state.
9. **[Execution](/docs/concepts/execution)** - The pipeline that runs actions: validation, chaining, retry, compensation, and async.
10. **[Threads](/docs/concepts/threads)** - The append-only interaction log that records what happened during agent operation.
11. **[Memory](/docs/concepts/memory)** - The mutable cognitive substrate where agents store current beliefs and goals.
12. **[Persistence](/docs/concepts/persistence)** - How agents survive restarts through hibernate, thaw, and storage adapters.

## Next steps

- [Your first agent](/docs/getting-started/first-agent) - apply these concepts in a hands-on tutorial
- [Guides](/docs/guides) - task-oriented recipes for common patterns
- [Ecosystem packages](/ecosystem) - package overviews and HexDocs links
