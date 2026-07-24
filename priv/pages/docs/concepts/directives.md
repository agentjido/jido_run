%{
  title: "Directives",
  description: "Pure descriptions of external effects that keep agent logic separated from runtime side effects.",
  category: :docs,
  order: 85,
  tags: [:docs, :concepts],
  legacy_paths: ["/docs/directives"]
}
---
A directive is a pure description of an external effect. Agents and strategies never interpret or execute directives. They only emit them, and the runtime handles the rest.

This separation is the core design invariant: `cmd/2` returns `{agent, directives}` where the returned agent is already complete. There is no "apply directives to state" step. Directives are outbound runtime instructions, not state mutators.

## Why directives exist

Side effects in agent systems create coupling that breaks under load. When a single function both updates state and sends messages, failures become ambiguous. Did the state change? Did the message send? Retrying either one risks duplication or inconsistency.

Directives solve this by splitting the decision from the execution. Your action decides what should happen and returns a struct describing the effect. The runtime decides when and how to execute it. This gives you pure, testable action logic and lets the runtime handle retries, ordering, and failure isolation independently.

## Core directives

Jido provides built-in directive types that cover the most common runtime effects.

### Emit

Dispatches a signal through `Jido.Signal.Dispatch`. You can target a specific process, broadcast over PubSub, or use any configured dispatch adapter. If no dispatch config is provided, the runtime uses the agent's default dispatch or falls back to emitting to the agent process itself.

```elixir
alias Jido.Agent.Directive

%Directive.Emit{signal: signal}

%Directive.Emit{signal: signal, dispatch: {:pubsub, topic: "events"}}

%Directive.Emit{signal: signal, dispatch: {:pid, target: pid}}
```

You can also target multiple destinations from a single emit:

```elixir
%Directive.Emit{signal: signal, dispatch: [
  {:pubsub, topic: "events"},
  {:logger, level: :info}
]}
```

### Schedule

Sends a delayed message back to the agent process after a specified interval. Use this for timeouts, deferred checks, and any "do this later" pattern.

```elixir
%Directive.Schedule{delay_ms: 5000, message: :timeout}

%Directive.Schedule{delay_ms: 30_000, message: {:check_status, order_id}}
```

The message arrives as a signal at the agent, so it flows through the same routing and action execution as any other signal.

### Cron and CronCancel

Agents natively support recurring scheduled execution using cron expressions. This means any agent can set up periodic tasks - health checks, cleanup jobs, polling loops, heartbeats - without external schedulers or infrastructure.

```elixir
%Directive.Cron{
  cron: "*/5 * * * *",
  message: health_check_signal,
  job_id: :health_check
}

%Directive.Cron{
  cron: "@daily",
  message: cleanup_signal,
  job_id: :daily_cleanup,
  timezone: "America/New_York"
}
```

Each tick sends the configured message back to the agent as a signal via `cast/2`. The `job_id` identifies the job within that agent - if you emit a `Cron` directive with the same `job_id`, it replaces the existing job.

Cancel a job by emitting a `CronCancel` with the matching `job_id`:

```elixir
%Directive.CronCancel{job_id: :health_check}
```

### SpawnAgent

Starts a child agent with full parent-child hierarchy tracking. The parent monitors the child process, tracks it by tag, and receives exit signals when the child stops.

```elixir
%Directive.SpawnAgent{agent: MyApp.WorkerAgent, tag: :worker_1}

%Directive.SpawnAgent{
  agent: MyApp.WorkerAgent,
  tag: :processor,
  opts: %{initial_state: %{batch_size: 100}},
  meta: %{assigned_topic: "orders"}
}
```

Child agents can send signals back to their parent using `Directive.emit_to_parent/3`, and parents can stop children with `StopChild`.

### StopChild

Requests a tracked child agent to stop gracefully.

```elixir
%Directive.StopChild{tag: :worker_1, reason: :normal}
```

### Spawn

Starts a generic BEAM process under the agent's supervisor without hierarchy tracking. Use this for fire-and-forget tasks like sending an email or writing to a log.

```elixir
%Directive.Spawn{child_spec: {MyApp.EmailWorker, to: "jane@example.com"}}
```

### RunInstruction

Executes an instruction at runtime and routes the result back through `cmd/2`. This is useful for async workflows where an instruction depends on external data that isn't available during the original `cmd/2` call.

```elixir
%Directive.RunInstruction{
  instruction: instruction,
  result_action: :handle_result
}
```

### Stop

Terminates the agent process itself.

```elixir
%Directive.Stop{reason: :shutdown}
```

### Error

Wraps a `Jido.Error.t()` to signal an error from command processing. The runtime can log, emit, or handle errors based on this directive.

```elixir
%Directive.Error{error: error, context: :normalize}
```

## Returning directives from actions

Actions return directives as the third element of their `{:ok, state_changes, directives}` tuple. You can return a single directive or a list.

```elixir
defmodule MyApp.NotifyAction do
  use Jido.Action,
    name: "notify",
    schema: Zoi.object(%{user_id: Zoi.string()})

  alias Jido.Agent.Directive

  @impl true
  def run(params, context) do
    signal = Jido.Signal.new!(
      "user.notified",
      %{user_id: params.user_id},
      source: "/notifications"
    )

    {:ok, %{notified: true}, %Directive.Emit{signal: signal}}
  end
end
```

Return multiple directives to express compound effects from a single action:

```elixir
def run(params, _context) do
  {:ok, %{status: :processing}, [
    %Directive.Emit{signal: started_signal},
    %Directive.Schedule{delay_ms: 30_000, message: :check_timeout},
    %Directive.SpawnAgent{agent: MyApp.Worker, tag: :worker}
  ]}
end
```

The agent struct returned by `cmd/2` already reflects the state changes. Directives travel alongside the agent but never modify it.

## How the runtime executes directives

When `cmd/2` completes, the `AgentServer` enqueues all returned directives into an internal queue. The drain loop dequeues directives one at a time and calls the `Jido.AgentServer.DirectiveExec` protocol, which dispatches on the directive's struct type.

Each `DirectiveExec.exec/3` implementation returns one of three results:

- `{:ok, state}` - successful execution, continue draining
- `{:async, ref, state}` - async work was started
- `{:stop, reason, state}` - terminate the agent process

Directives execute in the order they were returned. If new directives arrive while the queue is draining, they are appended to the end.

## Custom directives

You can define your own directive types without modifying Jido core. Define a struct and implement the `DirectiveExec` protocol for it.

```elixir
defmodule MyApp.Directive.CallLLM do
  defstruct [:model, :prompt, :tag]
end

defimpl Jido.AgentServer.DirectiveExec,
  for: MyApp.Directive.CallLLM do

  def exec(%{model: model, prompt: prompt}, _signal, state) do
    Task.Supervisor.start_child(
      Jido.TaskSupervisor,
      fn -> MyApp.LLM.call(model, prompt) end
    )
    {:async, nil, state}
  end
end
```

> **Note:** LLM integration is already implemented in `jido_ai` using the `req_llm` package. The example above illustrates the custom directive pattern - you would not need to build this yourself.

The protocol uses `@fallback_to_any true`, so unknown directive types are logged and ignored rather than crashing the agent. This makes it safe to introduce new directives incrementally.

## Next steps

- [Actions](/docs/concepts/actions) - learn how Actions produce state changes and directives
- [Agent runtime](/docs/concepts/agent-runtime) - understand how AgentServer supervises agents and drains directives
- [Signals](/docs/concepts/signals) - explore the typed envelopes that directives dispatch
