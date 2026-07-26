%{
name: "jido_otel",
title: "Jido OTEL",
graph_label: "Jido OTEL",
version: "0.1.0",
tagline: "OpenTelemetry tracer bridge for Jido.Observe instrumentation",
license: "Apache-2.0",
visibility: :public,
category: :integrations,
atlas_facet: :observability,
tier: 2,
tags: [:opentelemetry, :observability, :tracing, :telemetry],
github_url: "https://github.com/agentjido/jido_otel",
github_org: "agentjido",
github_repo: "jido_otel",
tech_lead: "@mikehostetler",
elixir: "~> 1.18",
maturity: :beta,
support_level: :beta,
hex_status: "unreleased",
api_stability: "unstable - integration package still maturing",
stub: false,
support: :best_effort,
limitations: [
"Not published to Hex - available via GitHub dependency",
"Tied to current Jido Observe and OpenTelemetry APIs",
"Instrumentation defaults may evolve as tracing conventions stabilize"
],
control_capabilities: [
"OpenTelemetry export — bridges Jido.Observe spans and events into OTel span names, attributes, and exception events and exports them over OTLP to a collector you operate. It is an exporter, not the source of observation — the events it exports are emitted by jido core."
],
control_limitations: [
"Does not serve as an audit record — exported spans are distributed traces for a collector, not tamper-evident history. Durable, replayable audit is the separate jido_signal Signal Journal.",
"Experimental and not published to Hex — verify against your Jido version before relying on it in production."
],
ecosystem_deps: ["jido"],
key_features: [
"Implements Jido.Observe tracer bridge for OpenTelemetry",
"Maps Jido event prefixes into span naming conventions",
"Converts metadata and measurements into OTel attributes",
"Captures Jido exceptions as OTel exception events",
"Includes runtime app startup and telemetry wiring patterns"
],
  landing_summary: "OpenTelemetry tracer bridge for Jido.Observe instrumentation",
  landing_use_when: ["You are integrating Jido with another framework or service."],
  landing_not_for: ["You are not using the framework this package integrates with.", "Beta — verify against your Jido version before production use."]
}

---

## Overview

Jido Otel integrates Jido observability events with the OpenTelemetry ecosystem so traces can flow into standard tooling stacks.

## Purpose

Jido Otel is the OTel bridge package for teams running Jido in environments with centralized tracing requirements.

## Major Components

### Tracer Bridge

Implements `Jido.Observe.Tracer` with OpenTelemetry-backed span emission.

### Attribute Mapping

Transforms Jido telemetry metadata and measurements into OTel-compatible attributes.

### Runtime Integration

Includes application wiring patterns for initializing tracing at startup.
