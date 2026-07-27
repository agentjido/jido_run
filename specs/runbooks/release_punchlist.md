# Website Release Punchlist

Last updated: 2026-07-26

## Purpose

Ship the public site with consistent positioning, working navigation paths, and no critical link/content regressions.

This runbook is the operator checklist for release readiness.

## Launch Scope Assumptions

- Training pages are intentionally hidden for this launch.
- Any existing `/training` or `/training/*` links are release defects unless explicitly accepted as temporary 404 behavior.
- Core positioning is locked from `specs/README.md`:
  - Anchor phrase: `Jido is a runtime for reliable, multi-agent systems.`
  - Hero headline/subhead and top nav labels are fixed for launch.

## Required Hard Gates

All items must be green before release:

1. Positioning parity:
- Home + top-nav entry pages align to the locked anchor language and differentiator.

2. Link integrity:
- Internal links resolve to canonical shipped routes or are intentionally redirected.
- No hidden-scope links are used as primary path CTAs.

3. Content quality:
- No placeholders (`TODO`, `TBD`, `coming soon`, etc.).
- Claims are bounded and proof-backed.
- Section template expectations are met (`specs/templates/*`).

4. Technical quality:
- `mix format --check-formatted`
- `mix credo`
- `mix test`

5. SEO/share baseline:
- OG routes return images for top pages.
- `sitemap.xml` and `feed` endpoints render.

6. Operational-control copy review:
- Every control page answers the four control questions, holds the claim limits, and resolves proof links (see [Operational-Control Copy Review](#operational-control-copy-review-jido-e12-t45) below).

## Operational-Control Copy Review (`jido-e12-t45`)

A reviewer runs this copy review before every release that touches operational-control
messaging. It is release hard gate 6 above. The reviewer must confirm three things on
every high-level page that uses `production`, `control`, `identity`, `audit`,
`observable`, or `reliable` language:

1. **The four control questions are answered.** Each such page must preserve all four
   questions Jido answers for every piece of agent work — **Who initiated work**,
   **What was allowed**, **What happened**, and **How failure was handled** — and link
   each question to its proof surface. A page that drops a question fails the review.

2. **Claim limits hold.** Copy must stay inside the bounded meanings in
   `specs/positioning.md` (§13 Claim Discipline → Claim boundaries). The six bounded
   terms — **identity**, **authorization**, **audit**, **observability**, **policy**,
   and **production** — each have one safe current meaning; copy must not imply more (do
   not imply authentication/IAM from identity, a complete RBAC/ABAC product from
   authorization, tamper evidence or retention from audit, durable audit evidence from
   observability, central administration across packages from policy, or no
   downtime/complete safety from production). Restricted, proof-required, and
   definition-required language is held to the Claim policy and proof levels in the same
   section.

3. **Proof links resolve.** Every control claim links to its evidence: the Control Proof
   Fields in `specs/proof.md` (control point, configuration, test, limitation, owner,
   version, validation date) and the runnable proof — the controlled-Agent example proves
   the complete control path end to end. A claim whose version basis depends on an
   unreleased or unsupported package fails this review (`jido-e12-t44`); a control claim
   with a broken or missing proof link fails this review.

The reviewer records the result in the Sign-Off Record (reviewer, date, and any accepted
residual risk). This review complements the automated content gates below — it is the
human check that the copy reads as bounded control, not as compliance or safety it
cannot back.

## Execution Order (Homepage Down)

Run this in top-down order so narrative and routing issues are caught early:

1. `/` (home)
- Validate hero copy against locked anchor.
- Validate primary CTA and secondary CTA paths.
- Validate in-page links to Features/Ecosystem/Examples/Docs/Build/Community.

2. `/features` + `/features/*`
- Confirm each page has: clear capability claim, proof reference, next-step CTA.
- Confirm no primary CTA points into hidden routes.

3. `/ecosystem` + `/ecosystem/*`
- Confirm package claims match metadata in `priv/ecosystem/*`.
- Confirm links into docs/examples/build are live.

4. `/examples` + `/examples/*`
- Confirm example detail routes render and key flows are runnable/documented.

5. `/docs` + `/docs/*`
- Confirm canonical docs routes and legacy redirects.
- Confirm references match current module/function names.

6. `/build` + `/build/*`
- Validate setup and implementation steps against current code/repo structure.

7. `/community` + `/community/*`
- Validate adoption/case-study claims and attribution.

8. `/blog`, `/blog/:slug`, `/feed`, `/sitemap.xml`
- Smoke-test list, detail, tag, search, feed, and sitemap.

## Punchlist Matrix Template

Use one row per route/page under review:

| Route | Page purpose | Key claim | Proof link(s) | Primary CTA target | Link audit | Content QA | Owner | Status | Notes |
|---|---|---|---|---|---|---|---|---|---|
| `/` | | | | | ✅ / ⚠️ / ❌ | ✅ / ⚠️ / ❌ | | todo / in-progress / done | |

## Link Audit Workflow

Run internal link checks first (fast), then optional external checks:

```bash
mix site.link_audit --include-heex
mix site.link_audit --include-heex --check-external
```

Notes:

- The audit intentionally ignores global `/*path` catch-all routing so links that only land on 404 are still flagged.
- Use `--allow-prefix /training` only if you intentionally want to suppress hidden-training findings for a specific release cycle.
- `scripts/link_audit.sh` remains available as a compatibility wrapper around `mix site.link_audit`.

## Release-Day Command Set

```bash
mix format --check-formatted
mix credo
mix test
mix phx.routes
mix site.link_audit --include-heex
mix site.orphan_page_report
```

## Severity and Triage

- `P0` (block release): broken primary nav path, broken CTA, broken docs/build entry path, runtime error on public route.
- `P1` (fix before release if feasible): broken secondary links, stale claims, missing proof links.
- `P2` (post-release backlog): polish copy, low-impact UX rough edges.

## Sign-Off Record

Fill before release cut:

- Release date:
- Reviewer:
- Scope:
- Hard-gate status:
- Remaining accepted risks:
- Follow-up tickets:

## Unmatched-Link Regression Gate (`E00-T07`)

A release **must not increase** the number of unmatched internal links.

- Baseline (2026-07-23, frozen): **64 unmatched internal links** across 603
  internal links and 173 route patterns.
  Artifact: `specs/audits/link-audit-baseline-2026-07-23.md`.
- Current ceiling: **0** (reduced from 64 by retired-training redirects and the published Operations section (`E01`, `E07`) and
  getting-started legacy redirects). This is the max allowed count.
- Check: `mix site.link_audit --include-heex --report tmp/link_audit_report.md`.
  The audit scans `priv/pages/**/*.{md,livemd}` and `lib/agent_jido_web/**/*.{heex,ex}`
  (Livebooks were added to the input set in `E00-T04`), and treats paths with a
  `LegacyRedirects` destination as matched (`E01-T13/T14/T15`).
- Gate rule: the `Unmatched internal links` count in a PR must be less than or
  equal to the current ceiling. A net increase blocks the release until the links
  are fixed or each new unmatched link is given an intentional redirect.
- Lowering the count is always allowed and encouraged; update the current ceiling
  above (and the frozen baseline stays as the historical record).

## Automated content gates (`jido-e12`)

These gates run in `mix test` and block a release on failure:

- **Unmatched internal links = 0** — `test/mix/tasks/site.link_audit_test.exs` (ceiling 0; scans `.md`/`.livemd` + HEEx; legacy-redirect-aware).
- **No restricted claims on public pages** — `test/agent_jido/content_claim_linter_test.exs` (corpus-wide, negation-aware) + `test/agent_jido_web/canon_claim_scan_test.exs` (global surfaces).
- **No unresolved `{{...}}` placeholders in public Markdown** — `test/agent_jido_web/markdown_content_test.exs`.
- **Public Livebooks have matching tests** — `test/agent_jido/livebook_docs_coverage_test.exs`.
- **AI tutorial key/model provider consistency** — `test/agent_jido/first_llm_tutorial_consistency_test.exs`.
- **Public example detail pages in the sitemap** — `test/agent_jido_web/controllers/sitemap_controller_test.exs`.
- **Skills catalog renders cards** — `test/agent_jido/skills_catalog_test.exs`.
- **No orphan public content pages** — `test/agent_jido/release/orphan_page_report_test.exs` (ceiling 0; every published page must appear in the sidebar menu or be the target of an internal link from `priv/pages`, `priv/blog`, `priv/examples`, `priv/ecosystem`, or `lib/agent_jido_web/**`).

## Orphan-Page Report Gate (`E12-T20`)

A release **must not ship** a public content page that has no inbound link.

- Check: `mix site.orphan_page_report --report tmp/orphan_page_report.md`.
- Scope: published `AgentJido.Pages` routes (docs, features, build, compare),
  excluding the retired `/training/*` surface and the `/docs` index alias, which
  mirrors the router's compile-time `@page_routes`.
- Reachability rule: a page passes when it appears in the navigation menu
  (`page.in_menu == true`, rendered by the section sidebar) **or** another
  published page or HEEx template links to its route (a related-content link).
  An orphan is a page that satisfies neither — it cannot be reached from
  anywhere on the site.
- Ceiling: **0** orphans. If a page must be hidden from the menu (`in_menu: false`),
  add a cross-link to it from another page or template so it stays reachable.
- The report also lists pages *reachable only via the menu* — those pass the gate
  but would become orphans if ever hidden, so they are prime candidates for an
  added related-content link.

