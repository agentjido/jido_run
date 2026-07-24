%{
  description: "Task-oriented implementation guides for building and operating Jido agent systems.",
  title: "Guides",
  category: :docs,
  legacy_paths: ["/docs/getting-started/guides"],
  tags: [:docs, :guides],
  order: 30
}
---

You know what you want to build - these guides show you how. Unlike [Learn tutorials](/docs/learn) that teach progressively or [Concepts](/docs/concepts) that explain primitives, guides are task-oriented. Pick the one that matches your problem and go.

## Before you start

Guides assume you have completed [Your first agent](/docs/getting-started/first-agent): Elixir 1.18+/OTP 27+, Jido installed, and a deterministic agent running. AI guides additionally need a provider key ([Your first LLM agent](/docs/getting-started/first-llm-agent)).

## Guides

- [Testing agents and actions](/docs/guides/testing-agents-and-actions) - unit and integration test patterns for agents, actions, and workflows
- [Debugging and troubleshooting](/docs/guides/debugging-and-troubleshooting) - diagnosing issues with debug modes, event buffers, and structured diagnostics
- [Error handling and recovery](/docs/guides/error-handling-and-recovery) - configure error policies, handle failures, and recover gracefully
- [Persistence and checkpoints](/docs/guides/persistence-and-checkpoints) - save and restore agent state with ETS, file, and hibernate/thaw
- [Building a weather agent](/docs/guides/building-a-weather-agent) - end-to-end tool-calling agent with external API integration

## Next steps

- [Concepts](/docs/concepts) - understand the primitives behind these patterns
- [Operations](/docs/operations) - deploy, monitor, and scale your agent systems
