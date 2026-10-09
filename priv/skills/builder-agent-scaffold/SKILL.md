---
name: builder-agent-scaffold
description: Scaffolds a new Jido or Jido.AI agent with strategy, runtime policy, and workbench documentation follow-up.
license: Apache-2.0
compatibility: Jido.AI >= 2.0
allowed-tools: read_file write_file grep scaffold_agent_module scaffold_agent_test update_docs
metadata:
  author: agent-jido-workbench
  version: "1.0.0"
  host_repo: jido.run
  intended_runtimes: Jido.AI, jido_skill, Codex
  boundary: package repo implementation with workbench docs and example follow-up
  jido_ai.tags: "builder scaffold agent strategy"
---

# Builder Agent Scaffold

Use this skill when the task is to create a new agent and the caller needs a clear split between strategy wiring, tools, and docs.

## Workflow

1. Identify the agent type, strategy, plugins, skills, and runtime guardrails.
2. Generate the module with explicit timeouts, retry posture, tool boundaries, and signal routes.
3. Add tests for the core command path, error handling, and deterministic local fixtures.
4. Capture the follow-up work needed in the workbench: examples, ecosystem notes, and migration guidance.

## Package Boundary

- Package repo: agent module, local fixtures, tests, and release notes.
- Workbench repo: ecosystem page narrative, example/demo surface, and contributor docs.

## Deliverables

- agent module scaffold
- runtime/test checklist
- workbench publishing checklist
