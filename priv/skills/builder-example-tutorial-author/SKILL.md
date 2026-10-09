---
name: builder-example-tutorial-author
description: Turns package source material into a runnable example or tutorial plan for the workbench.
license: Apache-2.0
compatibility: Jido.AI >= 2.0
allowed-tools: read_file grep summarize_changes draft_example_outline draft_tutorial_outline update_docs
metadata:
  author: agent-jido-workbench
  version: "1.0.0"
  host_repo: jido.run
  intended_runtimes: Jido.AI, jido_skill, Codex
  boundary: package repo provides source truth; workbench owns example/tutorial presentation
  jido_ai.tags: "builder example tutorial docs"
---

# Builder Example or Tutorial Author

Use this skill when the task is to turn package source material into a runnable example page or a docs/tutorial flow in the workbench.

## Workflow

1. Extract the smallest truthful workflow from the package source.
2. Decide whether the work belongs as an example, tutorial, cookbook, or reference page.
3. Define the deterministic fixture plan so the surface is testable without external credentials.
4. Produce the content outline, implementation targets, and verification checklist.

## Package Boundary

- Package repo: implementation modules, test fixtures, and public API examples.
- Workbench repo: example page, tutorial copy, live demo surface, and narrative sequencing.

## Deliverables

- example or tutorial outline
- deterministic fixture plan
- implementation and verification checklist
