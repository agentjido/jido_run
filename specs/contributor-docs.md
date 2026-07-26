# Contributor Docs Guide

Last updated: 2026-07-26
Audience: contributors editing site docs/content/specs

This guide defines the **source, review, and proof rules** every contributor
follows, plus what to keep canonical, what to normalize, and what to streamline.

## Source, review, and proof rules at a glance

Every contributor must know three rule families before opening a content or docs
PR. Each family has one named canonical owner — when in doubt, that file wins.

| Rule family | What it means | Canonical owner | When it gates |
|---|---|---|---|
| **Source** | One named source of truth per fact. `specs/` is policy; `priv/` is implementation. | This guide (§ Source rules below) | Every PR |
| **Review** | A page moves to `draft: false` only after ST-CONT-001 Definition of Done passes and is signed off. | `content-governance.md` §11–12 · `runbooks/release_punchlist.md` | Draft-flag removal and every release window |
| **Proof** | Every reliability/performance/adoption/production/control claim links to concrete evidence at a named proof level. | `proof.md` · `positioning.md` (Positioning Canon: Claim policy and proof levels; §13 Claim Discipline; §15 Required proof chain) | Every claim change and every major-page publish |

If a contributor can answer three questions — _where is the source?_, _what must
pass review?_, and _what proof does this claim need?_ — they have the rules.

---

## Source rules

### Keep these canonical (PR-gating) documents

- `specs/positioning.md` — source of truth for narrative and claims.
- `specs/style-voice.md` — source of truth for voice, terms, and mechanical rules.
- `specs/content-outline.md` — source of truth for IA and page inventory.
- `specs/content-system.md` — source of truth for pipeline and route mapping.
- `specs/content-governance.md` — source of truth for publish gates and quality checks.
- `specs/taxonomy.md` — source of truth for tags/axes/crosswalk.
- `specs/proof.md` — source of truth for claim-to-evidence coverage.
- `specs/templates/*` — source of truth for authoring structure by page type.

Keep these as operational but not narrative policy:

- `specs/runbooks/*` — release/admin/ops procedures.

Keep these as context-only references (not normative for PR acceptance):

- `specs/competitors/*`
- `specs/brainstorms/*`
- `specs/ontology/*`
- `specs/docs-manifesto.md`

### Single-owner sections

Do not maintain the same canonical list in multiple files.

- Persona promises: one owner doc, others link to it.
- IA route inventory: one owner doc, others link to it.
- Proof inventory: one owner doc (`specs/proof.md`), others reference it.

### Cross-link style

- Use absolute route links for public content (`/docs/...`, `/features/...`).
- Use repo paths for internal references (`priv/...`, `lib/...`).
- If a page moved, update the reference immediately or mark it as historical.

### Path vocabulary

Use only current path families in canonical docs:

- `priv/pages/*`
- `priv/content_plan/*`
- `priv/ecosystem/*`
- `priv/examples/*`
- `priv/blog/*`

Treat these as retired unless explicitly discussing history:

- `priv/documentation/*`
- `priv/content_plan/why/*`
- `priv/content_plan/operate/*`

## Normalize

Apply these standards across canonical docs.

### 1) Header fields

Every canonical spec file should include these fields near the top:

- `Status:` (`active`, `draft`, `reference`, `deprecated`)
- `Owner:` (role/team, not just person)
- `Last updated:` (`YYYY-MM-DD`)
- `Scope:` (one sentence)

### 2) Status language

Use one vocabulary for work state in new or edited canonical entries:

- `planned`
- `in-progress`
- `ready`
- `published`
- `blocked`

Avoid mixed labels like `partial`, emoji state markers, or ad hoc phrases in canonical docs. Existing legacy labels should be normalized as those files are touched.

## Streamline

### 1) Keep TODOs short and current

`specs/TODO.md` should contain open work only, with clear priority and direct action language.

### 2) Move exploration out of canonical flow

If a doc is exploratory, put it in `specs/brainstorms/` and keep a short pointer from canonical docs when needed.

### 3) Keep canonical docs thin

For canonical files, prefer:

- policy statements
- clear constraints
- links to source details

Avoid large historical narratives and duplicate background sections.

### 4) Enforce update coupling

In PRs that change content routes, structure, or claims, update related canonical docs in the same PR (no deferred doc fixes):

- IA / route / nav change → update `content-outline.md`, `content-system.md`, and `taxonomy.md`.
- Claim change → update `proof.md` and confirm claim discipline still matches `positioning.md`.
- Writing mechanics change → update `style-voice.md` and confirm templates still align.

---

## Proof rules

Proof binds every claim to evidence. A claim with no proof cell is unsupported
and must not ship. The canonical owner is `specs/proof.md`; the policy is in
`positioning.md`.

1. **Every major-page claim has a proof chain.** Per `positioning.md` §15, the
   required chain is: narrative claim → concrete architecture explanation →
   runnable example → training module → relevant section-level reference docs.
2. **Each claim names its proof level.** Per `positioning.md` Positioning Canon
   (Claim policy and proof levels), the levels are (1) design intent,
   (2) tested behavior, (3) benchmark, (4) production evidence. State the level
   beside the claim (`specs/proof.md`).
3. **Restricted language is rejected unless cited.** Self-healing, no downtime,
   uptime guarantees, observe everything, secure by default, compliance-ready,
   enterprise governance, and complete audit trail require an approved proof
   reference. Production-grade / production-ready / production-proven need named
   evidence; `autonomous` must define scope, controls, and stop conditions
   (`positioning.md` Positioning Canon: Claim policy and proof levels,
   `jido-e02` T18–T22).
4. **Bound the claim.** No performance, scale, or reliability claim without a
   concrete reference (benchmark, runnable example, architecture explanation).
   Apply `positioning.md` §13 (Claim Discipline).
5. **Keep the inventory current.** When a claim changes, update `specs/proof.md`
   in the same PR. Restricted control, security, and compliance language cannot
   publish without qualified evidence (content-governance.md §11 proof alignment).

## Review rules

Review enforces the publish gate. The canonical owner is `content-governance.md`
§11 (ST-CONT-001 Definition of Done); the operator checklist is
`runbooks/release_punchlist.md`.

1. **ST-CONT-001 is a hard gate.** A page may move from `draft: true` to
   `draft: false` only when all DoD checks pass and reviewer sign-off plus date
   are recorded (`content-governance.md` §11).
2. **No placeholders in published pages.** `TODO`, `TBD`, `Content coming soon`,
   `lorem ipsum`, and equivalent draft markers must be gone before publish
   (`content-governance.md` §11).
3. **Routes and content stay in sync.** Frontmatter `path`, internal links, and
   CTA destinations must match routable paths in
   `lib/agent_jido_web/router.ex` and shipped content under `priv/`
   (`content-governance.md` §11).
4. **Run the Day-One checklist for every page.** Package references are real,
   code compiles, links resolve, claims are bounded, CTA is routed, voice is
   peer-technical, and the cross-link chain exists in both directions
   (`content-governance.md` §10).
5. **Revalidate freshness each release window.** Re-check proof links/claims,
   re-run the placeholder scan, confirm route/content parity, and reconfirm code
   snippets against current signatures (`content-governance.md` §12). Move stale
   pages back to draft until checks pass.
6. **No major page publishes without proof links.** The reviewer gate blocks
   publish (`content-governance.md` §8). Restricted language is held to the
   proof rules above.

---

## Contributor PR checklist

Before merging content/docs/spec changes:

1. Confirm file/category placement is correct under `priv/`.
2. Confirm route references match `lib/agent_jido_web/router.ex` (source rule).
3. Confirm claim changes are reflected in `specs/proof.md` and the claim is at a
   named proof level (proof rule).
4. Confirm style/term consistency with `specs/style-voice.md`.
5. Confirm the page meets ST-CONT-001 Definition of Done if `draft` is changing
   to `false`, and record reviewer sign-off and date (review rule).
6. Run checks:

```bash
mix format --check-formatted
mix credo
mix test
mix phx.routes
```
