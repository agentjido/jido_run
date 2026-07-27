%{
  title: "Behavior-first architecture",
  description: "Why Jido is built around behavioral contracts instead of prompt loops, callback graphs, or implementation-specific agent classes.",
  category: :docs,
  legacy_paths: [],
  tags: [:docs, :reference, :architecture],
  order: 275,
  draft: false
}
---
Jido is built around behaviors, not implementations.

[Concepts](/docs/concepts) documents the primitives. This page explains why those primitives are shaped the way they are.

## Core claim

The main lesson Jido takes from Erlang and OTP is not "many lightweight processes" or "message passing everywhere." Those are mechanisms. The deeper contribution is behavioral abstraction: define a small set of stable contracts, implement concurrency and recovery once, and keep application code focused on domain logic.

OTP did this with behaviors such as `gen_server`, `supervisor`, and `application`. Application code does not reimplement process lifecycle, crash recovery, mailbox handling, or restart policy for each service. Those concerns live in reusable runtime components. Application code supplies callbacks and data.

Jido applies the same idea to agent systems.

Instead of defining an "agent" by a prompt loop, callback graph, or tool-calling wrapper, Jido defines a set of behavioral contracts:

- What unit of work means
- What message exchange means
- What state transition means
- What side effects mean
- What runtime execution means
- What external perception means

Implementations can vary underneath those contracts. The contracts are the architectural center.

## The Erlang spirit

Erlang is often reduced to actors and lightweight processes. That misses the part that matters most here.

Processes and message passing matter because they enable isolation and concurrency. OTP turned those mechanisms into an engineering discipline by standardizing behaviors. Teams stopped writing their own concurrency framework for each application. They wrote callback code against stable process patterns with clear ownership boundaries.

That is the part Jido carries forward:

- generic runtime machinery should be written once
- domain logic should stay narrow and explicit
- failure handling should be part of the architecture, not bolted on later
- application code should describe intent, not reimplement infrastructure

That is an architectural contribution, not only a mechanical one.

## The Elixir spirit

Elixir keeps the OTP model but makes it easier to express with data-oriented APIs, smaller modules, and direct composition. Macros such as `use` keep the surface area small without hiding the model.

Jido follows the same posture. The public shape of a primitive is usually small:

- `use Jido.Action`
- `use Jido.Agent`
- `use Jido.Signal`
- return directives instead of executing effects inline

Underneath those declarations sits the harder machinery: validation, execution, routing, supervision, scheduling, dispatch, and recovery. The developer-facing contract stays small. The runtime carries the operational weight.

## What behavior means here

In this page, "behavior" is broader than Erlang's `@behaviour` attribute.

Some Jido concepts are formal callback modules. Some are protocols, structs, macros, or runtime conventions. The common point is that each concept defines a stable contract for one responsibility. Other parts of the system depend on that contract, not on a specific implementation style.

Jido is behavior-first in the architectural sense. The system is organized around explicit semantic roles, not around one privileged implementation style.

## The core behavioral triad

Three concepts sit at the center of the model.

### Action - the work boundary

An [Action](/docs/concepts/actions) defines a validated unit of computation.

It defines:

- what inputs are allowed
- what result shape is produced
- what work is being done

The important point is that the Action contract exists independently of any process, transport, or model provider. An Action is a named capability with an inspectable boundary.

### Signal - the communication boundary

A [Signal](/docs/concepts/signals) defines how events and commands move through the system.

It defines:

- what happened
- where it came from
- how it should be classified

This matters because agent systems become hard to integrate once each boundary invents its own envelope. Jido uses one Signal format so Sensors, Agents, runtimes, and external integrations can speak the same language.

### Agent - the state-transition boundary

An [Agent](/docs/concepts/agents) defines how state evolves.

It defines:

- what state is held
- how commands are applied
- what side effects are requested

In Jido, the Agent itself is data. It is not the process, mailbox, or deployment artifact. That separation keeps the command boundary deterministic even when the runtime around it is concurrent and fault-tolerant.

## The surrounding layer

The rest of the core extends the same split.

| Concept | Contract |
| --- | --- |
| [Directive](/docs/concepts/directives) | Describes effects without executing them inline |
| [Agent runtime](/docs/concepts/agent-runtime) | Owns lifecycle, routing, supervision, and Directive execution |
| [Sensor](/docs/concepts/sensors) | Translates external events into Signals |
| [Strategy](/docs/concepts/strategy) | Defines execution policy without changing the Agent contract |
| [Plugin](/docs/concepts/plugins) | Packages reusable capability bundles for composition |
| [Execution](/docs/concepts/execution) | Runs validation, chaining, retry, and compensation consistently |
| [Thread](/docs/concepts/threads) | Records what happened in an append-only log |
| [Memory](/docs/concepts/memory) | Holds mutable working knowledge and intent |
| [Persistence](/docs/concepts/persistence) | Defines how agents survive restart and restore state |

This is not concept proliferation for its own sake. Each primitive has one job. That keeps the model small even when the runtime surface grows.

## Why Jido does not start from implementation

Many agent systems start from an execution model and let architecture accrete around it:

- an LLM loop with tools
- a callback graph
- a planner/executor pair
- a framework-specific agent class

Those approaches can be effective for prototypes. They optimize for getting the first system running quickly.

The tradeoff is that the first implementation vocabulary becomes the system vocabulary. State, effects, retries, scheduling, observability, and coordination end up expressed in whatever mechanics that implementation exposes. Over time, the codebase depends on incidental mechanics rather than stable contracts.

Jido inverts that order.

Execution style can change while the contracts stay stable. A Strategy might be:

- direct deterministic execution
- a behavior tree
- a state machine
- a multi-step planner
- an LLM reasoning loop

Those are implementation choices. They matter, but they are downstream choices. The Agent contract, Signal model, and Directive boundary stay in place regardless.

That is one of the main differences between Jido and many agent stacks. AI is an optional execution layer, not the definition of the system.

## Practical consequences

### Deterministic state transitions

When agent transitions are separate from runtime effects, you can test the core logic as a pure state transition. Replay and debugging are much easier than in systems where state changes and side effects live in the same callback or prompt loop.

### Explicit effect boundaries

Directives make effect intent visible. The code that decides what should happen is separate from the code that performs it. That reduces ambiguity around retries, partial failure, and recovery.

### Swappable execution policy

Because the system is not defined by one execution style, you can add or replace Strategies without rewriting the core domain model. That matters in agent systems, where planning and reasoning techniques change quickly.

### AI stays optional

Jido's core does not require an LLM. AI integration belongs in the optional `jido_ai` layer. That keeps the non-LLM case first-class and prevents "agent" from collapsing into "prompt wrapper."

### Clear runtime ownership

A behavior-first system is easier to supervise, inspect, and run. Responsibilities line up with runtime boundaries. You can answer:

- where state lives
- where effects are requested
- where effects execute
- where failures are isolated
- where messages enter and leave the system

That clarity matters in production.

## Why the separation matters in agent systems

Agent systems create pressure to collapse everything into one loop.

A single loop can hold the prompt, choose tools, call APIs, mutate state, retry failures, schedule follow-up work, emit events, and talk to users. That is convenient at first. It also makes the behavior hard to review and hard to operate.

Jido assumes agentic programming needs stronger boundaries, not weaker ones.

Once a system becomes long-running, multi-step, tool-using, stateful, or multi-agent, the cost of implicit architecture rises quickly. Behavioral contracts preserve a simple mental model while still supporting richer runtime behavior underneath.

## Tradeoffs

- Jido has more named concepts than a prompt-first demo framework.
- It asks developers to think in terms of contracts and runtime boundaries earlier.
- It fits best when workflow shape, recovery semantics, and operability matter.

Jido is not the shortest path to a tool-calling demo. It is designed to keep long-lived agent systems legible.

For smaller problems, a plain function, a plain `GenServer`, or a lighter orchestration layer may be the right choice. Behavior-first architecture is a deliberate tradeoff, not a claim that every problem needs the full model.

## Related pages

Use these pages next:

- [Concepts](/docs/concepts) explain what each primitive is
- [Why not just a GenServer?](/docs/reference/why-not-just-a-genserver) explains when Jido's separation pays off
- [BEAM-Native Agent Model](/features/beam-native-agent-model) explains the runtime stance for new evaluators
- [Jido vs framework-first stacks](/features/jido-vs-framework-first-stacks) explains the positioning tradeoff

## Background reading

For the deeper lineage behind this design, start with:

- Stevana's essay, [Erlang's not about lightweight processes and message passing](https://stevana.github.io/erlangs_not_about_lightweight_processes_and_message_passing.html)
- Joe Armstrong's thesis, [Making reliable distributed systems in the presence of software errors](https://kth.diva-portal.org/smash/record.jsf?pid=diva2:9492)

You do not need either one to use Jido. They are useful if you want the historical and architectural background for this design.

## Next steps

- Put the model into code — build [Your first agent](/docs/getting-started/first-agent).
- Extend it with [Actions](/docs/concepts/actions) and [Signals](/docs/concepts/signals).
- Run an AI agent next in [Your first LLM agent](/docs/getting-started/first-llm-agent).
