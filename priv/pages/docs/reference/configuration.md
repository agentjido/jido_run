%{
  description: "All configuration keys, defaults, and examples for jido and jido_ai.",
  title: "Configuration",
  category: :docs,
  legacy_paths: ["/docs/configuration"],
  tags: [:docs, :reference],
  order: 270
}
---

Configuration is set in your `config/*.exs` files. Runtime secrets belong in `config/runtime.exs`. All keys have sensible defaults — you only need to configure what you want to change.

## jido — Core

### Telemetry

Controls structured logging for agent commands, signal processing, and directive execution.

```elixir
config :jido, :telemetry,
  log_level: :debug,                    # :trace | :debug | :info | :warning | :error
  log_args: :keys_only,                 # :keys_only | :full | :none
  slow_signal_threshold_ms: 10,         # log signals slower than this
  slow_directive_threshold_ms: 5,       # log directives slower than this
  interesting_signal_types: [           # always log these signal types at debug level
    "jido.strategy.init",
    "jido.strategy.complete"
  ]
```

| Key | Type | Default | Description |
| --- | --- | --- | --- |
| `log_level` | atom | `:debug` | Minimum level for telemetry logs. `:trace` logs everything; `:info` logs only request start/stop. |
| `log_args` | atom | `:keys_only` | How action arguments appear in logs. `:full` logs values, `:none` suppresses entirely. |
| `slow_signal_threshold_ms` | integer | `10` | Signals exceeding this duration are always logged at debug level. |
| `slow_directive_threshold_ms` | integer | `5` | Directives exceeding this duration are always logged at debug level. |
| `interesting_signal_types` | list | `["jido.strategy.init", "jido.strategy.complete"]` | Signal types always logged at debug level regardless of duration. |

### Observability

Controls the `Jido.Observe` instrumentation layer.

```elixir
config :jido, :observability,
  log_level: :info,            # Logger level for observe spans
  debug_events: :off,          # :off | :minimal | :all
  redact_sensitive: false       # redact sensitive fields in telemetry metadata
```

| Key | Type | Default | Description |
| --- | --- | --- | --- |
| `log_level` | Logger.level | `:info` | Logger level for observe-layer span logging. |
| `debug_events` | atom | `:off` | Buffer debug events in-process. `:minimal` captures key events, `:all` captures everything. |
| `redact_sensitive` | boolean | `false` | When `true`, scrubs keys like `api_key`, `password`, `secret`, and `*_token` from telemetry metadata. |

### Timeouts

Default timeouts for agent operations. Override per-call where needed.

```elixir
config :jido, :timeouts,
  agent_server_shutdown_ms: 5_000,
  agent_server_call_ms: 5_000,
  agent_server_await_ms: 10_000,
  worker_pool_checkout_ms: 5_000,
  worker_pool_call_ms: 5_000
```

| Key | Type | Default | Description |
| --- | --- | --- | --- |
| `agent_server_shutdown_ms` | integer | `5_000` | Graceful shutdown timeout for AgentServer workers. |
| `agent_server_call_ms` | integer | `5_000` | Timeout for synchronous `AgentServer` calls. |
| `agent_server_await_ms` | integer | `10_000` | Timeout for `AgentServer.await_completion/2`. |
| `worker_pool_checkout_ms` | integer | `5_000` | Checkout timeout for worker pool agents. |
| `worker_pool_call_ms` | integer | `5_000` | Call timeout when signaling pooled agents. |

### Per-instance configuration

Each Jido instance can override global config under its own module key:

```elixir
# Global default
config :jido, :telemetry, log_level: :info

# Instance override — this instance gets trace-level logging
config :my_app, MyApp.Jido,
  telemetry: [log_level: :trace],
  observability: [debug_events: :all]
```

Resolution order (highest priority first):

1. `Jido.Debug` runtime override (persistent_term, per-instance)
2. Per-instance app config (`config :my_app, MyApp.Jido, ...`)
3. Global app config (`config :jido, :telemetry` / `config :jido, :observability`)
4. Hardcoded default

## jido_ai — AI integration

### Model aliases

Map semantic names to provider model strings. Override defaults or add your own:

```elixir
config :jido_ai,
  model_aliases: %{
    fast: "anthropic:claude-haiku-4-5",
    capable: "anthropic:claude-sonnet-4-20250514",
    thinking: "anthropic:claude-sonnet-4-20250514",
    reasoning: "anthropic:claude-sonnet-4-20250514",
    planning: "anthropic:claude-sonnet-4-20250514",
    image: "openai:gpt-image-1",
    embedding: "openai:text-embedding-3-small"
  }
```

The table above shows built-in defaults. Your config merges on top — define only the aliases you want to change. Use aliases in code with `Jido.AI.resolve_model(:fast)`.

A full list of supported provider/model IDs is available at [llmcatalog.dev](https://llmcatalog.dev).

### LLM defaults

Role-based defaults for the `generate_text/2`, `generate_object/3`, and `stream_text/2` facade functions:

```elixir
config :jido_ai,
  llm_defaults: %{
    text: %{model: :fast, temperature: 0.2, max_tokens: 1024, timeout: 30_000},
    object: %{model: :thinking, temperature: 0.0, max_tokens: 1024, timeout: 30_000},
    stream: %{model: :fast, temperature: 0.2, max_tokens: 1024, timeout: 30_000}
  }
```

| Kind | Used by | Default model | Default temperature |
| --- | --- | --- | --- |
| `:text` | `Jido.AI.generate_text/2` | `:fast` | 0.2 |
| `:object` | `Jido.AI.generate_object/3` | `:thinking` | 0.0 |
| `:stream` | `Jido.AI.stream_text/2` | `:fast` | 0.2 |

Per-kind config merges with defaults, so you only need to specify fields you want to override.

### Provider API keys

Set provider API keys in `config/runtime.exs` (never commit these to source control):

```elixir
# config/runtime.exs
config :req_llm,
  anthropic_api_key: System.get_env("ANTHROPIC_API_KEY"),
  openai_api_key: System.get_env("OPENAI_API_KEY")
```

See [req_llm HexDocs](https://hexdocs.pm/req_llm) for the full list of supported providers and their key names.

## Next steps

- [Telemetry and observability](/docs/reference/telemetry-and-observability) - events emitted by these config options
- [Glossary](/docs/reference/glossary) - definitions for terms used on this page
