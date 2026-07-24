%{
  name: "jido_vfs",
  title: "Jido VFS",
  version: "1.0.0",
  tagline: "Backend-agnostic filesystem contract for agent runtimes and sandbox adapters",
  graph_label: "Jido VFS",
  license: "Apache-2.0",
  visibility: :public,
  category: :tools,
  atlas_facet: :workspace,
  tier: 2,
  tags: [:vfs, :filesystem, :runtime, :sandbox, :tools],
  github_url: "https://github.com/agentjido/jido_vfs",
  github_org: "agentjido",
  github_repo: "jido_vfs",
  tech_lead: "@mikehostetler",
  elixir: "~> 1.11",
  maturity: :stable,
  support_level: :stable,
  hex_status: "unreleased",
  api_stability: "stable core contract; adapter surface evolves with backend support",
  stub: false,
  support: :maintained,
  limitations: [
    "Not published to Hex - available via GitHub dependency",
    "Elixir floor remains `~> 1.11`, creating matrix skew with newer runtime packages",
    "Still carries optional git-pinned sprites dependency in some integration paths"
  ],
  ecosystem_deps: [],
  key_features: [
    "Backend-agnostic filesystem behavior contract",
    "Broad adapter coverage across local and virtual backends",
    "Stable substrate for higher-level shell and workspace runtimes",
    "Safe file operations suitable for autonomous agent workflows",
    "Clear separation between filesystem primitives and provider orchestration"
  ],
  landing_summary: "Backend-agnostic filesystem contract for agent runtimes and sandbox adapters",
  landing_use_when: ["You want ready-made tool Actions for an agent."],
  landing_not_for: ["You need tools this package does not provide."]
}
---
## Overview

Jido VFS is the runtime filesystem substrate for the CLI-agent ecosystem. It provides a stable, backend-agnostic contract that higher-level packages build on for safe read/write/list/mutation workflows.

## Purpose

Jido VFS provides the backend-agnostic filesystem contract used by shell, workspace, and harness runtime layers.

## Boundary Lines

- Owns filesystem abstractions, adapter behavior, and safe file-operation primitives.
- Supports multiple backends and execution environments without prescribing agent strategy.
- Does not own CLI session orchestration, provider contracts, or app-level workflow policy.

## Major Components

### Filesystem Contract

Defines the core behavior and data model for backend-agnostic file operations.

### Backend Adapters

Implements concrete adapters that satisfy the contract across local and virtual backends.

### Runtime Safety Primitives

Provides predictable operations used by shell/workspace layers to support autonomous execution.
