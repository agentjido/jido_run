%{
  name: "jido_workflow",
  title: "Jido Workflow",
  graph_label: "Jido Workflow",
  version: "0.1.0",
  tagline: "Deprecated workflow runtime retained for historical reference",
  license: "Apache-2.0",
  visibility: :private,
  category: :runtime,
  tier: 2,
  tags: [:workflow, :dag, :cli, :orchestration, :signals],
  github_url: "https://github.com/agentjido/jido_workflow",
  github_org: "agentjido",
  github_repo: "jido_workflow",
  elixir: "~> 1.17",
  maturity: :experimental,
  support_level: :experimental,
  hex_status: "unreleased",
  api_stability: "unstable - workflow run controls and CLI contract are pre-1.0",
  stub: false,
  support: :best_effort,
  limitations: [
    "Deprecated and removed from the public ecosystem atlas",
    "Not published to Hex - available via GitHub dependency",
    "CLI and task contract behavior is still evolving",
    "Current source metadata in upstream mix config may point to a non-org URL"
  ],
  ecosystem_deps: ["jido", "jido_runic"],
  key_features: [
    "Workflow runtime for DAG-style code execution flows",
    "Escript CLI for workflow run/control/watch/signal command surfaces",
    "Reserved run option handling with typed input coercion",
    "Mix task integration for workflow operations from development environments",
    "Run lifecycle control APIs for pause/resume/list style operations"
  ],
  landing_summary: "Deprecated workflow runtime retained for historical reference",
  landing_use_when: ["You need runtime infrastructure (persistence, scheduling, or observability) for a deployed agent."],
  landing_not_for: ["You are still prototyping and do not yet run agents long-term.", "Not production-ready; APIs may change."]
}
---
## Overview

Jido Workflow provides a DAG-oriented workflow runtime and CLI for running structured code workflows in Jido environments. It combines run control, signaling, and command surfaces in a single executable runtime.

## Purpose

Jido Workflow is the workflow orchestration package for teams executing repeatable multi-step code workflows through Jido runtime primitives.

## Boundary Lines

- Owns workflow run orchestration, lifecycle control commands, and workflow-specific CLI entry points.
- Integrates with core Jido primitives and Runic-backed execution patterns.
- Does not own provider adapter contracts, memory governance policy, or transport/channel integrations.

## Major Components

### Workflow Runtime

Executes DAG-like workflow runs with typed input handling and reserved runtime options.

### CLI Surface

Provides a `workflow` executable for start/control/watch/signal operations and command-forwarding behavior.

### Control and Observability

Includes run lifecycle controls (list/pause/etc.) and watch surfaces for operational visibility.

### Mix Task Integration

Supports equivalent workflow operations through mix tasks for local development automation.
