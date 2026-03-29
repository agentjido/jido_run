%{
  priority: :high,
  status: :published,
  title: "Counter Agent Example",
  repos: ["agentjido/jido:jido", "agentjido/jido_action:jido_action"],
  tags: [:docs, :learn, :build, :example, :agents],
  audience: :beginner,
  content_type: :tutorial,
  destination_collection: :pages,
  destination_route: "/docs/learn/counter-agent",
  legacy_paths: ["/build/counter-agent"],
  ecosystem_packages: ["jido", "jido_action", "kino"],
  learning_outcomes: [
    "Build a complete counter agent with increment, decrement, and reset",
    "Observe deterministic state transitions through sequential commands",
    "Test agent behavior with ExUnit assertions on state output"
  ],
  order: 40,
  prerequisites: ["docs/learn/first-agent"],
  purpose: "Provide a minimal but complete agent example that reinforces the cmd/2 command model and state transition patterns",
  related: [
    "docs/learn/first-agent",
    "docs/learn/demand-tracker-agent",
    "docs/concepts/agents",
    "docs/concepts/actions"
  ],
  source_files: ["lib/jido/agent.ex", "lib/jido_action.ex"],
  source_modules: ["Jido.Agent", "Jido.Action"],
  prompt_overrides: %{
    document_intent: "Write a minimal but complete counter agent tutorial that perfectly illustrates the `cmd/2` command model and deterministic state transitions.",
    required_sections: [
      "Agent Definition",
      "Defining Actions",
      "Running Commands",
      "Testing State Transitions",
      "What to Try Next"
    ],
    must_include: [
      "Full agent module with a typed state containing a `count` field.",
      "Three distinct actions: Increment, Decrement, and Reset with schema validation.",
      "Sequential cmd/2 calls showing state progression.",
      "An ExUnit test block that proves deterministic state transitions.",
      "Assign the final compiled agent module to the variable `DemoAgent` at the end of the script for the visualizer."
    ],
    must_avoid: [
      "Do NOT include LLM integration.",
      "Do NOT introduce Signals or routing; keep it strictly single-agent.",
      "Do NOT wrap the output in ```markdown fences.",
      "Do NOT include production concerns."
    ],
    required_links: [
      "/docs/learn/first-agent",
      "/docs/learn/demand-tracker-agent",
      "/docs/concepts/agents",
      "/docs/concepts/actions"
    ],
    min_words: 500,
    max_words: 1_000,
    minimum_code_blocks: 4,
    diagram_policy: "none",
    section_density: "light_technical",
    max_paragraph_sentences: 3
  }
}
---
## Content Brief

This guide should serve as the "Hello World" of Agent state management in Jido. Keep the prose incredibly concise and let the Elixir code do the talking.

Cover:
- Agent definition with typed count state
- Increment, decrement, reset actions with schema validation
- Sequential command execution and state inspection via `cmd/2` on the child module
- ExUnit test for deterministic state transitions

Start by explaining the schema definition of the Agent. Then define the three Actions. Then show how to stitch them together and invoke them sequentially using `YourModule.cmd/2`. Conclude by writing a fully functional `ExUnit` test that asserts the count goes up, down, and resets exactly as expected.

### Validation Criteria

- Code compiles against current Jido.Agent and Jido.Action APIs
- State transitions are deterministic and testable
- Example is self-contained -- copy-paste-run in a fresh project
- Links to demand-tracker as the next example with more complexity
