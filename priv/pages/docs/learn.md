%{
  title: "Learn",
  description: "Progressive hands-on tutorials from first workflow to multi-agent orchestration.",
  category: :docs,
  order: 25,
  tags: [:docs, :learn],
  draft: false
}
---

Hands-on tutorials that progressively build your understanding of Jido, from composing simple workflows to orchestrating multi-agent AI systems. Complete [Getting Started](/docs/getting-started) before diving in.

## Core training series

Learn the main Jido runtime model in a guided sequence.

- [Agent fundamentals on the BEAM](/docs/learn/agent-fundamentals) - separate agent state from process lifetime
- [Actions and schema validation](/docs/learn/actions-validation) - define safe action contracts
- [Signals, routing, and agent communication](/docs/learn/signals-routing) - connect agents with stable signals
- [Directives, scheduling, and time-based behavior](/docs/learn/directives-scheduling) - model side effects and recurring work
- [LiveView and Jido integration patterns](/docs/learn/liveview-integration) - connect user events to agent state
- [Production readiness](/docs/learn/production-readiness) - prepare supervision, telemetry, and recovery controls

## Jido core mastery

Build increasingly powerful agents using Jido's core primitives.

- [Build your first workflow](/docs/learn/first-workflow) - compose actions into a pipeline with shared state
- [Plugins and composable agents](/docs/learn/plugins-and-composable-agents) - add reusable capabilities to any agent
- [State machines with FSM](/docs/learn/state-machines-with-fsm) - model stateful workflows with guarded transitions
- [Parent-child agent hierarchies](/docs/learn/parent-child-agent-hierarchies) - spawn workers, route signals, aggregate results
- [Sensors and real-time events](/docs/learn/sensors-and-real-time-events) - connect external data sources to agents

## Jido AI mastery

Add LLM reasoning, tools, and multi-agent coordination.

- [Build an AI Chat Agent](/docs/learn/ai-chat-agent) - keep a multi-turn conversation on one agent process
- [Build a Hybrid Chat Agent](/docs/learn/hybrid-chat-agent) - mix quick replies and deeper reasoning turns in one chat thread
- [AI agent with tools](/docs/learn/ai-agent-with-tools) - build a ReAct agent that calls tools iteratively
- [Reasoning strategies compared](/docs/learn/reasoning-strategies-compared) - CoT, ToT, and Adaptive side-by-side
- [Task planning and execution](/docs/learn/task-planning-and-execution) - decompose goals into tasks and execute them
- [Memory and retrieval-augmented agents](/docs/learn/memory-and-retrieval-augmented-agents) - persistent context and RAG patterns
- [Multi-agent orchestration](/docs/learn/multi-agent-orchestration) - coordinate specialized AI sub-agents

## Next steps

- [Concepts](/docs/concepts) - understand the architecture behind what you built
- [Guides](/docs/guides) - task-focused recipes for specific problems
- [Ecosystem](/ecosystem) - explore the packages that extend Jido
