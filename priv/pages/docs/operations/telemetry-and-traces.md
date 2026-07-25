%{
  description: "The two observation layers a long-running agent exposes: the :telemetry events Jido core emits for free, and the separate, optional jido_otel exporter that bridges them to OpenTelemetry.",
  title: "Telemetry and Traces",
  category: :docs,
  legacy_paths: [],
  tags: [:docs, :operations],
  order: 359,
  draft: false
}
---
# Telemetry and Traces

Supervision recovers a process; retries recover a call; scheduling decides what enters the agent. None of them answer a different question: **once the agent is running, how do you see what it is doing?** This page covers observation — the two layers a long-running agent exposes, and why they are not the same thing.

There are two observation layers and they live at different altitudes:

- **Core observation events** are the `:telemetry` events `jido` core emits while it runs. They are always on, they cost nothing to attach to, and they do not depend on any tracing package.
- **`jido_otel`** is a separate, optional package that bridges those same events into OpenTelemetry spans for distributed traces. It is an exporter, not the source of observation.

Confusing the two is the common operational mistake. Treating core telemetry as your audit history, or assuming OpenTelemetry export is built into `jido`, are both wrong. The table separates them before the detail does.

| Layer | Source | Ships with `jido` core? | Maturity | What it is for |
|---|---|---|---|---|
| **Core observation events** | `Jido.Observe`, `Jido.Telemetry`, `Jido.AI.Observe`, `jido_signal` tracing | Yes | Stable | In-process `:telemetry` any reporter can consume |
| **`jido_otel` export** | the `jido_otel` package (`Jido.Observe.Tracer` behaviour) | No — separate package, not on Hex | Experimental | Bridge those spans to OpenTelemetry distributed traces |

Contrast this with [Supervision and Failure Boundaries](/docs/operations/supervision-and-failure-boundaries) (process recovery), [Retries, Timeouts, and Provider Failure](/docs/operations/retries-timeouts-and-provider-failure) (call recovery), and [Scheduling and Event Input](/docs/operations/scheduling-and-event-input) (ingress).

## Core observation events

Every agent lifecycle transition, Action run, signal, and AI call emits standard `:telemetry` events from `jido` core. The work is done by `Jido.Observe` (agent and Action spans), `Jido.Telemetry` (the event stream and pre-built metrics), `Jido.AI.Observe` (LLM, tool, request, and strategy events), and `jido_signal` tracing (the signal causation and correlation chain). Events follow the `[:jido, ...]` namespace and use `:start` / `:stop` / `:exception` spans for duration. The full event catalog is in [Telemetry and observability](/docs/reference/telemetry-and-observability).

Because these are plain `:telemetry` events, any Elixir telemetry reporter attaches to them with **no Jido tracing package installed**:

```elixir
# lib/my_app/application.ex
def start(_type, _args) do
  Jido.Telemetry.setup()
  # Attach Prometheus, StatsD, LiveDashboard, or a custom handler here.
  # None of this requires jido_otel.
  ...
end
```

Each span carries correlation metadata — `:jido_trace_id`, `:jido_span_id`, `:jido_parent_span_id`, and `:jido_causation_id` — so a chain of signals ties together across an agent's run without an external tracer. This is in-process correlation; it does not, by itself, propagate a distributed trace across nodes or external services. Secrets are scrubbed before emission: with `redact_sensitive: true` (the production default), keys such as `api_key`, `token`, and `password`, and any key containing `secret_` or ending in `_key` / `_token` / `_password`, are replaced with `[REDACTED]`. See [Configuration](/docs/reference/configuration) for log levels, thresholds, and redaction.

What to decide, explicitly:

- **Attach a reporter.** The events exist whether or not you consume them. Decide which reporter (metrics store, log pipeline, LiveDashboard) captures them, and call `Jido.Telemetry.setup()` once at startup.
- **Define redaction rules.** Telemetry is for system understanding; secrets, prompts, and principal data must stay out of events, logs, and error output. Set `redact_sensitive` and review the sensitive-key list against your workload.

## jido_otel: the OpenTelemetry export bridge

`jido_otel` is a **separate package** that turns Jido spans into OpenTelemetry traces. It is not part of `jido` core: it does not ship with it, it is not published on Hex, and you add it as an explicit GitHub dependency. See the [`jido_otel` package page](/ecosystem/jido_otel) and the [repository](https://github.com/agentjido/jido_otel).

It plugs in by implementing the `Jido.Observe.Tracer` behaviour (`span_start/2`, `span_stop/2`, `span_exception/4`, and the optional `with_span_scope/3`). Where core `:telemetry` is a flat event stream, `jido_otel` translates that stream into OpenTelemetry spans and exports them over OTLP to a collector — Jaeger, Honeycomb, Datadog, or any OTLP-compatible backend. When one agent emits a Signal that triggers another, it propagates trace context through the signal, producing one trace that spans processes and external service calls.

```elixir
# Optional, experimental — not required to observe a Jido agent.
# Add jido_otel only when you want distributed OpenTelemetry traces.
children = [
  {JidoOtel, []}
]
```

What to decide, explicitly:

- **Treat it as optional and current-state.** `jido_otel` is Experimental. Evaluate it against that maturity — do not present OpenTelemetry export as a built-in, stable capability of `jido`. The [Production readiness checklist](/docs/operations/production-readiness-checklist) calls this out explicitly.
- **Require a collector.** Exported traces appear only when a collector is configured and reachable. Without one, export can drop events silently. Core `:telemetry` still flows regardless; `jido_otel` adds the OTLP export path on top.

## Decide deliberately

For each agent class, write down the observation contract:

- **Which layer answers which question.** Core `:telemetry` answers "what is this agent doing right now, and how long does it take?" `jido_otel` answers "how does this request trace across agents and external services?" Keep them separate so a gap in one does not look like a gap in the other.
- **Correlation vs. distributed tracing.** A `:jido_trace_id` correlates signals inside a run; an OpenTelemetry trace spans processes and services. They are not the same identifier — see [Security and Governance](/docs/operations/security-and-governance) for why trace and correlation IDs are not authenticated principals.
- **Retention and audit.** Telemetry and traces are an ephemeral stream with no built-in retention. Define where spans are stored, for how long, and who can read them at the platform layer — Jido does not keep them.

## What telemetry and traces do not do

Observation helps you understand the system. It does not, by itself:

- **Serve as an audit log.** Telemetry is observation, not an audit log — it is an ephemeral stream that carries no tamper-evidence and is not retained by Jido. An audit trail is a separate, application-owned duty — see [Security and Governance](/docs/operations/security-and-governance).
- **Identify a principal.** Correlation and trace IDs tie work together; they do not authenticate who initiated it. Do not treat a trace ID as an identity.
- **Guarantee delivery.** Core events are emitted in-process; `jido_otel` export depends on a reachable collector. Either can drop events under load. Treat spans as best-effort observation, not a complete record.
- **Export to OpenTelemetry on their own.** Core `:telemetry` can be bridged to many backends, but the dedicated Jido-to-OTel span bridge is the separate `jido_otel` package — it is not built into `jido` core.

## Next steps

- Read the full event, metric, and log-level catalog in [Telemetry and observability](/docs/reference/telemetry-and-observability).
- Tune log levels, thresholds, and redaction in [Configuration](/docs/reference/configuration).
- Map observation to the control surface in [Security and Governance](/docs/operations/security-and-governance).
- Build the controls end to end from the [Operational controls](/docs/getting-started/operational-controls) onboarding lane.
