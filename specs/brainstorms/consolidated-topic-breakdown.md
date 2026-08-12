# Consolidated Content Topic Breakdown

Date: 2026-02-22
Status: Review draft — for discussion before any new briefs are created

Sources:
- Current `priv/content_plan` inventory (76 pages)
- `priv/content_plan/gap-analysis-vs-agent-framework-doc-model.md`
- `specs/brainstorms/proposed-content-topics-2.0.md`

---

## How to read this

Every topic below is either **existing** (already in `priv/content_plan`) or **proposed new** (from the gap analysis / 2.0 planning). Existing pages are grouped under the theme they naturally belong to, regardless of their current section folder. Proposed new topics are marked with `[NEW]` and show where they'd land.

Priority tiers:
- **P0** — positioning-critical; if this is missing or weak, evaluators get the wrong picture of Jido
- **P1** — production-confidence; needed to back up reliability/ops claims
- **P2** — ecosystem breadth; important but not blocking core narrative
- **Stub** — roadmap mention only for 2.0; no deep brief yet

---

## 1. Onboarding and First Value

> Goal: Three progressive build guides that take a builder from zero to orchestrated workflows. Each one stands alone but they form a clear ladder: pure runtime → LLM agent → workflow orchestration. The sequence makes the "LLM optional" positioning self-evident through structure, not just messaging.

| # | Topic | Status | File / Placement | Priority | Notes |
|---|---|---|---|---|---|
| 1.1 | Installation and Setup | review | `build/installation.md` | P0 | Near-ready; needs cross-link to the three-guide sequence below |
| 1.2 | Build Your First Agent (no LLM) | review | `build/first-agent.md` | P0 | **Guide 1.** Explicitly no-LLM. Pure runtime primitives: define agent schema, write actions, handle signals, run via AgentServer. Proves the runtime works without any model dependency. |
| 1.3 | `[NEW]` Build Your First LLM Agent | — | `build/first-llm-agent.md` | P0 | **Guide 2.** Uses `jido_ai` (`Jido.AI.Agent` / ReAct reasoning). Configure API keys, define a tool-calling agent, show structured output. Direct comparison to guide 1 — same coordination model, intelligence added. |
| 1.4 | `[NEW]` Build Your First Workflow | — | `build/first-workflow.md` | P0 | **Guide 3.** Uses `jido_runic` to compose ActionNodes into a DAG-based workflow. Demonstrates multi-step orchestration with signal gating, strategy integration, and directive-driven execution. Source material: `jido_runic/lib/examples/` (studio pipeline, branching, delegating demos). |
| 1.5 | Getting Started Docs Hub | outline | `docs/getting-started.md` | P0 | Navigation page routing 1.1 → 1.2 → 1.3 → 1.4 → concepts |
| 1.6 | Docs Overview | outline | `docs/overview.md` | P0 | Top-level docs entry point |
| 1.7 | Quickstarts by Persona | outline | `build/quickstarts-by-persona.md` | P1 | Role-specific fast paths |
| 1.8 | `[NEW]` Why Not Just a GenServer? | — | `build/why-not-just-a-genserver.md` | P1 | Progressive complexity walkthrough based on `req_llm/lib/examples/` (GenServer agent with streaming, tool calling, conversation history, multi-model support). Shows how building a production-grade agent from raw GenServer + ReqLLM accumulates complexity that Jido's primitives handle by design. Bridges the ReqLLM → Jido adoption path. |

---

## 2. Core Primitives and Concepts

> Goal: Canonical explainers for every Jido primitive. These are the "what is it and how does it work" pages.

| # | Topic | Status | File / Placement | Priority | Notes |
|---|---|---|---|---|---|
| 2.1 | Key Concepts | draft | `docs/key-concepts.md` | P0 | Foundation page; add "LLM optional by design" framing (TOPIC-001) |
| 2.2 | Core Concepts Hub | outline | `docs/core-concepts.md` | P0 | Navigation hub for 2.3–2.8 |
| 2.3 | Agents | draft | `docs/agents.md` | P0 | |
| 2.4 | Actions | draft | `docs/actions.md` | P0 | |
| 2.5 | Signals | draft | `docs/signals.md` | P0 | |
| 2.6 | Directives | outline | `docs/directives.md` | P0 | |
| 2.7 | Plugins | outline | `docs/plugins.md` | P1 | |
| 2.8 | Agent Runtime (AgentServer) | draft | `docs/agent-server.md` | P0 | Critical for runtime-first story |
| 2.9 | Glossary | draft | `docs/glossary.md` | P1 | Terminology alignment |
| 2.10 | Guides Docs Hub | outline | `docs/guides.md` | P1 | Navigation page for guides section |

---

## 3. Architecture and Positioning

> Goal: Make the runtime-first, BEAM-native, model-agnostic thesis unmistakable.

| # | Topic | Status | File / Placement | Priority | Notes |
|---|---|---|---|---|---|
| 3.1 | Why Jido | outline | `features/overview.md` | P0 | Top-of-funnel positioning |
| 3.2 | Architecture Overview | outline | `docs/architecture-overview.md` | P0 | Layered architecture explainer; add LLM-optional architecture rule (TOPIC-001) |
| 3.3 | BEAM-Native Agent Model | published | `features/beam-native-agent-model.md` | — | Done |
| 3.4 | Why BEAM for AI Builders | outline | `features/beam-for-ai-builders.md` | P0 | Non-Elixir team translation |
| 3.5 | Jido vs Framework-First Stacks | outline | `features/jido-vs-framework-first-stacks.md` | P0 | Competitive differentiation |
| 3.6 | Schema-Validated Actions | published | `features/schema-validated-actions.md` | — | Done |
| 3.7 | Signal Routing and Coordination | published | `features/multi-agent-coordination.md` | — | Done |
| 3.8 | Directives and Scheduling | published | `features/directives-and-scheduling.md` | — | Done |
| 3.9 | Supervision and Fault Isolation | published | `features/reliability-by-architecture.md` | — | Done |
| 3.10 | Architecture Decision Guides | outline | `docs/architecture-decision-guides.md` | P1 | |
| 3.11 | `[NEW]` AI Integration Decision Guide | — | `docs/ai-integration-decision-guide.md` | P0 | Runtime-only vs ReqLLM vs jido_ai decision tree (TOPIC-006) |

---

## 4. Build Guides (Hands-On)

> Goal: "Here's how to build X with Jido" — concrete, runnable tutorials.

| # | Topic | Status | File / Placement | Priority | Notes |
|---|---|---|---|---|---|
| 4.1 | Counter Agent Example | published | `build/counter-agent.md` | — | Done |
| 4.2 | Demand Tracker Agent Example | published | `build/demand-tracker-agent.md` | — | Done |
| 4.3 | `[NEW]` Behavior Tree Workflows Without LLM | — | `build/behavior-tree-without-llm.md` | P1 | Concrete no-LLM proof surface (TOPIC-003); primary proof page for `jido_behaviortree` package. Deprioritized from P0 — the no-LLM story is now carried by Guide 1 (1.2) and the workflow guide (1.4). |
| 4.4 | Build an AI Chat Agent | outline | `build/ai-chat-agent.md` | P1 | LLM path; thread ReqLLM visibility (TOPIC-004) |
| 4.5 | Tool Use and Function Calling | outline | `build/tool-use.md` | P1 | Thread ReqLLM visibility (TOPIC-004) |
| 4.6 | Multi-Agent Workflows | outline | `build/multi-agent-workflows.md` | P1 | |
| 4.7 | Mixed-Stack Integration | outline | `build/mixed-stack-integration.md` | P1 | |
| 4.8 | Reference Architectures | outline | `build/reference-architectures.md` | P2 | |
| 4.9 | Product Feature Blueprints | outline | `build/product-feature-blueprints.md` | P2 | |

---

## 5. AI / Model Integration

> Goal: Show that LLM support is powerful but explicitly optional. ReqLLM is first-class, providers are well-mapped.

| # | Topic | Status | File / Placement | Priority | Notes |
|---|---|---|---|---|---|
| 5.1 | `[NEW]` Provider Capability and Fallback Matrix | — | `docs/provider-capability-and-fallback-matrix.md` | P0 | Provider support, fallback routing, rate limits, LLM Catalog refs (TOPIC-005) |
| 5.2 | Configuration Reference | draft | `docs/configuration.md` | P0 | Thread provider config (TOPIC-005 secondary) |
| 5.3 | Composable Ecosystem (feature page) | published | `features/composable-ecosystem.md` | — | Done; thread ReqLLM visibility on update (TOPIC-004) |

---

## 6. Operations and Reliability

> Goal: Back up the "runtime for reliable systems" claim with concrete operational docs.

| # | Topic | Status | File / Placement | Priority | Notes |
|---|---|---|---|---|---|
| 6.1 | Operations Docs Hub | outline | `docs/operations.md` | P0 | Navigation page |
| 6.2 | Production Readiness Checklist | outline | `docs/production-readiness-checklist.md` | P0 | |
| 6.3 | Retries, Backpressure, and Failure Recovery | draft | `docs/retries-backpressure-and-failure-recovery.md` | P1 | |
| 6.4 | Incident Playbooks | outline | `docs/incident-playbooks.md` | P1 | |
| 6.5 | Long-Running Agent Workflows | outline | `docs/long-running-agent-workflows.md` | P1 | |
| 6.6 | Mixed-Stack Runbooks | outline | `docs/mixed-stack-runbooks.md` | P2 | |
| 6.7 | Migrations and Upgrade Paths | outline | `docs/migrations-and-upgrade-paths.md` | P2 | |
| 6.8 | `[NEW]` Backup and Disaster Recovery | — | `docs/backup-and-disaster-recovery.md` | P1 | Ops-first claim needs explicit DR (gap analysis P1) |

---

## 7. Security and Governance

> Goal: Define scope boundaries clearly — what Jido controls vs platform/Phoenix/Ash — without over-promising enterprise depth.

| # | Topic | Status | File / Placement | Priority | Notes |
|---|---|---|---|---|---|
| 7.1 | Security and Governance | outline | `docs/security-and-governance.md` | P0 | Expand with shared-responsibility model + scope boundary (TOPIC-009) |
| 7.2 | Content Governance and Drift Detection | outline | `docs/content-governance-and-drift-detection.md` | P2 | |

---

## 8. Observability and Debugging

> Goal: Connect telemetry, debugging, and troubleshooting into a coherent ops story. Lean heavily on three concrete proof surfaces: **jido_studio** (LiveView-based observability UI, tracing, runtime inspection), **jido_otel** (OpenTelemetry bridge — converts Jido event prefixes to OTel spans), and **BEAM tooling** (`:observer`, `:recon`, process inspection, supervision tree visualization). These are the "show don't tell" anchors for the ops-first pillar.

| # | Topic | Status | File / Placement | Priority | Notes |
|---|---|---|---|---|---|
| 8.1 | Production Telemetry (feature page) | published | `features/operations-observability.md` | — | Done |
| 8.2 | Telemetry and Observability Reference | draft | `docs/telemetry-and-observability.md` | P1 | Expand to cover: jido_otel span mapping, jido_studio dashboards, BEAM-native tooling (`:observer`, `:recon`, process introspection). These three layers form the observability stack. |
| 8.3 | Troubleshooting and Debugging Playbook | outline | `docs/troubleshooting-and-debugging-playbook.md` | P1 | Reference jido_studio tracing and BEAM debugging workflows as concrete procedures |
| 8.4 | LiveView Integration Patterns (feature page) | published | `features/liveview-integration-patterns.md` | — | Done |

---

## 9. Interoperability and Protocols

> Goal: Cover MCP as in-flight; position protocol support as a first-class concern.

| # | Topic | Status | File / Placement | Priority | Notes |
|---|---|---|---|---|---|
| 9.1 | `[NEW]` MCP Integration Guide | — | `docs/mcp-integration.md` | P1 | Dedicated protocol guide (TOPIC-010); competitor table-stakes |

---

## 10. Data, Persistence, and Memory

> Goal: Practical guidance on state durability, embeddings, and vector search.

| # | Topic | Status | File / Placement | Priority | Notes |
|---|---|---|---|---|---|
| 10.1 | Persistence, Memory, and Vector Search | draft | `docs/persistence-memory-and-vector-search.md` | P1 | Expand brief to cover session model, memory scope/privacy, and retention lifecycle as sections — not separate pages |
| 10.2 | Data Storage and pgvector Reference | draft | `docs/data-storage-and-pgvector.md` | P1 | |

---

## 11. Testing and Quality

> Goal: Cover what's testable today. Eval framework is a roadmap stub only.

| # | Topic | Status | File / Placement | Priority | Notes |
|---|---|---|---|---|---|
| 11.1 | Testing Agents and Actions | draft | `docs/testing-agents-and-actions.md` | P1 | |
| 11.2 | Cookbook | outline | `docs/cookbook.md` | P2 | Recipe-style patterns |

---

## 12. Package References

> Goal: Every package gets a real API contract page, not just a stub. This is the "API trust" gap.

| # | Topic | Status | File / Placement | Priority | Notes |
|---|---|---|---|---|---|
| 12.1 | Reference Docs Hub | outline | `docs/reference.md` | P0 | Navigation |
| 12.2 | Package Reference: jido | outline | `docs/reference-jido.md` | P0 | Expand from stub (TOPIC-007) |
| 12.3 | Package Reference: jido_action | outline | `docs/reference-jido-action.md` | P0 | Expand from stub |
| 12.4 | Package Reference: jido_signal | outline | `docs/reference-jido-signal.md` | P0 | Expand from stub |
| 12.5 | Package Reference: jido_ai | outline | `docs/reference-jido-ai.md` | P0 | Expand from stub |
| 12.6 | Package Reference: req_llm | outline | `docs/reference-req-llm.md` | P0 | Expand from stub |
| 12.7 | Package Reference: jido_browser | outline | `docs/reference-jido-browser.md` | P1 | |
| 12.8 | Package Reference: agent_jido | outline | `docs/reference-agent-jido.md` | P1 | |
| 12.9 | `[NEW]` Package Reference: jido_memory | — | `docs/reference-jido-memory.md` | P1 | Public package, no brief yet; cross-link from Theme 10 persistence/memory guide |
| 12.10 | `[NEW]` Package Reference: jido_otel | — | `docs/reference-jido-otel.md` | P1 | Public package, no brief yet; cross-link from Theme 8 telemetry page — backs up ops-first pillar |
| 12.11 | `[NEW]` Package Reference: jido_behaviortree | — | `docs/reference-jido-behaviortree.md` | P1 | Public package, no brief yet; primary proof linked from build guide 4.3 |
| 12.12 | `[NEW]` Package Reference: jido_runic | — | `docs/reference-jido-runic.md` | P0 | Primary workflow orchestration package; referenced from onboarding guide 1.4. Source: `jido_runic/` (ActionNode, Strategy, SignalFact, Introspection) |

---

## 13. Ecosystem and Adoption

> Goal: Help teams select packages, plan rollouts, and evaluate fit.

| # | Topic | Status | File / Placement | Priority | Notes |
|---|---|---|---|---|---|
| 13.1 | Ecosystem Overview | outline | `ecosystem/overview.md` | P1 | |
| 13.2 | Ecosystem Package Matrix | draft | `ecosystem/package-matrix.md` | P1 | |
| 13.3 | Package Selection by Use Case | outline | `ecosystem/package-selection-by-use-case.md` | P1 | |
| 13.4 | Incremental Adoption Paths | outline | `features/incremental-adoption.md` | P1 | |
| 13.5 | Executive Brief | outline | `features/executive-brief.md` | P1 | |
| 13.6 | Adoption Playbooks | outline | `community/adoption-playbooks.md` | P2 | |
| 13.7 | Case Studies | planned | `community/case-studies.md` | P2 | |
| 13.8 | Learning Paths | outline | `community/learning-paths.md` | P2 | |
| 13.9 | Manager Adoption Roadmap | outline | `training/manager-roadmap.md` | P2 | |

---

## 14. Training Modules

> Goal: Structured learning tracks. Most are already published.

| # | Topic | Status | File / Placement | Priority | Notes |
|---|---|---|---|---|---|
| 14.1 | Agent Fundamentals on the BEAM | published | `training/agent-fundamentals.md` | — | Done |
| 14.2 | Actions and Schema Validation | published | `training/actions-validation.md` | — | Done |
| 14.3 | Signals, Routing, and Agent Communication | published | `training/signals-routing.md` | — | Done |
| 14.4 | Directives, Scheduling, and Time-Based Behavior | published | `training/directives-scheduling.md` | — | Done |
| 14.5 | LiveView and Jido Integration Patterns | published | `training/liveview-integration.md` | — | Done |
| 14.6 | Production Readiness | published | `training/production-readiness.md` | — | Done |

---

## 15. Transparency and Roadmap

> Goal: Show what's in 2.0, what's coming, and what's explicitly deferred. Builds evaluator trust.

| # | Topic | Status | File / Placement | Priority | Notes |
|---|---|---|---|---|---|
| 15.1 | `[NEW]` Roadmap and Known Gaps | — | `features/roadmap-and-known-gaps.md` | P0 | Central transparency page (TOPIC-008) |
| 15.2 | Examples Inventory | outline | `examples/overview.md` | P2 | |

---

## 16. Roadmap Stubs Only (no deep brief in 2.0)

> These get a "Coming Soon" mention on the Roadmap page (15.1) but no dedicated content brief yet.

| # | Topic | Source | Rationale |
|---|---|---|---|
| 16.1 | Evaluation and Quality Gates | TOPIC-011 | No eval system exists yet |
| 16.2 | `jido_cluster` Reliability | TOPIC-012 | Package does not exist in ecosystem yet — future/planned name only |
| 16.3 | `jido_bedrock` Reliability | TOPIC-013 | Package does not exist in ecosystem yet — future/planned name only |
| 16.4 | `jido_studio` Observability UI | TOPIC-014 | Package not ready |
| 16.5 | Performance and Cost Profiling | TOPIC-015 | Tooling doesn't exist yet; add "Coming Soon" section to telemetry page (8.2) |
| 16.6 | Streaming and Interruption Semantics | Gap analysis P1 | No runtime support for dedicated docs yet |
| 16.7 | Voice / Multimodal | Gap analysis P2 | Low priority for current thesis |
| 16.8 | Build-vs-Buy Decision Guide | Gap analysis P2 | After core runtime docs are publish-ready |
| 16.9 | Deep Enterprise RBAC/Tenancy/Compliance | Gap analysis | Out of scope; shared-responsibility boundary only |

---

## Proposed New Briefs Summary

13 new content plan briefs to create (if you approve):

**P0 (positioning-critical):**

| Brief file | Theme | Source |
|---|---|---|
| `build/first-llm-agent.md` | 1. Onboarding | Guide 2: jido_ai ReAct agent |
| `build/first-workflow.md` | 1. Onboarding | Guide 3: jido_runic DAG workflows |
| `docs/provider-capability-and-fallback-matrix.md` | 5. AI/Model Integration | TOPIC-005 |
| `docs/ai-integration-decision-guide.md` | 3. Architecture | TOPIC-006 |
| `features/roadmap-and-known-gaps.md` | 15. Transparency | TOPIC-008 |
| `docs/reference-jido-runic.md` | 12. Package Refs | Primary workflow package |

**P1 (production-confidence):**

| Brief file | Theme | Source |
|---|---|---|
| `build/why-not-just-a-genserver.md` | 1. Onboarding | ReqLLM GenServer agent complexity walkthrough |
| `build/behavior-tree-without-llm.md` | 4. Build Guides | TOPIC-003 (deprioritized from P0) |
| `docs/mcp-integration.md` | 9. Interoperability | TOPIC-010 |
| `docs/backup-and-disaster-recovery.md` | 6. Operations | Gap analysis |
| `docs/reference-jido-memory.md` | 12. Package Refs | Public package, no brief |
| `docs/reference-jido-otel.md` | 12. Package Refs | Public package, no brief |
| `docs/reference-jido-behaviortree.md` | 12. Package Refs | Public package, no brief |

Internal governance doc (not a published page — lives in `specs/`, not `priv/content_plan`):
- `specs/reference-completeness-plan.md` — defines "done" criteria for each package reference (TOPIC-007)

---

## Cross-Cutting Concerns (apply to all topics)

From TOPIC-001 and TOPIC-004 — these are **not standalone pages** but expansions woven into existing briefs:

1. **"LLM optional by design"** — thread into: key-concepts, architecture-overview, getting-started, first-agent, features/overview, quickstarts-by-persona
2. **ReqLLM first-class visibility** — thread into: composable-ecosystem, reference-req-llm, reference-jido-ai, ai-chat-agent, tool-use, package-matrix
3. **LLM Catalog mentions** — thread into: provider-capability matrix, reference-req-llm, configuration
4. **Runtime-first language primary** — every page; model layer stays optional framing

---

## Suggested Execution Sequence

### Wave 1: Positioning-critical hardening (P0)
1. **Onboarding ladder:** Finalize first-agent (no-LLM baseline), create first-llm-agent (jido_ai), create first-workflow (jido_runic)
2. Finalize existing P0 concept pages: architecture-overview, key-concepts, agents, actions, signals, directives, agent-server, production-readiness-checklist
3. Create new briefs: ai-integration-decision-guide, provider-capability matrix, roadmap-and-known-gaps, reference-jido-runic
4. Expand security-and-governance with shared-responsibility scope boundary
5. Thread "LLM optional" and ReqLLM visibility across existing pages

### Wave 2: Production-confidence completion (P1)
1. Create: why-not-just-a-genserver, behavior-tree-without-llm, mcp-integration, backup-and-disaster-recovery
2. Create package refs: reference-jido-memory, reference-jido-otel, reference-jido-behaviortree
3. Finalize: retries/backpressure, telemetry (expand with jido_otel + jido_studio + BEAM tooling), troubleshooting, incident playbooks, testing
4. Upgrade remaining package reference stubs to full API contract pages
5. Finalize: ai-chat-agent, tool-use, multi-agent-workflows
6. Create `specs/reference-completeness-plan.md` as internal governance doc

### Wave 3: Ecosystem breadth (P2)
1. Reference architectures, product blueprints, mixed-stack runbooks
2. Adoption playbooks, case studies, learning paths
3. Cookbook recipes
4. Build-vs-buy guidance (if warranted)
