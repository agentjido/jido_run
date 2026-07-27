%{
  description: "How timed and external work enters a long-running agent: Schedule and Cron directives, sensors, and direct Signal injection — and the operational decisions each one forces.",
  title: "Scheduling and event input",
  category: :docs,
  legacy_paths: [],
  tags: [:docs, :operations],
  order: 358,
  draft: false
}
---
# Scheduling and Event Input

Supervision keeps a crashed agent alive; retries recover a failed call. Neither answers a different question: **how does timed and external work get *into* the agent in the first place?** This page covers that ingress path — the two ways work arrives as a Signal, and the operational decisions each one forces.

Both paths land in the same place. A scheduled tick and an external event both become a Signal routed through the agent's `signal_routes/1`. From the agent's perspective there is no "scheduler input" versus "event input" — there are only Signals with types. The difference is what generates them and what survives a restart. Contrast this with [Supervision and Failure Boundaries](/docs/operations/supervision-and-failure-boundaries) (process recovery) and [Retries, Timeouts, and Provider Failure](/docs/operations/retries-timeouts-and-provider-failure) (call recovery).

## Two ingress paths

Work enters a long-running agent through one of two paths. Keep them separate so you can reason about each one's failure mode:

| Path | What generates the Signal | Where the timer lives | Restarts with the agent? |
|---|---|---|---|
| **Scheduling** | A `Directive.Schedule` or `Directive.Cron` the agent emits to itself | The agent process | Cron declared on the agent does; a one-shot `Schedule` does not |
| **Event input** | A Sensor or an outside process casting a Signal in | A Sensor process (or none) | Only if the source restarts and re-delivers |

The key operational question for both is the same: **what happens to in-flight or pending work when the agent restarts?** A restart rebuilds the process with a fresh agent; whatever lived only in memory is gone. See [Supervision and Failure Boundaries](/docs/operations/supervision-and-failure-boundaries).

## Scheduling

Jido agents schedule work with directives — no external scheduler or cron daemon required. A directive emits a message back to the agent process, which arrives as a Signal and flows through the same routing as any other Signal. Use this to run work later or on a recurring cadence. See [Directives](/docs/concepts/directives).

A one-shot delay uses `Directive.Schedule`:

```elixir
# Fire :timeout back to this agent in 5 seconds. Use this for timeouts,
# deferred checks, and "do this later" patterns.
%Directive.Schedule{delay_ms: 5_000, message: :timeout}

%Directive.Schedule{delay_ms: 30_000, message: {:check_status, order_id}}
```

Recurring work uses `Directive.Cron`, declared directly on the agent:

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

Each cron tick sends the configured message back to the agent via `cast/2`. The `job_id` identifies the job within the agent — emitting a `Cron` directive with the same `job_id` replaces it, and `%Directive.CronCancel{job_id: :health_check}` cancels it. Because cron is declared on the agent, the recurring cadence is rebuilt when the agent restarts; a one-shot `Schedule` is a single in-memory timer that is lost if the process dies before it fires.

What to decide, explicitly:

- **Which cadence is bound to the agent and which is bound to a process.** Declare recurring work as `Directive.Cron` so a restart restores the cadence. Do not rely on a one-shot `Directive.Schedule` for work that must survive a crash — re-arm it from an Action or persist the intent.
- **Timezones.** A cron schedule without a timezone runs in the node's local time. Set `timezone:` deliberately when the cadence is wall-clock-bound, so a deploy to a different region does not silently shift it.

A complete, runnable Schedule example — delayed work, bounded retries, and cron recurring Signals on one agent — is in the [Schedule Directive Agent](/examples/schedule-directive-agent) example.

## Event input

An agent that only runs work on its own timers cannot react to the world. External events — PubSub messages, webhooks, message-queue deliveries, database changes — must enter as Signals. Two ways exist, and they are not interchangeable.

### Sensors: one focused process per external source

A Sensor is a GenServer (`Jido.Sensor` under `Jido.Sensor.Runtime`) that owns the translation from one external source into your Signal vocabulary. It fetches or receives raw data, wraps it in a typed Signal, and delivers it to the agent. The agent does not know or care where the Signal came from. See [Sensors](/docs/concepts/sensors).

```elixir
children = [
  {Jido.AgentServer, agent: MyApp.OrderAgent, id: :order_agent},
  {Jido.Sensor.Runtime,
   sensor: MyApp.OrderSensor,
   config: %{pubsub: MyApp.PubSub, topic: "orders"},
   context: %{agent_ref: :order_agent}}
]
```

Because each sensor is its own supervised process, a misbehaving external source — a flooded queue, a malformed webhook, a stalled poll — is isolated from the agent. The sensor's crash boundary is its own; the agent keeps serving.

### Direct Signal injection: webhooks and one-off pushes

You do not need a Sensor to deliver a Signal. Any process can build a Signal and cast it to the agent. This is how webhooks arrive: a Phoenix controller constructs the Signal and sends it.

```elixir
webhook_signal =
  Jido.Signal.new!("webhook.github", %{event: "push", payload: payload},
    source: "/webhooks/github"
  )

Jido.AgentServer.cast(agent_ref, webhook_signal)
```

Whether the Signal came from a sensor or a direct cast, the agent routes it identically. A complete, runnable Sensor example — a polling sensor that emits Signals, plus direct webhook injection into the same agent — is in the [Sensors and real-time events](/docs/learn/sensors-and-real-time-events) guide.

## Decide deliberately

For each agent class, write down the ingress contract:

- **Recoverability.** What scheduled or pending work survives an agent restart, and what does not? Declare recurring cadences as `Directive.Cron`; do not depend on a one-shot `Directive.Schedule` surviving a crash.
- **Idempotency.** A restarted agent may re-run a cron tick, and an external source may redeliver an event. Treat Signals as idempotent — use Signal IDs or idempotency keys before relying on a schedule firing exactly once. See [Retries, Timeouts, and Provider Failure](/docs/operations/retries-timeouts-and-provider-failure).
- **Backpressure.** Delivery is via `cast/2`, which is fire-and-forget: the agent's mailbox is the only buffer between a fast external source and the agent. A source that outpaces the agent fills the mailbox; size the source, batch, or shed load before it does. See [Backpressure and Queue Limits](/docs/operations/backpressure-and-queue-limits) for the four limit surfaces and where each bound lives.
- **One sensor per source.** Give each external source its own sensor so a format change or protocol drift touches one module, not agent logic.

| Source | Ingress path | Survives an agent restart? |
|---|---|---|
| Recurring cadence | `Directive.Cron` on the agent | Yes — rebuilt from the agent declaration |
| One-shot delay | `Directive.Schedule` | No — lost if the process dies before firing |
| PubSub / queue / webhook | Sensor process → Signal | Only if the source redelivers |
| Webhook / one-off push | Direct `AgentServer.cast/2` | No — in-flight casts to a down process are dropped |

## What scheduling and event input do not do

These paths deliver work. They do not, by themselves:

- **Deliver each event once.** A restarted agent can re-run a cron tick, and an external source can redeliver an event. Single-delivery semantics are an application contract you build with idempotency keys and Signal IDs — the ingress path delivers, it does not deduplicate.
- **Recover state.** Re-delivering a Signal replays it against the agent's current state; it does not reconstruct state lost to a crash. State recovery is an application choice — see [Supervision and Failure Boundaries](/docs/operations/supervision-and-failure-boundaries).
- **Bound a flooding source for you.** `cast/2` does not apply backpressure. A source that outpaces the agent fills the mailbox; shed or throttle at the source — see [Backpressure and Queue Limits](/docs/operations/backpressure-and-queue-limits).
- **Serve as an audit trail.** Signals and the telemetry they emit are system understanding, not a tamper-evident audit log — see [Security and Governance](/docs/operations/security-and-governance).

## Next steps

- Run the [Schedule Directive Agent](/examples/schedule-directive-agent) example to see delayed and recurring scheduling end to end.
- Build a polling sensor with the [Sensors and real-time events](/docs/learn/sensors-and-real-time-events) guide.
- Pair the ingress contract with process recovery in [Supervision and Failure Boundaries](/docs/operations/supervision-and-failure-boundaries).
- Build the controls end to end from the [Operational controls](/docs/getting-started/operational-controls) onboarding lane.
