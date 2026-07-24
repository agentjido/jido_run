%{
  name: "jido_chat_slack",
  title: "Jido Chat Slack",
  graph_label: "Jido Chat Slack",
  orbit_parent: "jido_chat",
  orbit_label: "Slack",
  orbit_weight: 8,
  version: "1.0.0",
  tagline: "Slack adapter package for Jido Chat",
  license: "Apache-2.0",
  visibility: :public,
  category: :integrations,
  atlas_facet: :chat,
  tier: 2,
  tags: [:chat, :slack, :adapter, :messaging, :websocket],
  github_url: "https://github.com/agentjido/jido_chat_slack",
  github_org: "agentjido",
  github_repo: "jido_chat_slack",
  tech_lead: "@mikehostetler",
  elixir: "~> 1.18",
  maturity: :beta,
  support_level: :beta,
  hex_status: "unreleased",
  api_stability: "unstable - adapter and Slack runtime behavior may change",
  stub: false,
  support: :best_effort,
  limitations: [
    "Not published to Hex - available via GitHub dependency",
    "Depends on Slack app configuration and workspace permissions",
    "Depends on evolving Jido Chat core contracts"
  ],
  ecosystem_deps: ["jido_chat"],
  key_features: [
    "Implements a Slack transport adapter for Jido Chat",
    "Uses websocket-capable runtime dependencies for Slack event handling",
    "Normalizes Slack payloads into shared chat envelopes",
    "Includes quality, coverage, Dialyzer, and documentation tooling",
    "Supports the broader chat adapter family across multiple channels"
  ],
  landing_summary: "Slack adapter package for Jido Chat",
  landing_use_when: ["You are integrating Jido with another framework or service."],
  landing_not_for: ["You are not using the framework this package integrates with.", "Beta — verify against your Jido version before production use."]
}
---
## Overview

Jido Chat Slack connects Slack workspace conversations to the Jido Chat adapter model. It gives teams a Slack-specific transport while keeping chat workflows portable across channels.

## Purpose

Jido Chat Slack provides Slack integration for Jido Chat systems that need to ingest, normalize, and deliver messages through Slack.

## Boundary Lines

- Owns Slack-specific adapter behavior and payload normalization.
- Implements the shared Jido Chat adapter surface.
- Does not own Slack workspace administration, app approval, or cross-channel policy.

## Major Components

### Slack Adapter

Handles Slack message transport and adapter behavior for chat workflows.

### Event Normalization

Maps Slack-native payloads into normalized Jido Chat structures.

### Quality Tooling

Includes package-level quality gates, coverage support, and release metadata for ongoing hardening.
