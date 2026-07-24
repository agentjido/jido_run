%{
  name: "jido_connect",
  title: "Jido Connect",
  graph_label: "Jido Connect",
  version: "0.1.0",
  tagline: "Integration and connector framework for Jido host applications",
  license: "Apache-2.0",
  visibility: :public,
  category: :integrations,
  atlas_facet: :protocols,
  tier: 3,
  tags: [:connectors, :integrations, :github, :slack, :mcp],
  github_url: "https://github.com/agentjido/jido_connect",
  github_org: "agentjido",
  github_repo: "jido_connect",
  tech_lead: "@mikehostetler",
  maturity: :beta,
  support_level: :beta,
  hex_status: "unreleased",
  api_stability: "unstable - provider boundaries and catalog APIs are pre-release",
  stub: false,
  support: :best_effort,
  limitations: [
    "Umbrella development repo - provider packages may publish as separate Hex packages",
    "Not published to Hex - available via GitHub dependency until package boundaries settle",
    "Connector authentication and webhook setup depends on external provider configuration"
  ],
  ecosystem_deps: ["jido", "jido_action"],
  key_features: [
    "Core Jido.Connect contracts for provider integrations",
    "Spark DSL extension for declaring connector capabilities",
    "GitHub, Slack, and MCP connector app slices",
    "Catalog discovery, deterministic tool search, and safe tool calling",
    "Provider action contracts for GitHub issues, Slack messages, and MCP tool calls",
    "Local Phoenix demo host for OAuth callbacks, webhook validation, and integration testing"
  ],
  landing_summary: "Integration and connector framework for Jido host applications",
  landing_use_when: ["You are integrating Jido with another framework or service."],
  landing_not_for: ["You are not using the framework this package integrates with.", "Beta — verify against your Jido version before production use."]
}
---
## Overview

Jido Connect is the integration framework for host applications that need to expose provider tools to Jido agents. It defines the core connector contracts, catalog discovery surface, and safe tool-calling path used by provider apps such as GitHub, Slack, and MCP.

The repository is structured as an umbrella for development and publishing. Host applications should depend only on the provider packages they need, while the provider package brings in the shared `jido_connect` core dependency.

## Purpose

Jido Connect provides a common boundary for provider integrations so agents can discover, describe, and invoke external tools without hard-coding every provider into the host application.

## Boundary Lines

- Owns connector contracts, provider discovery, catalog search, and safe tool invocation.
- Owns provider slices for GitHub, Slack, and MCP while package boundaries are still settling.
- Does not own chat-channel adapters, long-term memory, or provider-specific business workflows outside connector operations.

## Major Components

### Core Contracts

Zoi-backed contracts under `Jido.Connect` define the shared integration surface and validation rules for connector providers.

### DSL Extension

Spark DSL support gives provider authors a structured way to declare capabilities, actions, triggers, and provider metadata.

### Provider Apps

Current provider slices include GitHub, Slack, and MCP apps for issue operations, message/file operations, and MCP tool bridging.

### Catalog

`Jido.Connect.Catalog` discovers installed providers, searches tools deterministically, describes tool schemas, and routes safe execution through the connector invocation path.

### Demo Host

A local Phoenix demo host exercises OAuth callbacks, GitHub App setup callbacks, webhooks, and provider routes without turning every provider package into a demo application.
