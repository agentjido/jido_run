# Content Governance Strategy

Version: 2.0  
Last updated: 2026-02-18  
Scope: Keep site content accurate as the Jido ecosystem evolves.

## 1) Problem Statement

Site content can drift from source code as packages, modules, signatures, and examples change.  
Governance needs to detect drift early and route fixes consistently.

## 2) Governance Principles

- Source-of-truth first: ecosystem metadata and package repos drive factual claims.
- Validation before promotion: published content must pass machine-checkable gates.
- Signal-driven workflow: drift checks should be composable and observable.
- Safe automation: no destructive actions; issue filing and notifications must deduplicate.
- Proof-backed claims: feature/capability copy must link to runnable examples and references.

## 3) Canonical Sources

- `priv/ecosystem/*.md` via `AgentJido.Ecosystem`
- `priv/content_plan/**/*.md` via `AgentJido.ContentPlan`
- Package repositories declared in ecosystem metadata
- Site routes/pages under `lib/agent_jido_web/`

## 4) Validation Pipeline (High-Level)

1. Load ecosystem registry
- Normalize package IDs, repos, versions, and dependency edges.

2. Resolve source refs
- Determine target tag/branch/SHA using content ref overrides and package version policy.

3. Sync repositories
- Clone/fetch and checkout refs in a deterministic working directory.

4. Build code intelligence index
- Index modules, public functions/arities, deprecations, and source paths.

5. Validate content plan
- Verify module references, file references, cross-links, and publication policy fields.

6. Crawl markdown/livebook content
- Inventory code fences, module mentions, links, and metadata.

7. Detect drift
- Module rename/removal.
- Signature change.
- File path drift.
- Broken links or stale examples.

8. Triage and action
- Deduplicate findings, assign severity, and generate actionable issue drafts.

9. Report and notify
- Publish run summary and route alerts to owners.

## 5) Finding Severity Model

- High: broken published paths, invalid examples, missing core module references.
- Medium: signature mismatch, outdated API usage, unresolved cross-link.
- Low: minor copy inconsistencies, optional metadata gaps.

Each finding should include:

- `kind`
- `expected`
- `observed`
- `evidence`
- `suggested_fix`
- `owner_scope`

## 6) Publish Gates (Recommended)

Required for published content:

- Valid package/repo reference.
- Valid source module or source file mapping.
- Resolved prerequisites/related links.
- Defined purpose and learning outcomes.
- At least one example/training/ops-reference cross-link in strategic pages.

## 7) Operating Cadence

- Hourly incremental checks (changed scope).
- Nightly full sweep (all packages/content).
- On deploy: quick validation for touched pages and routes.

## 8) Ownership Model

- Content strategy owner: message clarity, narrative consistency.
- Technical docs owner: API and implementation correctness.
- Platform owner: validation jobs and observability health.
- Reviewer gate: no major page publish without proof links.

## 9) Implementation Phases

1. Foundation
- Registry load, repo sync, and content-plan validation baseline.

2. Drift intelligence
- Code index + module/signature/path drift detection.

3. Deep validation
- Code-fence checks, livebook execution checks, link verification.

4. Action loop
- Automated triage, issue filing, and recurring report delivery.

## 10) Day-One Content Checklist

Use this manual checklist for every page before publishing. This is the minimum viable governance gate while the automated pipeline (§4) is under development.

### Before publishing any page

1. **Package references are real.** Every package named on the page exists in `priv/ecosystem/*.md` with `visibility: public`. Do not reference packages that are stubs, private, or not yet released.
2. **Code examples compile.** Every code fence with Elixir code must reference real modules, real functions, and correct arities. Run the example or verify against current source.
3. **Links resolve.** Every internal cross-link points to a route that exists in `lib/agent_jido_web/router.ex` or a published content path. No links to planned-but-unbuilt pages.
4. **Claims are bounded.** No performance, scale, or reliability claims without a concrete reference (benchmark, example, architecture explanation). Apply positioning.md §13 (Claim Discipline).
5. **CTA is present and routed.** Every strategic page includes `Get Building` or section-appropriate CTA that links to a real destination.
6. **Voice check.** Page reads like a staff engineer explaining to a peer, not marketing copy. Apply positioning.md §19 (Voice and Tone Guide).
7. **Cross-link chain exists.** Page links forward to at least one next-step page (training, docs, build, or community) and backward to at least one context page (features, ecosystem).

### Section-specific checks

- **Features pages:** Include at least one code example demonstrating the capability. Link to relevant ecosystem package and training module.
- **Ecosystem pages:** Package metadata matches `priv/ecosystem/*.md` frontmatter. Dependency relationships are accurate.
- **Build pages:** All setup steps are tested against current package versions. Prerequisites are listed.
- **Training pages:** Learning outcomes are stated. Code is runnable in sequence. Links to prerequisite and next training module.
- **Docs pages:** API references match current module signatures. Configuration keys are valid.
- **Community pages:** Claims about adoption or usage are attributed. Case studies have explicit permission.

## 11) Canonical Content Publish Definition of Done (ST-CONT-001)

This section is the hard gate for changing content pages from draft to published state across Epic 4 story waves.

### Required Definition of Done checks

1. **Proof alignment requirement.** Claims that describe reliability, performance, adoption, production readiness, or governance must link to concrete proof assets (`specs/proof.md`, runnable examples, docs reference pages, or validated package metadata).
2. **Placeholder prohibition.** Published pages cannot include placeholder text such as "TODO", "TBD", "Content coming soon", "Coming soon", "lorem ipsum", or equivalent draft markers.
3. **Route/content sync requirement.** Frontmatter `path`, internal links, and CTA destinations must match currently routable paths in `lib/agent_jido_web/router.ex` and shipped content under `priv/`.
4. **Draft-flag removal gate criteria.** `draft: false` is allowed only when all minimum checks below pass and are documented in the release review note.

### Minimum checks before changing `draft: true` to `draft: false`

1. Verify no placeholder markers remain in title, body, metadata, or CTA blocks.
2. Verify all internal links and CTAs resolve to existing routes or published content paths.
3. Verify claims are proof-backed and point to current evidence (or rewrite to remove unsupported claims).
4. Verify code examples and configuration snippets still match current APIs/module signatures.
5. Verify section template expectations are met (`specs/templates/*`) for page type.
6. Record reviewer sign-off and date in the content release note/checklist for the page.

## 12) Freshness Checklist and Release Cadence (ST-CONT-001)

### Freshness checklist (required each release window)

1. Revalidate proof links and claims against current `specs/proof.md`, package metadata, and public routes.
2. Re-run placeholder scan for edited pages and linked dependency pages.
3. Re-check route/content parity for any changed slugs, nav labels, and CTA targets.
4. Reconfirm code/config snippets against current source signatures and package versions.
5. Confirm each page has an explicit owner and last-reviewed date in the release log.
6. Keep stale pages in draft (or move back to draft) until checks pass.

### Release cadence process

1. **Weekly freshness triage (Monday):** Review pages changed in the prior week and create fix tickets for drift findings.
2. **Biweekly publish window (Wednesday):** Apply the DoD checks above, then approve `draft: false` transitions for eligible pages.
3. **Monthly full sweep (first business week):** Sample every top-nav section for route parity, proof coverage, and stale claims; feed findings into next sprint.
4. **Quarterly operational-control proof audit (every quarter, ST-CONT-001 / jido-e12-t49):** Each operational-control claim recorded in `specs/proof.md` (Control Proof Fields) is re-verified by its **owner**. The owner confirms current **behavior** (control point + configuration), **versions** (version basis is a released, supported package), **limits** (limitation), and **links** (test references resolve), then refreshes the claim's `Validation date`. A claim whose `Validation date` drifts past the quarter (or is missing/malformed) is overdue and becomes assigned work attributed to its owner. The executable audit is `AgentJido.OperationalControlProof.audit_queue/1`; the seven-field schema and the version/test gates are enforced continuously by the jido-e12-t38 proof gate and the jido-e12-t44 release gate.
5. **Quarterly message review (every quarter, ST-CONT-001 / jido-e12-t36):** The four messaging dimensions are reviewed together — **position** (`specs/positioning.md`, whose §1 public category is the canonical positioning anchor), **package roles** (the ecosystem registry, `priv/ecosystem/*.md` via `AgentJido.Ecosystem`; every public package carries a role), **proof** (`specs/proof.md`), and **audience** (`specs/persona-journeys.md`). Reviewed together means the four still tell one story: **position**, **proof**, and **audience** record the same positioning anchor, and every public package still carries a role. Each dated source records its `Last updated` date; a dimension whose date drifts past the quarter (or is missing), whose recorded anchor diverges from the canonical anchor, or — for package roles — where a public package has lost its role, is overdue and becomes assigned work. The executable review is `AgentJido.MessageReview.review_queue/1`; `reviewed_together?/1` is true only when no dimension is overdue. This is the messaging counterpart of the quarterly operational-control proof audit: that audit re-verifies control **claims**; this review re-verifies the **message**.

### Trust-boundary change review (on material architecture change, ST-CONT-001 / jido-e12-t50)

A **material architecture change** is one that alters a documented trust boundary
in `specs/operations-reference-architecture.md` — the **authentication
boundary**, the **recovery boundaries**, **what stays outside Jido**, the
**threat and control model**, or the **explicit non-goals**. Each boundary
carries a recorded content signature and last-reviewed date in
`specs/audits/trust-boundary-baseline.md`. When a boundary's current signature
no longer matches its recorded signature (or it has no recorded baseline), the
boundary is **changed** and creates two reviews:

1. **Documentation review** — re-read the documented boundary and confirm the
   threat-and-control model still describes the architecture.
2. **Proof review** — re-verify the seven proof fields (control point,
   configuration, test, limitation, owner, version, validation date) for each
   operational-control proof claim that depends on the changed boundary
   (`specs/proof.md`, Control Proof Fields; the field set is enforced
   continuously by the jido-e12-t38 proof gate and the jido-e12-t44 release
   gate).

This is the **event-triggered** counterpart of the quarterly
operational-control proof audit (§12 release cadence step 4) and the quarterly
message review (step 5): those fire on the calendar; this fires when a trust
boundary actually changes. The executable review is
`AgentJido.ThreatControlModel.review_queue/1`; `review_due?/1` is true when any
boundary is changed. After the review, refresh the baseline via
`AgentJido.ThreatControlModel.to_baseline_markdown/1`.

### Required references for downstream stories

- Story cards ST-CONT-002 through ST-CONT-008 must treat this section as a hard gate before any draft-flag removal.
- When those story cards reference "Apply ST-CONT-001 DoD," they refer specifically to §11 and §12 of this document.
