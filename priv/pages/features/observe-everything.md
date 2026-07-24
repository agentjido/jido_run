%{
  title: "Instrument agent lifecycles",
  category: :features,
  description: "Built-in telemetry and OpenTelemetry tracing across every agent lifecycle transition.",
  doc_type: :explanation,
  audience: :beginner,
  draft: false,
  order: 35
}
---
Jido emits telemetry events for every agent lifecycle transition. Pair them with OpenTelemetry for distributed tracing across multi-agent workflows. You get visibility into what your agents are doing without writing instrumentation code.

## At a glance

| Item | Summary |
|---|---|
| Best for | Platform teams, SREs, anyone running agents in production |
| Core packages | [jido](/ecosystem/jido), [jido_otel](/ecosystem/jido_otel) |
| Package status | `jido` (Beta), `jido_otel` (Experimental) |
| First proof path | Wire up dashboard metrics → trace a multi-step workflow |
| Key idea | Every state transition emits telemetry. Add OpenTelemetry for cross-process traces. |

## Telemetry events for agent lifecycle

Jido's runtime emits `:telemetry` events at every stage of agent execution:

| Event | When it fires |
|---|---|
| `[:jido, :agent, :start]` | Agent process starts |
| `[:jido, :agent, :cmd, :start]` | A command begins execution |
| `[:jido, :agent, :cmd, :stop]` | A command completes |
| `[:jido, :agent, :cmd, :exception]` | A command fails |
| `[:jido, :agent, :directive, :emit]` | A directive is executed |

These are standard Erlang telemetry events. Attach handlers the same way you would for Phoenix or Ecto:

```elixir
:telemetry.attach(
  "agent-cmd-handler",
  [:jido, :agent, :cmd, :stop],
  fn _event, measurements, metadata, _config ->
    Logger.info("Agent #{metadata.agent} completed in #{measurements.duration}ms")
  end,
  nil
)
```

## OpenTelemetry integration

The `jido_otel` package bridges Jido's telemetry events to OpenTelemetry spans. This gives you distributed tracing across agent processes and external service calls:

```elixir
# In your application supervision tree
children = [
  {JidoOtel, []},
  # ... your agent servers
]
```

Once enabled, every `cmd/2` execution creates a span. If that command triggers directives that invoke other agents, the spans are linked, giving you a full trace of a multi-agent workflow.

## Cross-process workflow tracing

When Agent A emits a signal that triggers Agent B, OpenTelemetry trace context propagates through the signal. The result is a single trace that shows:

1. The incoming request to Agent A
2. Agent A's command execution and state transition
3. The emitted signal
4. Agent B receiving and processing the signal
5. Agent B's command execution and directives

This works across any number of agents, regardless of which BEAM node they run on.

## Dashboard wiring

Wire Jido metrics into Phoenix LiveDashboard for runtime visibility:

```elixir
live_dashboard("/dashboard",
  metrics: AgentJidoWeb.Telemetry,
  additional_pages: JidoLiveDashboard.pages(),
  on_mount: @admin_on_mount
)
```

This exposes agent execution metrics alongside your existing Phoenix and Ecto dashboards. No separate monitoring stack required.

## What to explore next

- **Agent foundations:** [How Jido agents work](/features/how-agents-work)
- **Fault tolerance:** [Agents that self-heal](/features/agents-that-self-heal)
- **Coordination:** [Agents that work together](/features/multi-agent-coordination)
- **Production readiness:** [Production readiness checklist](/docs/operations/production-readiness-checklist)
- **Reference docs:** [Incident playbooks](/docs/operations/incident-playbooks)

## Get Building

Attach a telemetry handler to `[:jido, :agent, :cmd, :stop]` and inspect the measurements. Then add `jido_otel` and trace your first multi-agent workflow.
