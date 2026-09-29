%{
  name: "jido_lib",
  title: "Jido Lib",
  graph_label: "Jido Lib",
  version: "unreleased",
  tagline: "Archived GitHub workflow experiments retained as an unsupported historical example",
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
  maturity: :experimental,
  support_level: :unsupported,
  hex_status: "unreleased",
  api_stability: "archived - no supported API",
  stub: false,
  support: :unsupported,
  limitations: [
    "Archived, deprecated, and unsupported",
    "Version 0.1.0 was never tagged or published to Hex or as a GitHub release",
    "No dependency updates, bug fixes, security fixes, or releases",
    "Historical example only; do not use for new work"
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
    "Historical GitHub PR and issue-triage workflow experiments",
    "Historical provider-swappable orchestration over Harness adapters",
    "Historical composition patterns across shell, VFS, Runic, and AI layers"
  ]
}
---
## Overview

Jido Lib was an experimental package for GitHub triage and PR workflows. The repository is archived, deprecated, and unsupported. It remains available only as a historical example.

## Purpose

The package has no active product role and no successor. Do not use it for new work.

## Boundary Lines

- The historical code composed domain workflows and workflow-level policy.
- The historical code coordinated providers through Harness and adjacent runtime packages.
- No module, task, policy, test, or guide is an active Jido interface.

## Major Components

### GitHub Agent APIs

Contains former entry points for issue triage and PR bot orchestration.

### Workflow Composition

Shows historical use of Jido action and Runic primitives for multi-step automation pipelines.

### Utility Modules

Contains historical helpers for shell, workspace, and CLI-based agent components.
