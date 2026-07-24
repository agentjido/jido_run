%{
  title: "Persistence Storage Agent",
  description: "Focused round-trip example for Persist.hibernate/2 and Persist.thaw/3 using ETS-backed checkpoints.",
  tags: ["persistence", "storage", "operations", "ops-governance", "l1"],
  category: :production,
  emoji: "💾",
  related_resources: [
    %{
      path: "/docs/concepts/persistence",
      kind: "Concept",
      description: "Understand checkpoint/restore semantics."
    },
    %{
      path: "/docs/guides/persistence-and-checkpoints",
      kind: "Guide",
      description: "Walk through persistence setup and patterns.",
      include_livebook: true
    },
    %{
      path: "/docs/operations/production-readiness-checklist",
      kind: "Operations",
      description: "Operational considerations for durable agents."
    }
  ],
  source_files: [
    "lib/agent_jido/demos/persistence_storage/persistence_storage_agent.ex",
    "lib/agent_jido/demos/persistence_storage/actions/increment_action.ex",
    "lib/agent_jido/demos/persistence_storage/actions/add_note_action.ex",
    "lib/agent_jido_web/examples/persistence_storage_agent_live.ex"
  ],
  live_view_module: "AgentJidoWeb.Examples.PersistenceStorageAgentLive",
  difficulty: :beginner,
  status: :live,
  scenario_cluster: :ops_governance,
  wave: :l1,
  journey_stage: :operationalization,
  content_intent: :tutorial,
  capability_theme: :operations_observability,
  evidence_surface: :runnable_example,
  demo_mode: :real,
  sort_order: 26,
  outcome: "An agent whose state survives a restart via hibernate/thaw persistence.",
  packages: ["jido"],
  package_maturity: "Beta",
  prerequisites: ["Elixir 1.18+", "OTP 27+", "Jido installed", "a persistence store"],
  expected_result: "State is restored from the store after a restart; no API key required.",
  run_command: "Run the interactive demo on /examples/persistence-storage-agent, or: mix test test/agent_jido/demos/persistence_storage_agent_test.exs"
}
---

## What you'll learn

- How to save agent state snapshots with `Persist.hibernate/2`.
- How to restore a full agent struct with `Persist.thaw/3`.
- How to validate a simple round-trip in a deterministic demo.

## How it works

The demo keeps one agent id and one ETS-backed storage table.

1. Mutate state via `cmd/2` actions.
2. Hibernate to checkpoint storage.
3. Thaw into a new in-memory agent struct.

This keeps persistence behavior explicit without external services.
