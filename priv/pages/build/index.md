%{
  title: "Build with Jido",
  category: :build,
  description: "Quickstarts, reference architectures, and integration guides for building with Jido.",
  doc_type: :guide,
  audience: :beginner,
  draft: false,
  order: 1
}
---
Build is where you convert Jido concepts into workflows that can ship.
Use this section when you already understand the runtime model and need a concrete implementation path.

## What you can do from here

- Pick a starting path by role in [Quickstarts by Persona](/build/quickstarts-by-persona).
- Choose a topology before coding in [Reference Architectures](/build/reference-architectures).
- Validate design and operations assumptions with [Architecture](/docs/reference/behavior-first-architecture) and [Error handling and recovery](/docs/guides/error-handling-and-recovery).

## Build guides at a glance

| Guide | Use it when | Outcome |
| --- | --- | --- |
| [Quickstarts by Persona](/build/quickstarts-by-persona) | You need a first milestone matched to your role | A bounded first deliverable in one focused session |
| [Reference Architectures](/build/reference-architectures) | You need to choose process boundaries and package layout | A blueprint with clear runtime and ownership boundaries |

## Proof surface in this repository

The workbench runs a supervised agent runtime in `AgentJido.Application`.
This is the same execution model referenced throughout the build guides.

```elixir
children = [
  AgentJido.Jido,
  {Jido.AgentServer,
   id: AgentJido.ContentOps.OrchestratorServer,
   agent: AgentJido.ContentOps.OrchestratorAgent,
   jido: AgentJido.Jido,
   name: AgentJido.ContentOps.OrchestratorServer}
]

Supervisor.start_link(children, strategy: :one_for_one)
```

Expected result:

```
{:ok, #PID<...>}
```

## Recommended flow

1. Start with your persona route and complete one small implementation proof.
2. Select an architecture pattern and document why it matches your constraints.
3. Run through training and checklist validation before broad rollout.

## Get Building

Start with [Quickstarts by Persona](/build/quickstarts-by-persona), then move to [Reference Architectures](/build/reference-architectures) when you need to harden topology decisions.
