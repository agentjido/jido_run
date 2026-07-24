# Site Content Outline

Version: 2.0  
Last updated: 2026-02-12  
Positioning anchor: `Jido is the Elixir framework for long-running agent systems.` (see `specs/positioning.md` Section 11; `jido-e02`)  
Differentiator: `Build Agent systems you can supervise, constrain, and inspect.`
Project posture: Open-source, self-serve first.

## 1) Narrative Ladder

Use this ladder consistently from homepage through deeper pages:

1. Broad statement: `Jido is a runtime for reliable, multi-agent systems.`
2. Outcome statement: `Design, coordinate, and operate agent workflows that stay stable in production.`
3. Technical differentiator: `Built on Elixir/OTP for fault isolation, concurrency, and uptime.`
4. Category contrast: `Not only framework APIs, but a runtime model for production operation.`

## 1.1) North-Star Outcomes

Business outcomes:

- Increase ecosystem adoption depth (single-package trials to multi-package usage).
- Reduce time-to-first-success for new teams.
- Increase trust for production deployment decisions.

User outcomes:

- Understand which package fits each architecture layer.
- Build a meaningful workflow quickly.
- Operate that workflow safely under production constraints.

## 2) Top-Level Information Architecture

## Current primary nav (implementation reality)

- `/` Home
- `/ecosystem`
- `/features`
- `/examples`
- `/training`
- `/docs`

## Target nav (locked)

- `/features`
- `/ecosystem`
- `/examples`
- `/training`
- `/docs`
- `/community`
- `Get Building` (primary CTA)

## 3) Section Outline (High-Level)

| Section   | Primary question                                           | Required page outcomes                             |
| --------- | ---------------------------------------------------------- | -------------------------------------------------- |
| Features  | What capabilities matter most?                             | Map capabilities to real engineering problems      |
| Ecosystem | Which package does what?                                   | Select minimal package set for first build         |
| Build     | How do we implement this now?                              | Ship first workflow with a clear architecture path |
| Training  | How do we level up skill and confidence?                   | Progress from fundamentals to production readiness |
| Docs      | Where are canonical tutorials, guides, and reference docs? | Enable self-serve implementation for most teams    |
| Community | How do teams adopt and share patterns?                     | Enable repeatable, org-level adoption              |

## 4) Recommended Page Inventory

## Features

- `/features`
- `/features/reliability-by-architecture`
- `/features/multi-agent-coordination`
- `/features/operations-observability`
- `/features/incremental-adoption`
- `/features/beam-for-ai-builders`
- `/features/jido-vs-framework-first-stacks`
- `/features/executive-brief`

## Ecosystem

- `/ecosystem`
- `/ecosystem/matrix`
- Package detail pages (one per package)

## Build

- `/build`
- `/build/quickstarts-by-persona`
- `/build/reference-architectures`
- `/build/mixed-stack-integration`
- `/build/product-feature-blueprints`

## Training

- `/training`
- `/training/agent-fundamentals`
- `/training/actions-validation`
- `/training/signals-routing`
- `/training/directives-scheduling`
- `/training/liveview-integration`
- `/training/production-readiness`

## Docs

- `/docs`
- `/docs/getting-started`
- `/docs/contributors`
- `/docs/contributors/ecosystem-atlas`
- `/docs/contributors/package-support-levels`
- `/docs/contributors/package-quality-standards`
- `/docs/contributors/roadmap`
- `/docs/contributors/contributing`
- `/docs/contributors/governance-and-team`
- `/docs/core-concepts`
- `/docs/guides`
- `/docs/reference`
- `/docs/architecture`
- `/docs/production-readiness-checklist`
- `/docs/security-and-governance`
- `/docs/incident-playbooks`

## Community

- `/community`
- `/community/learning-paths`
- `/community/adoption-playbooks`
- `/community/case-studies`

## 5) Content Rules Per Page

Every strategic page should include:

1. A clear claim.
2. A concrete architecture explanation.
3. One runnable proof surface.
4. One training cross-link.
5. One docs/reference cross-link.
6. Include `Get Building` as the primary CTA.

## 6) Conversion Paths (Required Cross-Links)

- Features -> Ecosystem -> Build
- Features -> Examples -> Training
- Training -> Docs
- Ecosystem package pages -> Build quickstarts -> Training modules
- Features -> Get Building
- Docs -> Get Building
- Training -> Get Building

## 7) Near-Term Priority Build Order

1. `/features` sub-pages (beam-for-ai-builders, jido-vs-framework-first-stacks, executive-brief)
2. `/build` + persona quickstarts
3. `/docs` information architecture, getting-started hub, and reference docs
4. Global `Get Building` CTA implementation and routing
5. Community adoption assets and case studies

## 8) Delivery Phases

1. Foundation

- Clarify nav story (`Features -> Ecosystem -> Training -> Docs -> Community`, with `Get Building` CTA).
- Ensure each primary page links to proof + training + docs/reference.

2. Confidence

- Add mixed-stack build guides and explicit migration-without-rewrite paths.
- Expand docs depth for reliability, governance, and operational personas.

3. Scale

- Add architecture decision guides, adoption playbooks, and case-study evidence.
- Build role-specific training tracks and advanced capstones.

## 9) Governance Link

For content validation and drift control workflow, use:

- `specs/content-governance.md`
