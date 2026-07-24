# Persona And Journey Strategy

Version: 3.0  
Last updated: 2026-07-23  
Positioning anchor: `Jido is the Elixir framework for long-running agent systems.` (see `specs/positioning.md` §11; `jido-e02`)  
Differentiator: `Build Agent systems you can supervise, constrain, and inspect.`

## 1) Strategy Premise

- Do not assume visitors know Elixir or BEAM.
- Lead with outcomes and operational confidence.
- Introduce Elixir/OTP as the reason reliability claims are credible.
- Give non-Elixir teams safe, bounded adoption paths.
- "Why BEAM/Elixir" content targets polyglot evaluators (Python, TypeScript, JVM, .NET engineers), not Elixir insiders. Frame BEAM advantages as outcome comparisons, not community advocacy.

## 2) Persona Clusters

| Cluster | Who | Primary need |
|---|---|---|
| BEAM-native builders | Elixir/OTP engineers | Build quickly without losing reliability discipline |
| Polyglot technical builders | Python/TypeScript/JVM/.NET engineers | Adopt agent runtime safely without full-stack rewrite |
| Decision and influence roles | EM, VP, CTO, architect, PM | Evaluate risk, ROI, and phased adoption plan |

## 3) Priority Personas (Site-Wide)

| Persona | Core question | Promise to deliver | First route |
|---|---|---|---|
| Elixir platform engineer | How does this map to OTP patterns? | Reliable agent architecture aligned to supervision | `/features` |
| AI product engineer | How do I ship AI features safely? | Tool-using agent patterns with fewer runtime surprises | `/build` |
| Staff architect / tech lead | Can this scale across teams? | Reference architecture and governance path | `/ecosystem/matrix` |
| Python AI engineer | Why Jido vs Python-first frameworks? | Better runtime semantics for long-lived workloads | `/features/beam-for-ai-builders` |
| TypeScript fullstack engineer | Can this be my backend agent service? | Mixed-stack integration with clear boundaries | `/build/mixed-stack-integration` |
| Platform/SRE engineer | Is this operable and safe under failure? | Runbooks, telemetry, and reliability controls | `/docs/production-readiness-checklist` |
| Security/compliance engineer | How do we control tool risk? | Policy, guardrails, and auditability guidance | `/docs/security-and-governance` |
| Engineering manager | How do I de-risk team adoption? | 30/60/90 staged rollout and training roadmap | `/training/manager-roadmap` |
| CTO/founder | Is this strategic and practical now? | Differentiation + phased execution plan | `/features/executive-brief` |

## 4) Journey Framework (Intent Stages)

| Stage | User intent | Required proof | Best content surfaces |
|---|---|---|---|
| Awareness | Understand what Jido is | Problem statement + clear differentiation | `/features` |
| Orientation | Map to current stack/context | Persona quickstarts + package matrix | `/build/quickstarts-by-persona`, `/ecosystem/matrix` |
| Evaluation | Test feasibility quickly | Runnable examples + setup constraints | `/examples`, `/training/agent-fundamentals` |
| Activation | Ship first meaningful feature | Implementation guides + validation checklists | `/build`, `/docs/guides`, `/training` |
| Operationalization | Run safely in production | Runbooks + telemetry + rollback strategy | `/docs/production-readiness-checklist`, `/docs/reference` |
| Expansion | Scale across teams/products | Governance patterns + architecture decisions | `/docs/guides/architecture-decision-guides`, `/community/adoption-playbooks` |
| Advocacy | Teach and standardize | Reusable assets + case studies | `/community`, `/why/case-studies` |

## 5) Canonical Journey Templates

## A) Non-Elixir technical evaluator

- Goal: start a bounded pilot without full-stack migration.
- Path: `/features/beam-for-ai-builders` -> `/ecosystem/matrix` -> `/examples/counter-agent` -> `/build/mixed-stack-integration` -> `/docs/reference`
- Success signal: first cross-stack workflow running with defined production guardrails.

## B) Elixir-native builder

- Goal: move from baseline to production-ready workflow.
- Path: `/features` -> `/examples` -> `/training` -> `/docs/reference`
- Success signal: supervised agent workflow with telemetry and failure controls.

## C) AI feature team (engineering + product)

- Goal: ship user-facing AI capability with quality and reliability criteria.
- Path: `/features` -> `/build/product-feature-blueprints` -> `/docs/guides/ai-chat-agent` -> `/docs/guides/retries-backpressure-and-failure-recovery`
- Success signal: first feature shipped with explicit readiness checklist.

## D) Platform/SRE readiness track

- Goal: establish reliability and governance baseline before broader rollout.
- Path: `/docs/production-readiness-checklist` -> `/docs/reference` -> `/docs/security-and-governance` -> `/docs/guides`
- Success signal: approved runbook/alerting baseline and safe upgrade path.

## 6) Cross-Cutting Content Needed For Non-Elixir Personas

1. Why Elixir/OTP for agent workloads — written for polyglot outsiders, not BEAM insiders. Frame as outcome comparisons (failure recovery, concurrency, operational cost) rather than language advocacy.
2. Mixed-stack integration blueprints (TS/Python/JVM/.NET boundaries).
3. Migration-without-rewrite playbooks (bounded context strategy).
4. Security and governance center (tool permissions, threat model, audit posture).

## 7) Journey KPIs

| Stage | KPI examples |
|---|---|
| Awareness | Features-page completion rate, comparison-page engagement |
| Orientation | Persona quickstart selection rate, matrix depth |
| Evaluation | Example start/completion rate, time to first local success |
| Activation | Guide-to-implementation conversion, training progression |
| Operationalization | Production-readiness checklist completion, docs reference depth |
| Expansion | Multi-team adoption signals, package depth growth |

## 8) Messaging Guardrails By Persona

- Use broad language first; technical depth second.
- Keep claims bounded to demonstrable behavior.
- Avoid jargon-only claims without practical translation.
- Always connect persona pages to a concrete next step (`Build`, `Training`, `Docs`, or `Community`).
- Use `Get Building` as the default global CTA for OSS onboarding.

## Control-Evaluation Audience and Journey (`jido-e02` T40/T41)

Secondary to Elixir builders, a control-evaluation audience evaluates Jido for governed environments: platform engineers, SREs, security teams, and regulated-environment evaluators.

| Persona | Core question | First route |
|---|---|---|
| Platform / SRE engineer | Can I supervise, observe, and recover agent work? | `/docs/operations` |
| Security evaluator | Where are the authorization and audit boundaries? | `/docs/operations/security-and-governance` |

Control-evaluation journey: architecture → authorization hook (`prepare_action/3`) → causal Signal Journal → telemetry and redaction → operations proof (failure drill, incident playbooks). The journey follows the operational-control pillars in `specs/positioning.md` §11 and stays within the claim boundaries (no IAM/compliance overreach).
