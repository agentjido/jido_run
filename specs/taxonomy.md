# Taxonomy Specs

Status: Draft (integrated site taxonomy baseline)
Owner: Product marketing + docs + ecosystem maintainers
Last updated: 2026-02-23

## Purpose

Define one coherent taxonomy for the entire site so content is classifiable, navigable, and proof-linked across:

- Features
- Ecosystem
- Examples
- Build
- Training
- Docs
- Community
- Blog

This spec combines narrative positioning taxonomy with technical package taxonomy.

## Scope

In scope:

- site-wide taxonomy model and naming
- feature categorization
- example categorization
- docs section taxonomy (including package-reference taxonomy under docs)
- ecosystem package taxonomy and its docs/reference crosswalk

Out of scope:

- implementation changes in schemas, LiveViews, filters, routes, or card UI
- visual styling and layout design decisions

## Inputs Reviewed

- `specs/README.md`
- `specs/positioning.md`
- `specs/content-outline.md`
- `specs/persona-journeys.md`
- `priv/pages/**/*.{md,livemd}`
- `priv/examples/*.md`
- `priv/ecosystem/*.md`
- `priv/content_plan/**/*`
- `lib/agent_jido/pages/page.ex`
- `lib/agent_jido/examples/example.ex`
- `lib/agent_jido/ecosystem/package.ex`
- `lib/agent_jido/ecosystem/layering.ex`

## Inventory Snapshot (Current)

- Pages (`priv/pages`): 70
- Examples (`priv/examples`): 21 published, 1 unpublished
- Ecosystem packages (`priv/ecosystem`): 32 (12 public, 20 private)
- Blog posts (`priv/blog`): 4
- Content plan entries (`priv/content_plan`): 89

Pages by section (`priv/pages`):

- `docs`: 47
- `features`: 8
- `build`: 5
- `training`: 6
- `community`: 4

Docs sections (`/docs/*`):

- `/docs/getting-started` (1)
- `/docs/concepts` (8)
- `/docs/learn` (6)
- `/docs/guides` (11)
- `/docs/reference` (16)
- `/docs/operations` (4)
- `/docs` root (1)

## Unified Taxonomy Model

Use five axes across the site:

1. `section`: top-level IA section (Features, Ecosystem, Examples, Build, Training, Docs, Community, Blog)
2. `journey_stage`: awareness, orientation, evaluation, activation, operationalization, expansion, advocacy
3. `content_intent`: explanation, guide, tutorial, reference, cookbook, case-study, decision-brief
4. `capability_theme`: runtime/reliability themes used across sections
5. `evidence_surface`: package, runnable example, training module, docs reference, runbook, case study

## Canonical Capability Themes

These are the cross-section themes used to connect pages, examples, docs, and packages:

- `runtime_foundations`: agent model, deterministic state, process/lifecycle model
- `reliability_architecture`: supervision, isolation, recovery boundaries
- `coordination_orchestration`: signals, directives, workflow/strategy composition
- `operations_observability`: telemetry, tracing, incident workflows, readiness controls
- `ai_intelligence`: LLM integration, memory, tool use, eval quality
- `execution_tooling`: shell/vfs/sandbox/workspace/runtime substrate
- `integration_interop`: framework/channel/provider adapters, mixed-stack boundaries
- `adoption_architecture`: phased rollout, reference architectures, decision criteria
- `learning_enablement`: structured onboarding and skill progression
- `community_adoption`: playbooks, case studies, organizational adoption

## Feature Taxonomy

All current feature pages are `content_intent=explanation`.

Primary feature clusters:

`runtime_foundations`

- `/features/beam-native-agent-model`

`reliability_architecture`

- `/features/reliability-by-architecture`

`coordination_orchestration`

- `/features/multi-agent-coordination`

`operations_observability`

- `/features/operations-observability`

`adoption_architecture`

- `/features/incremental-adoption`

`integration_interop` (polyglot bridge framing)

- `/features/beam-for-ai-builders`

`adoption_architecture` + `integration_interop` (fit-for-purpose comparison)

- `/features/jido-vs-framework-first-stacks`

`decision-brief` (exec/leadership)

- `/features/executive-brief`

Feature role taxonomy (for editorial planning):

- `pillar`: reliability, coordination, operations, incremental adoption
- `supporting`: runtime model foundation, polyglot bridge, comparison framing, executive brief

## Example Taxonomy

### Existing schema axis (kept)

- `category`: `core | ai | production`
- current distribution: `core=14`, `ai=6`, `production=1`

### Additional editorial axes (proposed)

`scenario_cluster`

- `core_mechanics`
- `coordination`
- `ai_tool_use`
- `liveview_product`
- `ops_governance`
- `foundational_legacy` (for older examples without scenario tags)

`wave`

- `l1` (first-wave examples)
- `l2` (second-wave examples)
- `legacy` (no explicit wave tag)

Current scenario mapping:

`core_mechanics` (8)

- `address-normalization-agent`
- `capacity-quota-tracker-agent`
- `cart-value-calculator-agent`
- `feature-flag-audit-agent`
- `csv-import-validator-agent`
- `catalog-variant-consistency-agent`
- `changelog-entry-linter-agent`
- `dependency-license-classifier-agent`

`coordination` (4)

- `order-approval-to-fulfillment-chain`
- `ticket-triage-swarm-coordinator`
- `async-payment-retry-orchestrator`
- `dead-letter-reprocessor-workflow`

`ai_tool_use` (4)

- `document-grounded-policy-qna-agent`
- `pr-review-suggestion-agent`
- `incident-timeline-narrator-agent`
- `release-notes-drafting-agent`

`liveview_product` (2)

- `liveview-checkout-recovery-coach`
- `meeting-prep-briefing-console`

`ops_governance` (1)

- `telemetry-slo-budget-sentinel`

`foundational_legacy` (2)

- `counter-agent`
- `demand-tracker-agent`

Operational notes:

- 21 published examples, 1 unpublished (`budget-guardrail-agent`)
- difficulty: 20 beginner, 1 intermediate
- rank-tagged `top20`: 19 examples

## Docs Taxonomy

Docs are organized by intent and task posture.

`/docs/getting-started`

- role: bootstrap and first success
- journey: awareness -> activation

`/docs/concepts`

- role: shared mental models and primitives
- journey: orientation

`/docs/learn`

- role: guided tutorial progression
- journey: evaluation -> activation

`/docs/guides`

- role: task-oriented implementation workflows
- journey: activation

`/docs/reference`

- role: exact contracts and decision support
- journey: activation -> operationalization

`/docs/operations`

- role: production safety, governance, and incident response
- journey: operationalization -> expansion

### Docs Sub-Taxonomy: `/docs/reference/packages/*`

Treat package reference docs as a child taxonomy of Ecosystem.
Each package reference page should carry:

- ecosystem `layer` (architecture position)
- ecosystem `domain` (functional purpose)

Current package reference coverage:

- existing docs pages: 7
- mapped to public ecosystem packages: 5
- includes private package references: `jido_ai`, `agent_jido`

Current docs package pages mapped to ecosystem taxonomy:

- `jido` -> `layer=core`, `domain=agent_core`
- `jido_action` -> `layer=foundation`, `domain=agent_core`
- `jido_signal` -> `layer=foundation`, `domain=agent_core`
- `jido_ai` -> `layer=ai`, `domain=cognition_planning` (private)
- `jido_browser` -> `layer=ai`, `domain=cognition_planning`
- `req_llm` -> `layer=foundation`, `domain=llm_foundation`
- `agent_jido` -> `layer=app`, `domain=reference_app` (private)

Public-package reference gaps in docs:

- `ash_jido`
- `jido_behaviortree`
- `jido_memory`
- `jido_messaging`
- `jido_otel`
- `jido_studio`
- `llm_db`

## Ecosystem Taxonomy (Authoritative Package Taxonomy)

3-axis package taxonomy:

- Axis 0: `jido` = gravitational center — every package in the ecosystem depends on jido
- Axis 1: `layer` = `foundation | core | ai | app` — distance from center (orbital ring)
- Axis 2: `domain` = functional package purpose — angular sector within a ring

jido sits at the core of the ecosystem as the single package through which all
other packages connect. It is not grouped with peers — it IS the center. The
remaining packages orbit around it in concentric rings by layer, clustered into
angular sectors by domain.

Layer distribution (current):

- `center`: 1 (`jido`)
- `foundation`: 5
- `ai`: 8
- `app`: 18

Ring 0 — Center:
`jido` — core agent framework, depends on `jido_action` + `jido_signal`

Ring 1 — Foundation (closest orbit):

`agent_core`

- `jido_action`, `jido_signal`, `jido_harness`

`llm_foundation`

- `req_llm`, `llm_db`

Ring 2 — AI (middle orbit):

`cognition_planning`

- `jido_ai`, `jido_memory`, `jido_character`, `jido_behaviortree`, `jido_runic`, `jido_eval`, `jido_evolve`, `jido_browser`

Ring 3 — Application (outer orbit):

`execution_substrate`

- `jido_vfs`, `jido_shell`, `jido_sandbox`, `jido_workspace`

`adapters`

- `ash_jido`, `jido_messaging`, `jido_otel`, `jido_amp`, `jido_claude`, `jido_codex`, `jido_gemini`, `jido_opencode`

`ops_runtime`

- `jido_flame`, `jido_studio`, `jido_live_dashboard`

`workflow_products`

- `jido_code`, `jido_lib`

`reference_app`

- `agent_jido`

## Build, Training, Community, Blog Taxonomy

### Build (`/build`)

`quickstart_paths`

- `/build/quickstarts-by-persona`

`architecture_blueprints`

- `/build/reference-architectures`

`interop_patterns`

- `/build/mixed-stack-integration`

`feature_implementation_blueprints`

- `/build/product-feature-blueprints`

### Training (`/training`)

Track taxonomy:

- `foundations`: `agent-fundamentals`, `actions-validation`
- `coordination`: `signals-routing`, `directives-scheduling`
- `integration`: `liveview-integration`
- `operations`: `production-readiness`

Difficulty taxonomy:

- beginner, intermediate, advanced (currently all three represented)

### Community (`/community`)

`learning_paths`

- `/community/learning-paths`

`adoption_playbooks`

- `/community/adoption-playbooks`

`case_studies`

- `/community/case-studies`

### Blog (`/blog`)

Keep blog taxonomy aligned to `post_type` and `audience` from schema.
Current state:

- `post_type`: currently represented as `:announcement`, `:release`, `:tutorial`, and `:post`
- `audience`: currently represented as `:general` and `:beginner`

Canonical blog tag policy:

- tags are normalized to lowercase canonical tokens
- package/topic aliases redirect to canonical tags (for example: `req`, `reqllm`, `req-llm` -> `req_llm`)
- legacy tag URLs remain valid via permanent redirects

Blog metadata alignment (implemented):

- each post carries `journey_stage`
- each post carries `content_intent`
- each post carries `capability_theme`
- each post carries `evidence_surface`

## Crosswalk: Feature -> Examples -> Docs -> Ecosystem

Use this as a linking rule:

- `runtime_foundations`
  - examples: `counter-agent`, `core_mechanics` cluster
  - docs: `/docs/concepts`, `/docs/learn`
  - packages: `agent_core`

- `reliability_architecture`
  - examples: `counter-agent`, coordination flows
  - docs: `/docs/operations`, `/docs/reference/architecture`
  - packages: `agent_core`, `ops_runtime`

- `coordination_orchestration`
  - examples: `coordination` cluster, `demand-tracker-agent`
  - docs: `/docs/concepts/signals`, `/docs/guides/long-running-agent-workflows`
  - packages: `agent_core`, `cognition_planning`

- `operations_observability`
  - examples: `telemetry-slo-budget-sentinel`
  - docs: `/docs/operations/*`, `/docs/reference/telemetry-and-observability`
  - packages: `ops_runtime`, `adapters`

- `ai_intelligence`
  - examples: `ai_tool_use` cluster
  - docs: `/docs/guides/*` + package reference branch
  - packages: `cognition_planning`, `llm_foundation`

- `adoption_architecture` / `integration_interop`
  - examples: `liveview_product` cluster + coordination workflows
  - docs: `/docs/guides/mixed-stack-runbooks`, `/docs/reference/architecture-decision-guides`
  - packages: `adapters`, `reference_app`, `execution_substrate`

## Governance Rules

1. Every new content asset gets values for at least `section`, `journey_stage`, `content_intent`, and `capability_theme`.
2. Feature pages must map to exactly one primary capability theme and optionally one secondary theme.
3. Examples keep schema `category` but also receive one `scenario_cluster`.
4. Docs package references must inherit ecosystem `layer + domain` from package metadata, not ad-hoc labels.
5. New ecosystem domains require a minimum of 3 packages or a near-term roadmap commitment.
6. Taxonomy changes are reviewed monthly while content shape is changing rapidly.

## Implementation Notes (Not Started)

When implementing this taxonomy in code/content metadata:

- add optional `capability_theme` and `journey_stage` metadata for pages/examples
- add optional `scenario_cluster` metadata for examples
- add `domain` to ecosystem package schema/frontmatter
- expose docs package reference filters by ecosystem `layer + domain`

## Route Status Table (`E00-T05`)

Every content route family has exactly one state. This is the canonical reference
for the link audit allow-list and for release gating.

| Route family | State | Source | Notes |
|---|---|---|---|
| `/docs/**` (published) | public | `priv/pages/docs/**` | Excludes the draft set below |
| `/docs/operations/**`, `/docs/reference/architecture/**`, 7 others | draft | `priv/pages/docs/**` (draft) | Hidden from published indexes; do not link from public pages (`E01-T16`) |
| `/features/**` | public | `priv/pages/features/*.md` | |
| `/build/**` | public | `priv/pages/build/*.md` | |
| `/compare/**` | public | `priv/pages/compare/*.md` | |
| `/examples/**` | public (22) / draft (24) | `priv/examples/*.md` | Status defaults to draft when unset (`E08-T30`) |
| `/ecosystem/**` | public (47) / private (5) | `priv/ecosystem/*.md` | |
| `/blog/**` | public | `priv/blog/**` | |
| `/community/**` | public (2) / private (1) | `priv/community_showcase/**` | |
| `/skills` | public (route) | LiveView | Catalog renders 0 cards until `E10-T23` |
| `/training/**` | retired | `priv/pages/training/*.md` | Public routing retired; inbound links are defects (`E01-T15`) |
| `/getting-started` | redirect (target) | legacy route | Redirect to `/docs/getting-started` (`E01-T13`) |

State definitions:

- **public** — indexed, sitemapped, linkable.
- **draft** — exists in source, excluded from published indexes and sitemap; public pages must not link here.
- **retired** — source retained for history; route returns 404; inbound links must be replaced (`E01-T15`).
- **redirect** — route resolves to a canonical target.
