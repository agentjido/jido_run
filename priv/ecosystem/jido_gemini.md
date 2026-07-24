%{
  name: "jido_gemini",
  title: "Jido Gemini",
  graph_label: "Jido Gemini",
  version: "0.1.0",
  tagline: "Google Gemini adapter for Jido Harness with early-stage parity coverage",
  license: "Apache-2.0",
  visibility: :public,
  category: :integrations,
  atlas_facet: :provider_adapters,
  tier: 2,
  tags: [:gemini, :google, :cli, :harness, :coding],
  github_url: "https://github.com/agentjido/jido_gemini",
  github_org: "agentjido",
  github_repo: "jido_gemini",
  tech_lead: "@mikehostetler",
  elixir: "~> 1.18",
  maturity: :beta,
  support_level: :beta,
  hex_status: "unreleased",
  api_stability: "unstable - adapter contract under active development",
  stub: false,
  support: :best_effort,
  limitations: [
    "Not published to Hex - available via GitHub dependency",
    "Requires Gemini CLI tooling and local auth setup",
    "Smallest current adapter surface and least hardened parity profile"
  ],
  ecosystem_deps: ["jido_harness"],
  key_features: [
    "Provider adapter for running Gemini CLI through Jido Harness",
    "Normalized request and response mapping into Harness event streams",
    "Baseline streaming and tool-event support for provider interoperability",
    "Shared operational patterns with other CLI coding adapters",
    "Project aliases for quality checks and compatibility verification",
    "Designed for multi-provider composition alongside Codex and Amp adapters"
  ],
  landing_summary: "Google Gemini adapter for Jido Harness with early-stage parity coverage",
  landing_use_when: ["You are integrating Jido with another framework or service."],
  landing_not_for: ["You are not using the framework this package integrates with.", "Beta — verify against your Jido version before production use."]
}
---
## Overview

Jido Gemini bridges Google Gemini CLI workflows into the Jido Harness protocol so teams can run Gemini as a first-class coding provider in Jido systems.

## Purpose

Jido Gemini is the Gemini-specific provider adapter for Harness-based coding agents.

## Boundary Lines

- Owns Gemini-specific request mapping and event normalization.
- Implements only the provider-facing adapter layer for Harness interoperability.
- Does not own cross-provider policy, parity governance, or app workflow orchestration.

## Major Components

### Adapter

Implements the Harness adapter behavior for Gemini request execution and stream handling.

### Event Mapping

Normalizes provider-specific output into provider-agnostic Harness event envelopes.

### Development Tooling

Includes setup and quality automation for iterative adapter development.
