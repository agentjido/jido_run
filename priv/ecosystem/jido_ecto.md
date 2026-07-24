%{
  name: "jido_ecto",
  title: "Jido Ecto",
  graph_label: "Jido Ecto",
  version: "0.1.0",
  tagline: "Ecto-backed storage and persistence adapters for Jido",
  license: "Apache-2.0",
  visibility: :public,
  category: :integrations,
  atlas_facet: :storage,
  tier: 2,
  tags: [:ecto, :storage, :persistence, :database, :runtime],
  github_url: "https://github.com/agentjido/jido_ecto",
  github_org: "agentjido",
  github_repo: "jido_ecto",
  tech_lead: "@mikehostetler",
  elixir: "~> 1.18",
  maturity: :beta,
  support_level: :beta,
  hex_status: "unreleased",
  api_stability: "unstable - pre-1.0 storage and persistence APIs may change",
  stub: false,
  support: :best_effort,
  limitations: [
    "Not published to Hex - available via GitHub dependency",
    "Storage adapter contract and migrations are still stabilizing",
    "Database operational behavior depends on host application Ecto setup"
  ],
  ecosystem_deps: ["jido"],
  key_features: [
    "Ecto-backed storage and persistence adapters for Jido runtimes",
    "Supports SQL-backed runtime persistence through Ecto and Ecto SQL",
    "Includes PostgreSQL and SQLite test/development dependency coverage",
    "Provides package quality gates with coverage, Dialyzer, Credo, and docs",
    "Complements Bedrock storage by providing a familiar Ecto persistence path"
  ],
  landing_summary: "Ecto-backed storage and persistence adapters for Jido",
  landing_use_when: ["You are integrating Jido with another framework or service."],
  landing_not_for: ["You are not using the framework this package integrates with.", "Beta — verify against your Jido version before production use."]
}
---
## Overview

Jido Ecto provides Ecto-backed persistence adapters for Jido runtimes. It lets teams connect Jido storage behavior to familiar database-backed application infrastructure.

## Purpose

Jido Ecto is the Ecto storage integration package for teams that want database-backed persistence through standard Elixir application patterns.

## Boundary Lines

- Owns Ecto-specific persistence adapters and database integration behavior.
- Depends on host application database setup, migrations, and operational policy.
- Does not replace core Jido runtime contracts or define a general storage governance layer.

## Major Components

### Ecto Storage Adapter

Implements Jido persistence behavior on top of Ecto and Ecto SQL.

### Database Test Surface

Exercises adapter behavior against database-backed test dependencies.

### Package Quality Tooling

Includes coverage, Dialyzer, Credo, Doctor, docs, and release metadata for hardening.
