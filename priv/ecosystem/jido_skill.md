%{
  name: "jido_skill",
  title: "Jido Skill",
  graph_label: "Jido Skill",
  version: "0.1.0",
  tagline: "Deprecated skill runtime retained for historical reference",
  license: "Apache-2.0",
  visibility: :private,
  category: :tools,
  tier: 2,
  tags: [:skills, :markdown, :cli, :signals, :runtime],
  github_url: "https://github.com/agentjido/jido_skill",
  github_org: "agentjido",
  github_repo: "jido_skill",
  elixir: "~> 1.18",
  maturity: :experimental,
  support_level: :experimental,
  hex_status: "unreleased",
  api_stability: "unstable - pre-1.0 skill dispatch and registry behavior may change",
  stub: false,
  support: :best_effort,
  limitations: [
    "Deprecated and removed from the public ecosystem atlas",
    "Not published to Hex - available via GitHub dependency",
    "Skill conventions are markdown/file-structure driven and still evolving",
    "Registry and route dispatch APIs are pre-1.0 and subject to change"
  ],
  ecosystem_deps: ["jido"],
  key_features: [
    "Skill-only runtime centered on markdown-defined skill files",
    "Signal-first skill dispatch with route-level invocation support",
    "CLI and mix-task surfaces for run/list/reload/routes/watch flows",
    "Runtime route inspection and signal publication utilities",
    "Local executable workflow via escript build/install"
  ],
  landing_summary: "Deprecated skill runtime retained for historical reference",
  landing_use_when: ["You want ready-made tool Actions for an agent."],
  landing_not_for: ["You need tools this package does not provide.", "Not production-ready; APIs may change."]
}
---
## Overview

Jido Skill is a markdown-centric runtime for defining and executing skills with signal-first dispatch. It focuses on discovery, routing, and operational control for skill catalogs.

## Purpose

Jido Skill is the dedicated skill runtime package for teams standardizing markdown-based skill workflows in Jido environments.

## Boundary Lines

- Owns skill discovery, routing, dispatch, and lifecycle observability for skill execution.
- Provides CLI and mix-task operational interfaces for skill runtime workflows.
- Does not own general command orchestration, chat transport integration, or provider-specific adapter behavior.

## Builder Skill Catalog In This Workbench

This repo now carries a starter builder-skill catalog under `priv/skills/builder-*/SKILL.md` for ecosystem work that touches `jido_skill` and companion packages.

- Load individual builder skills with `Jido.AI.Skill.Loader.load/1`.
- Load the full checked-in catalog with `Jido.AI.Skill.Registry.load_from_paths/1`.
- The intended runtime targets for this catalog are `Jido.AI`, `jido_skill`, and Codex-style contributor workflows.

The package boundary stays explicit:

- `jido_skill` owns markdown-skill runtime behavior, registry and dispatch surfaces, CLI/mix tasks, and release artifacts.
- `jido_run` owns the ecosystem page, example/tutorial presentation, and contributor-facing narrative around how those skills are used.

### Current Builder Catalog

- `builder-action-scaffold`
- `builder-agent-scaffold`
- `builder-plugin-scaffold`
- `builder-adapter-package`
- `builder-ecosystem-page-author`
- `builder-example-tutorial-author`
- `builder-package-review`

## Major Components

### Skill Registry

Discovers and indexes markdown-defined skills with reload support.

### Dispatch Surface

Supports route-driven skill invocation with signal-first runtime behavior.

### CLI and Mix Tasks

Provides commands for run/list/reload/routes/watch/signal operations in local environments.

### Runtime Observability

Exposes lifecycle signal streams for tracking skill execution and registry events.
