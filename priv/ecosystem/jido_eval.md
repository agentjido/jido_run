%{
  name: "jido_eval",
  title: "Jido Eval",
  graph_label: "Jido Eval",
  version: "0.1.0",
  tagline: "Evaluation framework for LLM and Jido agent quality measurement",
  license: "Apache-2.0",
  visibility: :public,
  category: :ai,
  atlas_facet: :evaluation,
  tier: 2,
  tags: [:evaluation, :llm, :benchmarking, :quality],
  github_url: "https://github.com/agentjido/jido_eval",
  github_org: "agentjido",
  github_repo: "jido_eval",
  tech_lead: "@mikehostetler",
  elixir: "~> 1.18",
  maturity: :experimental,
  support_level: :experimental,
  hex_status: "unreleased",
  api_stability: "very early-stage and likely to change",
  stub: false,
  support: :best_effort,
  limitations: [
    "Not published to Hex - available via GitHub dependency",
    "README and docs are still minimal",
    "Evaluation workflows and score models are under active design"
  ],
  ecosystem_deps: ["jido_ai"],
  key_features: [
    "Framework foundation for evaluating LLM/agent behavior",
    "Structured project layout for datasets, scoring, and pipelines",
    "Typed schemas and CSV utilities for experiment inputs/outputs",
    "Quality automation aliases for repeatable evaluation workflows",
    "Designed to integrate tightly with Jido AI pipelines"
  ],
  landing_summary: "Evaluation framework for LLM and Jido agent quality measurement",
  landing_use_when: ["You want to add LLM reasoning or tool-calling to an agent."],
  landing_not_for: ["Your agent has no LLM component (core Jido needs no LLM).", "Not production-ready; APIs may change."]
}
---
## Overview

Jido Eval is an experimental framework focused on measuring and improving LLM and agent performance in Jido-based systems.

## Purpose

Jido Eval provides an ecosystem home for evaluation datasets, scoring methods, and repeatable quality checks.

## Major Components

### Evaluation Core

Defines project primitives for assembling benchmark runs and collecting outputs.

### Data Utilities

Uses typed structs and CSV tooling for controlled experiment datasets.

### Quality Tooling

Ships project aliases oriented around formatting, static analysis, and docs-driven iteration.
