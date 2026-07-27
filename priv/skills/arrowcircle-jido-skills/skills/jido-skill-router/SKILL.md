---
name: jido-skill-router
description: Meta-skill for routing Jido ecosystem work to the right package skills. Use when Codex needs to choose between $jido, $jido-action, $jido-signal, $req-llm, $llm-db, $ash-jido, $jido-browser, $jido-memory, $jido-behaviortree, $jido-messaging, $jido-otel, or $jido-studio, or when a task spans several of them and needs a handoff order. Also use it for operational-control intent — authorization, audit, observability, policy, quotas, or approval — where the minimum package set and the host-application duties must be named.
---

# Jido Skill Router

Use this skill as the entry point when the correct Jido package skill is unclear or when the work crosses package boundaries.

Read [references/skill-manifest.yaml](references/skill-manifest.yaml) when the task needs a full routing map, related-skill lookup, or a machine-readable inventory of the current catalog.

## Routing Workflow

1. Identify the anchor concern first.
2. Load only the anchor skill.
3. Add one adjacent skill when the task crosses its boundary.
4. Keep each handoff explicit in the work plan or response.
5. If the docs are thin, narrow the scope and call out the gap instead of inventing behavior.

## Anchor Skill Selection

- Use `$jido` for agents, directives, runtime loops, and cross-package orchestration.
- Use `$jido-action` for executable units of work, action schemas, and action reviews.
- Use `$jido-signal` for signal contracts, event structure, and dispatch semantics.
- Use `$llm-db` for model catalogs, provider metadata, and capability or price-based model selection.
- Use `$req-llm` for provider calls, request shaping, streaming, and response normalization.
- Use `$jido-browser` for browser-backed automation and DOM-dependent workflows.
- Use `$jido-memory` for recall, summarization, retrieval, and memory policy.
- Use `$jido-behaviortree` for selectors, sequences, fallback paths, and explicit branching.
- Use `$ash-jido` for Ash-to-Jido boundaries, generated actions, and domain-context propagation.
- Use `$jido-studio` for operator tooling, workbench pages, and ecosystem demos.
- Use `$jido-messaging` for external transport adapters, delivery semantics, and broker boundaries.
- Use `$jido-otel` for tracing, spans, observability hooks, and OpenTelemetry integration.

## Operational-Control Routing

Use this section when the intent is operational control — authorization, audit or history, observability, policy, quotas, or approval for a unit of agent work (the four questions every piece of Jido work answers: who initiated work, what was allowed, what happened, and how failure was handled).

Operational control is a host-application concern first. The packages supply hooks and carry context; the host application owns the decision and the enforcement. Route to the **minimum** set and name the host duties the packages do not cover.

The canonical terms, the nine control dimensions, and the proof live on the Security and governance page (`/docs/operations/security-and-governance`) and the Operations hub (`/docs/operations`). Fetch them with the `get_operational_control` tool rather than restating them here, so the router never drifts from the public control surface.

### Minimum package skills

- Anchor on `$jido`. Core Jido supplies the fail-closed `prepare_action/3` and `prepare_signal/2` plugin hooks (authorization and context integration points — not decisions), in-process observation (`Jido.Observe`, `Jido.Telemetry`), and OTP supervision. Load `$jido` alone for a generic control question.
- Add one adjacent skill only when the task crosses its boundary:
  - `$jido-signal` for durable, replayable history (the optional Signal Journal).
  - `$jido-otel` for exporting telemetry as OpenTelemetry spans to a collector.
  - `$ash-jido` when Ash carries the actor, tenant, and authorization context and Ash policies must run unchanged.

### Gap — no `$jido-ai` skill

AI tool, effect, and prompt policy and request/token quotas ship with the `jido_ai` package, which has **no vendored skill** in this catalog. Do not invent a `$jido-ai` skill. Point at the `jido_ai` package page (`/ecosystem/jido_ai`) and narrow the scope until a skill exists.

### Host-application duties (no package ships these)

Name these explicitly in the plan or response so control is never implied where a package does not provide it:

- the authorization decision and RBAC/ABAC enforcement — Jido supplies the `prepare_action/3` hook; the host decides and enforces.
- approval workflows — wire a gate through `prepare_action/3`; no package ships an approval workflow.
- overall spend limits and billing enforcement — quotas bound AI work; total spend stays platform-owned.
- durable audit evidence — retention, access control, and tamper evidence for the Signal Journal and telemetry.
- integration with IAM, storage, and the SIEM or telemetry backend.

## Common Handoffs

- `$llm-db -> $req-llm -> $jido` for model-routed AI workflows.
- `$jido-action -> $jido -> $jido-signal` for action-driven agent flows.
- `$ash-jido -> $jido-action -> $jido -> $jido-signal` for Ash-triggered agents.
- `$jido-browser -> $jido-action -> $jido` for browser agents.
- `$jido-signal -> $jido-messaging` for external transport delivery.
- `$jido -> $jido-otel` for runtime observability.
- `$jido -> $jido-memory` when the workflow needs long-lived recall.
- `$jido -> $jido-behaviortree` when branching logic becomes a first-class concern.
- `$jido` alone for operational-control intent (authorization hooks, observation, supervision); add `$jido-signal` (history), `$jido-otel` (export), or `$ash-jido` (Ash context) only for the dimension touched, and name the host-application duties no package covers.

## Boundaries

- Do not load all Jido skills by default.
- Do not replace package-specific guidance with generic router text; hand off to the package skill.
- Do not invent cross-package integrations that the package docs do not support.
- Do not use this skill when one package skill already owns the task clearly.
- Do not imply a package supplies approval, overall spend limits, or durable audit evidence; those are host-application duties — state the boundary instead.
- Do not invent a `$jido-ai` skill; `jido_ai` has no vendored skill, so point at its package page and narrow the scope.
