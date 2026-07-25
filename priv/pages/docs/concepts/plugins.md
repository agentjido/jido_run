%{
  title: "Plugins",
  description: "Reusable packages of agent functionality - actions, routes, state, and lifecycle hooks.",
  category: :docs,
  order: 105,
  tags: [:docs, :concepts],
  legacy_paths: ["/docs/plugins"],
  draft: false
}
---
Plugins are how you extend agent functionality and package reusable agent capabilities. A plugin bundles actions, state, signal routing, and lifecycle hooks into a single module that any agent can include. They are meant to be distributed as separate Mix packages, giving you an extension point for sharing functionality across agents and projects.

## What plugins solve

Without plugins, every agent must define its own actions, signal routes, and state fields inline. This works for simple agents but breaks down when multiple agents need the same capability. You end up duplicating action lists, route tables, and initialization logic across modules.

Plugins solve this by packaging a complete capability into one module. A chat plugin brings its own actions, message history state, and signal routes. A database plugin brings connection pooling, query actions, and health checks. You declare the plugins you want and the agent gains those capabilities at compile time.

Plugins also enforce structure. Each plugin validates its configuration at compile time using Zoi schemas, declares its dependencies explicitly, and isolates its state under a dedicated key. This prevents plugins from stepping on each other or corrupting shared state.

## Anatomy of a plugin

You define a plugin with `use Jido.Plugin` and a set of required options:

```elixir
defmodule MyApp.ChatPlugin do
  use Jido.Plugin,
    name: "chat",
    state_key: :chat,
    actions: [MyApp.Actions.SendMessage, MyApp.Actions.ListHistory],
    schema: Zoi.object(%{
      messages: Zoi.list(Zoi.any()) |> Zoi.default([]),
      model: Zoi.string() |> Zoi.default("gpt-4")
    }),
    signal_patterns: ["chat.*"],
    signal_routes: [
      {"chat.send", MyApp.Actions.SendMessage},
      {"chat.history", MyApp.Actions.ListHistory}
    ]
end
```

Three options are required. `name` identifies the plugin. `state_key` is the atom key under which the plugin's state lives in the agent struct. `actions` lists the action modules the plugin provides.

The optional `schema` defines the shape and defaults for the plugin's state slice using a Zoi schema. `config_schema` defines a separate schema for per-agent configuration, letting each agent customize the plugin at declaration time. Both schemas are validated at compile time.

## Default plugins

Every agent automatically includes three singleton plugins provided by Jido core:

| Plugin | State key | Purpose |
| --- | --- | --- |
| `Jido.Thread.Plugin` | `:__thread__` | Conversation history and thread state management |
| `Jido.Identity.Plugin` | `:__identity__` | Agent identity and self-model |
| `Jido.Memory.Plugin` | `:__memory__` | Cognitive memory state |

These are singleton plugins - they cannot be duplicated or aliased. They reserve their state keys with double-underscore prefixes to avoid collisions with your own plugins.

Default plugins are initialized lazily. `Thread.Plugin` does not create a thread until you call `Jido.Thread.Agent.ensure/2`. `Memory.Plugin` does not allocate memory until first use. This keeps bare agents lightweight.

You can disable or replace default plugins per-agent:

```elixir
defmodule MyApp.BareAgent do
  use Jido.Agent,
    name: "bare_agent",
    default_plugins: %{__thread__: false}
end

defmodule MyApp.CustomAgent do
  use Jido.Agent,
    name: "custom_agent",
    default_plugins: %{__thread__: MyApp.CustomThreadPlugin}
end
```

To disable all defaults, pass `default_plugins: false`.

## Plugin lifecycle

Plugins follow a five-stage lifecycle from compile time through runtime signal processing.

**Compile time.** You declare plugins in the agent's `plugins:` option. Jido validates each plugin's configuration against its schemas and merges the plugin's actions and routes into the agent's definitions.

```elixir
defmodule MyAgent do
  use Jido.Agent,
    name: "my_agent",
    plugins: [
      MyApp.ChatPlugin,
      {MyApp.DatabasePlugin, %{pool_size: 5}}
    ]
end
```

You can pass a plugin module directly or as a tuple with a configuration map. The configuration map is validated against the plugin's `config_schema`.

**Mount.** When you call `Agent.new/1`, each plugin's `mount/2` callback runs to initialize plugin-specific state. This is a pure function with no side effects. It receives the agent struct and the per-agent config, and returns a map that gets merged into the plugin's state slice.

```elixir
@impl Jido.Plugin
def mount(agent, config) do
  {:ok, %{initialized_at: DateTime.utc_now()}}
end
```

**Child processes.** When `AgentServer.init/1` runs, it calls each plugin's `child_spec/1` callback. Returned process specifications are started and monitored by the agent server. If a plugin needs a worker process, connection pool, or background task, this is where it declares them.

**Signal handling.** During signal processing, each plugin's `handle_signal/2` callback runs before the signal reaches the router. Plugins execute in declaration order. This hook can inspect, transform, or override the signal's routing.

**Result transformation.** On the synchronous call path, `transform_result/3` runs after action execution. It lets a plugin modify the agent struct returned to the caller without affecting internal server state.

## Signal routing

Plugins contribute signal routes to the agent's unified router. You declare routes in two ways.

Static routes use the `signal_routes:` compile-time option. Each tuple maps a signal type string to an action module:

```elixir
use Jido.Plugin,
  signal_routes: [
    {"chat.send", MyApp.Actions.SendMessage},
    {"chat.history", MyApp.Actions.ListHistory}
  ]
```

For dynamic routes that depend on runtime configuration, override the `signal_routes/1` callback instead. Static routes are preferred when the mapping is known at compile time.

The `signal_patterns` option controls which signals reach the plugin's `handle_signal/2` hook. Patterns use dot-delimited wildcards like `"chat.*"`. A plugin with an empty patterns list acts as global middleware and receives all signals.

The `handle_signal/2` callback returns one of several responses:

- `{:ok, :continue}` to pass through to normal routing
- `{:ok, {:continue, signal}}` to rewrite the signal before routing
- `{:ok, {:override, action}}` to bypass the router entirely
- `{:error, reason}` to abort signal processing

## Schedules

Plugins can declare `schedules` for cron-style periodic execution. Each schedule is a tuple of a cron expression and an action module:

```elixir
schedules: [{"*/5 * * * *", MyApp.Actions.SyncMessages}]
```

## Control surface

A plugin's control surface is its lifecycle hooks — the integration points where an application verifies, enriches, or authorizes work. The table names each control point. Jido supplies the hooks; the **policy decisions** (verifying a principal, authorizing an action) stay with your application. `prepare_action/3` is the fail-closed authorization point used by the controlled-Agent path. See [Security and governance](/docs/operations/security-and-governance) for the full control-point map.

| Hook | Input | Decision | Output | Failure behavior | Evidence |
| --- | --- | --- | --- | --- | --- |
| `prepare_signal/2` | incoming signal | Verify or enrich runtime context | Enriched signal | No-op pass-through by default | Signal context after enrichment |
| `prepare_action/3` | action + params + context | Permit or deny the action | `:ok` or `{:halt, reason}` | Fail-closed when implemented — a protected action does not run without an allow | Deny or allow outcome; the action never executes on a deny |
| Plugin config schema | plugin options | Validate at compile time | Configured plugin | Compile error on invalid options | Compile-time validation result |

## Next steps

- [Actions](/docs/concepts/actions) - understand the building blocks that plugins bundle together
- [Signals](/docs/concepts/signals) - learn how signals flow through the routing system that plugins extend
- [Agent runtime](/docs/concepts/agent-runtime) - see how child processes and signal dispatch work at the server level
