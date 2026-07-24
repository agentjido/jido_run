%{
  name: "jido_mcp",
  title: "Jido MCP",
  graph_label: "Jido MCP",
  version: "0.1.1",
  tagline: "MCP server integration package with pooled clients and Jido action surfaces",
  license: "Apache-2.0",
  visibility: :public,
  category: :integrations,
  atlas_facet: :protocols,
  tier: 2,
  tags: [:mcp, :tools, :resources, :prompts, :integrations],
  github_url: "https://github.com/agentjido/jido_mcp",
  github_org: "agentjido",
  github_repo: "jido_mcp",
  tech_lead: "@mikehostetler",
  elixir: "~> 1.18",
  maturity: :beta,
  support_level: :beta,
  hex_status: "unreleased",
  api_stability: "unstable - pre-1.0 MCP endpoint and action APIs may change",
  stub: false,
  support: :best_effort,
  limitations: [
    "Not published to Hex - available via GitHub dependency",
    "Currently focused on stdio and streamable HTTP MCP transport modes",
    "Endpoint configuration and runtime defaults may evolve with MCP protocol changes"
  ],
  ecosystem_deps: ["jido"],
  key_features: [
    "Pooled MCP client connections per configured endpoint",
    "Consume-side APIs for tools, resources, prompts, and template discovery",
    "Normalized success/error envelopes for MCP calls",
    "Jido actions and plugin routes for signal-driven MCP usage",
    "Bridge support for exposing MCP servers with explicit allowlists"
  ],
  landing_summary: "MCP server integration package with pooled clients and Jido action surfaces",
  landing_use_when: ["You are integrating Jido with another framework or service."],
  landing_not_for: ["You are not using the framework this package integrates with.", "Beta — verify against your Jido version before production use."]
}
---
## Overview

Jido MCP integrates MCP servers into the Jido ecosystem through pooled client connections, normalized call envelopes, and action/plugin surfaces that fit existing Jido agent workflows.

## Purpose

Jido MCP is the MCP interoperability package for connecting Jido agents to external tool/resource/prompt servers.

## Boundary Lines

- Owns MCP endpoint lifecycle, transport wiring, and normalized result envelopes.
- Exposes MCP operations through Jido-friendly APIs, actions, and plugin routes.
- Does not own provider-neutral orchestration policy, non-MCP adapter contracts, or application-specific permission governance.

## Major Components

### Endpoint Client Pool

Manages reusable MCP client connections per configured endpoint and transport.

### Consume APIs

Provides typed operations for listing/calling tools, reading resources, and retrieving prompts.

### Action and Plugin Integration

Ships Jido action modules and plugin wiring so MCP operations can be used from signal-driven agents.

### Server Bridge

Supports bridging MCP server surfaces with explicit allowlists for controlled exposure.
