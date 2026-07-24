%{
  name: "jido_evolve",
  title: "Jido Evolve",
  graph_label: "Jido Evolve",
  version: "0.1.0",
  tagline: "Evolutionary optimization toolkit for Elixir with pluggable fitness pipelines",
  license: "Apache-2.0",
  visibility: :public,
  category: :ai,
  atlas_facet: :optimization,
  tier: 2,
  tags: [:evolution, :optimization, :search, :algorithms],
  github_url: "https://github.com/agentjido/jido_evolve",
  github_org: "agentjido",
  github_repo: "jido_evolve",
  tech_lead: "@mikehostetler",
  elixir: "~> 1.18",
  maturity: :beta,
  support_level: :beta,
  hex_status: "unreleased",
  api_stability: "unstable - APIs may change rapidly",
  stub: false,
  support: :best_effort,
  limitations: [
    "Not published to Hex - available via GitHub dependency",
    "Early-stage API with limited production hardening",
    "Benchmark and tuning presets are still evolving"
  ],
  ecosystem_deps: [],
  key_features: [
    "Pluggable evolutionary loops for arbitrary Elixir data structures",
    "Configurable mutation, crossover, and generation controls",
    "Fitness behavior abstraction for domain-specific scoring",
    "Example pipelines including knapsack and traveling-salesman style demos",
    "Telemetry-friendly architecture for tracking optimization runs"
  ],
  landing_summary: "Evolutionary optimization toolkit for Elixir with pluggable fitness pipelines",
  landing_use_when: ["You want to add LLM reasoning or tool-calling to an agent."],
  landing_not_for: ["Your agent has no LLM component (core Jido needs no LLM).", "Beta — verify against your Jido version before production use."]
}
---
## Overview

Jido Evolve provides evolutionary algorithm primitives for exploring search spaces where closed-form optimization is impractical.

## Purpose

Jido Evolve gives the ecosystem an optimization layer that can be combined with agent planning and evaluation workflows.

## Major Components

### Evolution Engine

Coordinates populations, selection, mutation, crossover, and generation transitions.

### Fitness Behaviors

Lets applications define custom evaluation functions for domain-specific goals.

### Config and Examples

Provides reusable configuration patterns and runnable demos for common optimization tasks.
