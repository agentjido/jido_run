%{
  description: "A worked example of an AgentServer process crash: the supervisor restarts the process, and the observed state result is explicit.",
  title: "Process crash and restart",
  category: :docs,
  legacy_paths: [],
  tags: [:docs, :operations],
  order: 356,
  draft: false
}
---
# Process Crash and Restart

[Supervision and Failure Boundaries](/docs/operations/supervision-and-failure-boundaries) states the rule: a Jido agent runs as a BEAM process under an OTP supervisor, and supervision is your first failure boundary — it restarts a crashed process and keeps one agent's crash from reaching another. This page is the worked example. It takes one supervised `AgentServer`, crashes it, and shows the two things an operator must be able to see: **the process restarts**, and **the observed state result is explicit**.

Process recovery is not state recovery. A restart rebuilds the process with a fresh agent; whatever lived only in memory is gone. That is the distinction this example makes observable — you read the post-restart state through the real API and see the initial value, rather than assuming the agent "came back as it was."

## What a process crash is (and is not)

A process crash is the BEAM process backing the `AgentServer` terminating abnormally — an out-of-memory kill, a linked process dying, an OTP exit, or, in this example, a deliberate `Process.exit(pid, :kill)`. OTP supervision exists to recover from exactly this: the supervisor restarts the child according to its restart type and strategy.

It is not the same as an Action error. Jido isolates Action failures — a raise or `{:error, _}` inside an Action's `run/2` is caught and returned as an error result, it does **not** crash the `AgentServer`. So the failure surface is layered:

- **Action errors** are handled at the call boundary — see [Tool Error and Retry Decision](/docs/operations/tool-error-and-retry-decision) and [Retries, Timeouts, and Provider Failure](/docs/operations/retries-timeouts-and-provider-failure).
- **Process crashes** are handled by OTP supervision — this page.

The example terminates the process directly to exercise the supervision path on its own.

## The example agent

The runnable example is a single supervised agent, `AgentJido.Demos.AgentServerCrashAgent`, that holds an `events` counter incremented through a validated Action. The counter lives only in process state, so what survives a restart is exactly observable:

```elixir
defmodule AgentJido.Demos.AgentServerCrashAgent do
  alias AgentJido.Demos.AgentServerCrash.RecordEvent

  use Jido.Agent,
    name: "agent_server_crash_agent",
    schema: [events: [type: :integer, default: 0]],
    signal_routes: [{"agent_server_crash.record", RecordEvent}]
end
```

It runs as a `:permanent` child of a dedicated supervisor, the same shape you would ship:

```elixir
children = [
  {Jido.AgentServer, jido: AgentJido.Jido, agent: AgentServerCrashAgent, id: agent_id}
]

Supervisor.init(children, strategy: :one_for_one, max_restarts: 1000, max_seconds: 1)
```

Because `Jido.AgentServer.child_spec/1` sets `restart: :permanent`, OTP supervision restarts the process automatically when it dies.

## The process restarts

Start the supervisor, grab the running pid, accumulate some state, then crash the process the way a real process-level failure would:

```elixir
{:ok, sup} = AgentJido.Demos.AgentServerCrash.Supervisor.start_link([])

pid1 = AgentJido.Demos.AgentServerCrash.Supervisor.agent_server_pid(sup)

Enum.each(1..3, fn _ ->
  {:ok, _agent} =
    Jido.AgentServer.call(
      pid1,
      Jido.Signal.new!("agent_server_crash.record", %{by: 1}, source: "/ops")
    )
end)

# Crash the process.
Process.exit(pid1, :kill)
```

The supervisor restarts it. The recovery is observable as a **new pid** under the same supervisor, live and serving:

```elixir
pid2 = AgentJido.Demos.AgentServerCrash.Supervisor.agent_server_pid(sup)

pid2 != pid1           # => true — a new process
Process.alive?(pid2)   # => true — and it is running
```

That is the first half of the acceptance: the process restarted. It is the supervisor that did this — nothing in the agent or the application code reconstructed the process.

## The observed state result is explicit

After a crash you do not *assume* the agent restarted, and you do not *assume* what state it holds. You observe the result explicitly through the `AgentServer` API and read a concrete value.

`Jido.AgentServer.status/1` confirms the restarted process — it returns the new pid and the agent id, or `{:error, :not_found}` if no process is registered:

```elixir
{:ok, status} = Jido.AgentServer.status(pid2)
status.pid       # => pid2
status.agent_id  # => the same agent id, carried across the restart
```

`Jido.AgentServer.state/1` returns the agent's actual post-restart state — the agent struct with its `state` map:

```elixir
{:ok, %{agent: agent_after}} = Jido.AgentServer.state(pid2)
agent_after.state.events   # => 0
```

The result is explicit: the counter that read `3` before the crash reads `0` after it. Supervision restarted the process; it did not recover the three events that lived only in memory. Contrast that with the value observed before the crash:

```elixir
{:ok, %{agent: agent_before}} = Jido.AgentServer.state(pid1)
agent_before.state.events   # => 3  (before the crash)
```

The before/after difference — `3`, then `0` — is the explicit evidence that process recovery and state recovery are separate things. If you need the events to survive a crash, that is an application-owned persistence decision, not something supervision provides.

## What this example shows and what it does not

This example proves one thing directly: when an `AgentServer` process crashes, OTP supervision restarts it, and you can observe the restart and its post-crash state explicitly through the `AgentServer` API.

It does not, by itself:

- **Recover state.** A restart rebuilds the process with a fresh agent. Persisting state across a restart is an application choice — wiring a store, an idempotent replay, or a durable Signal Journal is separate work.
- **Bound a crash loop.** A single restart is shown here. A loop — repeated crashes inside the restart window — escalates when it exceeds `max_restarts` / `max_seconds`; see [Supervision and Failure Boundaries](/docs/operations/supervision-and-failure-boundaries).
- **Serve as an audit trail.** Observing state through the API is an operational check, not a tamper-evident record — see [Security and governance](/docs/operations/security-and-governance).

## Run it yourself

The example ships with a test that encodes the acceptance condition — the process restarts (new pid, live) and the observed state result is explicit (`status/1` returns the restarted process, `state/1` returns the initial state):

```
mix test test/agent_jido/demos/agent_server_crash_test.exs
```

The source is under `lib/agent_jido/demos/agent_server_crash/` — the agent, its `RecordEvent` Action, and the supervisor that restarts it.

> The end-to-end long-running reference application is a tracked follow-up (jido-e07-t29). When it lands, this crash-and-restart path folds into it so the same observed result can be reproduced against the full reference app rather than the standalone demo.

## Next steps

- Read the full failure-boundary framework — topology, restart strategy, and restart intensity — on [Supervision and Failure Boundaries](/docs/operations/supervision-and-failure-boundaries).
- Separate call-boundary recovery (retries) from process recovery on [Retries, Timeouts, and Provider Failure](/docs/operations/retries-timeouts-and-provider-failure).
- Practice the same crash as a repeatable drill with the [Incident playbooks](/docs/operations/incident-playbooks).
- Confirm your restart type and intensity against the [Production readiness checklist](/docs/operations/production-readiness-checklist).
