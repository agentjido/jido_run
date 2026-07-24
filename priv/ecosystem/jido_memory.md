%{
  name: "jido_memory",
  title: "Jido Memory",
  graph_label: "Jido Memory",
  version: "0.1.0",
  tagline: "ETS-backed memory system and plugin model for Jido agents",
  license: "Apache-2.0",
  visibility: :public,
  category: :ai,
  atlas_facet: :memory,
  tier: 2,
  tags: [:memory, :state, :plugin, :agents],
  github_url: "https://github.com/agentjido/jido_memory",
  github_org: "agentjido",
  github_repo: "jido_memory",
  tech_lead: "@mikehostetler",
  elixir: "~> 1.18",
  maturity: :stable,
  support_level: :stable,
  hex_status: "unreleased",
  api_stability: "stable — supported memory layer with continued backend and workflow expansion",
  stub: false,
  support: :maintained,
  limitations: [
    "Not published to Hex - available via GitHub dependency",
    "Current implementation uses ETS as the authoritative store",
    "Long-term persistence backends and retention policies are still evolving"
  ],
  ecosystem_deps: ["jido", "jido_action", "jido_ai"],
  key_features: [
    "Structured memory records and query filters",
    "Jido plugin for memory integration into agent lifecycles",
    "Explicit actions for remember, recall, and forget workflows",
    "Auto-capture hooks for LLM and non-LLM signal flows",
    "Namespace-aware storage patterns for multi-agent systems"
  ],
  landing_summary: "ETS-backed memory system and plugin model for Jido agents",
  landing_use_when: ["You want to add LLM reasoning or tool-calling to an agent."],
  landing_not_for: ["Your agent has no LLM component (core Jido needs no LLM)."]
}
---
## Overview

Jido Memory provides a data-driven memory layer for Jido agents with a practical ETS-backed implementation and action-based APIs.

## Purpose

Jido Memory gives agents explicit, inspectable memory operations instead of ad-hoc context mutation.

## Major Components

### Memory Models

Defines structured record and query representations for memory operations.

### Plugin

Ships an ETS plugin that can be mounted into agents for runtime memory behavior.

### Memory Actions

Exposes remember/recall/forget actions to compose memory workflows with the broader Jido action system.
