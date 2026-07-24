%{
  name: "jido_code",
  title: "Jido Code",
  graph_label: "Jido Code",
  version: "0.1.0",
  tagline: "Terminal-native AI coding assistant built on the Jido agent framework",
  license: "Apache-2.0",
  visibility: :public,
  category: :tools,
  atlas_facet: :developer_ux,
  tier: 2,
  tags: [:coding, :terminal, :tui, :assistant, :tools],
  github_url: "https://github.com/agentjido/jido_code",
  github_org: "agentjido",
  github_repo: "jido_code",
  tech_lead: "@mikehostetler",
  maturity: :beta,
  support_level: :beta,
  hex_status: "unreleased",
  api_stability: "unstable — expect breaking changes",
  stub: false,
  support: :best_effort,
  limitations: [
    "Not published to Hex — available only via GitHub dependency",
    "Terminal UI depends on TermUI which may have platform-specific issues",
    "Knowledge graph foundation is early-stage"
  ],
  ecosystem_deps: ["jido", "jido_ai"],
  key_features: [
    "Terminal-native AI assistant with Elm Architecture TUI and streaming responses",
    "Multi-provider LLM support — Anthropic, OpenAI, and any JidoAI provider with runtime switching",
    "Chain-of-Thought reasoning with automatic complexity detection",
    "16 built-in tools — file I/O, search, shell, web fetch, Livebook editing, task spawning",
    "Multi-session workspaces with isolated contexts and persistence",
    "Defense-in-depth security — path boundaries, command allowlists, Lua sandboxing, domain restrictions",
    "Livebook .livemd file parsing, editing, and serialization",
    "Knowledge graph foundation with RDF-based semantic code understanding",
    "Sub-task delegation via isolated TaskAgents with independent LLM context",
    "Two-level settings system — global + project-specific with environment overrides"
  ],
  landing_summary: "Terminal-native AI coding assistant built on the Jido agent framework",
  landing_use_when: ["You want ready-made tool Actions for an agent."],
  landing_not_for: ["You need tools this package does not provide.", "Beta — verify against your Jido version before production use."]
}
---
## Overview

Jido Code is an agentic coding assistant that runs entirely in your terminal, built on the Jido autonomous agent framework. It combines LLM-powered chat with a rich set of sandboxed tools — file operations, search, shell commands, web fetching, and Livebook editing — all wrapped in an Elm Architecture TUI with real-time streaming, Chain-of-Thought reasoning, and multi-session support.

Unlike hosted coding assistants, Jido Code is self-hosted and provider-agnostic. It supports Anthropic, OpenAI, and any provider registered through JidoAI, with runtime switching between models. Its multi-layered security model ensures the agent can only operate within your project's boundaries, making it safe for autonomous tool use.

## Purpose

Jido Code is the Jido ecosystem's coding agent — an interactive, terminal-based AI assistant that demonstrates the full capabilities of the Jido agent framework in a real-world developer tool. It serves as both a practical coding assistant and a reference implementation.

## Major Components

### TUI Layer
Elm Architecture terminal interface built on TermUI with conversation view, session tabs, sidebar, markdown rendering with syntax highlighting, and keyboard shortcuts.

### Agent Layer
LLMAgent wrapping JidoAI's agent system for chat interactions, streaming, tool dispatch, and conversation history. TaskAgent for isolated sub-task execution with independent LLM context.

### Tool System
16 tools with ETS-backed registry, executor with timeout enforcement, and Lua sandbox for secure script execution. Covers file read/write/edit, directory listing, search, shell, Livebook, web, todo, and task operations.

### Security Layer
Multi-layered enforcement: path validation against project boundaries, shell command allowlists, protected settings files, web domain restrictions, and Lua sandbox with restricted stdlib.

### Session System
Multi-session support with DynamicSupervisor lifecycle management, per-session state and persistence, and isolated security boundaries.
