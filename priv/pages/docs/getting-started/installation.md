%{
  title: "Installation and setup",
  description: "Add Jido to a new or existing Elixir project with a production-safe baseline.",
  category: :docs,
  order: 25,
  tags: [:docs, :getting_started, :setup],
  draft: false,
  legacy_paths: ["/docs/learn/installation"],
  learning_outcomes: [
    "Add core Jido dependencies to mix.exs",
    "Configure runtime secrets and provider settings",
    "Verify the installation with a smoke test"
  ]
}
---
## Prerequisites

- Elixir `~> 1.18` and OTP 27+
- An existing Elixir app, or create one with `mix new my_agent_app --sup`
- An API key for an LLM provider if you plan to use AI-backed features

## Install Jido

The recommended way to install Jido is the [Igniter](https://hex.pm/packages/igniter) installer. It adds the dependency and generates a Jido instance module wired into your supervision tree, so the runtime is owned by your OTP application:

```shell
mix igniter.install jido
```

This creates a `use Jido` module (for example `MyAgentApp.Jido`) and adds it to your application supervisor's `children` list. Then continue to [Your first agent](/docs/getting-started/first-agent).

### Add dependencies manually

If you prefer to wire things up by hand, add `jido` to `mix.exs` (add `jido_ai` and `req_llm` when you introduce AI):

```elixir
defp deps do
  [
    {{mix_dep:jido}},
    {{mix_dep:jido_ai}},
    {{mix_dep:req_llm}}
  ]
end
```

Define a Jido instance module and start it under your application supervisor:

```elixir
defmodule MyAgentApp.Jido do
  use Jido, otp_app: :my_agent_app
end
```

```elixir
# lib/my_agent_app/application.ex
children = [
  {MyAgentApp.Jido, name: MyAgentApp.Jido}
]
```

Fetch and compile:

```shell
mix deps.get
mix compile
```

The exact supported range for every package — across the Core, AI, and Operate stacks — is listed in the [stack compatibility matrix](/ecosystem#stack-compatibility). Pin from those ranges so you do not have to infer which versions are compatible.

## Configure runtime

Runtime configuration belongs in `config/runtime.exs`, not `config/config.exs`. That separation keeps secrets out of compiled artifacts.

Add a minimal provider block for ReqLLM, the credential layer that `jido_ai` uses under the hood:

```elixir
# config/runtime.exs
import Config

config :req_llm,
  openai_api_key: System.get_env("OPENAI_API_KEY")
```

Set the environment variable in your shell or a `.env` file:

```shell
export OPENAI_API_KEY="your-api-key"
```

See [req_llm HexDocs](https://hexdocs.pm/req_llm) for the full list of supported providers and their key names.

## Verify installation

Start an IEx session and confirm both applications load:

```shell
iex -S mix
```

```elixir
iex> Application.ensure_all_started(:jido)
#=> {:ok, _}
iex> Application.ensure_all_started(:jido_ai)
#=> {:ok, _}
```

Both calls return `{:ok, _}`. If you see errors, check the troubleshooting section below.

Run a quick smoke test. Define a trivial agent and action inline, execute a command, and confirm the state changes:

```elixir
iex> defmodule SmokeAgent do
...>   use Jido.Agent,
...>     name: "smoke_agent",
...>     schema: Zoi.object(%{
...>       status: Zoi.string() |> Zoi.default("pending")
...>     })
...> end

iex> defmodule MarkReady do
...>   use Jido.Action,
...>     name: "mark_ready",
...>     schema: Zoi.object(%{})
...>   @impl true
...>   def run(_params, _context), do: {:ok, %{status: "ready"}}
...> end

iex> agent = SmokeAgent.new()
iex> {updated, _directives} = SmokeAgent.cmd(agent, {MarkReady, %{}})
iex> updated.state.status
#=> "ready"
```

The state moved from `"pending"` to `"ready"`. Jido is working.

## Common failures

- **`UndefinedFunctionError` for a Jido module** - Run `mix deps.get && mix compile` again, then restart IEx.
- **`{:error, {:jido_ai, ...}}`** - Confirm `jido_ai` is listed in `mix.exs` and the dependency was fetched.
- **`nil` provider config** - Your `OPENAI_API_KEY` is not set in the shell session running `iex -S mix`. ReqLLM reads keys at runtime from application config.
- **Version conflicts** - Confirm you are on Elixir 1.18+ and OTP 27+. Run `elixir --version` to check.

## Next steps

- [Your first agent](/docs/getting-started/first-agent) - define typed state and run a validated Action
- [Core concepts](/docs/concepts) - understand Agents, Actions, and Signals
