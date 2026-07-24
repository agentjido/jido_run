%{
  name: "jido_codex",
  title: "Jido Codex",
  graph_label: "Jido Codex",
  version: "0.1.0",
  tagline: "OpenAI Codex adapter for Jido Harness with deep runtime capability coverage",
  license: "Apache-2.0",
  visibility: :public,
  category: :integrations,
  atlas_facet: :provider_adapters,
  tier: 2,
  tags: [:codex, :openai, :cli, :harness, :coding],
  github_url: "https://github.com/agentjido/jido_codex",
  github_org: "agentjido",
  github_repo: "jido_codex",
  tech_lead: "@mikehostetler",
  elixir: "~> 1.18",
  maturity: :beta,
  support_level: :beta,
  hex_status: "unreleased",
  api_stability: "unstable - adapter protocol still evolving",
  stub: false,
  support: :best_effort,
  limitations: [
    "Not published to Hex - available via GitHub dependency",
    "Requires Codex CLI installed and authenticated",
    "Rich feature depth increases parity drift risk versus simpler adapters"
  ],
  ecosystem_deps: ["jido_harness"],
  key_features: [
    "Implements `Jido.Harness.Adapter` for Codex-backed execution",
    "Most complete provider capability surface including resume/cancel handling",
    "Streaming event normalization into Harness-compatible envelopes",
    "Exec transport by default with optional app-server transport",
    "Validation and smoke-test mix tasks for local setup"
  ],
  landing_summary: "OpenAI Codex adapter for Jido Harness with deep runtime capability coverage",
  landing_use_when: ["You are integrating Jido with another framework or service."],
  landing_not_for: ["You are not using the framework this package integrates with.", "Beta — verify against your Jido version before production use."]
}
---
## Overview

Jido Codex adapts OpenAI Codex CLI into the Jido Harness protocol so coding-agent workflows can run through a unified provider interface.

## Purpose

Jido Codex is the Codex-specific provider adapter in the CLI-agent stack.

## Boundary Lines

- Owns Codex-specific request mapping, runtime contract wiring, and event normalization.
- Implements provider capabilities within the shared Harness contract.
- Does not define cross-provider policy, contract governance, or app-level workflow logic.

## Major Components

### Adapter

Translates Harness run requests into Codex CLI sessions and maps responses back into normalized events.

### Mapper

Normalizes streaming and lifecycle events for downstream agent orchestration.

### Operational Tasks

Includes install and compatibility checks to catch local environment issues early.
