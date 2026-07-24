%{
  name: "jido_character",
  title: "Jido Character",
  graph_label: "Jido Character",
  version: "1.0.0",
  tagline: "Composable character definitions and context rendering for AI agents",
  license: "Apache-2.0",
  visibility: :public,
  category: :ai,
  atlas_facet: :reasoning_models,
  tier: 2,
  tags: [:character, :persona, :prompting, :ai],
  github_url: "https://github.com/agentjido/jido_character",
  github_org: "agentjido",
  github_repo: "jido_character",
  tech_lead: "@mikehostetler",
  elixir: "~> 1.17",
  maturity: :stable,
  support_level: :stable,
  hex_status: "unreleased",
  api_stability: "stable — supported character/context layer with Hex packaging still pending",
  stub: false,
  support: :maintained,
  limitations: [
    "Hex package not currently published",
    "Prompt rendering conventions may evolve as req_llm integrations expand",
    "Persistence adapters are intentionally minimal by default"
  ],
  ecosystem_deps: ["req_llm"],
  key_features: [
    "Zoi-validated schemas for identity, voice, memory, and knowledge",
    "Immutable updates with version tracking",
    "`use Jido.Character` macro for reusable templates",
    "Direct rendering to req_llm context payloads",
    "Pluggable persistence adapter pattern with in-memory defaults"
  ],
  landing_summary: "Composable character definitions and context rendering for AI agents",
  landing_use_when: ["You want to add LLM reasoning or tool-calling to an agent."],
  landing_not_for: ["Your agent has no LLM component (core Jido needs no LLM)."]
}
---
## Overview

Jido Character defines a structured way to model agent personas and render them into LLM-ready context. It helps teams keep identity, style, and memory constraints explicit instead of scattering prompt fragments across the codebase.

## Purpose

Jido Character is the persona and context layer for agent workflows built with Jido and ReqLLM.

## Major Components

### Core Character API

Create, update, and validate character definitions as immutable data.

### Rendering

Convert character data into deterministic prompt/context blocks for model requests.

### Persistence

Adapter-based persistence lets applications choose memory-only or custom storage backends.
