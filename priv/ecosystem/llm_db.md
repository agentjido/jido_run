%{
  name: "llm_db",
  title: "LLMDB",
  version: "2026.5.0",
  tagline: "Fast, zero-network LLM model metadata catalog for Elixir",
  graph_label: "LLM DB",
  license: "MIT",
  visibility: :public,
  category: :ai,
  atlas_facet: :reasoning_models,
  tier: 2,
  tags: [:llm, :metadata, :catalog, :models],
  hex_url: "https://hex.pm/packages/llm_db",
  hexdocs_url: "https://hexdocs.pm/llm_db",
  github_url: "https://github.com/agentjido/llm_db",
  github_org: "agentjido",
  github_repo: "llm_db",
  tech_lead: "@mikehostetler",
  elixir: "~> 1.17",
  maturity: :stable,
  support_level: :stable,
  hex_status: "2026.5.0",
  api_stability: "stable",
  stub: false,
  support: :maintained,
  limitations: [
    "Model metadata is a point-in-time snapshot — new models require a package release",
    "Pricing data may lag behind provider changes"
  ],
  ecosystem_deps: [],
  key_features: [
    "O(1) lock-free queries via :persistent_term",
    "Zero network required at runtime — ships complete snapshot",
    "665+ models from all major providers",
    "Capability-based model selection",
    "Allow/deny filtering with glob and regex patterns",
    "Custom provider overlay for private LLM providers",
    "Multi-source ETL with precedence-based merging",
    "Flexible component-based pricing",
    "SHA-256 integrity verification for snapshots",
    "CalVer versioning tracking data freshness"
  ],
  landing_summary: "Fast, zero-network LLM model metadata catalog for Elixir",
  landing_use_when: ["You want to add LLM reasoning or tool-calling to an agent."],
  landing_not_for: ["Your agent has no LLM component (core Jido needs no LLM)."]
}
---
## Overview

LLMDB is a fast, zero-network LLM model metadata catalog for Elixir. It ships a pre-built snapshot of model metadata from every major LLM provider and serves it from `:persistent_term` for O(1), lock-free reads. Query with a simple `"provider:model"` spec and get back a validated struct with token limits, pricing, capabilities, modalities, and lifecycle status.

## Purpose

LLMDB serves as the model metadata backbone for the Jido ecosystem. It gives every package in the stack a single, validated source of truth about what each LLM model can do, what it costs, and how to talk to it.

## Major Components

### Public API (`LLMDB`)
`model/1`, `models/0`, `providers/0`, `select/1`, `candidates/1`, `allowed?/1`, `parse/1` — all O(1) reads from persistent_term.

### Model & Provider Structs
Zoi-validated structs covering limits, costs, capabilities, modalities, tags, aliases, and lifecycle status.

### Store (`LLMDB.Store`)
Persistent-term-backed runtime store with atomic snapshot swaps, O(1) lookups, and provider aliasing.

### Engine (`LLMDB.Engine`)
Build-time ETL pipeline: Ingest → Normalize → Validate → Merge → Finalize → Ensure Viable. Eight data sources including OpenRouter, models.dev, and provider-specific APIs.

### Query (`LLMDB.Query`)
Capability-based model selection with require, forbid, prefer, and scope options.
