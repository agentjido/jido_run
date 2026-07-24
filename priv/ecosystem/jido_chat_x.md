%{
  name: "jido_chat_x",
  title: "Jido Chat X",
  graph_label: "Jido Chat X",
  orbit_parent: "jido_chat",
  orbit_label: "X",
  orbit_weight: 8,
  version: "0.1.0",
  tagline: "X/Twitter Direct Messages adapter package for Jido Chat",
  license: "Apache-2.0",
  visibility: :public,
  category: :integrations,
  atlas_facet: :chat,
  tier: 2,
  tags: [:chat, :x, :twitter, :adapter, :messaging],
  github_url: "https://github.com/agentjido/jido_chat_x",
  github_org: "agentjido",
  github_repo: "jido_chat_x",
  tech_lead: "@mikehostetler",
  elixir: "~> 1.18",
  maturity: :beta,
  support_level: :beta,
  hex_status: "unreleased",
  api_stability: "unstable - pre-1.0 adapter APIs and upstream X integration behavior may change",
  stub: false,
  support: :best_effort,
  limitations: [
    "Not published to Hex - available via GitHub dependency",
    "Depends on an upstream X/Twitter SDK Git dependency",
    "Direct-message platform behavior and API access can change externally"
  ],
  ecosystem_deps: ["jido_chat"],
  key_features: [
    "Implements an X/Twitter Direct Messages adapter for Jido Chat",
    "Maps direct-message payloads into shared Jido Chat message envelopes",
    "Uses xdk_elixir as the platform integration boundary",
    "Supports quality checks for adapter development and validation",
    "Complements the chat adapter set for multi-channel agent workflows"
  ],
  landing_summary: "X/Twitter Direct Messages adapter package for Jido Chat",
  landing_use_when: ["You are integrating Jido with another framework or service."],
  landing_not_for: ["You are not using the framework this package integrates with.", "Beta — verify against your Jido version before production use."]
}
---
## Overview

Jido Chat X connects X/Twitter direct messages to the Jido Chat adapter model. It gives Jido Chat workflows a channel-specific path for DM-style communication.

## Purpose

Jido Chat X is the X/Twitter Direct Messages adapter for teams experimenting with agent chat across social messaging surfaces.

## Boundary Lines

- Owns X/Twitter-specific payload mapping and adapter behavior.
- Implements the common Jido Chat adapter shape.
- Does not own platform policy, account permissions, or cross-channel orchestration.

## Major Components

### X Adapter

Wraps X/Twitter direct-message behavior behind the shared Jido Chat adapter contract.

### Event Normalization

Converts platform-native direct-message payloads into normalized chat messages.

### SDK Boundary

Uses the X SDK dependency as the platform access layer while keeping Jido Chat workflows channel-neutral.
