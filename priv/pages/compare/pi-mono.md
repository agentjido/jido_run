%{
  title: "Jido vs Pi Mono",
  category: :compare,
  description: "Technical comparison between Jido and Pi Mono. Elixir/BEAM agents vs TypeScript agent runtime and coding-agent toolkit.",
  doc_type: :explanation,
  audience: :beginner,
  draft: false,
  order: 80,
  last_validated: "2026-03-02"
}
---
## Pi Mono

[Pi Mono](https://github.com/badlogic/pi-mono) is a TypeScript monorepo combining an agent runtime core, a coding-agent harness, a unified multi-provider model SDK, and model deployment tooling. With 14K+ GitHub stars, it offers a stateful loop-based agent runtime with event streaming, tree-structured session persistence with branching and compaction, a flexible extension system for tools and policies, and multiple integration modes (interactive CLI, RPC, SDK). Pi Mono targets developers who want a practical, customizable agent toolkit with strong developer workflow ergonomics.

## Jido

Jido is an Elixir framework that models each agent as a BEAM process with deterministic state transitions, explicit side effects, and OTP supervision. It separates pure business logic from LLM interactions, giving you reproducible testing and fault isolation at the runtime level. Jido targets teams building production agent systems that need to stay up, recover from failures, and scale predictably.

## Side-by-side comparison

| Dimension | Jido | Pi Mono |
|---|---|---|
| **Language and runtime** | Elixir on the BEAM VM with preemptive scheduling, lightweight processes, and built-in distribution | TypeScript on Node.js with a monorepo architecture spanning runtime, model, and deployment packages |
| **Agent model** | Each agent is a supervised OTP process with explicit state schema and deterministic transitions | Loop-based agent runtime with event lifecycle, steering queues, and context transformation pipelines |
| **Tool calling** | Actions as composable, typed Elixir modules with schema validation; MCP client support | Built-in coding tools plus custom tool registration with TypeBox schemas; extension-driven policy gates |
| **Multi-agent coordination** | OTP-native process communication via GenServer calls, PubSub, and dynamic supervision trees | Sub-agent patterns via extensions; isolated subprocess agents for delegation |
| **Failure handling** | OTP supervisors restart failed agents automatically; process isolation prevents cascading failures | Session resume/fork flows; abort controls and queue-based intervention; application-level error handling |
| **Observability** | BEAM introspection (process info, message queues), Telemetry events, LiveDashboard integration | Event stream model for runtime introspection; token and cost tracking; session tree navigation for debugging |
| **LLM provider support** | Provider-agnostic through `jido_ai`, supporting OpenAI, Anthropic, Google, and others via unified interface | `pi-ai` SDK with broad provider coverage (OpenAI, Anthropic, Google, Bedrock, OpenRouter) and unified streaming |

## When to choose Pi Mono

Pi Mono is a strong choice when you want a practical, extensible agent toolkit with excellent developer workflow features. Specific scenarios where Pi Mono fits well:

- **Coding-agent use cases** where the built-in coding tools, session branching, and context compaction provide a production-ready interactive agent experience.
- **TypeScript teams** that want an agent runtime, model SDK, and deployment tooling in one monorepo without managing separate dependencies.
- **Extension-driven customization** where custom tools, policy gates, UI components, and resource loaders let you shape agent behavior without forking the core.
- **Multiple integration modes** where you need the same agent accessible via interactive CLI, RPC server, SDK embedding, or JSON output depending on the deployment context.

## When to choose Jido

Jido is a strong choice when you need orchestration and fault tolerance built into the runtime. Specific scenarios where Jido fits well:

- **Elixir/Erlang teams** that want agents built on the same concurrency and fault-tolerance model they use for the rest of their system.
- **Multi-agent orchestration** where OTP's process model, supervision trees, and PubSub provide native coordination primitives rather than extension-based sub-agent patterns.
- **Deterministic testing needs** where separating pure state logic from side effects lets you unit test agent decisions without running the full agent loop.
- **Always-on agent systems** where OTP supervisors provide automatic restart and health monitoring, letting agents self-heal without manual session resume or fork workflows.

## Get started

Ready to try Jido? Follow the [getting started guide](/docs/getting-started) to build your first agent in under ten minutes.
