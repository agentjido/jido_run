%{
  title: "Use the Phoenix starter",
  description: "Run a complete Phoenix app that demonstrates Jido and Jido AI, with its Postgres and provider-key requirements called out.",
  menu_label: "Use the Phoenix starter",
  category: :docs,
  order: 22,
  tags: [:docs, :getting_started, :phoenix],
  draft: false,
  last_validated: "2026-07-24",
  tested_with: %{jido: "2.3.2", jido_ai: "2.2.0", req_llm: "1.17.1"}
}
---

## A running app instead of a blank project

The two paths above start from a blank Mix project and build an agent in an `iex` session. If you would rather explore Jido inside a real, running Phoenix application, use the [Jido PHX Starter](https://github.com/agentjido/jido_phx_starter).

The starter is a beginner-friendly Phoenix app with working demos for agent actions, signals, directives (`Schedule`, `Emit`), AI chat with tool calling, Ash and AshJido integration, and multi-agent orchestration. Clone it, get it running, and read the demo source to see how each piece fits together.

This path is a complement to the tutorials, not a replacement. The demos show finished patterns; the [onboarding ladder](#next-steps) walks you through building the same primitives step by step.

## Before you start: requirements

The starter is a database-backed Phoenix app, so it needs a little more local setup than the plain `iex` tutorials. Two requirements come straight from the starter README:

- **Postgres.** Install [PostgreSQL](https://www.postgresql.org/download/) and make sure the server is running. The starter's dev and test config expects a local database with username `postgres`, password `postgres`, and host `localhost`. `mix ecto.setup` creates and migrates the database for you.
- **A provider API key for the AI demos (optional).** The AI demos - `/jido/chat` and `/jido/listings` - use Jido AI and need an LLM API key. Set one before you start the server, for example `export ANTHROPIC_API_KEY="your_key_here"`. The core demos (counter, demand tracker, weekend-sale workflow) run without any key; without an API key the AI input controls simply stay disabled.

You also need Elixir and Erlang/OTP, Phoenix installed, and Git - the same toolchain the rest of getting started assumes.

## Run the starter

```bash
git clone https://github.com/agentjido/jido_phx_starter.git
cd jido_phx_starter
mix setup
mix ecto.setup
mix phx.server
```

Then open [http://localhost:4000](http://localhost:4000) for the demo index. Direct routes include `/jido/counter`, `/jido/demand-tracker`, `/jido/chat`, `/jido/listings`, and `/jido/weekend-sale`.

## What you can learn from it

- **Actions and Signals** - typed, validated actions and the Signal dispatch model, in a running process.
- **Directives** - `Schedule` and `Emit` directives returned from actions and executed by the runtime.
- **AI chat with tool calling** - Jido AI conversations that call back into Jido tools (requires a provider key).
- **Ash and AshJido** - generated actions with Ash authorization preserved.
- **Multi-agent orchestration** - coordinating more than one agent.

Open `lib/jido_phx_starter_web/demo_metadata.ex` to see how demos are registered, and `lib/jido_phx_starter/demos/` to inspect each one.

## Next steps

- [Start the tutorial ladder instead](/docs/getting-started/installation) - build an agent from scratch in an `iex` session
- [Your first agent](/docs/getting-started/first-agent) - the deterministic agent every path converges on
- [Jido PHX Starter on the ecosystem page](/ecosystem/jido_phx_starter) - the curated package record
- [Concepts](/docs/concepts) - the architectural reference for every Jido primitive
