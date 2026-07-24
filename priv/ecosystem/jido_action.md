%{
  name: "jido_action",
  title: "Jido Action",
  graph_label: "Jido Action",
  version: "2.2.1",
  tagline: "Composable, validated command pattern for Elixir with built-in AI tool integration",
  license: "Apache-2.0",
  visibility: :public,
  category: :core,
  atlas_facet: :primitives,
  tier: 1,
  tags: [:actions, :tools, :ai, :workflow],
  hex_url: "https://hex.pm/packages/jido_action",
  hexdocs_url: "https://hexdocs.pm/jido_action",
  github_url: "https://github.com/agentjido/jido_action",
  github_org: "agentjido",
  github_repo: "jido_action",
  tech_lead: "@mikehostetler",
  elixir: "~> 1.17",
  maturity: :stable,
  support_level: :stable,
  hex_status: "2.2.1",
  api_stability: "evolving — 2.0 shipped, but expect continued API refinements across early 2.x",
  stub: false,
  support: :maintained,
  limitations: [
    "Early 2.x hardening may still introduce focused breaking changes",
    "2.0.0 introduced breaking changes from 1.x — review migration notes before upgrading"
  ],
  ecosystem_deps: [],
  key_features: [
    "Structured action definition with compile-time validation and rich metadata",
    "Dual schema validation — NimbleOptions and Zoi with type coercion",
    "AI tool integration — automatic conversion to OpenAI function calling format",
    "Robust execution engine with retries, timeouts, and process monitoring",
    "Error compensation with optional rollback callbacks",
    "Action chaining for sequential execution with output piping",
    "DAG-based workflow planning with dependency management",
    "25+ pre-built tools covering file I/O, HTTP, GitHub, weather, and more",
    "Sandboxed Lua evaluation for untrusted code execution"
  ],
  landing_summary: "Composable, validated command pattern for Elixir with built-in AI tool integration",
  landing_use_when: ["You are building an agent and need the Agent model, validated Actions, Signals, Directives, and the OTP runtime."],
  landing_not_for: ["You only need a thin LLM call without an agent model."]
}
---
## Overview

Jido Action is the foundational action framework for the Jido ecosystem — a composable, validated command pattern for Elixir applications with built-in AI tool integration. It provides a standardized way to define discrete units of functionality that can be validated at compile and runtime, composed into complex workflows, and automatically converted into LLM-compatible tool definitions for AI agent integration.

## Purpose

Jido Action serves as the **Base Agentic Command Pattern & Tools SDK** for the Jido ecosystem. It defines the universal interface through which all agent capabilities are expressed — every action an agent can take is a `Jido.Action`. The package provides the contract (schema validation, lifecycle hooks, error handling) and the execution machinery (sync/async execution, retries, timeouts, compensation) that the rest of the ecosystem builds upon.

## Major Components

### `Jido.Action` — Core Behavior
The foundational behaviour module that all actions implement via `use Jido.Action`. Provides compile-time configuration validation, runtime parameter and output schema validation, lifecycle hooks, metadata, and automatic JSON serialization. Every action implements a single `run/2` callback.

### `Jido.Exec` — Execution Engine
Modular execution engine supporting synchronous and asynchronous execution, automatic retries with exponential backoff, timeout handling, parameter/output validation, telemetry integration, error compensation, action chaining, closures, and instance-scoped supervision.

### `Jido.Instruction` — Workflow Composition
Wraps actions with params, context, and runtime options to create discrete work orders. Supports multiple creation formats, normalization, and action allowlist validation.

### `Jido.Plan` — DAG Execution Planning
Directed Acyclic Graph-based execution planning for complex workflows with dependency declarations, parallel execution phases, and cycle detection.

### `Jido.Action.Tool` — AI Tool Conversion
Converts any Jido Action into a standardized tool map compatible with LLM function calling (OpenAI format) with automatic JSON Schema generation.

### Pre-built Tools
25+ tools organized by domain: Basic utilities, Arithmetic, File operations, HTTP requests (Req), GitHub Issues (Tentacat), Weather (NWS API), Workflow primitives, Lua evaluation, and more.
