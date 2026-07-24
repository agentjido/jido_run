%{
  name: "jido_chat_discord",
  title: "Jido Chat Discord",
  graph_label: "Jido Chat Discord",
  orbit_parent: "jido_chat",
  orbit_label: "Discord",
  orbit_weight: 8,
  version: "0.1.0",
  tagline: "Discord adapter package implementing the Jido Chat adapter contract",
  license: "Apache-2.0",
  visibility: :public,
  category: :integrations,
  atlas_facet: :chat,
  tier: 2,
  tags: [:chat, :discord, :adapter, :nostrum, :messaging],
  github_url: "https://github.com/agentjido/jido_chat_discord",
  github_org: "agentjido",
  github_repo: "jido_chat_discord",
  tech_lead: "@mikehostetler",
  elixir: "~> 1.17",
  maturity: :beta,
  support_level: :beta,
  hex_status: "unreleased",
  api_stability: "unstable - pre-1.0 adapter and ingress surfaces may change",
  stub: false,
  support: :best_effort,
  limitations: [
    "Not published to Hex - available via GitHub dependency",
    "Gateway vs webhook ingress behaviors are still stabilizing",
    "Depends on evolving pre-1.0 Jido Chat core contracts"
  ],
  ecosystem_deps: ["jido_chat"],
  key_features: [
    "Implements `Jido.Chat.Discord.Adapter` for Discord channel integration",
    "Normalizes Discord payloads into typed Jido Chat message envelopes",
    "Supports listener child specs for gateway or webhook ingress modes",
    "Uses Nostrum-backed ingestion for gateway event handling",
    "Includes compatibility wrapper for legacy channel integrations"
  ],
  landing_summary: "Discord adapter package implementing the Jido Chat adapter contract",
  landing_use_when: ["You are integrating Jido with another framework or service."],
  landing_not_for: ["You are not using the framework this package integrates with.", "Beta — verify against your Jido version before production use."]
}
---
## Overview

Jido Chat Discord is the Discord transport adapter for Jido Chat. It maps Discord events and message operations onto the shared `Jido.Chat.Adapter` contract.

## Purpose

Jido Chat Discord provides Discord-specific ingress and egress behavior while preserving a common chat adapter surface across channels.

## Boundary Lines

- Owns Discord payload transformation, listener setup, and transport-specific message operations.
- Implements the shared Jido Chat adapter contract so chat workflows remain portable.
- Does not own cross-channel chat contracts, runtime policy, or non-Discord transport logic.

## Major Components

### Discord Adapter

`Jido.Chat.Discord.Adapter` handles inbound transformation and outbound message execution for Discord channels.

### Ingress Modes

Supports both webhook and gateway ingress modes through `listener_child_specs/2` and configurable event source wiring.

### Event Normalization

Converts Discord-native event structures into normalized typed envelopes used across Jido Chat flows.

### Compatibility Surface

Maintains a compatibility wrapper for legacy channel interfaces during migration to canonical adapter modules.
