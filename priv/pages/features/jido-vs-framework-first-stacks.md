%{
  title: "Jido vs framework-first stacks",
  category: :features,
  description: "Fit-for-purpose comparison between runtime-first and framework-first approaches to agent systems.",
  doc_type: :explanation,
  audience: :beginner,
  draft: false,
  order: 60
}
---
This comparison is about operating model fit, not vendor ranking. Prototype-first frameworks can be the right tool for rapid exploration. Jido is for teams optimizing for long-lived, operable multi-agent systems.

## At a glance

| Item | Summary |
|---|---|
| Best for | Teams evaluating architecture posture for production agent systems |
| Core question | Are we optimizing for fastest prototype or most predictable operation over time? |
| Jido posture | Runtime-first: explicit lifecycle, coordination, and operations boundaries |
| First proof path | [Multi-agent coordination](/features/multi-agent-coordination) -> [Production readiness checklist](/docs/learn/production-readiness) |

## Fit-for-purpose comparison

| Dimension | Prototype-first frameworks | Jido runtime-first posture |
|---|---|---|
| Initial setup | Usually faster for early experiments | More explicit setup up front |
| Runtime semantics | Often app-layer conventions | OTP supervision and process boundaries |
| Coordination model | Frequently callback/prompt choreography | Actions + Signals + Directives |
| Failure handling | Can be distributed across custom glue | Centralized lifecycle model in runtime |
| Operability | Often added later | Designed into architecture decisions |
| LLM dependency | Commonly central | Optional add-on layer |

## Capability-level view

| Capability category | Jido package proof | Maturity |
|---|---|---|
| Runtime lifecycle and recovery | [jido](/ecosystem/jido) | Beta |
| Typed capability contracts | [jido_action](/ecosystem/jido_action) | Beta |
| Signal-based coordination | [jido_signal](/ecosystem/jido_signal) | Beta |
| Optional LLM intelligence layer | [jido_ai](/ecosystem/jido_ai), [req_llm](/ecosystem/req_llm), [llm_db](/ecosystem/llm_db) | Beta / Stable |
| Advanced orchestration strategies | [jido_behaviortree](/ecosystem/jido_behaviortree), [jido_runic](/ecosystem/jido_runic) | Experimental |

## Proof: coordination contracts are inspectable in code

```elixir
alias AgentJido.Demos.CounterAgent
alias AgentJido.Demos.Counter.IncrementAction

routes = CounterAgent.signal_routes(%{})
{"counter.increment", IncrementAction} in routes
#=> true

{agent, _directives} = CounterAgent.cmd(CounterAgent.new(), {IncrementAction, %{by: 3}})
agent.state.count
```

Expected result:

```
3
```

This is a focused, testable contract path rather than hidden orchestration behavior.

## Tradeoffs and non-goals

- Jido does not optimize for minimum boilerplate in day-one prototypes.
- Runtime-first structure can feel heavier early but reduces long-term ambiguity.
- Experimental strategy/integration packages should not be default choices for production rollouts.

## What to explore next

- **Agent model foundations:** [BEAM-native agent model](/features/beam-native-agent-model)

## How to choose quickly

Use Jido when your primary constraints are:

- explicit failure boundaries,
- operability under sustained load,
- multi-agent coordination you can review and test.

Use prototype-first stacks when your primary constraint is very short-cycle idea validation with low operational risk.

## Get Building

Run a bounded comparison: start with [Counter Agent](/examples/counter-agent), then map production criteria using the [production readiness checklist](/docs/learn/production-readiness).
