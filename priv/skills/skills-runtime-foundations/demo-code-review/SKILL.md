---
name: demo-code-review
description: Reviews changed files for correctness, safety, and test gaps in the skills runtime demo.
license: Apache-2.0
compatibility: Jido.AI >= 2.0
allowed-tools: read_file grep git_diff
metadata:
  author: agent-jido-demo
  version: "1.0.0"
  jido_ai:
    tags:
      - demo
      - code-review
      - runtime
---

# Demo Code Review

Use this skill when you want a deterministic review checklist for changed files.

## Workflow

1. Read the modified files.
2. Compare the code against the requested behavior.
3. Flag correctness issues, missing tests, and risky assumptions.
4. Summarize the highest-priority findings first.

## Response Format

1. One-sentence summary of the change
2. Findings ordered by severity
3. Remaining test or rollout risks
