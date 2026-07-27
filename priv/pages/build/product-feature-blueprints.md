%{
  title: "Product feature blueprints",
  category: :build,
  description: "Step-by-step blueprints for common product features powered by agents.",
  doc_type: :guide,
  audience: :intermediate,
  draft: false,
  order: 40,
  last_validated: "2026-03-16"
}
---
Product feature blueprints convert fuzzy requirements into shippable milestones.
Use these patterns to map feature intent to agent boundaries, package choices, and readiness checks before launch.

## How to use this page

1. Pick the blueprint closest to your current product requirement.
2. Keep phase 1 limited to one user-visible workflow and one reliability objective.
3. Attach one training module and one docs checklist before adding secondary features.

## Prerequisites

- Complete one bounded implementation from [Quickstarts by Persona](/build/quickstarts-by-persona) or [Counter Agent](/examples/counter-agent).
- Choose runtime boundaries in [Reference Architectures](/build/reference-architectures).
- Validate package intent with [Compare Packages](/ecosystem#compare).
- Review release guardrails in [Production Readiness: Supervision, Telemetry, and Failure Modes](/training/production-readiness).

## Blueprint format

Each blueprint should include:

- User-facing outcome and explicit non-goals.
- Owning agent boundary and required package set.
- Verification proof route (example or command path).
- Launch gate checklist tied to docs and training assets.

Template:

```markdown
Feature:
Owner:
Primary workflow:
Non-goals:
Required packages:
Proof route:
Readiness checks:
```

## Blueprint library

### Blueprint A: Conversational support assistant

- Outcome: One production support flow that answers with tool-backed context.
- Required packages: `jido`, `jido_action`, `jido_ai`
- Proof route: [Examples index](/examples)
- Launch checks: [Security and Governance](/docs/operations/security-and-governance), [Actions and Validation](/training/actions-validation)
- Non-goals: autonomous ticket closure, cross-team escalation routing

### Blueprint B: Demand operations workflow

- Outcome: One event-driven demand scoring flow with deterministic state transitions.
- Required packages: `jido`, `jido_action`, `jido_signal`
- Proof route: [Demand Tracker Agent example](/examples/demand-tracker-agent)
- Launch checks: [Signals and Routing](/training/signals-routing), [Incident Playbooks](/docs/operations/incident-playbooks)
- Non-goals: full forecasting pipeline, multi-region replication

### Blueprint C: Internal ops co-pilot

- Outcome: One operator workflow that proposes actions and records directive results.
- Required packages: `jido`, `jido_signal`, `jido_ai`
- Proof route: [Jido Documentation](/docs)
- Launch checks: [Production Readiness Checklist](/docs/operations/production-readiness-checklist), [Production Readiness: Supervision, Telemetry, and Failure Modes](/training/production-readiness)
- Non-goals: replacing existing incident command process, auto-approval of high-risk actions

## Proof check: feature blueprint stays bounded

```elixir
alias AgentJido.Demos.DemandTrackerAgent
alias AgentJido.Demos.Demand.BoostAction

agent = DemandTrackerAgent.new()
{agent, directives} = DemandTrackerAgent.cmd(agent, {BoostAction, %{amount: 20}})

{agent.state.demand, Enum.any?(directives, &match?(%Jido.Agent.Directive.Emit{}, &1))}
```

Expected result:

```
{70, true}
```

This proof confirms a blueprint can define a narrow workflow with explicit state changes plus side-effect directives.

## Selection checklist

1. Confirm the first release has one primary workflow and explicit non-goals.
2. Confirm package choices match runtime boundaries and signal needs.
3. Confirm at least one runnable proof route before adding integration breadth.
4. Confirm readiness checks are assigned to specific owners.

## Get Building

Pick one blueprint, implement the smallest proof that reaches user value, and document non-goals before sprint planning.
Then use [Mixed-Stack Integration](/build/mixed-stack-integration) to connect that blueprint to existing product services.
