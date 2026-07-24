%{
  name: "jido_workspace",
  title: "Jido Workspace",
  graph_label: "Jido Workspace",
  version: "0.1.0",
  tagline: "Workspace state and artifact lifecycle library for agent sessions",
  license: "Apache-2.0",
  visibility: :public,
  category: :tools,
  atlas_facet: :workspace,
  tier: 2,
  tags: [:workspace, :artifacts, :shell, :vfs, :agents],
  github_url: "https://github.com/agentjido/jido_workspace",
  github_org: "agentjido",
  github_repo: "jido_workspace",
  tech_lead: "@mikehostetler",
  elixir: "~> 1.18",
  maturity: :beta,
  support_level: :beta,
  hex_status: "unreleased",
  api_stability: "unstable - package and persistence interfaces may change",
  stub: false,
  support: :best_effort,
  limitations: [
    "Not published to Hex - available via GitHub dependency",
    "Branch-based dependencies remain in current repo wiring",
    "Canonical ownership overlap with `Jido.Harness.Exec.Workspace` is still unresolved",
    "Snapshot and execution semantics are still evolving"
  ],
  ecosystem_deps: ["jido_shell", "jido_vfs", "jido_harness"],
  key_features: [
    "Unified workspace abstraction for file artifacts and command execution",
    "In-memory VFS-backed workspace creation and lifecycle operations",
    "Snapshot and restore support for speculative agent workflows",
    "Convenience API for read/write/list/delete artifact operations",
    "Shell execution integration for workspace-local command runs"
  ],
  landing_summary: "Workspace state and artifact lifecycle library for agent sessions",
  landing_use_when: ["You want ready-made tool Actions for an agent."],
  landing_not_for: ["You need tools this package does not provide.", "Beta — verify against your Jido version before production use."]
}
---
## Overview

Jido Workspace provides a unified artifact workspace abstraction for agent sessions, combining virtual filesystem and shell primitives.

## Purpose

Jido Workspace is the workspace state and artifact lifecycle layer for higher-level agent systems.

## Boundary Lines

- Owns workspace creation, artifact APIs, and snapshot lifecycle operations.
- Provides workspace-local execution composition using shell and VFS primitives.
- Long-term canonical ownership is still open versus `Jido.Harness.Exec.Workspace`.

## Major Components

### Workspace Core

Creates and manages workspace instances backed by VFS semantics.

### Artifact API

Supports common file operations and artifact inspection helpers.

### Snapshot Lifecycle

Allows checkpoint/restore workflows for reversible autonomous operations.

### Shell Integration

Runs commands against workspace state through jido_shell adapters.
