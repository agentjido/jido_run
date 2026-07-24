%{
  name: "jido_lib",
  title: "Jido Lib",
  graph_label: "Jido Lib",
  version: "0.1.0",
  tagline: "GitHub triage and PR orchestration workflows composed over the CLI-agent stack",
  license: "Apache-2.0",
  visibility: :public,
  category: :tools,
  atlas_facet: :automation,
  tier: 2,
  tags: [:library, :workflows, :github, :orchestration, :automation],
  github_url: "https://github.com/agentjido/jido_lib",
  github_org: "agentjido",
  github_repo: "jido_lib",
  tech_lead: "@mikehostetler",
  elixir: "~> 1.18",
  maturity: :beta,
  support_level: :beta,
  hex_status: "unreleased",
  api_stability: "unstable - module set and APIs are evolving",
  stub: false,
  support: :best_effort,
  limitations: [
    "Not published to Hex - available via GitHub dependency",
    "Still owns Sprite lifecycle actions and runtime integration steps that overlap with harness ownership",
    "Workflow APIs are consolidating around provider-swappable patterns"
  ],
  ecosystem_deps: [
    "jido_harness",
    "jido_claude",
    "jido_amp",
    "jido_codex",
    "jido_gemini",
    "jido_opencode",
    "jido_shell",
    "jido_vfs",
    "jido_runic",
    "jido_ai"
  ],
  key_features: [
    "Canonical GitHub PR bot workflow API",
    "Canonical GitHub issue triage workflow API",
    "Provider-swappable orchestration over Harness adapters",
    "Workflow composition across shell, VFS, runic, and AI strategy layers",
    "Reusable implementation patterns for production automation agents"
  ],
  landing_summary: "GitHub triage and PR orchestration workflows composed over the CLI-agent stack",
  landing_use_when: ["You want ready-made tool Actions for an agent."],
  landing_not_for: ["You need tools this package does not provide.", "Beta — verify against your Jido version before production use."]
}
---
## Overview

Jido Lib provides domain-oriented orchestration modules for GitHub triage and PR workflows that compose the lower-level CLI-agent runtime stack.

## Purpose

Jido Lib is the application orchestration layer for reusable GitHub workflow automation.

## Boundary Lines

- Owns domain workflows, orchestration composition, and workflow-level policy.
- Coordinates providers through Harness and adjacent runtime packages.
- Should not redefine provider contracts or permanently own shared runtime bootstrap responsibilities.

## Major Components

### GitHub Agent APIs

Includes canonical entry points for issue triage and PR bot orchestration.

### Workflow Composition

Builds on Jido action and runic primitives to model multi-step automation pipelines.

### Utility Modules

Provides practical helpers for integrating shell, workspace, and CLI-based agent components.
