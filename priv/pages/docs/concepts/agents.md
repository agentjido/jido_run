%{
  title: "Agents",
  description: "The runtime contract for state transitions, command handling, and directives in Jido.",
  category: :docs,
  legacy_paths: ["/docs/agents"],
  order: 80,
  in_menu: true,
  draft: false,
  tags: [:docs, :concepts]
}
---
## Agents are pure data

This is the most important concept in Jido: **an agent is an immutable struct, not a process.**

There is no GenServer inside an agent. No message passing, no mailbox, no `handle_call`. An agent is a plain Elixir struct with schema-validated state and a command interface. You create one, pass it to `cmd/2` with an action, and get back a new struct plus a list of directives. The original is unchanged.

This makes agents trivially testable, serializable, and composable. You can hold ten agents in a list, run the same action against all of them, and inspect results without starting any processes.

If you need a long-running process with supervision, message routing, and directive execution, that's what [AgentServer](/docs/concepts/agent-runtime) provides. It wraps an agent struct and runs it inside OTP. But the agent itself remains data.

Jido's core has no AI dependency. You can build, test, and ship agents without any LLM, any API key, or any neural network. AI capabilities live in the separate `jido_ai` package, which treats machine learning as one more action an agent can run - not as the foundation of what an agent is.

## Agents before LLMs

The word "agent" has been hijacked. In 2024, "agent" became shorthand for "LLM in a loop with tools." But agents have a 30-year history in computer science that predates large language models by decades.

In classical AI, an agent is an entity that perceives its environment through sensors and acts upon it through effectors. Stuart Russell and Peter Norvig defined this in *Artificial Intelligence: A Modern Approach* (1995). The BDI (Belief-Desire-Intention) model formalized how agents reason about goals. Behavior trees gave game AI agents deterministic decision-making. None of these required a language model.

Jido implements this classical definition. An agent has state (beliefs), receives signals (perceptions), executes actions (effectors), and emits directives (intentions). The execution model - how the agent decides what to do - is pluggable through strategies. A strategy can be a simple sequential pipeline, a behavior tree, a state machine, or yes, an LLM chain of thought. The agent contract is the same regardless.

This is why Jido agents are powerful in ways that LLM wrappers are not. You get deterministic testing, predictable performance, and composability that doesn't depend on a network call to a model provider. When you do want AI, `jido_ai` adds reasoning strategies like ReAct, chain-of-thought, and tree-of-thoughts as pluggable strategies - not as the core abstraction.

## What this solves

Most agent systems fail in production for one reason: state transitions and side effects are coupled.

When one function both mutates state and performs external work, failures become hard to isolate. You get partial updates, retry ambiguity, and brittle tests. Jido solves this by making the command boundary explicit:

- State transitions happen through `cmd/2`
- Side effects are emitted as directives
- Runtime execution of directives is separate from state mutation

The result is a system you can reason about under load.

## When to use it

A plain function is enough if your workflow is single-step and stateless. Reach for a Jido Agent when you need:

- Multi-step workflows where each step depends on prior state
- Validation of state shape over time
- Runtime-level failure isolation via OTP processes
- Clear effect boundaries for emits, scheduling, spawning, and retries

## Quick start

Define an agent with schema-backed state, then execute an action through `cmd/2`.

```elixir
defmodule MyApp.CounterAgent do
  use Jido.Agent,
    name: "counter_agent",
    description: "Tracks command executions",
    schema: Zoi.object(%{
      count: Zoi.integer() |> Zoi.default(0),
      status: Zoi.atom() |> Zoi.default(:idle)
    })
end

defmodule MyApp.Increment do
  use Jido.Action,
    name: "increment",
    schema: Zoi.object(%{by: Zoi.integer() |> Zoi.default(1)})

  @impl true
  def run(params, ctx) do
    agent = Map.get(ctx, :agent) || Map.get(ctx, "agent") || ctx
    by = Map.get(params, :by) || Map.get(params, "by") || 1
    {:ok, %{count: agent.state.count + by, status: :active}}
  end
end

# Example invocation:
# agent = MyApp.CounterAgent.new()
# {updated_agent, directives} = MyApp.CounterAgent.cmd(agent, {MyApp.Increment, %{by: 2}})
# updated_agent.state.count
# # => 2
# directives
# # => []
```

## How `cmd/2` works

`cmd/2` is the core contract for agent evolution.

At a high level:

1. `on_before_cmd/2` runs (optional hook)
2. action input is normalized into instructions
3. the configured strategy executes instructions
4. `on_after_cmd/3` runs (optional hook)
5. result returns as `{agent, directives}`

Two invariants matter:

- The returned `agent` is already complete; there is no "apply directives to state" step
- Directives are outbound runtime instructions, not state mutators

## Progressive example

This example updates agent state and emits a signal directive for the runtime.

```elixir
defmodule MyApp.RegistrationAgent do
  use Jido.Agent,
    name: "registration_agent",
    schema: Zoi.object(%{
      processed: Zoi.integer() |> Zoi.default(0),
      last_user_id: Zoi.string() |> Zoi.optional()
    })
end

defmodule MyApp.ProcessRegistration do
  use Jido.Action,
    name: "process_registration",
    schema: Zoi.object(%{user_id: Zoi.string()})

  alias Jido.Agent.Directive

  @impl true
  def run(params, ctx) do
    agent = Map.get(ctx, :agent) || Map.get(ctx, "agent") || ctx
    user_id = Map.get(params, :user_id) || Map.get(params, "user_id")

    signal = %Jido.Signal{
      id: "sig_registration_processed",
      type: "registration.processed",
      source: "my_app.registration",
      data: %{user_id: user_id}
    }

    {:ok,
     %{processed: agent.state.processed + 1, last_user_id: user_id},
     %Directive.Emit{signal: signal}}
  end
end

# Example invocation:
# agent = MyApp.RegistrationAgent.new()
# {agent, directives} =
#   MyApp.RegistrationAgent.cmd(agent, {MyApp.ProcessRegistration, %{user_id: "usr_123"}})
# agent.state
# # => %{processed: 1, last_user_id: "usr_123"}
# directives
# # => [%Jido.Agent.Directive.Emit{...}]
```

In production, the runtime handles the directive dispatch; your state transition logic stays pure.

## Strategy selection guidance

| Strategy | Best for | Tradeoff |
| --- | --- | --- |
| `Jido.Agent.Strategy.Direct` | Deterministic workflows and most business-state transitions | Single-pass execution; no built-in tick loop |
| Custom strategy implementing `Jido.Agent.Strategy` | Multi-step planners, staged execution, or domain-specific orchestration | More control, but you own strategy semantics and testing |

Start with `Direct` unless you can name the specific runtime behavior you need from a custom strategy.

## Failure modes and operational boundaries

The most common failures are normalization errors, action execution failures, and schema violations.

Jido keeps those failures bounded:

- Invalid action input is surfaced as a validation-style error directive
- Instruction failures are represented as typed error directives
- Agent state updates remain explicit and inspectable

Operationally, this is where `AgentServer` and supervision matter. Supervisors handle process lifecycle; your agent contract handles state correctness and effect intent.

## Next steps

- [Agent runtime](/docs/concepts/agent-runtime) - run agents under OTP supervision with process management
- [Actions](/docs/concepts/actions) - learn how Actions transform agent state
- [Directives](/docs/concepts/directives) - understand effect payloads returned by actions
- [Strategy](/docs/concepts/strategy) - plug in custom execution models
