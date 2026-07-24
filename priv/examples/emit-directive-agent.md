%{
  title: "Emit Directive Agent",
  description: "Focused example showing how actions emit domain events while still updating agent state in one step.",
  tags: ["signals", "directives", "emit", "core-mechanics", "l1"],
  category: :core,
  emoji: "📣",
  related_resources: [
    %{
      path: "/docs/concepts/directives",
      kind: "Concept",
      description: "Review built-in directives and effect modeling."
    },
    %{
      path: "/docs/concepts/signals",
      kind: "Concept",
      description: "Understand signal structure and dispatch."
    },
    %{
      path: "/docs/learn/first-workflow",
      kind: "Next",
      description: "Combine emits into multi-step workflows.",
      include_livebook: true
    }
  ],
  source_files: [
    "lib/agent_jido/demos/emit_directive/emit_directive_agent.ex",
    "lib/agent_jido/demos/emit_directive/actions/create_order_action.ex",
    "lib/agent_jido/demos/emit_directive/actions/process_payment_action.ex",
    "lib/agent_jido/demos/emit_directive/actions/multi_emit_action.ex",
    "lib/agent_jido_web/examples/emit_directive_agent_live.ex"
  ],
  live_view_module: "AgentJidoWeb.Examples.EmitDirectiveAgentLive",
  difficulty: :beginner,
  status: :live,
  scenario_cluster: :core_mechanics,
  wave: :l1,
  journey_stage: :activation,
  content_intent: :tutorial,
  capability_theme: :runtime_foundations,
  evidence_surface: :runnable_example,
  demo_mode: :real,
  sort_order: 23,
  outcome: "An agent emits Directives that describe side effects for the runtime to execute.",
  packages: ["jido"],
  package_maturity: "Beta",
  prerequisites: ["Elixir 1.18+", "OTP 27+", "Jido installed"],
  expected_result: "Emitted Directives are visible and runtime-handled; no API key required.",
  run_command: "Run the interactive demo on /examples/emit-directive-agent, or: mix test test/agent_jido/demos/emit_directive_agent_test.exs"
}
---

## What you'll learn

- How `%Directive.Emit{}` publishes domain events.
- How state updates and emitted signals can happen in one action.
- How to inspect emitted signals from a real runtime.

## How it works

`create_order` updates `orders` state and emits `order.created`.
`process_payment` updates `last_payment` and emits `payment.processed`.
`multi_emit` demonstrates a list of emit directives in a single action.

## call behavior

The demo sends signals through `AgentServer.call/2`, then renders:

- Updated agent state
- Captured emitted signals
- A simple execution log
