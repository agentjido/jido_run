%{
  name: "jido_phx_starter",
  title: "Jido PHX Starter",
  graph_label: "Jido PHX Starter",
  version: "0.1.0",
  tagline: "Phoenix starter app for learning Jido and Jido AI in a real project",
  license: "Apache-2.0",
  visibility: :public,
  category: :runtime,
  atlas_facet: :applications,
  tier: 3,
  tags: [:phoenix, :starter, :demo, :learning, :ash],
  github_url: "https://github.com/agentjido/jido_phx_starter",
  github_org: "agentjido",
  github_repo: "jido_phx_starter",
  tech_lead: "@mikehostetler",
  elixir: "~> 1.15",
  maturity: :beta,
  support_level: :beta,
  hex_status: "unreleased",
  api_stability: "example app - dependencies and demo flows may move with the ecosystem",
  stub: false,
  support: :best_effort,
  limitations: [
    "Starter application, not a Hex package dependency",
    "Requires PostgreSQL and Phoenix local setup",
    "AI demos require provider API keys"
  ],
  ecosystem_deps: ["jido", "jido_ai", "ash_jido"],
  key_features: [
    "Beginner-friendly Phoenix app for learning Jido and Jido AI",
    "Working demos for actions, signals, directives, and multi-agent orchestration",
    "AI chat and listings demos with tool calling",
    "Ash and AshJido integration examples",
    "Local setup flow for database-backed Phoenix development"
  ],
  landing_summary: "Phoenix starter app for learning Jido and Jido AI in a real project",
  landing_use_when: ["You need runtime infrastructure (persistence, scheduling, or observability) for a deployed agent."],
  landing_not_for: ["You are still prototyping and do not yet run agents long-term.", "Beta — verify against your Jido version before production use."]
}
---
## Overview

Jido PHX Starter is a beginner-friendly Phoenix application for learning Jido and Jido AI in a real project. It includes working demos for agent actions, signals, directives, AI chat with tool calling, Ash/AshJido integrations, and multi-agent orchestration.

## Purpose

Jido PHX Starter gives new Jido users a concrete Phoenix app they can run locally while exploring common runtime and AI patterns.

## Boundary Lines

- Owns starter-app examples, demo routes, and local Phoenix setup guidance.
- Shows how Jido, Jido AI, and AshJido can fit into a Phoenix project.
- Does not define core package APIs and is not intended to be consumed as a library dependency.

## Major Components

### Demo Routes

Includes routes for counters, demand tracking, chat, listings, and weekend-sale workflows.

### AI Examples

Demonstrates Jido AI chat and tool-calling flows when provider API keys are available.

### Ash Integration

Shows Ash and AshJido patterns inside a normal Phoenix application structure.
