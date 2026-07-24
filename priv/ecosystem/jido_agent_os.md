%{
  name: "jido_agent_os",
  title: "Jido AgentOS",
  graph_label: "Jido AgentOS",
  version: "0.1.0",
  tagline: "Experimental OTP-native kernel for running durable Jido pods inside host applications",
  license: "Apache-2.0",
  visibility: :public,
  category: :runtime,
  atlas_facet: :applications,
  tier: 3,
  tags: [:agents, :pods, :otp, :runtime, :phoenix],
  github_url: "https://github.com/agentjido/jido_agent_os",
  github_org: "agentjido",
  github_repo: "jido_agent_os",
  tech_lead: "@mikehostetler",
  elixir: "~> 1.19",
  maturity: :experimental,
  support_level: :experimental,
  hex_status: "unreleased",
  api_stability: "unstable - exploratory spike that may be rewritten, renamed, or discarded",
  stub: false,
  support: :best_effort,
  limitations: [
    "Exploratory spike - current API and structure should not be treated as durable",
    "Not published to Hex - available via GitHub dependency",
    "Issue intake is enabled, but compatibility commitments are intentionally limited"
  ],
  ecosystem_deps: ["jido", "jido_ai"],
  key_features: [
    "OTP-native kernel concept for durable Jido pods",
    "Kernel to pod to agent mental model for long-lived agent backends",
    "Phoenix host-shell guidance for separating product UI from durable runtime topology",
    "Plugin-first extension model built on existing Jido runtime concepts"
  ],
  landing_summary: "Experimental OTP-native kernel for running durable Jido pods inside host applications",
  landing_use_when: ["You need runtime infrastructure (persistence, scheduling, or observability) for a deployed agent."],
  landing_not_for: ["You are still prototyping and do not yet run agents long-term.", "Not production-ready; APIs may change."]
}
---
## Overview

Jido AgentOS explores an OTP-native kernel for running durable Jido pods inside a host application such as Phoenix. It treats `Jido.Agent` as the unit of behavior, `Jido.Pod` as the unit of durable topology, and AgentOS as the kernel layer that runs pods.

The repository is public so the design can be followed early, but it is still a spike. The current API, module layout, DSL shape, and documentation should not be treated as stable.

## Purpose

Jido AgentOS is for exploring long-lived multi-agent backends that can do useful work over time, such as coding, research, workflow, or operational agent teams.

## Boundary Lines

- Owns the experimental kernel and pod-hosting model above core Jido agents.
- Provides guidance for Phoenix and other host applications that wrap durable agent backends.
- Does not replace `Jido.Agent`, `Jido.Pod`, or the lower-level Jido runtime contracts.

## Major Components

### Kernel Model

Defines the conceptual host layer that supervises and operates durable pod topologies inside a larger application.

### Pod Runtime Exploration

Explores how a durable pod can act as the boundary line for a coherent agent team.

### Phoenix Host Pattern

Documents how Phoenix can act as the product shell while a sibling runtime namespace owns long-lived agent backend behavior.
