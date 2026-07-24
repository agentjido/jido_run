%{
  name: "jido_command",
  title: "Jido Command",
  graph_label: "Jido Command",
  version: "0.1.0",
  tagline: "Deprecated slash-command runtime retained for historical reference",
  license: "Apache-2.0",
  visibility: :private,
  category: :tools,
  tier: 2,
  tags: [:commands, :cli, :signals, :markdown, :runtime],
  github_url: "https://github.com/agentjido/jido_command",
  github_org: "agentjido",
  github_repo: "jido_command",
  elixir: "~> 1.19",
  maturity: :experimental,
  support_level: :experimental,
  hex_status: "unreleased",
  api_stability: "unstable - command schema and lifecycle event contracts may change",
  stub: false,
  support: :best_effort,
  limitations: [
    "Deprecated and removed from the public ecosystem atlas",
    "Not published to Hex - available via GitHub dependency",
    "Relies on markdown + frontmatter command definitions and local file conventions",
    "Hook lifecycle and dispatch contracts are still pre-1.0"
  ],
  ecosystem_deps: ["jido"],
  key_features: [
    "Markdown-defined command registry with YAML frontmatter metadata",
    "Signal-first dispatch (`command.invoke`, `command.completed`, `command.failed`)",
    "Strict command payload and permission object validation",
    "Runtime command register/unregister/reload APIs",
    "CLI and mix-task execution surfaces for local workflows"
  ],
  landing_summary: "Deprecated slash-command runtime retained for historical reference",
  landing_use_when: ["You want ready-made tool Actions for an agent."],
  landing_not_for: ["You need tools this package does not provide.", "Not production-ready; APIs may change."]
}
---
## Overview

Jido Command is a signal-first command runtime for markdown-defined command catalogs. It lets teams define command behavior in frontmatter-backed documents and invoke commands through API, signal bus, or CLI surfaces.

## Purpose

Jido Command is the slash-command package for structured command execution in Jido-based workflows.

## Boundary Lines

- Owns command registry loading, invocation validation, and command lifecycle signaling.
- Provides command execution surfaces for API calls, signal dispatch, and local CLI usage.
- Does not own general-purpose orchestration, provider-specific adapters, or agent memory/persistence strategy.

## Major Components

### Command Registry

Loads and manages markdown command definitions from configured roots with reload and runtime registration support.

### Validation Pipeline

Validates command names, params, context, and permission maps before invocation.

### Dispatch and Lifecycle Events

Publishes typed command lifecycle events so execution can be observed and integrated through signals.

### CLI Surface

Provides escript and mix-task entry points for invoking, listing, reloading, and monitoring command operations.
