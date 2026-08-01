%{
  title: "Quickstarts by Persona",
  category: :build,
  description: "Choose your path: chatbot builder, data pipeline engineer, or autonomous agent architect.",
  doc_type: :tutorial,
  audience: :beginner,
  draft: false,
  order: 10
}
---
Use this page as a routing layer.
Pick the persona path that matches your current bottleneck, finish one milestone, then move to architecture and readiness work.

## How to use this page

1. Choose the persona closest to your day-to-day responsibilities.
2. Complete the first milestone without expanding scope.
3. Follow exactly one training link and one docs/checklist link before adding new requirements.

## Persona quickstarts

### Elixir platform engineer

- First milestone: run one supervised agent and verify deterministic state updates.
- Start: [Counter Agent example](/examples/counter-agent)
- Next training: [Agent Fundamentals on the BEAM](/training/agent-fundamentals)
- Ops/reference follow-up: [Architecture](/docs/reference/behavior-first-architecture)

### AI product engineer

- First milestone: ship one user-facing workflow backed by explicit actions.
- Start: [Demand Tracker Agent example](/examples/demand-tracker-agent)
- Next training: [Actions and Validation](/training/actions-validation)
- Ops/reference follow-up: [Error handling and recovery](/docs/guides/error-handling-and-recovery)

### Python AI engineer

- First milestone: understand where BEAM runtime boundaries improve reliability and orchestration.
- Start: [BEAM for AI Builders](/features/beam-for-ai-builders)
- Next training: [LiveView + Jido Integration Patterns](/training/liveview-integration)
- Ops/reference follow-up: [Plugins](/docs/concepts/plugins)

### TypeScript fullstack engineer

- First milestone: model one multi-step workflow with clear signal boundaries.
- Start: [Multi-Agent Coordination](/features/multi-agent-coordination)
- Next training: [Signals and Routing](/training/signals-routing)
- Ops/reference follow-up: [Guides](/docs/guides)

### Platform and SRE engineer

- First milestone: define runtime health checks and incident response expectations before launch.
- Start: [Observe everything](/features/observe-everything)
- Next training: [Production Readiness: Supervision, Telemetry, and Failure Modes](/training/production-readiness)
- Ops/reference follow-up: [Error handling and recovery](/docs/guides/error-handling-and-recovery)

## Proof check: first value in one command loop

```elixir
alias AgentJido.Demos.CounterAgent
alias AgentJido.Demos.Counter.IncrementAction

agent = CounterAgent.new()
{agent, _directives} = CounterAgent.cmd(agent, {IncrementAction, %{by: 1}})
agent.state.count
```

Expected result:

```
1
```

## When to move to architecture work

Move to [Reference Architectures](/build/reference-architectures) when any of these become true:

- You need multiple cooperating agents with distinct ownership boundaries.
- You need predictable recovery behavior for long-lived workflows.
- You need a package selection rationale that can be reviewed with platform stakeholders.

## Get Building

Choose one path, complete one milestone, and document your decisions.
Then continue with [Reference Architectures](/build/reference-architectures) for topology and package planning.
