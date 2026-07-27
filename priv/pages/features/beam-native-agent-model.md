%{
  title: "BEAM-native agent model",
  category: :features,
  description: "Why Jido models each Agent as an OTP process with deterministic state transitions and explicit side effects.",
  doc_type: :explanation,
  audience: :beginner,
  draft: false,
  order: 5
}
---
Jido's agent model is not a wrapper around prompt chains. Each Agent is a BEAM process with deterministic state logic, explicit effect boundaries, and OTP lifecycle semantics. This is the architectural foundation that makes everything else possible: coordination, observability, fault isolation.

## At a glance

| Item | Summary |
|---|---|
| Best for | Elixir engineers, architects evaluating runtime foundations, teams comparing agent abstractions |
| Core packages | [jido](/ecosystem/jido), [jido_action](/ecosystem/jido_action) |
| Package status | `jido` (Beta), `jido_action` (Beta) |
| First proof path | [Counter Agent](/examples/counter-agent) → [Agent fundamentals training](/training/agent-fundamentals) |
| Adoption stance | Understand the model first, then build one supervised workflow |

## Why the agent abstraction matters

Most agent frameworks define "agent" loosely: a prompt template, a function chain, or a class that calls an LLM. That flexibility is useful for prototypes, but it creates problems at scale:

- **No isolation boundary.** A failure in one agent's logic can crash shared state or block other agents.
- **No deterministic core.** When business logic and side effects are mixed, you cannot test decisions without running the full environment.
- **No lifecycle contract.** Restart, shutdown, and health-check behavior is ad-hoc and varies per implementation.

Jido defines "agent" as a specific runtime contract.

## The contract: Agent + cmd/2 + Directives

Every Jido Agent follows a three-part model:

| Concept | Role | What it enforces |
|---|---|---|
| **Agent struct** | Holds current state | Immutable between transitions; inspectable at any point |
| **`cmd/2`** | Applies an Action to produce new state + Directives | Deterministic: same input always produces same output |
| **Directives** | Describe side effects to execute | Effects are declared, not performed inline. The runtime decides when and how to execute. |

This separation means you can test Agent decision logic without processes, supervision, or network calls. The runtime (`Jido.AgentServer`) handles lifecycle concerns separately.

## Schema-validated Actions

Actions are the capabilities an Agent can perform. Each Action declares its input and output schemas up front:

- Invalid inputs fail before execution, not during.
- Action contracts are inspectable and testable without running a full agent.
- Teams can review what an Agent can do by reading its registered Actions.

This is the same mechanism that powers typed coordination contracts in [multi-agent workflows](/features/multi-agent-coordination).

## Directives: explicit side effects

When `cmd/2` runs, it returns the updated Agent state **and** a list of Directives: structured instructions for the runtime.

- `%Directive.Emit{}`: publish a Signal to other agents or external systems.
- `%Directive.EnqueueAction{}`: schedule follow-up work.
- Custom directives for domain-specific effects.

Side effects never run inside `cmd/2`. This makes Agent logic replayable, testable, and safe to supervise. If the process crashes after `cmd/2` but before directive execution, the Agent state is still consistent.

## Proof: deterministic transitions without a running process

```elixir
alias AgentJido.Demos.CounterAgent

agent = CounterAgent.new()
{updated_agent, directives} = CounterAgent.cmd(agent, CounterAgent.IncrementAction, %{amount: 5})

{updated_agent.state.count, length(directives)}
```

Expected result:

```
{5, 0}
```

No process, no supervision tree, no LLM. Just a pure state transition you can assert against in a test.

## How this model enables everything else

| Downstream capability | Why it depends on the agent model |
|---|---|
| [Agents that self-heal](/features/agents-that-self-heal) | Deterministic `cmd/2` means crashes don't corrupt state. OTP supervision restarts the process, not the logic. |
| [Agents that work together](/features/multi-agent-coordination) | Typed Actions and Signals create inspectable contracts between agents. |
| [Observe everything](/features/observe-everything) | Process-level boundaries give telemetry clear instrumentation points. |
| [Start small, grow safely](/features/start-small) | One Agent in one supervision tree is the smallest useful deployment unit. |

## Tradeoffs and non-goals

- More explicit structure up front than "define a function and call it an agent."
- The model optimizes for production legibility, not minimal demo code.
- `jido` is currently **Beta**. Expect API refinement as patterns stabilize.

## What to explore next

- **Runtime reliability:** [Agents that self-heal](/features/agents-that-self-heal)
- **Coordination contracts:** [Multi-agent coordination](/features/multi-agent-coordination)
- **Hands-on training:** [Agent fundamentals](/training/agent-fundamentals)
- **Reference docs:** [Architecture](/docs/reference/behavior-first-architecture), [Key concepts](/docs/concepts)

## Get Building

Start with [Counter Agent](/examples/counter-agent) to see the model in action, then read [Agent fundamentals](/training/agent-fundamentals) to build your own.
