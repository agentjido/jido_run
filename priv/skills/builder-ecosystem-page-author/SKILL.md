---
name: builder-ecosystem-page-author
description: Authors or updates a workbench ecosystem package page with boundaries, features, limitations, and companion links.
license: Apache-2.0
compatibility: Jido.AI >= 2.0
allowed-tools: read_file grep summarize_changes update_markdown validate_links
metadata:
  author: agent-jido-workbench
  version: "1.0.0"
  host_repo: jido.run
  intended_runtimes: Jido.AI, jido_skill, Codex
  boundary: workbench-only skill for package inventory and ecosystem documentation
  jido_ai.tags: "builder docs ecosystem catalog"
---

# Builder Ecosystem Page Author

Use this skill when the task is to add or refresh a package page in the workbench ecosystem catalog.

## Workflow

1. Gather the package purpose, boundary lines, maturity, dependencies, and limitations from source material.
2. Write or update the ecosystem page with concise package positioning and honest status notes.
3. Link the package to the right examples, guides, and upstream repositories.
4. Verify the page makes the repo boundary explicit: package repo implementation vs workbench narrative and examples.

## Package Boundary

- Package repo: code, changelog, versioning, and API specifics.
- Workbench repo: package overview, capability framing, limitations, and companion links.

## Deliverables

- ecosystem page draft or update
- related links checklist
- boundary and limitation summary
