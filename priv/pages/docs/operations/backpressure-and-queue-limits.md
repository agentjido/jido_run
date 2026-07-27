%{
  description: "The four limit surfaces a long-running Jido system exposes — mailbox, bus, task, and provider — and, for each, where the bound lives and what happens when it is exceeded.",
  title: "Backpressure and queue limits",
  category: :docs,
  legacy_paths: [],
  tags: [:docs, :operations],
  order: 366,
  control_types: [:policy, :quota],
  control_intent: :enforce,
  draft: false
}
---
# Backpressure and Queue Limits

Supervision keeps a crashed agent alive; retries recover a failed call; scheduling and event input decide how work arrives. None of them answers the question that sits between ingress and recovery: **when work arrives faster than the agent can process it, what bounds the backlog before it fails the node?** That is backpressure, and a long-running Jido system exposes four distinct limit surfaces. This page names each one, states where the bound lives (Jido or your application), and says what happens when it is exceeded.

The four surfaces are not interchangeable, and confusing them is the common operational mistake. A full mailbox, a saturated bus subscription, an overflowed directive queue, and a provider rate-limit all look like "the agent is slow" from the outside, but they trip different controls and need different responses. Keep them separate.

| Surface | What it bounds | Default | Who owns the bound | Exceeded behavior |
|---|---|---|---|---|
| **Mailbox** | Signals cast at an `AgentServer` process | None | Application | None — the mailbox grows without limit |
| **Bus** | Signals held by a persistent subscription | `max_in_flight` 1000, `max_pending` 10_000 | Jido | `{:error, :queue_full}` to the producer, or a dropped signal |
| **Task** | Pending directives and concurrent supervised tasks | `max_queue_size` 10_000, `max_tasks` 1000 | Jido | Directives dropped with `:queue_overflow`; tasks refused |
| **Provider** | In-flight LLM HTTP connections | 8 connections | Jido pool + provider 429 | Pool checkout waits; the provider returns 429 |

The rest of this page covers each surface in turn. Pair it with [Scheduling and Event Input](/docs/operations/scheduling-and-event-input) (where work arrives), [Health Checks and Readiness](/docs/operations/health-checks-and-readiness) (where you observe a growing backlog), and [Telemetry and Traces](/docs/operations/telemetry-and-traces) (where the overflow events surface).

## Mailbox: the AgentServer process mailbox

A `Jido.AgentServer` is a GenServer. A Signal reaches it one of two ways, and the choice is the entire backpressure story for this surface:

- `Jido.AgentServer.cast/2` is fire-and-forget. It enqueues the Signal in the BEAM process mailbox and returns `:ok` immediately — no acknowledgement, no retry, no way for the caller to learn whether the Signal was ever processed.
- `Jido.AgentServer.call/3` is synchronous. It blocks the caller until the server replies, with a default timeout of `5_000` ms.

The bound on the mailbox is the crucial honesty point: **Jido does not cap the mailbox for you.** The AgentServer process sets no `max_heap_size`, runs no message-queue trimming, and does not hibernate. A `cast/2` producer that outruns the agent piles Signals into the mailbox without limit, and `cast/2`'s `:ok` return gives the caller no backpressure signal at all. Left unchecked, a flooding source can grow the mailbox until the node runs out of memory.

This bound is application-owned. Decide, for each agent class:

- **Admit synchronously where backpressure matters.** Use `call/3` for paths where the caller must learn the mailbox is full (it will time out at `5_000` ms instead of piling up). Use `cast/2` only for fire-and-forget work the system can afford to lose.
- **Watch the queue length.** Poll `Process.info(pid, :message_queue_len)` or read `Jido.AgentServer.status/1` (see [Health Checks and Readiness](/docs/operations/health-checks-and-readiness)) so a growing mailbox trips an alert before it threatens the node.
- **Bound the source, not the mailbox.** A `cast/2`-delivered source — a cron tick, a sensor, a webhook — must shed, batch, or throttle at the source. There is no mailbox-side cap to save it.
- **Set your own heap ceiling if you need one.** `Process.flag(:max_heap_size, ...)` on the agent process turns an unbounded mailbox into a kill-and-restart, which supervision then handles. That is a deliberate application choice, not a Jido default.

## Bus: the Signal Bus subscription capacity

When work flows through a `Jido.Signal.Bus`, the bounded surface is the **persistent subscription**. Only persistent subscriptions hold a queue; a regular (non-persistent) subscription has no per-subscription process and no capacity bound. Two knobs, both set at `subscribe/3` time, govern a persistent subscription:

- **`max_in_flight`** (default `1000`) — the maximum number of signals dispatched to the subscriber but not yet acknowledged.
- **`max_pending`** (default `10_000`) — the maximum number of signals buffered waiting for an in-flight slot.

When a signal arrives and `max_in_flight` is full, it moves into `pending`. When `pending` is full too, the subscription is saturated. What happens next depends on the publish path:

- A **synchronous** publish fails back to the producer with `{:error, :queue_full}` — this is backpressure to the caller, who can retry. Note the signal has already been appended to the bus log at that point, so a retry re-delivers.
- A **cast/info** publish drops the signal and logs a warning.

Either way, the subscription emits the telemetry event `[:jido, :signal, :subscription, :backpressure]`, and the bus emits `[:jido, :signal, :bus, :backpressure]` when any subscriber saturates. Wire these to an alert (see [Telemetry and Traces](/docs/operations/telemetry-and-traces)).

Two further bus bounds are memory limits, not admission limits, but they shape the same operational picture:

- **`max_log_size`** (default `100_000`) caps the in-memory bus log. When it is exceeded, the oldest log entries are truncated and `[:jido, :signal, :bus, :log_truncated]` fires. This is retention, not a queue — it does not refuse new publishes.
- For **non-persistent** subscriptions only, a per-partition token-bucket rate limiter applies (`rate_limit_per_sec`, default `10_000`; `burst_size`, default `1_000`). When the bucket empties, signals are dropped with `[:jido, :signal, :bus, :rate_limited]`. Persistent subscriptions are routed around this limiter.

Decide deliberately: make a subscription persistent when you want its backlog bounded and observable, and size `max_in_flight` and `max_pending` to the consumer's real drain rate. A regular subscription is fast and cheap precisely because it carries no such guarantee.

## Task: the directive queue and the task supervisors

Inside an `AgentServer`, two separate task limits apply, and operators confuse them often.

The first is the **directive queue**, capped by `max_queue_size` (default `10_000`). A Signal can produce one or more directives that the agent drains asynchronously; this queue holds the pending directives. When a new directive would exceed the cap, it is dropped, the server logs a warning, it replies `{:error, :queue_overflow}`, and it emits `[:jido, :agent_server, :queue, :overflow]`. This protects the directive backlog; it does **not** protect the Signal mailbox (see [Mailbox](#mailbox-the-agentserver-process-mailbox)). A growing directive queue is a stuck or overloaded agent — pair it with the work-health probe in [Health Checks and Readiness](/docs/operations/health-checks-and-readiness).

The second is the **task supervisor** that runs the work itself. Execution is serialized per agent — an `AgentServer` runs one signal's work in flight at a time — but across an instance, the supervised task count is bounded by `max_tasks` (default `1000`), set as the `:max_children` of the instance's `TaskSupervisor`. Configure it when you start the instance:

```elixir
# In your application supervisor
children = [
  {Jido, name: MyApp.Jido, max_tasks: 2_000}
]

# Or in config
config :my_app, MyApp.Jido, max_tasks: 2_000
```

Note the gap: the per-instance supervisor is bounded (`max_tasks`), but the global `Jido.Action.TaskSupervisor` that backs standalone `Jido.Exec` calls is started with no `:max_children` cap. If you call Actions outside an agent instance, that path is effectively unbounded by Jido — bound it at the call site.

Decide deliberately: set `max_queue_size` and `max_tasks` for each instance relative to the work it runs, alert on `[:jido, :agent_server, :queue, :overflow]`, and treat a sustained overflow as a signal to scale the consumer or shed load — not to raise the ceiling and forget it.

## Provider: the LLM HTTP pool and the provider rate limit

The provider surface has two bounds, and Jido owns only the smaller of them.

- **No library-level concurrency cap or rate limiter ships.** Neither `jido_ai` nor `req_llm` imposes a limit on in-flight LLM requests or a requests-per-minute budget. The only rate bound is the provider's own — a 429 response, surfaced as `Jido.AI.Error.API.RateLimit`. It is handled reactively (streaming retries it; a plain `ReqLLM` step does not auto-retry HTTP errors). See [Retries, Timeouts, and Provider Failure](/docs/operations/retries-timeouts-and-provider-failure).
- **The only HTTP-level bound is the connection pool.** `req_llm` runs requests through a Finch pool whose default capacity is **8 connections** (`stream_pool_count: 8`, `stream_pool_size: 1`, HTTP/1 only). When all connections are busy, a new request waits for a checkout (up to the pool timeout) instead of opening an unbounded number of sockets. Tune the pool for high-concurrency streaming workloads:

```elixir
config :req_llm,
  stream_pool_protocols: [:http1],
  stream_pool_count: 16,
  stream_pool_size: 1
```

The LLM call itself runs in a supervised task, not inside the agent's GenServer loop, so a slow provider does not block the agent process — but a flood of concurrent calls still lands on the pool and, beyond it, on the provider's 429.

This is the surface most likely to need an application-owned bound. If your provider enforces a requests-per-minute or tokens-per-minute budget, add a semaphore or rate limiter upstream of the call (for example, gate the number of concurrent `ask` calls per tenant). Jido does not impose that limit for you, because the right budget is a property of your provider contract, not the framework — see [Rate Limits and Cost Budgets](/docs/operations/rate-limits-and-cost-budgets) for the opt-in Quota plugin that does the same job at the call boundary.

## Decide deliberately

For each agent class, write down the admission contract across all four surfaces:

- **Mailbox.** Which ingress paths use `call/3` (synchronous, bounded by timeout) and which use `cast/2` (fire-and-forget, unbounded)? What sheds a flooding source?
- **Bus.** Which subscriptions are persistent (bounded by `max_in_flight` and `max_pending`) and which are regular (unbounded)?
- **Task.** What is the `max_queue_size` ceiling and the alert threshold relative to it? What is the instance's `max_tasks`?
- **Provider.** What RPM/TPM must you stay under, and do you enforce it upstream, or rely on the provider's 429?

| Surface | Default | Exceeded behavior | Observable signal |
|---|---|---|---|
| Mailbox | none | grows without limit | `Process.info(pid, :message_queue_len)`, `status/1` |
| Bus (persistent) | 1000 in flight / 10_000 pending | `:queue_full` or dropped signal | `[:jido, :signal, :subscription, :backpressure]` |
| Bus log | 100_000 entries | oldest truncated | `[:jido, :signal, :bus, :log_truncated]` |
| Directive queue | 10_000 | dropped directives | `[:jido, :agent_server, :queue, :overflow]` |
| Task supervisor | 1000 tasks | task refused | `{:error, :max_children}` |
| Provider pool | 8 connections | checkout waits | pool timeout; provider 429 |

## What backpressure does not do

These limits bound load. They do not, by themselves:

- **Make `cast/2` safe.** The mailbox has no cap. A fire-and-forget source that outruns the agent still grows the mailbox until you bound it at the source.
- **Deduplicate delivery.** A retried publish, a re-delivered event, or a restarted subscription can deliver the same Signal twice. Idempotency is an application contract — see [Scheduling and Event Input](/docs/operations/scheduling-and-event-input).
- **Replace recovery.** A dropped directive or a saturated subscription is a signal that work did not complete. Bounded retries, fallbacks, and a dead-letter path still carry that work — see [Retries, Timeouts, and Provider Failure](/docs/operations/retries-timeouts-and-provider-failure) and [Poison Work and Dead-Letter Handling](/docs/operations/poison-work-and-dead-letter).
- **Bound the provider proactively.** The provider surface reacts to a 429; it does not prevent one. Staying under a provider budget is an application-owned limiter.
- **Serve as an audit trail.** Queue depth, overflow counts, and backpressure events are system understanding, not a tamper-evident record — see [Security and Governance](/docs/operations/security-and-governance).

## Next steps

- Trace where work arrives in [Scheduling and Event Input](/docs/operations/scheduling-and-event-input), and bound it at the source.
- Watch the backlogs grow in [Health Checks and Readiness](/docs/operations/health-checks-and-readiness), and wire the overflow and backpressure events in [Telemetry and Traces](/docs/operations/telemetry-and-traces).
- Send overflowed or saturated work to a recovery path in [Retries, Timeouts, and Provider Failure](/docs/operations/retries-timeouts-and-provider-failure) and [Poison Work and Dead-Letter Handling](/docs/operations/poison-work-and-dead-letter).
- Walk the response when a backlog trips in the [Incident Playbooks](/docs/operations/incident-playbooks), and gate every limit before go-live in the [Production Readiness Checklist](/docs/operations/production-readiness-checklist).
