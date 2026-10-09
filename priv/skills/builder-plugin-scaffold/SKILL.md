---
name: builder-plugin-scaffold
description: Scaffolds a Jido plugin with signal routes, actions, and docs notes for workbench consumers.
license: Apache-2.0
compatibility: Jido.AI >= 2.0
allowed-tools: read_file write_file grep scaffold_plugin_module scaffold_plugin_test update_docs
metadata:
  author: agent-jido-workbench
  version: "1.0.0"
  host_repo: jido.run
  intended_runtimes: Jido.AI, jido_skill, Codex
  boundary: package repo signal/runtime implementation with workbench usage docs
  jido_ai.tags: "builder scaffold plugin signals"
---

# Builder Plugin Scaffold

Use this skill when the task is to add a plugin that introduces new signal routes, runtime policy, or reusable operational behavior.

## Workflow

1. Capture the signal routes, required actions, plugin opts, and failure boundaries.
2. Generate the plugin module with explicit route mapping and minimal hidden behavior.
3. Add tests for route registration, action dispatch, and misconfiguration handling.
4. Document how the plugin should appear in examples, docs, and ecosystem package pages.

## Package Boundary

- Package repo: plugin module, actions, tests, and configuration docs.
- Workbench repo: example usage, docs snippets, and ecosystem positioning.

## Deliverables

- plugin scaffold
- route and action checklist
- workbench usage notes
