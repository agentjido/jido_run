%{
  name: "jido_cluster",
  title: "Jido Cluster",
  graph_label: "Jido Cluster",
  version: "0.1.0",
  tagline: "Distributed keyed instance management and storage for multi-node Jido runtimes",
  license: "Apache-2.0",
  visibility: :public,
  category: :runtime,
  atlas_facet: :distributed,
  tier: 2,
  tags: [:cluster, :distributed, :runtime, :storage, :agents],
  github_url: "https://github.com/agentjido/jido_cluster",
  github_org: "agentjido",
  github_repo: "jido_cluster",
  tech_lead: "@mikehostetler",
  elixir: "~> 1.18",
  maturity: :experimental,
  support_level: :experimental,
  hex_status: "unreleased",
  api_stability: "unstable - distributed runtime and storage APIs are pre-1.0",
  stub: false,
  support: :best_effort,
  limitations: [
    "Not published to Hex - available via GitHub dependency",
    "Rebalancing defaults are intentionally conservative and may require tuning",
    "Operational guidance for production multi-node deployments is still maturing"
  ],
  ecosystem_deps: ["jido"],
  key_features: [
    "Global singleton semantics per cluster key across connected nodes",
    "Deterministic owner-node placement via rendezvous hashing",
    "Cross-node lookup, call, cast, and stop operations by key",
    "Conservative ownership rebalancing with configurable migration limits",
    "Shared storage adapters for ETS, Mnesia, Bedrock, and Postgres-backed persistence"
  ],
  landing_summary: "Distributed keyed instance management and storage for multi-node Jido runtimes",
  landing_use_when: ["You need runtime infrastructure (persistence, scheduling, or observability) for a deployed agent."],
  landing_not_for: ["You are still prototyping and do not yet run agents long-term.", "Not production-ready; APIs may change."]
}
---
## Overview

Jido Cluster provides a distributed runtime layer for keyed Jido agent instances across multiple BEAM nodes. It adds ownership, routing, and recovery patterns on top of Jido instance management for multi-node deployments.

## Purpose

Jido Cluster is the distributed runtime package for teams running Jido agents beyond a single node.

## Boundary Lines

- Owns distributed instance ownership, node routing, and rebalancing mechanics for keyed agents.
- Provides cluster-aware storage adapter surfaces for cross-node recovery flows.
- Does not replace core agent contracts, action semantics, or provider-specific integration packages.

## Major Components

### Cluster Instance Manager

`Jido.Cluster.InstanceManager` coordinates keyed ownership and lifecycle operations for instances across connected nodes.

### Routing and Ownership

Uses deterministic owner resolution and cross-node call/cast APIs to route operations to the correct runtime node.

### Rebalancing Loop

Includes conservative periodic migration controls so ownership can adapt without aggressive movement.

### Storage Integrations

Provides cluster-friendly storage adapter options for shared persistence in distributed runtime topologies.
