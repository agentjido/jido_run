%{
  name: "jido_chat_signal",
  title: "Jido Chat Signal",
  graph_label: "Jido Chat Signal",
  orbit_parent: "jido_chat",
  orbit_label: "Signal",
  orbit_weight: 8,
  version: "0.1.0",
  tagline: "Signal adapter package for Jido Chat using signal-cli",
  license: "Apache-2.0",
  visibility: :public,
  category: :integrations,
  atlas_facet: :chat,
  tier: 2,
  tags: [:chat, :signal, :adapter, :messaging, :signal_cli],
  github_url: "https://github.com/agentjido/jido_chat_signal",
  github_org: "agentjido",
  github_repo: "jido_chat_signal",
  tech_lead: "@mikehostetler",
  elixir: "~> 1.18",
  maturity: :beta,
  support_level: :beta,
  hex_status: "unreleased",
  api_stability: "unstable - pre-1.0 adapter APIs and local signal-cli behavior may change",
  stub: false,
  support: :best_effort,
  limitations: [
    "Not published to Hex - available via GitHub dependency",
    "Requires signal-cli setup and local authentication",
    "Depends on evolving pre-1.0 Jido Chat core contracts"
  ],
  ecosystem_deps: ["jido_chat"],
  key_features: [
    "Implements a Signal transport adapter for Jido Chat",
    "Uses signal-cli as the local Signal integration boundary",
    "Normalizes Signal messages into shared Jido Chat message envelopes",
    "Supports environment-driven testing and local adapter configuration",
    "Complements other channel adapters for multi-platform chat workflows"
  ],
  landing_summary: "Signal adapter package for Jido Chat using signal-cli",
  landing_use_when: ["You are integrating Jido with another framework or service."],
  landing_not_for: ["You are not using the framework this package integrates with.", "Beta — verify against your Jido version before production use."]
}
---
## Overview

Jido Chat Signal brings Signal messaging into the Jido Chat adapter family. It uses signal-cli as the integration boundary and maps Signal messages into the shared chat model.

## Purpose

Jido Chat Signal is for teams that need Signal as a channel for Jido Chat workflows while preserving a common adapter contract across chat platforms.

## Boundary Lines

- Owns Signal-specific message mapping and signal-cli integration behavior.
- Implements the shared Jido Chat adapter shape.
- Does not own cross-channel runtime orchestration or Signal account provisioning.

## Major Components

### Signal Adapter

Wraps signal-cli-backed channel behavior for inbound and outbound Signal messages.

### Message Normalization

Converts Signal payloads into normalized structures expected by Jido Chat.

### Local Configuration

Uses environment-driven setup for local development and test execution.
