%{
  title: "I know Elixir",
  description: "Map Jido's architecture to OTP patterns you already know, then build your first agent.",
  menu_label: "I know Elixir",
  category: :docs,
  order: 20,
  tags: [:docs, :getting_started, :elixir],
  draft: false
}
---

## How Jido maps to what you know

Jido builds on OTP, not around it. The core concepts have direct parallels:

| OTP pattern | Jido equivalent | Key difference |
|---|---|---|
| GenServer state | `Agent` struct with Zoi schema | State is validated at every transition, not just `init/1` |
| `handle_call/3` logic | `Action` modules with `run/2` | Pure functions that return state changes, never perform side effects inline |
| Side effects in callbacks | `Directive` structs | Effects are data returned from actions, executed separately by the runtime |
| Supervision tree | `AgentServer` + standard supervisors | `AgentServer` is a GenServer that wraps an Agent struct |
| `send/2` / message passing | `Signal` routing | Typed, schema-validated event dispatch with pattern-matched routing |

The fundamental shift: Jido separates **what an agent decides** from **how the runtime executes it**. Your agent logic is pure data transformations. The process layer handles lifecycle, supervision, and effect execution.

## The architectural insight

In a typical GenServer, state mutation and side effects live in the same callback:

```elixir
def handle_call({:process, order}, _from, state) do
  {:ok, _} = Repo.insert(order)        # side effect
  Mailer.send_confirmation(order)       # side effect
  {:reply, :ok, %{state | last: order}} # state mutation
end
```

If `Mailer.send_confirmation/1` raises, the process restarts but the database write already happened. The state update and the side effects are entangled.

Jido makes the boundary explicit:

```elixir
defmodule MyApp.ProcessOrder do
  use Jido.Action,
    name: "process_order",
    schema: Zoi.object(%{order_id: Zoi.string()})

  @impl true
  def run(params, _context) do
    {:ok, %{last_order: params.order_id, status: :processed},
     %Jido.Agent.Directive.Emit{
       signal: Jido.Signal.new!("order.processed",
         %{order_id: params.order_id}, source: "/orders")
     }}
  end
end
```

State changes and effect descriptions come back as data. The runtime handles directive execution with its own failure semantics. Your action stays pure and testable without mocking.

## What you'll need

- Elixir 1.18+ and OTP 27+ installed
- An LLM API key (OpenAI, Anthropic, or similar) for the third tutorial
- About an hour for all four tutorials

## Your onboarding path

Work through these four tutorials in order. Each builds on the last.

1. **[Installation and setup](/docs/getting-started/installation)** - add `jido` and `jido_ai` to `mix.exs`, configure runtime secrets, verify compilation
2. **[Your first agent](/docs/getting-started/first-agent)** - define a `CounterAgent` with a Zoi schema, implement an Action, execute it with `cmd/2`
3. **[Your first LLM agent](/docs/getting-started/first-llm-agent)** - add `jido_ai`, configure a provider, run an AI-enhanced command through `AgentServer`
4. **[Build your first workflow](/docs/learn/first-workflow)** - compose multiple actions into a sequential workflow with shared state

Each tutorial takes under fifteen minutes and ends with a working result you can run in IEx.

## Understand the primitives

Jido's architecture is built on a small set of composable primitives. The [Concepts](/docs/concepts) section covers each one in depth - read these alongside or after the tutorials to solidify your mental model.

- **[Agents](/docs/concepts/agents)** - immutable structs with schema-validated state and the `cmd/2` contract
- **[Actions](/docs/concepts/actions)** - validated Actions with compile-time schemas that drive state transitions
- **[Directives](/docs/concepts/directives)** - effect descriptions returned from actions, executed by the runtime
- **[Signals](/docs/concepts/signals)** - typed events for inter-agent communication and routing
- **[Agent runtime](/docs/concepts/agent-runtime)** - the OTP process layer that wraps agents for supervision
- **[Strategy](/docs/concepts/strategy)** - pluggable execution models from sequential pipelines to AI reasoning

## Next steps

- [Start with installation](/docs/getting-started/installation) - begin the onboarding ladder
- [Concepts](/docs/concepts) - the full architectural reference for every Jido primitive
- [Why not just a GenServer?](/docs/reference/why-not-just-a-genserver) - the full case for separating data from process
