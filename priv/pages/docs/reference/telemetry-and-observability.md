%{
  description: "Every telemetry event, pre-built metric, and log level control in the Jido ecosystem.",
  title: "Telemetry and observability",
  category: :docs,
  legacy_paths: ["/docs/telemetry-and-observability"],
  tags: [:docs, :reference],
  order: 290
}
---

Jido emits standard `:telemetry` events that you can attach to any Elixir telemetry-compatible reporter — Prometheus, StatsD, OpenTelemetry, or custom handlers. Events follow the `[:jido, ...]` namespace convention and use start/stop/exception spans for duration tracking.

## Setup

Attach the built-in telemetry handlers in your application startup:

```elixir
# lib/my_app/application.ex
def start(_type, _args) do
  Jido.Telemetry.setup()
  # ...
end
```

This is idempotent — safe to call multiple times.

## Core events (jido)

### Agent commands

Emitted when `cmd/2` runs an action against an agent.

| Event | When |
| --- | --- |
| `[:jido, :agent, :cmd, :start]` | Command execution begins |
| `[:jido, :agent, :cmd, :stop]` | Command execution completes |
| `[:jido, :agent, :cmd, :exception]` | Command execution raises |

**Measurements:** `system_time` (start), `duration` (stop/exception, native units).

**Metadata:** `agent_id`, `agent_module`, `action`, `strategy`.

### AgentServer signals

Emitted when an AgentServer processes an inbound signal.

| Event | When |
| --- | --- |
| `[:jido, :agent_server, :signal, :start]` | Signal processing begins |
| `[:jido, :agent_server, :signal, :stop]` | Signal processing completes |
| `[:jido, :agent_server, :signal, :exception]` | Signal processing raises |

**Measurements:** `system_time`, `duration`.

**Metadata:** `agent_id`, `agent_module`, `signal_type`, `directive_count`, `directive_types`.

### AgentServer directives

Emitted when the runtime executes a directive returned by an action.

| Event | When |
| --- | --- |
| `[:jido, :agent_server, :directive, :start]` | Directive execution begins |
| `[:jido, :agent_server, :directive, :stop]` | Directive execution completes |
| `[:jido, :agent_server, :directive, :exception]` | Directive execution raises |

**Measurements:** `system_time`, `duration`.

**Metadata:** `agent_id`, `directive_type`.

### Queue overflow

Emitted when a directive queue exceeds its configured capacity.

| Event | When |
| --- | --- |
| `[:jido, :agent_server, :queue, :overflow]` | Queue limit exceeded |

**Metadata:** `agent_id`.

### Strategy events

Emitted during strategy lifecycle — initialization, command execution, and periodic ticks.

| Event | When |
| --- | --- |
| `[:jido, :agent, :strategy, :init, :start\|:stop\|:exception]` | Strategy initialization |
| `[:jido, :agent, :strategy, :cmd, :start\|:stop\|:exception]` | Strategy command execution |
| `[:jido, :agent, :strategy, :tick, :start\|:stop\|:exception]` | Strategy periodic tick |

**Metadata:** `agent_id`, `agent_module`, `strategy`.

## AI events (jido_ai)

Events from `Jido.AI.Observe` follow the `[:jido, :ai, ...]` namespace.

### LLM calls

| Event | When |
| --- | --- |
| `[:jido, :ai, :llm, :span]` | Full LLM call span (start/stop) |
| `[:jido, :ai, :llm, :start]` | LLM request sent |
| `[:jido, :ai, :llm, :delta]` | Streaming token received |
| `[:jido, :ai, :llm, :complete]` | LLM response complete |
| `[:jido, :ai, :llm, :error]` | LLM call failed |

**Measurements:** `duration_ms`, `input_tokens`, `output_tokens`, `total_tokens`, `retry_count`, `queue_ms`.

**Metadata:** `agent_id`, `request_id`, `run_id`, `model`, `llm_call_id`.

### Tool execution

| Event | When |
| --- | --- |
| `[:jido, :ai, :tool, :span]` | Full tool call span |
| `[:jido, :ai, :tool, :execute, :start]` | Tool execution begins |
| `[:jido, :ai, :tool, :execute, :stop]` | Tool execution completes |
| `[:jido, :ai, :tool, :execute, :error]` | Tool execution failed |

**Metadata:** `agent_id`, `tool_name`, `tool_call_id`.

### Request lifecycle

| Event | When |
| --- | --- |
| `[:jido, :ai, :request, :start]` | AI request begins |
| `[:jido, :ai, :request, :complete]` | AI request completes |
| `[:jido, :ai, :request, :error]` | AI request failed |

**Metadata:** `agent_id`, `request_id`, `iteration`, `termination_reason`, `error_type`.

### Reasoning strategies

Each reasoning strategy emits events under its own namespace:

| Strategy | Event prefix | Key events |
| --- | --- | --- |
| ReAct | `[:jido, :ai, :strategy, :react, ...]` | `:start`, `:step`, `:complete`, `:error` |
| Chain of Thought | `[:jido, :ai, :cot, ...]` | `:start`, `:step`, `:complete`, `:error` |
| Tree of Thoughts | `[:jido, :ai, :tot, ...]` | `:start`, `:step`, `:complete`, `:error` |
| TRM | `[:jido, :ai, :trm, ...]` | `:start`, `:step`, `:act_triggered`, `:complete`, `:error` |
| Graph of Thoughts | `[:jido, :ai, :got, ...]` | `:start`, `:step`, `:complete`, `:error` |

## Pre-built metrics

`Jido.Telemetry.metrics/0` returns metric definitions ready for any `Telemetry.Metrics`-compatible reporter:

```elixir
# In your application supervision tree
children = [
  {TelemetryMetricsPrometheus, metrics: Jido.Telemetry.metrics()}
]
```

Included metrics:

| Metric | Type | Description |
| --- | --- | --- |
| `jido.agent.cmd.stop.count` | Counter | Total agent commands executed |
| `jido.agent.cmd.stop.duration` | Summary | Agent command duration (ms) |
| `jido.agent_server.signal.stop.count` | Counter | Total signals processed (tagged by `signal_type`) |
| `jido.agent_server.signal.stop.duration` | Summary | Signal processing duration (ms) |
| `jido.agent_server.directive.stop.count` | Counter | Total directives executed (tagged by `directive_type`) |
| `jido.agent_server.queue.overflow.count` | Counter | Queue overflow incidents |

All metrics are tagged with `jido_instance` for multi-instance deployments.

## Log levels and filtering

Jido's telemetry logger uses three effective levels. See [Configuration](/docs/reference/configuration) for all options.

**INFO** — Developer narrative for user-facing interactions. Logs request start/stop only.

**DEBUG** — Interesting events only. A signal is "interesting" if it:
- Exceeds `slow_signal_threshold_ms` (default: 10ms)
- Produced one or more directives
- Matches a type in `interesting_signal_types`
- Resulted in an error

**TRACE** — Every signal and directive, regardless of interestingness. Opt-in via config. Produces high log volume.

### Structured log metadata

All telemetry log entries include structured metadata for filtering:

| Field | Description |
| --- | --- |
| `trace_id` | Distributed trace correlation |
| `span_id` | Span within a trace |
| `agent_id` | Agent identifier |
| `agent_module` | Agent module name |
| `signal_type` | Signal type string |
| `directive_count` | Number of directives produced |
| `directive_types` | List of directive type atoms |
| `duration` | Formatted timing (e.g., "12.3ms") |

## Sensitive data redaction

Enable redaction to scrub secrets from telemetry metadata:

```elixir
config :jido, :observability, redact_sensitive: true
```

Redacted keys: `api_key`, `password`, `secret`, `token`, `auth_token`, `private_key`, `access_key`, `bearer`, `client_secret`, and any key containing `secret_` or ending in `_secret`, `_key`, `_token`, `_password`.

## OpenTelemetry bridge (jido_otel)

Jido's telemetry events are standard `:telemetry` events, which means they can be bridged to any OpenTelemetry-compatible backend. The `jido_otel` package provides this bridge — it translates Jido spans and events into OpenTelemetry traces and exports them to your collector (Jaeger, Honeycomb, Datadog, etc.).

[`jido_otel`](https://github.com/agentjido/jido_otel) is functional but **experimental**. It does not ship with `jido` core and is not yet published on Hex. See the [GitHub repository](https://github.com/agentjido/jido_otel) for installation and usage.

For most development and early production use, the built-in telemetry logging and metrics described above are sufficient.

## Control surface

The observe control surface is the stream of spans and events Jido emits for understanding your system. The table names each control point. Telemetry is **observation, not an audit log** — it is an ephemeral stream with no built-in retention, and trace/correlation IDs are not authenticated principals. Define redaction rules so secrets, prompts, and principal data stay out of events, logs, and error output. See [Security and governance](/docs/operations/security-and-governance) for the full control-point map.

| Hook | Input | Decision | Output | Failure behavior | Evidence |
| --- | --- | --- | --- | --- | --- |
| `Jido.Observe` / `Jido.Telemetry` | agent lifecycle and action events | Emit a span or `:telemetry` event | Telemetry event | Ephemeral stream; nothing is retained | Event stream (observation, not an audit record) |
| `jido_signal` tracing | signal causation chain | Stamp trace context | Correlated spans | Context lost if no collector receives it | Correlated spans (causation, not identity) |
| `jido_otel` OTel export | Jido spans | Bridge to OpenTelemetry | OTel traces | Experimental; events may drop without a collector | Exported traces only when a collector is configured |

## Next steps

- [Configuration](/docs/reference/configuration) - tune log levels, thresholds, and filtering
- [Glossary](/docs/reference/glossary) - definitions for telemetry terms
