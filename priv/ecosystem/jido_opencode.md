%{
  name: "jido_opencode",
  title: "Jido OpenCode",
  graph_label: "Jido OpenCode",
  version: "0.1.0",
  tagline: "OpenCode CLI adapter for Jido Harness with buffered-first execution semantics",
  license: "Apache-2.0",
  visibility: :public,
  category: :integrations,
  atlas_facet: :provider_adapters,
  tier: 2,
  tags: [:opencode, :zai, :cli, :harness, :coding],
  github_url: "https://github.com/agentjido/jido_opencode",
  github_org: "agentjido",
  github_repo: "jido_opencode",
  tech_lead: "@mikehostetler",
  elixir: "~> 1.18",
  maturity: :beta,
  support_level: :beta,
  hex_status: "unreleased",
  api_stability: "unstable - adapter surface and parity model are still evolving",
  stub: false,
  support: :best_effort,
  limitations: [
    "Not published to Hex - available via GitHub dependency",
    "Buffered-first execution model currently limits parity with fully streamed adapters",
    "Runtime defaults are currently tuned for Z.AI/OpenCode workflows"
  ],
  ecosystem_deps: ["jido_harness"],
  key_features: [
    "Implements `Jido.Harness.Adapter` for OpenCode CLI execution",
    "Runtime contract support and compatibility tasks for local setup verification",
    "Buffered-first result handling with normalized event envelopes",
    "Provider-swappable integration through the shared Harness contract",
    "Contract-first posture for adapter interoperability and testing"
  ],
  landing_summary: "OpenCode CLI adapter for Jido Harness with buffered-first execution semantics",
  landing_use_when: ["You are integrating Jido with another framework or service."],
  landing_not_for: ["You are not using the framework this package integrates with.", "Beta — verify against your Jido version before production use."]
}
---
## Overview

Jido OpenCode integrates OpenCode CLI workflows into the Harness adapter ecosystem for provider-swappable coding-agent execution.

## Purpose

Jido OpenCode is the OpenCode-specific provider adapter in the CLI-agent stack.

## Boundary Lines

- Owns OpenCode-specific request mapping, runtime contract wiring, and event normalization.
- Uses buffered-first execution semantics while aligning to Harness interfaces.
- Does not own provider-neutral runtime policy, adapter parity governance, or domain workflow orchestration.

## Major Components

### Harness Adapter

Implements provider callbacks and maps Harness run requests into OpenCode execution flows.

### Runtime Contract and Compatibility

Defines provider runtime expectations and includes operational checks for local setup.

### Event Mapping

Normalizes OpenCode lifecycle output into shared Harness event envelopes.
