# Content Inventory Baseline — 2026-07-23

Status: Baseline (M0 controlled starting point). Frozen reference for the
site-facelift program. Do not edit in place; supersede with a new dated file.
Source epic: `jido-e00` / task `E00-T02`.

## Purpose

Record the exact content inventory at the start of the site-facelift program so
every later epic can compare against a fixed point. Counts are generated from the
file tree with the commands in the "Method" section.

## Counts (2026-07-23)

| Surface | Source location | Count | Notes |
|---|---|---:|---|
| Docs (Markdown) | `priv/pages/docs/**/*.md` | 50 | Includes section roots and the hard-coded hub source `priv/pages/docs/index.md` |
| Docs (Livebook) | `priv/pages/docs/**/*.livemd` | 21 | Runnable Livebooks; now included in the link audit (see `E00-T04`) |
| Docs (total files) | `priv/pages/docs/**` | 71 | 50 `.md` + 21 `.livemd` |
| Features | `priv/pages/features/*.md` | 11 | |
| Build | `priv/pages/build/*.md` | 5 | |
| Compare | `priv/pages/compare/*.md` | 9 | |
| Training (retired) | `priv/pages/training/*.md` | 6 | Public routing retired; inbound links are defects (see `E01-T15`) |
| Examples (records) | `priv/examples/*.md` | 46 | 22 public; status defaults to draft when unset (see `E08-T30`) |
| Ecosystem packages | `priv/ecosystem/*.md` | 52 | 47 public |
| Blog | `priv/blog/**/*.{md,livemd}` | 5 | |
| Community showcase | `priv/community_showcase/**` | 3 | 2 public |
| Skills | `priv/skills/**/SKILL.md` | 23 | 0 render as cards on the live Skills page (see `E10-T23`) |
| Example source noise | `priv/examples/*.tmp` | 1 | `address-normalization-agent.md.tmp` (see `E01-T18`) |

### Route status summary

| State | Families |
|---|---|
| public | Docs (most), Features, Build, Compare, Examples (22), Ecosystem (47), Blog, Community (2) |
| draft | Operations, Architecture, and 7 other Docs drafts (9 files); 1 published Debugging reference is TODO-only (see `E01-T17`) |
| retired | Training (6 files) |
| redirect | (none configured yet — see `E01-T13`, `E01-T14`) |

Draft detection note: Docs drafts are excluded from published indexes by the
`AgentJido.Pages` pipeline. A `grep` for `^draft: true` / `^status: draft` returns
0 because this repository marks drafts through the pipeline's status semantics,
not a single frontmatter key. The canonical route-status table is maintained in
`specs/taxonomy.md` (see `E00-T05`).

## Method

Counts are reproducible with:

```sh
find priv/pages/docs -name '*.md' | wc -l
find priv/pages/docs -name '*.livemd' | wc -l
find priv/pages/features -name '*.md' | wc -l
find priv/pages/build -name '*.md' | wc -l
find priv/pages/compare -name '*.md' | wc -l
find priv/pages/training -name '*.md' | wc -l
find priv/examples -name '*.md' | wc -l
find priv/ecosystem -name '*.md' | wc -l
find priv/blog -name '*.md' -o -name '*.livemd' | wc -l
find priv/community_showcase -type f | wc -l
find priv/skills -name 'SKILL.md' | wc -l
```

The authoritative published-vs-draft split is produced at runtime by
`lib/agent_jido/content_ingest/inventory.ex` (Docs/Blog/Ecosystem) and the
`AgentJido.Pages`, `AgentJido.Examples`, and `AgentJido.Ecosystem` modules.

## Related artifacts

- Link audit baseline: `specs/audits/link-audit-baseline-2026-07-23.md`
- Master baseline and ownership: `specs/audits/baseline-2026-07-23.md`
- Control-surface inventory: `specs/audits/control-inventory-2026-07-23.md`
