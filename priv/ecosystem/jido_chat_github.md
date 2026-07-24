%{
  name: "jido_chat_github",
  title: "Jido Chat GitHub",
  graph_label: "Jido Chat GitHub",
  orbit_parent: "jido_chat",
  orbit_label: "GitHub",
  orbit_weight: 8,
  version: "0.1.0",
  tagline: "GitHub Issues adapter package for Jido Chat",
  license: "Apache-2.0",
  visibility: :public,
  category: :integrations,
  atlas_facet: :chat,
  tier: 2,
  tags: [:chat, :github, :issues, :adapter, :collaboration],
  github_url: "https://github.com/agentjido/jido_chat_github",
  github_org: "agentjido",
  github_repo: "jido_chat_github",
  tech_lead: "@mikehostetler",
  elixir: "~> 1.18",
  maturity: :beta,
  support_level: :beta,
  hex_status: "unreleased",
  api_stability: "unstable - pre-1.0 adapter APIs may change",
  stub: false,
  support: :best_effort,
  limitations: [
    "Not published to Hex - available via GitHub dependency",
    "Depends on evolving pre-1.0 Jido Chat core contracts",
    "GitHub API behavior and issue workflows may need project-specific policy"
  ],
  ecosystem_deps: ["jido_chat"],
  key_features: [
    "Implements a GitHub Issues adapter for Jido Chat workflows",
    "Maps GitHub issue conversations into normalized Jido Chat messages",
    "Uses Req and Jason for API interaction and payload handling",
    "Supports adapter testing with local fixtures and environment-driven configuration",
    "Fits into the same channel adapter family as Discord, Telegram, Slack, and X"
  ],
  landing_summary: "GitHub Issues adapter package for Jido Chat",
  landing_use_when: ["You are integrating Jido with another framework or service."],
  landing_not_for: ["You are not using the framework this package integrates with.", "Beta — verify against your Jido version before production use."]
}
---
## Overview

Jido Chat GitHub connects GitHub Issues conversations to the Jido Chat adapter model. It gives agent workflows a channel-oriented way to read and respond to issue-driven collaboration.

## Purpose

Jido Chat GitHub is the GitHub Issues transport adapter for teams that want Jido Chat workflows to operate directly in repository issue queues.

## Boundary Lines

- Owns GitHub Issues payload mapping and outbound issue interaction behavior.
- Implements the common Jido Chat adapter shape for channel portability.
- Does not own GitHub project policy, triage decisions, or cross-channel chat contracts.

## Major Components

### GitHub Adapter

Maps GitHub issue data into Jido Chat messages and handles GitHub API calls for channel operations.

### Event Normalization

Normalizes issue payloads into the shared message structures consumed by chat workflows.

### Test Fixtures

Provides fixture-driven coverage for GitHub payload handling and adapter behavior.
