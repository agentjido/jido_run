%{
  name: "jido_sandbox",
  title: "Jido Sandbox",
  graph_label: "Jido Sandbox",
  version: "0.1.0",
  tagline: "Deprecated sandbox package retained for historical reference",
  license: "Apache-2.0",
  visibility: :private,
  category: :tools,
  tier: 2,
  tags: [:sandbox, :security, :vfs, :lua, :tools],
  hex_url: "https://hex.pm/packages/jido_sandbox",
  hexdocs_url: "https://hexdocs.pm/jido_sandbox",
  github_url: "https://github.com/agentjido/jido_sandbox",
  github_org: "agentjido",
  github_repo: "jido_sandbox",
  maturity: :experimental,
  support_level: :experimental,
  hex_status: "unreleased",
  api_stability: "unstable — expect breaking changes",
  stub: false,
  support: :best_effort,
  limitations: [
    "Deprecated and removed from the public ecosystem atlas",
    "Not published to Hex — available only via GitHub dependency",
    "Lua runtime has restricted stdlib — no os, io, package, or debug modules",
    "VFS is in-memory only with no disk persistence"
  ],
  ecosystem_deps: [],
  key_features: [
    "Pure in-memory virtual filesystem with no real filesystem access",
    "Sandboxed Lua execution with VFS bindings and dangerous globals removed",
    "Snapshot and restore for speculative execution and rollback",
    "Path traversal protection with validation and normalization",
    "Schema-validated inputs via Zoi for LLM tool-calling integration",
    "Pluggable VFS backend via behaviour abstraction",
    "POSIX-like directory semantics with parent validation and delete protection",
    "Lua-VFS integration with state propagation through the vfs namespace",
    "Zero-process architecture — pure data structure, no GenServer or ETS",
    "Usage rules documentation for LLM tool builders"
  ],
  landing_summary: "Deprecated sandbox package retained for historical reference",
  landing_use_when: ["You want ready-made tool Actions for an agent."],
  landing_not_for: ["You need tools this package does not provide.", "Not production-ready; APIs may change."]
}
---
## Overview

Jido Sandbox is a lightweight, pure-BEAM sandbox designed for safely executing LLM tool calls. It provides an in-memory virtual filesystem (VFS) paired with a hardened Lua scripting runtime, giving AI agents a controlled environment to read, write, and manipulate files without ever touching the real filesystem, network, or operating system.

By combining a fully virtual filesystem with sandboxed Lua execution, Jido Sandbox ensures that LLM-generated code can run freely without risk of side effects. Snapshot and restore capabilities allow agents to experiment with state changes and roll back instantly, enabling safe exploration and speculative execution patterns.

## Purpose

Jido Sandbox serves as the secure execution boundary in the Jido ecosystem. When LLM agents need to perform file operations or execute scripts as part of tool calls, Jido Sandbox provides a completely isolated environment — no real filesystem access, no networking, no shell commands.

## Major Components

### Public API
Top-level module delegating to the core Sandbox struct: `new/1`, `write/3`, `read/2`, `list/2`, `delete/2`, `mkdir/2`, `snapshot/1`, `restore/2`, and `eval_lua/2`.

### VFS
Behaviour-based virtual filesystem with an in-memory implementation storing files as path-to-binary maps. Supports full POSIX-like semantics including parent directory validation and non-empty directory delete protection.

### Path Validation
Security-focused path normalization enforcing absolute paths, blocking traversal attacks, collapsing duplicate slashes, and providing parent/basename utilities.

### Lua Runtime
Restricted Lua environment via the `lua` library with VFS userdata injection, API bindings for the `vfs` namespace, and stripped dangerous globals (`os`, `io`, `package`, `debug`).

### Schemas
Zoi-based input validation for all LLM tool inputs with absolute path requirements, traversal attack blocking, and clear error messages.
