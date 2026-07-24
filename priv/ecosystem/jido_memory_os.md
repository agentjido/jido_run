%{
  name: "jido_memory_os",
  title: "Jido MemoryOS",
  graph_label: "Jido MemoryOS",
  version: "0.1.0",
  tagline: "Deprecated memory orchestration layer retained for historical reference",
  license: "Apache-2.0",
  visibility: :private,
  category: :ai,
  atlas_facet: :memory,
  tier: 2,
  tags: [:memory, :agents, :retrieval, :governance, :context],
  github_url: "https://github.com/agentjido/jido_memory_os",
  github_org: "agentjido",
  github_repo: "jido_memory_os",
  tech_lead: "@pcharbon70",
  elixir: "~> 1.19",
  maturity: :experimental,
  support_level: :experimental,
  hex_status: "unreleased",
  api_stability: "deprecated - use jido_memory for active memory work",
  stub: false,
  support: :best_effort,
  limitations: [
    "Deprecated and removed from the public ecosystem atlas",
    "Not published to Hex - available via GitHub dependency",
    "Depends on active integration points with `jido_memory` and core runtime packages",
    "Governance and rollout controls are broad and may require project-specific tuning"
  ],
  ecosystem_deps: ["jido", "jido_action", "jido_memory"],
  key_features: [
    "Tiered memory model (`short`, `mid`, `long`) with lifecycle promotion controls",
    "Control plane for scheduling, retries, idempotency, and replay operations",
    "Explainable retrieval pipeline with ranking and context packaging",
    "Governance features including policy checks, approvals, masking, and audit logging",
    "Plugin/action integration surfaces for signal-driven runtime workflows"
  ],
  landing_summary: "Deprecated memory orchestration layer retained for historical reference",
  landing_use_when: ["You want to add LLM reasoning or tool-calling to an agent."],
  landing_not_for: ["Your agent has no LLM component (core Jido needs no LLM).", "Not production-ready; APIs may change."]
}
---
## Overview

Jido MemoryOS is a tiered memory orchestration layer built on top of `jido_memory` for agent context management. It combines retrieval, lifecycle control, and governance concerns into a coordinated memory operating layer.

## Purpose

Jido MemoryOS provides higher-level memory orchestration for Jido agents that need lifecycle-aware retrieval and policy controls beyond base memory primitives.

## Boundary Lines

- Owns tiered memory lifecycle orchestration, retrieval planning/ranking, and governance controls.
- Integrates with core Jido runtime surfaces through plugin and action entry points.
- Does not replace low-level agent execution contracts or external provider/runtime adapter responsibilities.

## Major Components

### Memory Manager Control Plane

Coordinates queueing, retries, idempotency, and operation scheduling for memory workflows.

### Tiered Lifecycle Model

Manages short/mid/long memory promotion and consolidation with lineage-aware behavior.

### Retrieval and Explainability

Implements retrieval planning, ranking, and explain payload generation for context assembly.

### Governance and Safety

Applies policy enforcement, approvals, retention controls, masking, and auditing around memory operations.
