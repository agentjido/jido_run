%{
  name: "jido_chat_ui",
  title: "Jido Chat UI",
  graph_label: "Jido Chat UI",
  orbit_parent: "jido_chat",
  orbit_label: "UI",
  orbit_weight: 9,
  version: "0.1.0",
  tagline: "Phoenix LiveView UI for Jido Chat",
  license: "Apache-2.0",
  visibility: :public,
  category: :integrations,
  atlas_facet: :chat,
  tier: 2,
  tags: [:chat, :ui, :phoenix, :liveview, :messaging],
  github_url: "https://github.com/agentjido/jido_chat_ui",
  github_org: "agentjido",
  github_repo: "jido_chat_ui",
  tech_lead: "@mikehostetler",
  elixir: "~> 1.18",
  maturity: :beta,
  support_level: :beta,
  hex_status: "unreleased",
  api_stability: "unstable - Phoenix UI and adapter demo surfaces may change",
  stub: false,
  support: :best_effort,
  limitations: [
    "Not projected into release-status reporting yet",
    "Application-style UI package rather than a pure Hex library target",
    "Depends on multiple chat adapters and Phoenix LiveView runtime setup"
  ],
  ecosystem_deps: [
    "jido_chat",
    "jido_messaging",
    "jidoka",
    "jido_ai",
    "jido_chat_discord",
    "jido_chat_github",
    "jido_chat_slack",
    "jido_chat_telegram",
    "jido_chat_x"
  ],
  key_features: [
    "Phoenix LiveView user interface for Jido Chat workflows",
    "Demonstrates multiple chat adapters in a unified application surface",
    "Uses Jido runtime and messaging packages as application dependencies",
    "Provides a UI-oriented integration path for chat package validation",
    "Supports local development workflows for adapter demos and runtime experiments"
  ],
  landing_summary: "Phoenix LiveView UI for Jido Chat",
  landing_use_when: ["You are integrating Jido with another framework or service."],
  landing_not_for: ["You are not using the framework this package integrates with.", "Beta — verify against your Jido version before production use."]
}
---
## Overview

Jido Chat UI is a Phoenix LiveView application surface for exercising and demonstrating Jido Chat workflows across multiple adapters.

## Purpose

Jido Chat UI gives the chat ecosystem an operator-facing and developer-facing UI for testing channel behavior, message flows, and agent participation.

## Boundary Lines

- Owns Phoenix UI composition and application wiring for chat workflows.
- Depends on chat adapters and runtime packages for actual channel behavior.
- Does not define the core Jido Chat contract or publish as a standard package release target yet.

## Major Components

### LiveView Interface

Provides Phoenix LiveView screens for chat workflow interaction.

### Adapter Showcase

Wires multiple Jido Chat adapters into a single application context for validation and demos.

### Runtime Integration

Uses Jido AI, messaging, and chat packages to exercise realistic agent chat flows.
