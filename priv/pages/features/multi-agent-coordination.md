%{
  title: "Agents that work together",
  category: :features,
  description: "Coordinate agent workflows with typed Signals, Actions, and explicit routing contracts.",
  doc_type: :explanation,
  audience: :intermediate,
  draft: false,
  order: 20
}
---
When agents need to work together, Jido keeps the contracts explicit. Signals define the messages agents exchange, Actions define what each agent can do, and Directives declare the side effects. No hidden callbacks, no implicit coupling. You can inspect and test every coordination boundary.

## At a glance

| Item | Summary |
|---|---|
| Best for | AI product engineers, staff architects, and teams moving beyond single-agent flows |
| Core packages | [jido_signal](/ecosystem/jido_signal), [jido_action](/ecosystem/jido_action), [jido](/ecosystem/jido) |
| Strategy add-ons | [jido_behaviortree](/ecosystem/jido_behaviortree), [jido_runic](/ecosystem/jido_runic) |
| Package status | `jido_signal` (Beta), `jido_action` (Beta), strategy add-ons (Experimental) |
| First proof path | [Demand Tracker Agent](/examples/demand-tracker-agent) -> [Signals routing training](/training/signals-routing) |

## Why coordination gets fragile

Coordination fails when behavior is encoded implicitly:

- Producer and consumer logic depend on undocumented callback order.
- Side-effect ownership is unclear across agent boundaries.
- Teams cannot test route-to-action behavior without running full environments.

Jido addresses this with explicit route tables, typed Actions, and inspectable Directives.

## Capability map

| Capability | Runtime mechanism | Package proof | Status |
|---|---|---|---|
| Event envelope consistency | CloudEvents-compatible Signal schema | [jido_signal](/ecosystem/jido_signal) | Beta |
| Route-level coordination | Signal route tables map event type -> Action module | [jido_signal](/ecosystem/jido_signal) | Beta |
| Typed capability execution | Action schema validation + execution controls | [jido_action](/ecosystem/jido_action) | Beta |
| Explicit side effects | Directives emitted from `cmd/2` instead of ad-hoc calls | [jido](/ecosystem/jido) | Beta |
| Strategy modularity | Behavior tree and DAG workflow strategy packages | [jido_behaviortree](/ecosystem/jido_behaviortree), [jido_runic](/ecosystem/jido_runic) | Experimental |

## Proof: verify route contracts and emitted directives

```elixir
alias AgentJido.Demos.DemandTrackerAgent
alias AgentJido.Demos.Demand.BoostAction
alias Jido.Agent.Directive.Emit

routes = DemandTrackerAgent.signal_routes(%{})
{"listing.demand.boost", BoostAction} in routes
#=> true

{_agent, directives} = DemandTrackerAgent.cmd(DemandTrackerAgent.new(), BoostAction)
Enum.any?(directives, &match?(%Emit{}, &1))
#=> true
```

Expected result:

```
true
```

This proves a concrete route mapping and an explicit emitted side effect using the same primitives you use in production.

## Directives: explicit side-effect control

When an Agent processes a command via `cmd/2`, side effects are not executed inline. Instead, `cmd/2` returns Directives: structured instructions the runtime evaluates separately.

- `%Directive.Emit{}`: publish a Signal to other agents or systems.
- `%Directive.EnqueueAction{}`: schedule follow-up work.
- Custom directives for domain-specific effects.

This separation means coordination logic is deterministic and testable. You can assert what Directives an Agent produces without triggering any external side effects.

For scheduling and recurring behaviors, Directives also model time-based orchestration. Agents can declare periodic work through plugin schedules without custom cron infrastructure.

## Tradeoffs and non-goals

- Explicit route and action design is slower up front than prompt-only choreography.
- Experimental strategy packages should be used with bounded pilots.
- Coordination clarity does not remove the need for domain-level retry and idempotency policies.

## What to explore next

- **Agent model foundations:** [BEAM-native agent model](/features/beam-native-agent-model)
- **Fault tolerance:** [Agents that self-heal](/features/agents-that-self-heal)
- **Observability:** [Observe everything](/features/observe-everything)
- **Training paths:** [Signals routing](/training/signals-routing), [Directives scheduling](/training/directives-scheduling)
- **Reference docs:** [Architecture](/docs/reference/behavior-first-architecture), [Guides](/docs/guides)

## Get Building

Start with [Demand Tracker Agent](/examples/demand-tracker-agent), then validate your first route table with [Signals routing training](/training/signals-routing).
