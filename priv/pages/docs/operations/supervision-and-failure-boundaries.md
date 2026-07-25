%{
  description: "How OTP supervision bounds agent failure: topology, restart strategy, and restart intensity.",
  title: "Supervision and Failure Boundaries",
  category: :docs,
  legacy_paths: [],
  tags: [:docs, :operations],
  order: 355,
  draft: false
}
---
# Supervision and Failure Boundaries

A Jido agent runs as a BEAM process under an OTP supervisor. Supervision is your first and most durable failure boundary: it restarts a crashed agent process and keeps one agent's crash from reaching another. This page covers the three things an operator must decide deliberately — the supervision **topology**, the **restart strategy**, and the **restart intensity** — so failure stays bounded and visible.

Supervision is process-level recovery, not data recovery. A restart reconstructs the process with a fresh agent state, and whatever lived only in memory is gone. Persisting agent state is an application choice — a restart is not state recovery. Confirm the persistence decision with the [Production readiness checklist](/docs/operations/production-readiness-checklist).

## Topology: where each agent lives

Each `Jido.AgentServer` is its own BEAM process with its own memory, mailbox, and crash boundary. One agent cannot corrupt another's heap, block another's mailbox, or take another down by crashing. This isolation is inherited from the BEAM; it is not something you configure per agent.

You place agents in a supervision tree the same way you place any OTP child. Give agents a dedicated supervisor so you can tune their restart behavior independently of the rest of your application:

```elixir
children = [
  {Jido.AgentServer, id: :support_agent, agent: MyApp.SupportAgent, name: :support_agent},
  {Jido.AgentServer, id: :billing_agent, agent: MyApp.BillingAgent, name: :billing_agent}
]

{:ok, _sup} =
  Supervisor.start_link(children, strategy: :one_for_one, name: MyApp.AgentSupervisor)
```

Two structural choices matter at this layer:

- **Static vs. dynamic.** A fixed set of long-running agents belongs in a `Supervisor`. Agents created and torn down at request time belong in a `DynamicSupervisor`, where each child is added with `DynamicSupervisor.start_child/2`.
- **Escalation boundaries.** Nest supervisors so that a subtree that cannot stabilize terminates its own supervisor and escalates to a parent, instead of restarting silently forever. A dedicated `AgentSupervisor` under your application supervisor is the common shape: agents escalate to the agent supervisor, the agent supervisor escalates to the application, and the blast radius is explicit at each level.

The agent's `id` (its lifecycle and profile identity) is what you follow in telemetry and Journal records after a restart — see [Security and governance](/docs/operations/security-and-governance). It is correlation metadata, not an authenticated principal.

## Restart strategy: what restarts, and what siblings do

"Restart strategy" covers two independent OTP decisions: the **supervisor strategy** (what happens to siblings when a child terminates) and the **child restart type** (whether a terminated child restarts at all).

Supervisor strategies:

| Strategy | When a child terminates |
|---|---|
| `:one_for_one` | Only that child restarts; siblings are untouched. |
| `:rest_for_one` | The terminated child and every child started after it restart. |
| `:one_for_all` | All children terminate and restart together. |

For independent agents, `:one_for_one` is the right default: a crashing agent restarts on its own, and unrelated agents keep serving. Reach for `:rest_for_one` or `:one_for_all` only when children have a start-order dependency (a later child needs an earlier one present).

The child restart type is the per-child `:restart` value. `Jido.AgentServer.child_spec/1` defaults to `:permanent` and `:worker`, alongside a configured `:shutdown` timeout:

```elixir
# Jido.AgentServer.child_spec/1 — the defaults that matter for restart
%{
  id: id,
  start: {__MODULE__, :start_link, [opts]},
  shutdown: shutdown_timeout,
  restart: :permanent,
  type: :worker
}
```

| Restart type | Behavior |
|---|---|
| `:permanent` | Always restarted — the default for `AgentServer`. Use for long-running agents that must come back. |
| `:transient` | Restarted only on an abnormal exit. Use when an agent is expected to finish and stop on its own. |
| `:temporary` | Never restarted. Use for agents where a crash should be terminal. |

Override the default when your workload needs it. Because `child_spec/1` hard-codes `:permanent`, merge the override with `Supervisor.child_spec/2` rather than passing it in the child tuple — for example, to make a request-scoped agent `:transient`:

```elixir
child =
  Supervisor.child_spec(
    {Jido.AgentServer, id: :session_agent, agent: MyApp.SessionAgent, name: :session_agent},
    restart: :transient
  )
```

## Restart intensity: how many restarts before escalation

A supervisor tracks how often its children restart within a rolling window. When a child restarts more than `max_restarts` times in `max_seconds` seconds, the supervisor gives up: it terminates itself, and its parent takes over. That is escalation, not a failure to recover — the failure has been promoted to a place that can be seen and acted on.

The OTP defaults are `max_restarts: 3` and `max_seconds: 5`. They are a guess, and they are rarely the right guess for agent workloads:

- An agent crash loop usually means a real defect — bad config, poisoned state, a bad tool result — not a transient blip. Restarting silently every few seconds hides the defect and can burn CPU or provider budget indefinitely.
- Set the intensity and period deliberately for each workload so a loop **escalates visibly** rather than restarting forever.

```elixir
Supervisor.start_link(children,
  strategy: :one_for_one,
  max_restarts: 5,
  max_seconds: 60,
  name: MyApp.AgentSupervisor
)
```

What to decide, explicitly:

- **How many restarts in what window** for each agent class. A cheap, fast-restarting agent can tolerate a higher intensity than one that calls an external provider on each start.
- **What escalation means operationally.** When `AgentSupervisor` escalates to the application supervisor, that is your signal to alert and investigate — pair the restart budget with a health check and telemetry on agent lifecycle events.

## What supervision does not do

Supervision bounds process failure. It does not, by itself:

- **Recover state.** A restart rebuilds the process with a fresh agent. Whatever was only in memory is lost; persistence is an application choice. A restart is not state recovery.
- **Retry work.** A crashed process loses in-flight work. Bounded retries, fallbacks, and idempotent Actions are separate concerns.
- **Guarantee uptime.** Supervision restarts processes and bounds blast radius; it is not an uptime or "no downtime" guarantee. Measure and verify recovery with a failure drill.

## Next steps

- Confirm your topology, strategy, and intensity against the [Production readiness checklist](/docs/operations/production-readiness-checklist).
- Practice a crash-and-recover drill with the [Incident playbooks](/docs/operations/incident-playbooks).
- See the runtime mechanics in [Supervised failure handling](/features/agents-that-self-heal).
- Build the controls end to end from the [Operational controls](/docs/getting-started/operational-controls) onboarding lane.
