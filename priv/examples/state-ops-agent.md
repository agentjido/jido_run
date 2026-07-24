%{
  title: "State Ops Agent",
  description: "Focused example for SetState, ReplaceState, DeleteKeys, SetPath, and DeletePath via pure cmd execution.",
  tags: ["state", "stateops", "actions", "core-mechanics", "l1"],
  category: :core,
  emoji: "🧱",
  related_resources: [
    %{
      path: "/docs/concepts/agents",
      kind: "Concept",
      description: "Review agent state model and immutability."
    },
    %{
      path: "/docs/concepts/actions",
      kind: "Concept",
      description: "Understand action contracts and result handling."
    },
    %{
      path: "/docs/learn/first-workflow",
      kind: "Next",
      description: "Compose multiple state mutations into workflows.",
      include_livebook: true
    }
  ],
  source_files: [
    "lib/agent_jido/demos/state_ops/state_ops_agent.ex",
    "lib/agent_jido/demos/state_ops/actions/merge_metadata_action.ex",
    "lib/agent_jido/demos/state_ops/actions/replace_all_action.ex",
    "lib/agent_jido/demos/state_ops/actions/set_nested_value_action.ex",
    "lib/agent_jido_web/examples/state_ops_agent_live.ex"
  ],
  live_view_module: "AgentJidoWeb.Examples.StateOpsAgentLive",
  difficulty: :beginner,
  status: :live,
  scenario_cluster: :core_mechanics,
  wave: :l1,
  journey_stage: :activation,
  content_intent: :tutorial,
  capability_theme: :runtime_foundations,
  evidence_surface: :runnable_example,
  demo_mode: :real,
  sort_order: 24,
  outcome: "An agent that changes state through validated Actions and inspects the result.",
  packages: ["jido"],
  package_maturity: "Beta",
  prerequisites: ["Elixir 1.18+", "OTP 27+", "Jido installed"],
  expected_result: "State transitions are deterministic and inspectable; no API key required.",
  run_command: "Run the interactive demo on /examples/state-ops-agent, or: mix test test/agent_jido/demos/state_ops_agent_test.exs"
}
---

## What you'll learn

- When to use SetState vs ReplaceState.
- How to remove keys and nested paths safely.
- How state operations stay pure under `cmd/2`.

## How it works

Each button executes one action that returns a specific `StateOp`.
The demo immediately renders the resulting state and logs each mutation.

## Focus

This example intentionally stays local and deterministic:

- No network
- No external services
- No background runtime required
