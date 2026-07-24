%{
  name: "jido_messaging",
  title: "Jido Messaging",
  graph_label: "Jido Messaging",
  version: "0.1.0",
  tagline: "Platform-agnostic messaging for AI agents across Telegram, Discord, Slack, and WhatsApp",
  license: "Apache-2.0",
  visibility: :public,
  category: :integrations,
  atlas_facet: :chat,
  tier: 2,
  tags: [:messaging, :telegram, :discord, :slack, :whatsapp, :chat],
  github_url: "https://github.com/agentjido/jido_messaging",
  github_org: "agentjido",
  github_repo: "jido_messaging",
  tech_lead: "@mikehostetler",
  maturity: :beta,
  support_level: :beta,
  hex_status: "unreleased",
  api_stability: "unstable — expect breaking changes",
  stub: false,
  support: :best_effort,
  limitations: [
    "Not published to Hex — available only via GitHub dependency",
    "Channel adapters (Telegram, Discord, Slack, WhatsApp) vary in completeness",
    "No production persistence backend ships by default"
  ],
  ecosystem_deps: ["jido", "jido_signal", "jido_ai"],
  key_features: [
    "Channel-agnostic messaging — write once, deploy to Telegram, Discord, Slack, WhatsApp",
    "AI agents as first-class participants alongside human users",
    "LLM-native message model with roles, tool calls, and tool results",
    "Ingest/deliver pipeline with deduplication, gating, and moderation",
    "Streaming responses with rate-limited progressive message updates",
    "Pure Elixir core with pluggable persistence — runs fully in-memory or with custom backends",
    "OTP-native architecture with GenServer per room and DynamicSupervisors",
    "Multi-instance isolation with per-instance supervision trees",
    "Composable moderation with keyword filter and rate limiter",
    "Dual observability — telemetry metrics and Jido Signal CloudEvents"
  ],
  landing_summary: "Platform-agnostic messaging for AI agents across Telegram, Discord, Slack, and WhatsApp",
  landing_use_when: ["You are integrating Jido with another framework or service."],
  landing_not_for: ["You are not using the framework this package integrates with.", "Beta — verify against your Jido version before production use."]
}
---
## Overview

Jido Messaging is a platform-agnostic messaging system that enables AI agents and humans to communicate across multiple messaging platforms through a unified, pure-Elixir API. It provides a channel-agnostic abstraction layer where conversations are modeled as rooms containing messages from participants — with AI agents as first-class citizens alongside human users. Messages use an LLM-native content structure (roles, tool calls, tool results) that maps directly to LLM context formats.

Built on OTP principles with GenServers, Supervisors, Registries, and ETS, Jido Messaging delivers fault-tolerant, isolated messaging instances that can run entirely in-memory for testing or connect to production persistence backends.

## Purpose

Jido Messaging serves as the communication layer in the Jido ecosystem, bridging Jido AI agents and external chat systems. It allows agents to participate in conversations on any supported messaging platform — responding to messages, using tools, streaming responses, and collaborating with human users — through a single, consistent API.

## Major Components

### Core Domain Model
Message struct with role-based identification and rich content blocks, Room conversation containers, Participant entities for humans/agents/systems, and Instance channel connection descriptors.

### Channel System
Behaviour-based platform adapters for Telegram (via Telegex), Discord (via Nostrum), Slack (via slack_elixir), and WhatsApp (via whatsapp_elixir). Plugin registry with capability declarations and content filtering.

### Message Pipeline
Ingest pipeline for inbound normalization with deduplication and room/participant resolution. Deliver pipeline for outbound delivery with status tracking. Streaming GenServer for rate-limited progressive updates.

### Agent Integration
AgentRunner GenServer managing agent participation per room with configurable triggers (all, mention, prefix). AgentSupervisor for lifecycle management.

### Room & Instance Management
RoomServer for per-room state with bounded history, presence, typing, reactions, and read receipts. InstanceServer for channel connection lifecycle state machines.
