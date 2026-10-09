---
name: builder-package-review
description: Reviews a Jido ecosystem package for boundaries, dependencies, testing gaps, and missing workbench documentation.
license: Apache-2.0
compatibility: Jido.AI >= 2.0
allowed-tools: read_file grep git_diff inspect_deps summarize_changes update_docs
metadata:
  author: agent-jido-workbench
  version: "1.0.0"
  host_repo: jido.run
  intended_runtimes: Jido.AI, jido_skill, Codex
  boundary: review can span package repo and workbench, but findings should separate the two clearly
  jido_ai.tags: "builder review boundaries dependencies"
---

# Builder Package Review

Use this skill when the task is to review a package for architectural boundaries, dependency fit, test gaps, or missing docs and examples.

## Workflow

1. Read the package boundary lines, public API, and dependency set.
2. Flag mismatches between implementation claims, tests, and workbench documentation.
3. Separate package-repo findings from workbench follow-up items.
4. Summarize the highest-risk gaps first, then note docs, example, or ecosystem-page work still needed.

## Package Boundary

- Package repo: architecture, dependencies, tests, changelog, and release readiness.
- Workbench repo: ecosystem page accuracy, examples, tutorials, and migration notes.

## Deliverables

- package review findings
- dependency and docs-gap summary
- package-vs-workbench follow-up split
