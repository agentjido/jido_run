%{
  name: "jido_bedrock",
  title: "Jido Bedrock",
  graph_label: "Jido Bedrock",
  version: "0.1.0",
  tagline: "Bedrock-backed persistence adapters for Jido runtimes",
  license: "Apache-2.0",
  visibility: :public,
  category: :integrations,
  atlas_facet: :storage,
  tier: 2,
  tags: [:bedrock, :storage, :persistence, :runtime, :agents],
  github_url: "https://github.com/agentjido/jido_bedrock",
  github_org: "agentjido",
  github_repo: "jido_bedrock",
  tech_lead: "@mikehostetler",
  elixir: "~> 1.18",
  maturity: :experimental,
  support_level: :experimental,
  hex_status: "unreleased",
  api_stability: "unstable - pre-1.0 persistence API surface may change",
  stub: false,
  support: :best_effort,
  limitations: [
    "Not published to Hex - available via GitHub dependency",
    "Focused on Bedrock-backed runtime persistence, not a general storage abstraction",
    "Operational hardening and migration tooling are still evolving"
  ],
  ecosystem_deps: ["jido"],
  key_features: [
    "Implements Bedrock-backed `Jido.Storage` for runtime persistence",
    "Durable checkpoint and thread journal persistence via `Bedrock.Repo`",
    "Optimistic concurrency for append operations using expected revision checks",
    "Drop-in storage adapter wiring for Jido runtime configuration",
    "Compatibility with existing Jido instance lifecycle and recovery workflows"
  ],
  landing_summary: "Bedrock-backed persistence adapters for Jido runtimes",
  landing_use_when: ["You are integrating Jido with another framework or service."],
  landing_not_for: ["You are not using the framework this package integrates with.", "Not production-ready; APIs may change."]
}
---
## Overview

Jido Bedrock provides Bedrock-backed persistence adapters for Jido runtimes. It gives Jido agents durable storage for checkpoints and thread journals while staying inside the standard `Jido.Storage` contract.

## Purpose

Jido Bedrock is the Bedrock storage integration package for teams that need durable, shared persistence for Jido runtimes.

## Boundary Lines

- Owns Bedrock-specific storage adapter behavior and data lifecycle mapping for Jido persistence operations.
- Focuses on persistence concerns only; agent orchestration and runtime control remain in core Jido packages.
- Does not replace provider-neutral runtime contracts or cross-storage governance policy.

## Major Components

### Bedrock Storage Adapter

Implements `Jido.Storage` operations backed by Bedrock repositories for runtime hibernation/thaw and journal persistence.

### Concurrency Control

Uses optimistic concurrency patterns (`expected_rev`) to protect append operations in concurrent runtime scenarios.

### Runtime Integration Surface

Provides direct wiring for Jido runtime storage configuration so existing agents can adopt durable persistence with minimal changes.
