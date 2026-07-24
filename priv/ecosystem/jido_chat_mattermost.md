%{
  name: "jido_chat_mattermost",
  title: "Jido Chat Mattermost",
  graph_label: "Jido Chat Mattermost",
  orbit_parent: "jido_chat",
  orbit_label: "Mattermost",
  orbit_weight: 8,
  version: "0.1.0",
  tagline: "Mattermost adapter package implementing the Jido Chat adapter contract",
  license: "Apache-2.0",
  visibility: :public,
  category: :integrations,
  atlas_facet: :chat,
  tier: 2,
  tags: [:chat, :mattermost, :adapter, :messaging, :websocket],
  github_url: "https://github.com/www-zaq-ai/jido_chat_mattermost",
  github_org: "www-zaq-ai",
  github_repo: "jido_chat_mattermost",
  tech_lead: "@jat10",
  elixir: "~> 1.17",
  maturity: :beta,
  support_level: :beta,
  hex_status: "unreleased",
  api_stability: "unstable - pre-1.0 adapter APIs and websocket runtime behavior may change",
  stub: false,
  support: :best_effort,
  limitations: [
    "Not published to Hex - available via GitHub dependency",
    "Depends on evolving pre-1.0 Jido Chat core contracts",
    "Websocket-first adapter behavior is still stabilizing"
  ],
  ecosystem_deps: ["jido_chat"],
  key_features: [
    "Implements `Jido.Chat.Mattermost.Adapter` for Mattermost integration",
    "Uses websocket-only ingress for real-time Mattermost event handling",
    "Normalizes Mattermost payloads into typed Jido Chat message envelopes",
    "Provides standalone transport implementation without external adapter dependencies",
    "Includes compatibility wrapper for legacy channel integrations"
  ],
  landing_summary: "Mattermost adapter package implementing the Jido Chat adapter contract",
  landing_use_when: ["You are integrating Jido with another framework or service."],
  landing_not_for: ["You are not using the framework this package integrates with.", "Beta — verify against your Jido version before production use."]
}
---
## Overview

Jido Chat Mattermost is the Mattermost transport adapter for Jido Chat. It maps Mattermost websocket events and message operations onto the shared adapter contract used across chat channels.

## Purpose

Jido Chat Mattermost provides Mattermost-specific transport behavior while preserving channel portability through the shared Jido Chat interface.

## Boundary Lines

- Owns Mattermost websocket event transformation and outbound message behavior.
- Implements the common Jido Chat adapter surface for interoperability with shared chat workflows.
- Uses a standalone implementation in this repository with no external gateway library dependency.
- Does not own cross-channel chat contracts, runtime orchestration, or non-Mattermost transports.

## Major Components

### Mattermost Adapter

`Jido.Chat.Mattermost.Adapter` handles websocket ingress transformation and message delivery through Mattermost-compatible flows.

### Websocket Ingress

Uses a websocket-only ingress model and does not include webhook ingestion support.

### Event Normalization

Converts Mattermost-native event payloads into the typed normalized structures expected by Jido Chat.

### Compatibility Layer

Provides migration support for legacy channel modules while adapter-first integration patterns stabilize.
