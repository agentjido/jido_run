%{
  title: "Signals",
  description: "The universal message format connecting sensors, agents, and side effects in Jido.",
  category: :docs,
  legacy_paths: ["/docs/signals"],
  order: 75,
  tags: [:docs, :concepts]
}
---
## What signals solve

Agent systems need a common message format that works across process boundaries, networks, and storage layers. Without one, each integration invents its own envelope, and interoperability breaks down.

Signals solve this by providing a structured messaging envelope for all external communication. They implement the [CloudEvents v1.0.2 specification](https://cloudevents.io/) with Jido-specific extensions, so you get a well-defined contract that tooling and infrastructure already understand.

Signals connect three core parts of the system:

- **Sensors** produce signals from external events (HTTP requests, timers, webhooks)
- **Agents** receive signals and execute actions in response
- **Directives** trigger outbound signals that flow to other agents or external systems

## Signal structure

Every signal carries a set of required CloudEvents fields plus optional metadata.

**Required fields:**

| Field | Description |
| --- | --- |
| `specversion` | Always `"1.0.2"` |
| `id` | UUID v7 identifier (generated automatically, monotonically increasing) |
| `source` | Origin of the event, e.g. `"/auth/registration"` |
| `type` | Classification string using dot notation |

UUID v7 is an intentional choice over UUID v4. The embedded timestamp means signal IDs are naturally time-ordered, which gives you chronological sorting, efficient database indexing, and the ability to extract creation time directly from the ID without extra fields.

**Optional fields:**

| Field | Description |
| --- | --- |
| `subject` | Specific subject of the event |
| `time` | Timestamp in ISO 8601 format |
| `datacontenttype` | Media type of the data (defaults to `"application/json"`) |
| `dataschema` | URI pointing to a schema for the data |
| `data` | The event payload |

Beyond the core spec, signals support a flexible extension system through `Jido.Signal.Ext` for attaching custom metadata like authentication context or tracing information.

### Type naming conventions

Signal types use hierarchical dot notation following the pattern `<domain>.<entity>.<action>`. Add a qualifier segment when you need to distinguish outcomes.

```
user.profile.updated
order.payment.processed.success
system.metrics.collected
```

Use lowercase with dots, order segments from general to specific, and keep each segment meaningful.

## Creating signals

The preferred constructor takes positional arguments for type, data, and optional attributes:

```elixir
alias Jido.Signal

{:ok, signal} = Signal.new(
  "metrics.collected",
  %{cpu: 80, memory: 70},
  source: "/monitoring"
)
```

A map-based constructor is also available:

```elixir
{:ok, signal} = Signal.new(%{
  type: "user.created",
  source: "/auth/registration",
  data: %{user_id: "usr_901", email: "jane@example.com"}
})
```

Both forms auto-generate the `id`, `specversion`, and `time` fields.

### Custom signal types

For signals you create repeatedly, define a module with `use Jido.Signal`. This locks in the type string, default source, and a validation schema for the data payload.

```elixir
defmodule MyApp.UserCreatedSignal do
  use Jido.Signal,
    type: "user.created",
    default_source: "/auth",
    schema: Zoi.object(%{
      user_id: Zoi.string(),
      email: Zoi.string()
    })
end

{:ok, signal} = MyApp.UserCreatedSignal.new(
  %{user_id: "usr_901", email: "jane@example.com"}
)
```

The schema is validated at creation time. Invalid data returns an error tuple instead of raising.

## Signal routing

When a signal arrives at an `AgentServer` through `call/3` or `cast/2`, the server determines which action to run. It does this through a trie-based `Signal.Router` built at startup from three sources:

1. **Strategy routes** - `strategy.signal_routes/1` (priority 50+)
2. **Agent routes** - `agent_module.signal_routes/1` (priority 0)
3. **Plugin routes** - `plugin.signal_routes/1` (priority -10)

Higher-priority routes take precedence. Each route maps a signal type string to the action module that handles it:

```elixir
def signal_routes(_config) do
  [
    {"chat.message", MyApp.Actions.HandleMessage},
    {"chat.complete", MyApp.Actions.CompleteChat},
    {"user.created", MyApp.Actions.OnboardUser}
  ]
end
```

The router supports exact matches (`"user.created"`), single-segment wildcards (`"user.*.updated"`), and multi-level wildcards (`"audit.**"`). When no route matches, the server falls back to using `{signal.type, signal.data}` as the action instruction.

## Dispatch

`Jido.Signal.Dispatch` is a utility for sending signals to various destinations. It provides a unified interface with built-in adapters:

| Adapter | Purpose |
| --- | --- |
| `:pid` | Direct delivery to a specific process |
| `:pubsub` | Broadcast via Phoenix.PubSub |
| `:logger` | Log signals through Elixir Logger |
| `:console` | Print signals to stdout |
| `:http` | Send signals as HTTP requests |
| `:webhook` | Webhook delivery with signatures |
| `:noop` | No-op adapter for testing |

Configure dispatch as a tuple of `{adapter, options}`:

```elixir
alias Jido.Signal.Dispatch

Dispatch.dispatch(signal, {:pid, target: pid})

Dispatch.dispatch(signal, {:pubsub, target: :my_pubsub, topic: "events"})

Dispatch.dispatch(signal, [
  {:pid, target: worker_pid},
  {:logger, level: :info}
])
```

For high-throughput scenarios, `dispatch_batch/3` processes large volumes of dispatch configurations with configurable concurrency:

```elixir
Dispatch.dispatch_batch(signal, configs, max_concurrency: 20)
```

## Control surface

A signal's control surface is the correlation context it carries and the durability of the record it leaves behind. The table names each control point. Signal `id`, request, run, and trace IDs are **correlation** metadata — not authenticated principals — and telemetry is observation, **not** an audit log. Nothing is durable until you configure a Journal adapter; the default keeps nothing across a restart. See [Security and governance](/docs/operations/security-and-governance) for the full control-point map.

| Hook | Input | Decision | Output | Failure behavior | Evidence |
| --- | --- | --- | --- | --- | --- |
| `Jido.Signal` id / trace | event payload | Stamp correlation and causation IDs | CloudEvents envelope | Dropped if unprocessable | `id` and trace IDs (correlation, not principal identity) |
| Signal Journal | recorded signal | Persist if a durable adapter is configured | Journal entry | Nothing durable by default — a recorded signal is lost on restart | Entry exists only with a configured durable adapter and a retention policy |
| Dispatch routing | signal + dispatch config | Route to handlers | Outbound directives | Route miss is a no-op; no audit record is produced | Emitted directives; routing is observable, not tamper-evident |

## Next steps

- [Actions](/docs/concepts/actions) - learn how actions transform agent state in response to signals
- [Agent runtime](/docs/concepts/agent-runtime) - run agents under OTP supervision where signals are processed
- [Directives](/docs/concepts/directives) - understand the effect payloads that produce outbound signals
