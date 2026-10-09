---
name: builder-adapter-package
description: Plans or scaffolds a new adapter or integration package for provider, browser, MCP, or tooling interoperability.
license: Apache-2.0
compatibility: Jido.AI >= 2.0
allowed-tools: read_file write_file grep draft_package_layout map_boundaries update_docs
metadata:
  author: agent-jido-workbench
  version: "1.0.0"
  host_repo: jido.run
  intended_runtimes: Jido.AI, jido_skill, Codex
  boundary: package repo owns adapter logic; workbench owns narrative, examples, and ecosystem inventory
  jido_ai.tags: "builder adapter integration package"
---

# Builder Adapter Package

Use this skill when the work is a new adapter or integration package for provider tooling, MCP, browser flows, or workbench interoperability.

## Workflow

1. Define the package boundary, public API, runtime dependencies, and failure modes.
2. Draft the package layout with clear separation between integration edges and core Jido abstractions.
3. Identify the deterministic fixtures or adapters needed for tests and examples.
4. Record the workbench deliverables: ecosystem page, example/tutorial ideas, and migration notes.

## Package Boundary

- Package repo: adapter modules, integration tests, release assets, and compatibility notes.
- Workbench repo: package page, examples/tutorials, and contributor-facing guidance.

## Deliverables

- package boundary map
- adapter package skeleton
- workbench follow-up checklist
