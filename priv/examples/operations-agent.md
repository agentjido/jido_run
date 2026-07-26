%{
  title: "Operations Remediation Agent",
  description: "A real Jido agent that watches a system metric, diagnoses the dominant issue, applies a remediation playbook entry, and verifies recovery -- no LLM required.",
  tags: ["primary", "showcase", "production", "l2", "operations", "ops-governance", "observability", "reliability"],
  category: :production,
  emoji: "🛠",
  related_resources: [
    %{
      path: "/docs/concepts/actions",
      kind: "Concept",
      description: "Understand the action contracts this agent runs."
    },
    %{
      path: "/docs/concepts/signals",
      kind: "Concept",
      description: "See how typed Signals route each step of the workflow."
    },
    %{
      path: "/docs/reference/telemetry-and-observability",
      kind: "Reference",
      description: "How Jido surfaces the metrics an operations agent would watch."
    }
  ],
  source_files: [
    "lib/agent_jido/demos/ops_remediation/ops_remediation_agent.ex",
    "lib/agent_jido/demos/ops_remediation/diagnostics.ex",
    "lib/agent_jido/demos/ops_remediation/fixtures.ex",
    "lib/agent_jido/demos/ops_remediation/actions/ingest_metric_action.ex",
    "lib/agent_jido/demos/ops_remediation/actions/detect_anomaly_action.ex",
    "lib/agent_jido/demos/ops_remediation/actions/diagnose_action.ex",
    "lib/agent_jido/demos/ops_remediation/actions/apply_remediation_action.ex",
    "lib/agent_jido/demos/ops_remediation/actions/verify_recovery_action.ex",
    "lib/agent_jido_web/examples/ops_remediation_agent_live.ex"
  ],
  live_view_module: "AgentJidoWeb.Examples.OpsRemediationAgentLive",
  difficulty: :intermediate,
  status: :live,
  scenario_cluster: :ops_governance,
  wave: :l2,
  journey_stage: :operationalization,
  content_intent: :tutorial,
  capability_theme: :operations_observability,
  evidence_surface: :runnable_example,
  demo_mode: :real,
  sort_order: 13,
  outcome: "A real Jido agent that watches a system metric, diagnoses the dominant issue, applies a remediation playbook entry, and verifies recovery -- no LLM required.",
  packages: ["jido"],
  package_maturity: "Beta",
  prerequisites: ["Elixir 1.18+", "OTP 27+", "Jido installed"],
  expected_result: "Detect flags a breached threshold as degraded; Diagnose picks the dominant issue (high-latency, error-rate-spike, or cpu-saturation); ApplyRemediation selects the matching playbook entry; VerifyRecovery confirms the system is back within thresholds.",
  run_command: "Run the interactive demo on /examples/operations-agent."
}
---

## What you'll learn

- How to shape an operations workflow on the Jido runtime: ingest a metric, detect an anomaly, diagnose the dominant issue, apply a remediation, and verify recovery.
- How to encode each step as a typed, validated Action an agent runs through `cmd/2`.
- How to keep an operations demo fully deterministic -- real threshold and playbook logic, no LLM, no API key, and no live system to break.

## How it runs

This example runs a real `AgentJido.Demos.OpsRemediation` agent. Load one of the
fixture system snapshots (a healthy baseline, a latency spike, an error spike, or
CPU saturation), then run the four typed actions in turn:

- `DetectAnomaly` checks the snapshot against three real SLO thresholds -- a p95
  latency ceiling, an error-rate ceiling, and a CPU saturation ceiling -- and
  rolls the result up to a single `healthy` or `degraded` status.
- `Diagnose` lists the breached thresholds and picks the single dominant issue
  in a fixed severity order (errors, then saturation, then latency); a clean
  snapshot diagnoses as `none` instead of always finding a fault.
- `ApplyRemediation` selects the playbook entry for the diagnosis for real -- a
  high-latency issue scales out, an error-rate spike rolls back, CPU saturation
  scales up, and a clean snapshot holds steady.
- `VerifyRecovery` projects the deterministic post-remediation metric a
  successful run produces and confirms the system is back within thresholds.

No LLM provider is called. The detection, diagnosis, remediation, and
verification are deterministic threshold and playbook logic on the metric
numbers, so you can run it without an API key -- and swap a real observer or
remediation backend in later using the same agent shape. It is a safe,
self-contained workflow: nothing is crashed and no external system is touched.
