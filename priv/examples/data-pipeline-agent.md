%{
  title: "Data Pipeline Agent",
  description: "A real Jido agent that collects records from multiple sources, validates them against their schemas, transforms the batch, loads it to a destination, and summarizes the run -- no LLM required.",
  tags: ["primary", "showcase", "production", "l2", "data", "pipeline", "etl"],
  category: :production,
  emoji: "🔗",
  related_resources: [
    %{
      path: "/docs/concepts/actions",
      kind: "Concept",
      description: "Understand the action contracts each pipeline stage runs."
    },
    %{
      path: "/docs/concepts/signals",
      kind: "Concept",
      description: "See how typed Signals route each stage of the pipeline."
    },
    %{
      path: "/docs/concepts/directives",
      kind: "Concept",
      description: "How side effects a scheduled pipeline would trigger return as Directives."
    }
  ],
  source_files: [
    "lib/agent_jido/demos/data_pipeline/data_pipeline_agent.ex",
    "lib/agent_jido/demos/data_pipeline/pipeline.ex",
    "lib/agent_jido/demos/data_pipeline/fixtures.ex",
    "lib/agent_jido/demos/data_pipeline/actions/ingest_source_action.ex",
    "lib/agent_jido/demos/data_pipeline/actions/validate_records_action.ex",
    "lib/agent_jido/demos/data_pipeline/actions/transform_records_action.ex",
    "lib/agent_jido/demos/data_pipeline/actions/load_records_action.ex",
    "lib/agent_jido/demos/data_pipeline/actions/summarize_action.ex",
    "lib/agent_jido_web/examples/data_pipeline_agent_live.ex"
  ],
  live_view_module: "AgentJidoWeb.Examples.DataPipelineAgentLive",
  difficulty: :intermediate,
  status: :live,
  scenario_cluster: :core_mechanics,
  wave: :l2,
  journey_stage: :operationalization,
  content_intent: :tutorial,
  capability_theme: :execution_tooling,
  evidence_surface: :runnable_example,
  demo_mode: :real,
  sort_order: 14,
  outcome: "A real Jido agent that collects records from multiple sources, validates them against their schemas, transforms the batch, loads it to a destination, and summarizes the run -- no LLM required.",
  packages: ["jido"],
  package_maturity: "Beta",
  prerequisites: ["Elixir 1.18+", "OTP 27+", "Jido installed"],
  expected_result: "Collect appends each source's records to the batch; Validate partitions them into valid and rejected by source schema; Transform normalizes and de-duplicates the valid batch; Load writes it and produces a stable checksum; Summarize rolls the run into one report.",
  run_command: "Run the interactive demo on /examples/data-pipeline-agent."
}
---

## What you'll learn

- How to shape a scheduled data pipeline on the Jido runtime: collect records from multiple sources, validate them, transform the batch, load it, and summarize the run.
- How to encode each stage as a typed, validated Action an agent runs through `cmd/2`.
- How to keep a pipeline demo fully deterministic -- real schema checks, transforms, and a stable destination checksum, with no LLM, no API key, and no live system to write to.

## How it runs

This example runs a real `AgentJido.Demos.DataPipeline` agent. Collect records
from one or more fixture sources (orders from the commerce service, users from
the identity service, and events from the analytics stream), then run the typed
actions in turn:

- `ValidateRecords` checks each collected record against its source's schema --
  an order needs a customer and a non-negative amount, a user needs a valid
  email, an event needs a user id -- and partitions the batch into valid records
  and rejected records, each with a reason.
- `TransformRecords` applies the real per-source transforms -- currency is
  uppercased and an amount derived for orders, emails and countries are
  canonicalized for users, events gain an analytics kind -- and de-duplicates by
  source and id so a repeated pull does not double-count.
- `LoadRecords` writes the transformed batch to a destination and produces a
  stable `phash2` checksum over a canonical projection of the batch, so two
  identical runs always agree.
- `Summarize` rolls the run up -- sources collected, records ingested, valid,
  rejected, transformed, and loaded -- into one human-readable report.

No LLM provider is called, and no real network write happens: the destination is
a deterministic in-process projection. The validation, transformation, loading,
and checksum are real logic over the record values, so you can run it without an
API key -- and swap a real source connector or destination sink in later using
the same agent shape. It is a safe, self-contained workflow: each stage resolves
its inputs lazily from the collected batch, so a step that runs out of order
still has what it needs.
