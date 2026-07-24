%{
  name: "jidoka",
  title: "Jidoka",
  graph_label: "Jidoka",
  version: "1.0.0-beta.1",
  tagline: "Developer-friendly LLM agent harness built on Jido and Jido AI",
  license: "Apache-2.0",
  visibility: :public,
  category: :runtime,
  atlas_facet: :applications,
  tier: 2,
  tags: [:agents, :dsl, :harness, :guardrails, :runtime],
  github_url: "https://github.com/agentjido/jidoka",
  github_org: "agentjido",
  github_repo: "jidoka",
  tech_lead: "@mikehostetler",
  elixir: "~> 1.18",
  maturity: :beta,
  support_level: :beta,
  hex_status: "unreleased",
  api_stability: "unstable - DSL, guardrails, and runtime APIs are still being proven out",
  stub: false,
  support: :best_effort,
  limitations: [
    "Not published to Hex - available via GitHub dependency",
    "Several Jido ecosystem dependencies are pinned to Git refs",
    "Agent DSL and workflow runtime behavior remain experimental"
  ],
  ecosystem_deps: [
    "ash_jido",
    "jido",
    "jido_ai",
    "jido_browser",
    "jido_character",
    "jido_eval",
    "jido_mcp",
    "jido_memory",
    "jido_runic"
  ],
  key_features: [
    "Developer-friendly LLM agent harness built on Jido and Jido AI",
    "Agent and workflow DSL surfaces for higher-level runtime composition",
    "Guardrail modules for input, output, and tool boundaries",
    "Trace and AgentView concepts for observing agent execution",
    "Integrates multiple Jido ecosystem packages into one experimental application runtime"
  ],
  landing_summary: "Developer-friendly LLM agent harness built on Jido and Jido AI",
  landing_use_when: ["You need runtime infrastructure (persistence, scheduling, or observability) for a deployed agent."],
  landing_not_for: ["You are still prototyping and do not yet run agents long-term.", "Beta — verify against your Jido version before production use."]
}
---
## Overview

Jidoka is an experimental agent harness and DSL layer built on Jido and Jido AI. It explores higher-level composition patterns for agent views, guardrails, and workflow runtime behavior.

## Purpose

Jidoka is for proving out developer-friendly agent-building patterns above the lower-level Jido runtime and package stack.

## Boundary Lines

- Owns its DSL, guardrail, AgentView, and harness-level runtime composition.
- Depends on core Jido, AI, memory, browser, MCP, and workflow packages.
- Does not define the canonical low-level Jido runtime contracts.

## Major Components

### Agent DSL

Provides higher-level authoring surfaces for defining agent behavior.

### Guardrails

Includes input, output, and tool guardrail modules for runtime boundaries.

### AgentView And Tracing

Explores observability and capture patterns for understanding agent execution.
