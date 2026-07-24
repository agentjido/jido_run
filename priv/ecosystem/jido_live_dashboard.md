%{
  name: "jido_live_dashboard",
  title: "Jido Live Dashboard",
  graph_label: "Jido Live Dashboard",
  version: "0.1.0",
  tagline: "Real-time observability and debugging for Jido agents in Phoenix LiveDashboard",
  license: "Apache-2.0",
  visibility: :public,
  category: :tools,
  atlas_facet: :developer_ux,
  tier: 2,
  tags: [:dashboard, :observability, :debugging, :liveview],
  hexdocs_url: "https://hexdocs.pm/jido_live_dashboard",
  github_url: "https://github.com/agentjido/jido_live_dashboard",
  github_org: "agentjido",
  github_repo: "jido_live_dashboard",
  tech_lead: "@mikehostetler",
  elixir: "~> 1.17",
  maturity: :beta,
  support_level: :beta,
  hex_status: "unreleased",
  api_stability: "unstable — expect breaking changes",
  stub: false,
  support: :best_effort,
  limitations: [
    "Not published to Hex — available only via GitHub dependency",
    "Dashboard pages are functional but UI polish is ongoing",
    "Trace buffer is in-memory only with no persistence"
  ],
  ecosystem_deps: ["jido"],
  key_features: [
    "Zero-config integration — one function call adds all monitoring pages",
    "Automatic telemetry capture for 13 Jido event patterns",
    "ETS ring buffer for high-performance event storage",
    "Trace correlation with trace_id/span_id linking",
    "Live process enumeration of running AgentServers",
    "Per-agent state introspection from the dashboard",
    "WorkerPool and InstanceManager monitoring",
    "Discovery catalog browsing for Actions, Agents, Skills, and Sensors"
  ],
  landing_summary: "Real-time observability and debugging for Jido agents in Phoenix LiveDashboard",
  landing_use_when: ["You want ready-made tool Actions for an agent."],
  landing_not_for: ["You need tools this package does not provide.", "Beta — verify against your Jido version before production use."]
}
---
## Overview

Jido Live Dashboard is a real-time observability and debugging toolkit for the Jido agent ecosystem, built as a native extension to Phoenix LiveDashboard. A single call to `JidoLiveDashboard.pages()` adds four purpose-built dashboard pages covering system health, component discovery, runtime process inspection, and distributed trace analysis.

## Purpose

Jido Live Dashboard serves as the observability layer for the Jido ecosystem. It answers: What components are registered? Which agents are running? What happened during that signal flow?

## Major Components

### Dashboard Pages
- **Home** — System status, discovery catalog summary, running agents, trace buffer stats
- **Discovery** — Tabbed browser for Actions, Agents, Skills, Sensors, and Demos
- **Runtime** — Live AgentServer process table, WorkerPool status, InstanceManager stats
- **Traces** — Telemetry event viewer with span hierarchy, measurements, and metadata

### TraceBuffer
GenServer with ETS ring buffer capturing 13 Jido telemetry event patterns with trace_id/span_id correlation, configurable buffer sizes, and automatic pruning.

### Runtime Introspection
Fault-tolerant functions for querying live Jido infrastructure: agent enumeration, state inspection, pool status, and discovery catalog queries.
