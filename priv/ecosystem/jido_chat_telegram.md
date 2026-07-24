%{
  name: "jido_chat_telegram",
  title: "Jido Chat Telegram",
  graph_label: "Jido Chat Telegram",
  orbit_parent: "jido_chat",
  orbit_label: "Telegram",
  orbit_weight: 8,
  version: "0.1.0",
  tagline: "Telegram adapter package implementing the Jido Chat adapter contract",
  license: "Apache-2.0",
  visibility: :public,
  category: :integrations,
  atlas_facet: :chat,
  tier: 2,
  tags: [:chat, :telegram, :adapter, :messaging, :exgram],
  github_url: "https://github.com/agentjido/jido_chat_telegram",
  github_org: "agentjido",
  github_repo: "jido_chat_telegram",
  tech_lead: "@mikehostetler",
  elixir: "~> 1.17",
  maturity: :beta,
  support_level: :beta,
  hex_status: "unreleased",
  api_stability: "unstable - pre-1.0 adapter and extension APIs may change",
  stub: false,
  support: :best_effort,
  limitations: [
    "Not published to Hex - available via GitHub dependency",
    "Depends on evolving pre-1.0 Jido Chat core contracts",
    "Telegram extension API coverage is still expanding"
  ],
  ecosystem_deps: ["jido_chat"],
  key_features: [
    "Implements `Jido.Chat.Telegram.Adapter` for Telegram integration",
    "Transforms Telegram updates into normalized Jido Chat envelopes",
    "Supports adapter-level send operations with token-based auth",
    "Provides Telegram-specific extension helpers for media and callbacks",
    "Includes compatibility surface for legacy channel-style integrations"
  ],
  landing_summary: "Telegram adapter package implementing the Jido Chat adapter contract",
  landing_use_when: ["You are integrating Jido with another framework or service."],
  landing_not_for: ["You are not using the framework this package integrates with.", "Beta — verify against your Jido version before production use."]
}
---
## Overview

Jido Chat Telegram is the Telegram transport adapter for Jido Chat. It maps Telegram updates and send operations onto the shared adapter contract used across chat channels.

## Purpose

Jido Chat Telegram provides Telegram-specific transport behavior while preserving channel portability through the shared Jido Chat interface.

## Boundary Lines

- Owns Telegram update transformation, outbound send behavior, and Telegram-specific extension helpers.
- Implements the common Jido Chat adapter surface for interoperability with shared chat workflows.
- Does not own cross-channel chat contracts, runtime orchestration, or non-Telegram transports.

## Major Components

### Telegram Adapter

`Jido.Chat.Telegram.Adapter` handles update transformation and message delivery through Telegram-compatible flows.

### Extension Surface

`Jido.Chat.Telegram.Extensions` exposes Telegram-specific helpers for media sends, callback handling, and other channel-specific operations.

### Event Normalization

Converts Telegram-native payloads into the typed normalized structures expected by Jido Chat.

### Compatibility Layer

Provides migration support for legacy channel modules while adapter-first integration patterns stabilize.
