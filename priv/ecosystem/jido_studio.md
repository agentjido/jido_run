%{
  name: "jido_studio",
  title: "Jido Studio",
  graph_label: "Jido Studio",
  version: "0.1.0",
  tagline: "Embeddable LiveView dashboard for managing and debugging Jido agents",
  license: "Apache-2.0",
  visibility: :public,
  category: :runtime,
  atlas_facet: :applications,
  tier: 2,
  tags: [:studio, :dashboard, :liveview, :debugging],
  github_url: "https://github.com/agentjido/jido_studio",
  github_org: "agentjido",
  github_repo: "jido_studio",
  tech_lead: "@mikehostetler",
  elixir: "~> 1.18",
  maturity: :beta,
  support_level: :beta,
  hex_status: "unreleased",
  api_stability: "unstable - extension API and UI surface may change",
  stub: false,
  support: :best_effort,
  limitations: [
    "Not published to Hex - available via GitHub dependency",
    "Depends on Phoenix LiveView host application integration",
    "Extension points are still evolving"
  ],
  ecosystem_deps: ["jido", "jido_ai"],
  key_features: [
    "Mountable dashboard UX for agent management in Phoenix",
    "Standalone package approach with minimal host-app coupling",
    "Operational visibility into agent state and workflow activity",
    "Optional extension pages compiled when companion packages are present",
    "Designed for production-style debugging and control loops"
  ],
  landing_summary: "Embeddable LiveView dashboard for managing and debugging Jido agents",
  landing_use_when: ["You need runtime infrastructure (persistence, scheduling, or observability) for a deployed agent."],
  landing_not_for: ["You are still prototyping and do not yet run agents long-term.", "Beta — verify against your Jido version before production use."]
}
---
## Overview

Jido Studio is an embeddable LiveView dashboard package for operating and debugging Jido-based systems inside Phoenix applications.

## Purpose

Jido Studio brings an operator-facing UI to agent lifecycle management, observability, and interactive debugging workflows.

## Major Components

### Router Integration

Mounts into host Phoenix routers as a self-contained studio surface.

### Dashboard Views

Provides runtime views for inspecting agent behavior and troubleshooting workflows.

### Extension Model

Supports optional package-specific pages when corresponding integrations are available.
