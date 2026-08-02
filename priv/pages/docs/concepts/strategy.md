%{
  title: "Strategy",
  description: "Pluggable execution models that control how agents process actions.",
  category: :docs,
  order: 100,
  draft: false,
  tags: [:docs, :concepts]
}
---
Every agent needs to decide how to run its actions. A Strategy is the pluggable execution model that controls this. It sits between the agent's `cmd/2` call and the actual action execution, letting you swap execution semantics without changing your agent or action code.

Strategies are a key extension point in Jido. The core ships with `Direct` and `FSM` strategies. The `jido_ai` package adds AI reasoning strategies. The `jido_behaviortree` package adds behavior tree execution. You can implement your own by satisfying a single callback.

## What strategies solve

Without strategies, execution logic gets baked into the agent definition. Every agent that needs retry logic, staged execution, or multi-step planning would need its own `cmd/2` implementation. This couples the agent's state model to its runtime behavior.

Strategies decouple these concerns. Your agent defines state shape and validation. Your actions define pure transformations. Your strategy decides how those actions run: sequentially, through a finite state machine, via a behavior tree, or with LLM-driven planning.

The same agent struct and actions work identically under different strategies. Swap from `Direct` to a behavior tree and your tests, state contracts, and action logic stay unchanged.

## Direct strategy

`Jido.Agent.Strategy.Direct` is the default and handles most use cases. It executes instructions sequentially in a single pass.

For each instruction, Direct calls `Jido.Exec.run/1`, merges the result into agent state, separates internal state operations from external directives, and moves to the next instruction. If an instruction fails, it emits an error directive and continues.

```elixir
defmodule MyApp.OrderAgent do
  use Jido.Agent,
    name: "order_agent",
    schema: Zoi.object(%{total: Zoi.integer() |> Zoi.default(0)})
end

agent = MyApp.OrderAgent.new()
{agent, directives} = MyApp.OrderAgent.cmd(agent, MyApp.AddItem)
```

Start with `Direct` unless you can name the specific runtime behavior you need from a custom strategy.

## FSM strategy

`Jido.Agent.Strategy.FSM` adds finite state machine semantics. Instructions trigger state transitions, and the strategy enforces which transitions are valid. This is useful for workflows with well-defined phases - order processing, approval pipelines, onboarding flows.

```elixir
defmodule MyApp.ApprovalAgent do
  use Jido.Agent,
    name: "approval_agent",
    strategy: {Jido.Agent.Strategy.FSM,
      initial_state: "draft",
      transitions: %{
        "draft" => ["pending_review"],
        "pending_review" => ["approved", "rejected"],
        "approved" => ["draft"],
        "rejected" => ["draft"]
      }
    }
end
```

The FSM state is stored in `agent.state.__strategy__` and tracked through the standard `snapshot/2` interface. Invalid transitions are rejected with error directives.

## Behavior tree strategy

The `jido_behaviortree` package implements behavior tree execution as a Jido strategy. Behavior trees are the proof point for Jido's classical agent model - they've powered game AI, robotics, and autonomous systems for decades without any LLM involvement.

A behavior tree composes actions into a tree of selectors, sequences, and conditions. The strategy traverses the tree, executing actions at leaf nodes and using control nodes to decide branching. This gives you deterministic, inspectable decision-making that is trivially testable.

```elixir
defmodule MyApp.PatrolAgent do
  use Jido.Agent,
    name: "patrol_agent",
    strategy: {Jido.Agent.Strategy.BehaviorTree,
      tree: sequence([
        MyApp.Actions.CheckBattery,
        selector([
          MyApp.Actions.InvestigateAnomaly,
          MyApp.Actions.ContinuePatrol
        ]),
        MyApp.Actions.ReportStatus
      ])
    }
end
```

The tree evaluates on each `cmd/2` call. Nodes return `:success`, `:failure`, or `:running`. A `:running` result schedules a tick for the next turn, letting the tree pause and resume across multiple execution cycles.

## AI reasoning strategies

The `jido_ai` package implements several AI reasoning strategies that use LLMs as the decision engine while preserving the same strategy contract. These include:

- **ReAct** - reason-act loops with tool calling
- **Chain of Thought** - step-by-step LLM reasoning
- **Chain of Draft** - concise iterative drafting
- **Tree of Thoughts** - branching exploration of reasoning paths
- **Graph of Thoughts** - non-linear reasoning with merging and refinement
- **Algorithm of Thoughts** - algorithmic search through solution space
- **TRM** - test-time reinforcement for self-improving responses
- **Adaptive** - dynamic strategy selection based on task complexity

Each uses the `tick/2` callback to implement multi-turn reasoning. The LLM call happens in one turn, tool execution in another, and result processing in the next. From the agent's perspective, it's the same `cmd/2` call with the same `{agent, directives}` return.

## The strategy contract

A strategy implements the `Jido.Agent.Strategy` behaviour. The only required callback is `cmd/3`. Three optional callbacks handle initialization, multi-step execution, and state inspection.

```elixir
@callback cmd(agent, instructions, context) :: {agent, directives}
@callback init(agent, context) :: {agent, directives}
@callback tick(agent, context) :: {agent, directives}
@callback snapshot(agent, context) :: Strategy.Snapshot.t()
```

**`cmd/3`** (required) receives the agent, a list of normalized `Instruction` structs, and an execution context. It returns the updated agent and a list of directives.

**`init/2`** (optional) is called by `AgentServer` after `new/1` and before the first `cmd/2`. Use it to set up strategy-specific state.

**`tick/2`** (optional) supports multi-turn execution. After `cmd/3` sets up initial state, the strategy emits a `{:schedule, ms, :strategy_tick}` directive. The `AgentServer` calls `tick/2` when the scheduled time arrives, and the strategy can continue execution or schedule another tick. This is how strategies implement turns - `jido_ai` uses this pattern extensively for reasoning loops that alternate between LLM calls, tool execution, and result processing.

**`snapshot/2`** (optional) returns a `Strategy.Snapshot` struct that exposes strategy state without leaking internal details.

```elixir
snap = MyAgent.strategy_snapshot(agent)
snap.status   # => :running, :waiting, :success, or :failure
snap.done?    # => true when status is :success or :failure
snap.result   # => the strategy's main output, if any
```

## Custom strategies

To build a custom strategy, `use Jido.Agent.Strategy` and implement `cmd/3`.

```elixir
defmodule MyApp.RetryStrategy do
  use Jido.Agent.Strategy

  @impl true
  def cmd(agent, instructions, ctx) do
    max_retries = ctx.strategy_opts[:max_retries] || 3

    Enum.reduce(instructions, {agent, []}, fn instr, {acc, dirs} ->
      {new_agent, new_dirs} = run_with_retry(acc, instr, max_retries)
      {new_agent, dirs ++ new_dirs}
    end)
  end
end
```

Set the strategy at compile time in your agent definition:

```elixir
defmodule MyApp.ResilientAgent do
  use Jido.Agent,
    name: "resilient_agent",
    strategy: {MyApp.RetryStrategy, max_retries: 5}
end
```

Strategy state lives inside `agent.state` under the reserved key `:__strategy__`. Use the `Jido.Agent.Strategy.State` helpers to manage it.

## Next steps

- [Agents](/docs/concepts/agents) for the full agent contract and `cmd/2` lifecycle
- [Actions](/docs/concepts/actions) to understand the Actions that strategies execute
- [Directives](/docs/concepts/directives) for the effect payloads that strategies return
- [Agent runtime](/docs/concepts/agent-runtime) to run strategy-backed agents under OTP supervision
