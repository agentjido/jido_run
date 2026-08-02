%{
  title: "Agent Runtime",
  description: "How AgentServer runs agents as OTP processes, routes signals, and executes directives.",
  category: :docs,
  order: 90,
  tags: [:docs, :concepts],
  legacy_paths: ["/docs/agent-server"]
}
---
## Agents think, the runtime acts

Jido splits agent work into two halves. Agents "think" by running pure decision logic through `cmd/2`, which returns an updated agent struct and a list of directives. AgentServer "acts" by executing those directives as side effects.

This separation keeps your agent logic testable without a running process. You can call `cmd/2` directly in tests and inspect the returned directives without starting a GenServer, connecting to external services, or managing process lifecycle.

AgentServer owns signal routing, directive execution, and process supervision. Your agent module never needs to know how signals arrive or where directives go.

## Starting an agent process

Each `AgentServer` is a single GenServer registered in `Jido.Registry`. You start one by passing an `:agent` option that identifies the agent module or struct.

```elixir
# Start under Jido.AgentSupervisor (DynamicSupervisor)
{:ok, pid} = Jido.AgentServer.start(agent: MyAgent)

# Start linked to the calling process
{:ok, pid} = Jido.AgentServer.start_link(
  agent: MyAgent,
  id: "order-42",
  initial_state: %{total: 0}
)
```

The `:agent` option accepts two forms:

- **Module name** -- The module must implement `new/0` or `new/1`. When `new/1` is available, AgentServer passes `[id: id, state: initial_state]` as keyword options.
- **Agent struct** -- Used directly. Provide `:agent_module` if the behavior module differs from the struct's module.

```elixir
# Pre-built struct with explicit module
agent = MyAgent.new(id: "prebuilt", state: %{value: 99})
{:ok, pid} = Jido.AgentServer.start_link(
  agent: agent,
  agent_module: MyAgent
)
```

Once started, you reference the server by pid or by its string ID. The `whereis/1` function resolves an ID to a pid through the registry.

## Signal flow

Signals are the sole input channel to a running agent. You send them synchronously with `call/3` or asynchronously with `cast/2`.

```elixir
signal = Jido.Signal.new!(%{type: "order.placed", data: %{item: "widget"}})

# Synchronous: blocks until cmd/2 completes, returns updated agent
{:ok, agent} = Jido.AgentServer.call(pid, signal)

# Asynchronous: returns immediately
:ok = Jido.AgentServer.cast(pid, signal)
```

When a signal arrives, AgentServer follows this path:

1. The signal router maps the signal type to one or more actions. Routes come from strategy-defined `signal_routes/1` or fall back to `{signal.type, signal.data}`.
2. AgentServer calls `Agent.cmd/2` with the resolved action. This runs in a supervised task, keeping the GenServer responsive.
3. `cmd/2` returns `{updated_agent, directives}`.
4. The agent struct is updated in server state. For synchronous calls, the updated agent is returned to the caller.
5. Directives are enqueued for execution.

Signal processing runs one at a time. If a synchronous call is in flight and an async signal arrives, the async signal is deferred until the current call completes.

## Directive execution

After `cmd/2` produces directives, AgentServer enqueues them and starts a drain loop. The drain loop processes one directive at a time by sending `:drain` messages to itself, keeping the GenServer free to handle other messages between iterations.

Each directive is executed through the `DirectiveExec` protocol. Built-in implementations handle the core directive types:

| Directive | Effect |
| --- | --- |
| `Emit` | Dispatches a signal to configured targets |
| `RunInstruction` | Executes another `cmd/2` cycle within the same process |
| `SpawnAgent` | Starts a child agent process |
| `Schedule` | Delivers a signal after a delay |
| `StopChild` | Stops a child agent by tag |
| `Error` | Routes to the configured error policy |

When the queue empties, the drain loop stops and the server returns to `:idle` status. If the queue exceeds `:max_queue_size` (default 10,000), new directives are dropped and a `:queue_overflow` error is returned.

## Parent-child hierarchy

AgentServer supports a logical parent-child hierarchy through directive-driven spawning. When a `SpawnAgent` directive executes, AgentServer starts a new child process under `Jido.AgentSupervisor` and monitors it.

The parent tracks children by tag in its state. When a child exits, the parent receives a `ChildExit` signal containing the tag, pid, and exit reason. You can route this signal to handle cleanup or retry logic.

Children receive a `:parent` reference at startup and monitor the parent process. The `:on_parent_death` option controls what happens when the parent goes down:

| Value | Behavior |
| --- | --- |
| `:stop` | Child shuts down cleanly |
| `:continue` | Child keeps running independently |
| `:emit_orphan` | Child processes an `Orphaned` signal, letting its strategy decide |

This hierarchy is logical, not supervisory. OTP supervision still comes from `Jido.AgentSupervisor`. The parent-child relationship gives you application-level coordination without coupling agent lifecycles to the supervision tree.

## Completion detection

Agents signal completion through state, not process death. Set `agent.state.status` to `:completed` or `:failed` inside your strategy, then observe it externally.

```elixir
# Poll for completion
{:ok, state} = Jido.AgentServer.state(pid)
case state.agent.state.status do
  :completed -> state.agent.state.last_answer
  :failed -> {:error, state.agent.state.error}
  _ -> :still_running
end

# Or await completion (event-driven, no polling)
{:ok, result} = Jido.AgentServer.await_completion(pid, timeout: 10_000)
```

The process stays alive after completion until explicitly stopped or cleaned up by supervision. Completion is a state concern, not a lifecycle event.

## Configuration

| Option | Description | Default |
| --- | --- | --- |
| `:agent` | Agent module or struct (required) | -- |
| `:id` | Instance ID for registry | Auto-generated |
| `:initial_state` | Initial state map passed to `new/1` | `%{}` |
| `:agent_module` | Behavior module when `:agent` is a struct | Struct module |
| `:max_queue_size` | Maximum directive queue depth | 10,000 |
| `:default_dispatch` | Default dispatch config for `Emit` directives | Current process |
| `:parent` | Parent reference for hierarchy | `nil` |
| `:on_parent_death` | `:stop`, `:continue`, or `:emit_orphan` | `:stop` |
| `:debug` | Enable in-memory event buffer | `false` |

## Next steps

- [Agents](/docs/concepts/agents) -- understand the pure decision logic that AgentServer executes
- [Signals](/docs/concepts/signals) -- learn about typed envelopes and routing patterns
- [Directives](/docs/concepts/directives) -- explore the side-effect payloads that drive the runtime
- [Actions](/docs/concepts/actions) -- see how Actions transform agent state
