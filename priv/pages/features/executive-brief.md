%{
  title: "Executive brief",
  category: :features,
  description: "Technical decision summary for leaders evaluating Jido as runtime infrastructure for multi-agent systems.",
  doc_type: :explanation,
  audience: :beginner,
  draft: false,
  order: 70
}
---
This page is for engineering managers, CTOs, and architecture leads evaluating whether Jido should be part of their production AI stack.

## At a glance

| Item | Summary |
|---|---|
| Strategic category | Elixir framework for long-running agent systems |
| Core differentiator | Elixir/OTP runtime semantics: isolation, supervision, and concurrency |
| Intelligence posture | LLM integration is optional, not mandatory |
| Adoption model | Bounded pilot -> measured expansion -> operations hardening |
| First decision path | [Compare packages](/ecosystem#compare) -> [Reference architectures](/build/reference-architectures) |

## What you are buying architecturally

| Capability area | Outcome for leadership teams | Package proof |
|---|---|---|
| Reliability by architecture | Lower blast radius and clearer recovery posture | [jido](/ecosystem/jido) |
| Explicit coordination | Easier code review, ownership boundaries, and testing | [jido_signal](/ecosystem/jido_signal), [jido_action](/ecosystem/jido_action) |
| Operations visibility | Better incident workflows and readiness gates | [jido_otel](/ecosystem/jido_otel), [docs checklist](/docs/operations/production-readiness-checklist) |
| Incremental adoption | Avoid full-platform rewrite before proving value | [Start small, grow safely](/features/start-small) |

## Decision criteria matrix

| Decision question | If answer is yes | If answer is no |
|---|---|---|
| Do we need long-lived workflows with strict uptime constraints? | prioritize Jido runtime pilot | use lighter prototype path first |
| Do we need explicit failure and recovery boundaries? | run supervised pilot with checklist gates | continue app-layer orchestration |
| Do we need LLM capabilities now? | add `jido_ai` and `req_llm` incrementally | stay on runtime-only baseline |
| Do we need mixed-stack integration? | use bounded service boundary and integration guides | defer integration complexity |

## 30/60/90 rollout shape

| Window | Objective | Deliverable |
|---|---|---|
| 0-30 days | prove runtime fit on one workflow | supervised pilot + acceptance criteria |
| 31-60 days | operationalize with visibility and runbooks | telemetry baseline + incident playbook |
| 61-90 days | expand package footprint where justified | compare table review + architecture review |

## Proof: supervised orchestration runtime in one process

```elixir
{:ok, _pid} =
  Jido.AgentServer.start_link(
    id: AgentJido.ContentOps.OrchestratorServer,
    agent: AgentJido.ContentOps.OrchestratorAgent,
    jido: AgentJido.Jido,
    name: AgentJido.ContentOps.OrchestratorServer
  )

{:ok, server_state} = Jido.AgentServer.state(AgentJido.ContentOps.OrchestratorServer)
is_map(server_state.agent.state)
```

Expected result:

```
true
```

This is the same runtime model used for larger adoption phases.

## Tradeoffs to acknowledge early

- Up-front modeling discipline is higher than in prototype-first tooling.
- Several ecosystem packages are still Beta or Experimental.
- Success depends on operational ownership, not just framework choice.

## Recommended next moves

- Build one pilot scope in [Quickstarts by persona](/build/quickstarts-by-persona).
- Review package choices in [Compare packages](/ecosystem#compare).
- **Agent model foundations:** [BEAM-native agent model](/features/beam-native-agent-model)
- Validate rollout criteria with [Production readiness checklist](/docs/operations/production-readiness-checklist).

## Get Building

If you can fund one bounded pilot with explicit success criteria, start at [getting started](/docs/getting-started) and track outcomes against the 30/60/90 plan above.
