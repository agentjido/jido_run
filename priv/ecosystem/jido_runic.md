%{
  name: "jido_runic",
  title: "Jido Runic",
  graph_label: "Jido Runic",
  version: "0.1.0",
  tagline: "Workflow composition and execution substrate for DAG-based agent orchestration",
  license: "Apache-2.0",
  visibility: :public,
  category: :tools,
  atlas_facet: :workflow,
  tier: 2,
  tags: [:workflow, :dag, :pipeline, :orchestration, :durable],
  hex_url: "https://hex.pm/packages/jido_runic",
  hexdocs_url: "https://hexdocs.pm/jido_runic",
  github_url: "https://github.com/agentjido/jido_runic",
  github_org: "agentjido",
  github_repo: "jido_runic",
  tech_lead: "@mikehostetler",
  maturity: :stable,
  support_level: :stable,
  hex_status: "unreleased",
  api_stability: "unstable — expect breaking changes",
  stub: false,
  support: :best_effort,
  limitations: [
    "Not published to Hex — available only via GitHub dependency",
    "Branch-pinned `runic` and `libgraph` dependencies increase release reproducibility risk",
    "Focuses on workflow execution substrate rather than provider/runtime provisioning concerns"
  ],
  ecosystem_deps: ["jido_ai"],
  key_features: [
    "Action-as-Node composition — wrap any Jido Action as a Runic DAG node",
    "Stable content-addressed identity surviving recompiles",
    "Signal-to-Fact bidirectional mapping preserving causality across both systems",
    "Signal-gated workflow branches for conditional pipelines",
    "Strategy-driven agent workflows — plug a DAG into any Jido Agent",
    "Automatic parallel dispatch of independent runnables via directives",
    "Full provenance tracking through fact ancestry chains",
    "Execution summaries with node count, facts, and satisfaction status",
    "Durable workflow state maintained across signal processing cycles",
    "Eager planning identifying all ready runnables after each fact production"
  ],
  landing_summary: "Workflow composition and execution substrate for DAG-based agent orchestration",
  landing_use_when: ["You want ready-made tool Actions for an agent."],
  landing_not_for: ["You need tools this package does not provide."]
}
---
## Overview

Jido Runic bridges Runic's DAG-based workflow engine with Jido's signal-driven agent framework, enabling durable, dataflow-driven agent workflows. Instead of imperative step-by-step orchestration, developers compose directed acyclic graphs (DAGs) of Jido Actions that execute according to dependency order — with full provenance tracking, signal gating, and automatic parallel dispatch.

The package solves a critical gap in agent design: how to express complex, multi-step pipelines (research, ETL, content generation, etc.) as composable, inspectable graphs that integrate natively with Jido's signal routing, lifecycle hooks, and telemetry.

## Purpose

Jido Runic is the workflow composition and execution substrate for durable DAG-based orchestration.

## Boundary Lines

- Owns DAG workflow composition, scheduling, and provenance-aware execution semantics.
- Serves as orchestration substrate consumed by higher-level workflow packages.
- Does not own CLI provider adapters, runtime preflight/bootstrap policy, or session provisioning.

## Major Components

### ActionNode
Core adapter wrapping any Jido Action module as a Runic workflow node. Preserves stable content-addressed identity, introspects NimbleOptions schemas for input/output specs, and delegates execution to `Jido.Exec.run/4`.

### SignalFact
Bidirectional adapter between Jido Signals and Runic Facts, converting causality tracking into fact ancestry chains and vice versa for continuous provenance.

### SignalMatch
Runic match node gating downstream DAG execution based on Jido signal type prefix patterns for conditional workflow branches.

### Strategy
Full `Jido.Agent.Strategy` implementation powered by a Runic DAG. Converts incoming signals to facts, emits runnables as directives, and automatically advances the workflow until satisfied.

### Introspection
Provenance queries and execution summaries for walking fact ancestry chains and generating workflow state statistics.
