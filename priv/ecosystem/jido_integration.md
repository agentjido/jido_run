%{
  name: "jido_integration",
  title: "Jido Integration",
  graph_label: "Jido Integration",
  version: "0.1.0",
  tagline: "Connector platform for auth lifecycle, invocation, async flows, and durable execution review",
  license: "Apache-2.0",
  visibility: :public,
  category: :integrations,
  atlas_facet: :protocols,
  tier: 2,
  tags: [:connectors, :integrations, :auth, :webhooks, :runtime],
  github_url: "https://github.com/agentjido/jido_integration",
  github_org: "agentjido",
  github_repo: "jido_integration",
  tech_lead: "@mikehostetler",
  elixir: "~> 1.19",
  maturity: :experimental,
  support_level: :experimental,
  hex_status: "unreleased",
  api_stability: "unstable - monorepo package boundaries and connector contracts are still settling",
  stub: false,
  support: :best_effort,
  limitations: [
    "Non-umbrella monorepo with multiple platform and connector surfaces",
    "Not published to Hex - package boundaries are still being formalized",
    "Hosted webhook and async flows require provider-specific credentials and infrastructure"
  ],
  ecosystem_deps: ["jido", "req_llm"],
  key_features: [
    "Public V2 facade for connector discovery, auth lifecycle, invocation, review, and target lookup",
    "Connector capability publishing and generated action, sensor, and plugin surfaces",
    "Hosted async dispatch and webhook routing APIs",
    "Durable execution state, events, artifacts, and review packets",
    "Inference runtime family for cloud, CLI endpoint, and self-hosted execution paths",
    "Conformance and publishing guides for connector package authors"
  ],
  landing_summary: "Connector platform for auth lifecycle, invocation, async flows, and durable execution review",
  landing_use_when: ["You are integrating Jido with another framework or service."],
  landing_not_for: ["You are not using the framework this package integrates with.", "Not production-ready; APIs may change."]
}
---
## Overview

Jido Integration is an Elixir integration platform for publishing connector capabilities, managing auth lifecycle, invoking work across runtime targets, and reviewing durable execution state.

The repository is a non-umbrella monorepo that contains platform contracts, connector packages, durability tiers, and proof apps for hosted webhook and async flows.

## Purpose

Jido Integration provides the higher-level connector platform for applications that need consistent discovery, authentication, invocation, review, and target lookup across provider integrations.

## Boundary Lines

- Owns connector discovery, auth lifecycle, invocation, review lookup, and hosted async/webhook APIs.
- Provides contracts and conformance workflows for connector package authors.
- Does not replace channel-specific chat adapters, lower-level Jido runtime contracts, or provider business logic outside connector operations.

## Major Components

### Public Facade

`Jido.Integration.V2` exposes the main surface for connector discovery, auth lifecycle calls, invocation, review lookups, and target lookup.

### Connector Contracts

Connector packages publish authored capability contracts and may expose generated `Jido.Action`, `Jido.Sensor`, and `Jido.Plugin` surfaces.

### Runtime And Durability

Core runtime packages support direct, session, stream, inference, async, and webhook execution paths with durable review data.

### Proof Applications

Apps under `apps/` exercise hosted webhook, async, inference, and provider-specific flows.
