%{
  name: "ash_jido",
  title: "Ash Jido",
  graph_label: "Ash Jido",
  version: "0.1.0",
  tagline: "Compile-time bridge from Ash Framework resources to Jido Action modules",
  license: "Apache-2.0",
  visibility: :public,
  category: :integrations,
  atlas_facet: :framework_bridges,
  tier: 2,
  tags: [:ash, :bridge, :code_generation, :actions],
  github_url: "https://github.com/agentjido/ash_jido",
  github_org: "agentjido",
  github_repo: "ash_jido",
  tech_lead: "@mikehostetler",
  maturity: :stable,
  support_level: :stable,
  hex_status: "unreleased",
  api_stability: "stable — supported integration surface with Hex packaging still pending",
  stub: false,
  support: :maintained,
  limitations: [
    "Not published to Hex — available only via GitHub dependency",
    "Tied to specific Ash Framework and Jido versions",
    "Does not auto-discover Ash domains — requires explicit DSL configuration"
  ],
  ecosystem_deps: ["jido", "jido_action"],
  key_features: [
    "Zero-boilerplate Ash-to-Jido bridging via a declarative jido DSL block",
    "Compile-time code generation — all action modules generated at compile time",
    "Smart default naming — auto-generates intuitive action names based on type and resource",
    "Bulk action exposure with only/except filters",
    "Full Ash context support — domain, actor, and tenant flow through to operations",
    "Ash authorization preserved — does not bypass policies or validations",
    "Typed parameter schemas from Ash attributes and action arguments",
    "Configurable struct-to-map conversion for AI/LLM consumption",
    "Comprehensive error translation from Ash to Jido's Splode hierarchy",
    "Igniter-powered installation for automated setup"
  ],
  landing_summary: "Compile-time bridge from Ash Framework resources to Jido Action modules",
  landing_use_when: ["You are integrating Jido with another framework or service."],
  landing_not_for: ["You are not using the framework this package integrates with."]
}
---
## Overview

AshJido is a compile-time bridge between the Ash Framework and the Jido agent ecosystem. It adds a declarative `jido` DSL section to Ash resources that automatically generates `Jido.Action` modules from Ash actions, enabling any Ash resource to be called as an AI tool while preserving Ash's authorization policies, data layers, and type safety.

The library is intentionally thin (~400 LOC) and unopinionated — it does not auto-discover domains, inject pagination logic, or bypass Ash authorization. Instead, it provides a clean, zero-boilerplate way to expose existing Ash CRUD and custom actions to Jido agents, letting developers choose exactly which actions to surface and how they should be named and tagged for AI discovery.

## Purpose

AshJido makes any Ash Framework resource instantly usable by Jido agents. Ash is the dominant declarative data/resource framework in Elixir — by bridging it to Jido, developers can turn their existing Ash resources into AI-callable actions with a few lines of DSL configuration rather than writing manual adapter code.

## Major Components

### Spark DSL Extension
The entry point added as an extension to any Ash resource. Registers the `jido` DSL section with `action` (expose a single named Ash action) and `all_actions` (bulk-expose with filters) entity types.

### Compile-Time Transformer
A Spark DSL transformer that runs after Ash finalizes its DSL, expanding `all_actions` declarations and generating `Jido.Action` modules under a `Resource.Jido.*` namespace.

### Type Mapper
Converts Ash attribute types into NimbleOptions schema types for proper typed parameter validation in generated Jido actions.

### Result Mapper
Handles converting Ash operation results into Jido-friendly formats, with configurable struct-to-map conversion via the `output_map?` option.

### Error Translation
Converts Ash error types into Jido's Splode-based error system with field-level detail extraction.
