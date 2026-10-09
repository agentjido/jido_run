---
name: builder-action-scaffold
description: Scaffolds a new Jido.Action with schema, tests, and workbench follow-up notes for ecosystem contributors.
license: Apache-2.0
compatibility: Jido.AI >= 2.0
allowed-tools: read_file write_file grep scaffold_action_module scaffold_action_test update_docs
metadata:
  author: agent-jido-workbench
  version: "1.0.0"
  host_repo: jido.run
  intended_runtimes: Jido.AI, jido_skill, Codex
  boundary: package repo implementation with workbench docs and example follow-up
  jido_ai.tags: "builder scaffold action workbench"
---

# Builder Action Scaffold

Use this skill when the task is to add a new `Jido.Action` and keep the surrounding contributor workflow consistent.

## Workflow

1. Capture the action name, schema, return contract, and deterministic fallback behavior.
2. Generate the module with explicit validation, tagged tuple errors, and any helper actions it needs.
3. Add focused tests that cover success, validation failures, and operational edge cases.
4. Record the workbench follow-up items: example page, ecosystem entry, and docs references if needed.

## Package Boundary

- Package repo: action module, tests, changelog, and package README updates.
- Workbench repo: ecosystem page updates, example/tutorial references, and contributor-facing docs.

## Deliverables

- action module scaffold
- companion test outline
- workbench follow-up checklist
