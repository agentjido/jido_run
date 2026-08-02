# Content System Reference

Last updated: 2026-02-28
Purpose: authoritative map from source files to published routes, with contributor workflow rules.

## 1) System architecture

The site has one unified page pipeline plus supporting content collections.

### Published collections

| Collection | Source path | Loader/build module | Primary routes |
|---|---|---|---|
| Pages | `priv/pages/**/*.{md,livemd}` | `AgentJido.Pages` | `/docs...`, `/features...`, `/build...`, `/community...`, `/training...` |
| Ecosystem | `priv/ecosystem/*.md` | `AgentJido.Ecosystem` | `/ecosystem/:id` + `/ecosystem/matrix` |
| Examples | `priv/examples/*.md` | `AgentJido.Examples` | `/examples/:slug` |
| Blog | `priv/blog/**/*.{md,livemd}` | `AgentJido.Blog` | `/blog/:slug`, `/feed`, `/sitemap.xml` |

### Internal collection

| Collection | Source path | Loader/build module | Rendered |
|---|---|---|---|
| Content plan | `priv/content_plan/**/*.md` | `AgentJido.ContentPlan` | No (planning only) |

## 2) Unified pages pipeline (`priv/pages`)

`AgentJido.Pages` is the canonical page pipeline.

- Category is derived from first folder under `priv/pages/`.
- Routes are generated at compile time and wired in `lib/agent_jido_web/router.ex`.
- Both `.md` and `.livemd` are supported through `AgentJido.Pages.LivebookParser`.
- Draft pages are excluded from published indexes.

Compile-time guards already enforce:

- duplicate canonical path detection
- duplicate legacy path detection
- legacy-path collisions with canonical paths
- docs section root shape consistency (`/docs/<section>` must exist when child pages exist)

## 3) Route mapping

| Category | Source pattern | Canonical route pattern |
|---|---|---|
| Docs index | `priv/pages/docs/index.*` | `/docs` |
| Docs pages | `priv/pages/docs/**/*` | `/docs/...` |
| Features pages | `priv/pages/features/*.md` | `/features/:slug` |
| Build pages | `priv/pages/build/*.md` | `/build/:slug` |
| Community pages | `priv/pages/community/*.md` | `/community/:slug` |
| Training pages | `priv/pages/training/*.md` | `/training/:slug` |

Notes:

- `/ecosystem/matrix` is an explicit static route and must stay above `/ecosystem/:id` in the router.
- Legacy docs aliases are handled via `AgentJido.Pages.docs_legacy_redirects/0` + `PageController.docs_legacy_redirect/2`.

## 4) Specs to content contract

Think of the flow as:

`specs/*.md` (strategy/rules) -> `priv/content_plan/**/*.md` (briefs) -> `priv/pages|ecosystem|examples|blog` (published content)

Responsibilities:

- `specs/` defines policy, narrative constraints, and quality gates.
- `priv/content_plan/` defines page-level intent and validation metadata.
- `priv/...` published collections contain ship-ready content.

## 5) Contributor workflow

When adding or changing a page:

1. Confirm destination and route in `specs/content-outline.md`.
2. Check tone and terminology in `specs/style-voice.md`.
3. Use the matching template from `specs/templates/`.
4. Ensure claim evidence exists (or update `specs/proof.md`).
5. If needed, update or create the brief in `priv/content_plan/`.
6. Add/update the page in the correct `priv/` collection.
7. Verify cross-links and route parity.

## 6) Required checks before merging

```bash
mix format --check-formatted
mix credo
mix test
mix phx.routes
```

For release or broad route changes, also run:

```bash
mix site.link_audit --include-heex
```

## 7) Anti-drift rules

- Do not add new references to retired path families (`priv/documentation/*`, `priv/content_plan/why/*`, `priv/content_plan/operate/*`).
- Keep route references canonical (`/docs/...`, `/features/...`, `/build/...`, `/community/...`, `/training/...`).
- If route structure changes, update these in the same PR:
  - `specs/README.md`
  - `specs/content-outline.md`
  - `specs/content-system.md`
  - `specs/taxonomy.md`

## 8) Canonical source per rendered surface (`E00-T06`)

Each rendered surface has one named canonical source. When the same surface is
served in multiple forms (browser HTML, Markdown, Livebook, search, MCP), all
forms derive from the source listed here.

| Surface | Canonical source | Also served as |
|---|---|---|
| Home page | `lib/agent_jido_web/live/jido_home_live.ex` (+ `components/jido/home_sections.ex`) | (no static equivalent — `E04`) |
| Docs hub | `priv/pages/docs/index.md` aligned to the docs hub LiveView | HTML, Markdown fallback (`E10-T13`) |
| Docs leaf (Markdown) | `priv/pages/docs/**/*.md` | HTML, `.md` endpoint (expanded — `E01-T08`) |
| Docs leaf (Livebook) | `priv/pages/docs/**/*.livemd` | HTML, `.md` endpoint, downloadable Livebook (`E01-T09`), Run-in-Livebook |
| Build / Compare / Features leaf | `priv/pages/{build,compare,features}/*.md` | HTML, Markdown (`E10-T10`, `E10-T12`) |
| Examples hub | `lib/agent_jido_web/live/jido_examples_live.ex` (data: `priv/examples/*.md`) | HTML, Markdown (`E10-T11`) |
| Example detail | `priv/examples/*.md` (+ embedded source) | HTML, sitemap (`E08-T31`, `E10-T21`) |
| Ecosystem hub | Ecosystem LiveView (data: `priv/ecosystem/*.md`, `layering.ex`) | HTML, Markdown (`E10-T12`) |
| Ecosystem detail | `priv/ecosystem/*.md` (+ registry data) | HTML |
| Skills catalog | vendored `priv/skills/**/SKILL.md` | LiveView cards (currently empty — `E10-T23`) |
| Markdown delivery | `lib/agent_jido_web/markdown_content.ex` | `.md` and `Accept: text/markdown` |
| Sitemap | `lib/agent_jido_web/controllers/sitemap_controller.ex` | `/sitemap.xml` |
| Search index | search ingestion pipeline | cited search results |
| MCP | MCP docs server (`lib/mix/tasks/mcp.docs.ex` + server) | MCP tool responses |

Rule: a change to a canonical source must update every "also served as" form in
the same PR. Parity is enforced by `E01-T11`/`E01-T12` and `E10-T34`.
