%{
  name: "jido_chat",
  title: "Jido Chat",
  graph_label: "Jido Chat",
  version: "0.1.0",
  tagline: "SDK-first chat core for typed message flows and adapter contracts",
  license: "Apache-2.0",
  visibility: :public,
  category: :integrations,
  atlas_facet: :chat,
  tier: 2,
  tags: [:chat, :sdk, :messages, :adapters, :agents],
  github_url: "https://github.com/agentjido/jido_chat",
  github_org: "agentjido",
  github_repo: "jido_chat",
  tech_lead: "@mikehostetler",
  elixir: "~> 1.17",
  maturity: :beta,
  support_level: :beta,
  hex_status: "unreleased",
  api_stability: "unstable - experimental pre-1.0 API aligned to Chat SDK patterns",
  stub: false,
  support: :best_effort,
  limitations: [
    "Not published to Hex - available via GitHub dependency",
    "Experimental API and adapter contracts may change before 1.0",
    "Parity with legacy channel abstractions is still in transition"
  ],
  ecosystem_deps: [],
  key_features: [
    "Typed chat domain model (`Incoming`, `Message`, `SentMessage`, `Response`)",
    "Canonical adapter behavior (`Jido.Chat.Adapter`) for channel integrations",
    "Pure struct/function bot loop for deterministic message handling",
    "Thread and channel reference handles for portable adapter implementations",
    "Compatibility shims to support migration from legacy channel modules"
  ],
  landing_summary: "SDK-first chat core for typed message flows and adapter contracts",
  landing_use_when: ["You are integrating Jido with another framework or service."],
  landing_not_for: ["You are not using the framework this package integrates with.", "Beta — verify against your Jido version before production use."]
}
---
## Overview

Jido Chat is an SDK-first chat core that defines typed message structures and canonical adapter contracts for chat integrations. It provides a stable architectural center for channel packages while remaining runtime-agnostic.

## Purpose

Jido Chat is the core chat protocol and type system package for the emerging messaging adapter family in the Jido ecosystem.

## Boundary Lines

- Owns chat data models, normalization contracts, and adapter behavior interfaces.
- Provides the common contract layer that channel-specific packages build on.
- Does not own channel transport implementations, runtime orchestration policy, or provider-specific delivery behavior.

## Major Components

### Core Chat Surface

`Jido.Chat` provides the pure struct/function loop for handling incoming events and generating outbound responses.

### Typed Payloads

Defines normalized envelope and payload structs used by adapters to translate platform-specific message events.

### Adapter Contract

`Jido.Chat.Adapter` standardizes channel integration behavior so downstream packages can integrate consistently.

### Compatibility Layer

Includes migration support for legacy channel modules while the canonical adapter path matures.
