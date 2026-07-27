# Jido Workbench

Jido Workbench is a Phoenix LiveView app for Jido ecosystem documentation, examples, and internal learning content.

- Live site: https://jido.run
- Deployment target: Fly.io

This repository is an internal docs/workbench app, not the public SDK source repository for `jido` or `jido_ai`.

## Quick Start

Prerequisites:

- Elixir and Erlang (see `mix.exs`)
- PostgreSQL running locally

```bash
git clone git@github.com:agentjido/agentjido_xyz.git
cd agentjido_xyz
cp .env.example .env
mix setup
mix phx.server
```

Open http://localhost:4000.

## Development Auth

Self-service signup is intentionally disabled.

Bootstrap a local admin account:

```bash
ADMIN_EMAIL=you@example.com ADMIN_PASSWORD='at-least-12-chars' mix run priv/repo/seeds.exs
```

Notes:

- `ADMIN_PASSWORD` is optional. If omitted, log in via magic link.
- With the local mail adapter, open http://localhost:4000/dev/mailbox to get login links.
- `mix setup` already runs seeds, so rerun the seed command any time you want to update/bootstrap your dev account.

## Common Commands

```bash
mix test
mix format
mix credo
mix quality
```

`mix quality` now runs the strict Credo baseline, warnings-as-errors compile, and Dialyzer. The managed `pre_push` hook also runs `mix credo --strict`, `mix test`, and `mix dialyzer`.

## MCP Docs Server

The workbench now ships a read-only MCP docs server for the published documentation corpus.

- `stdio` entrypoint: `mix mcp.docs`
- public HTTP endpoint: `POST /mcp/docs`
- local question helper: `mix run scripts/ask_mcp_docs.exs -- "How do plugins work?"`
- tools: `search_docs`, `get_doc`, `list_sections`, `get_operational_control`, `get_example`
- search/get_doc scope: docs only (`/docs/**`). Examples, skills, ecosystem packages, blog, and compare pages are **not** indexed. `get_example` retrieves the canonical Markdown and metadata for a single published interactive example by path or slug (`jido-e10-t18`); ecosystem stack retrieval is tracked as a scope-expansion task (`jido-e10-t19`).

Notes:

- The MCP server reads from the same docs Arcana collection populated by the local content ingestion flow.
- Search uses the existing hybrid retrieval pipeline and falls back to lexical docs search when the Arcana backend fails.
- `get_doc` returns markdown plus canonical metadata for docs routes.
- Compile the project before launching `mix mcp.docs` from an MCP client so stdout stays reserved for JSON-RPC.

You can also ask the HTTP endpoint questions from the repo with:

```bash
mix run scripts/ask_mcp_docs.exs -- "How do plugins work?"
mix run scripts/ask_mcp_docs.exs -- --sections
mix run scripts/ask_mcp_docs.exs -- --get /docs/learn/ai-chat-agent
```

If you need to refresh the underlying search index locally, run:

```bash
mix content.ingest.local
```

## Content Layout

- `priv/content_plan/**` contains content briefs and planning docs.
- `priv/pages/**` contains docs pages served by the site.
- `priv/blog/**`, `priv/examples/**`, and `priv/ecosystem/**` contain other published content.

For content updates, prefer updating the relevant brief in `priv/content_plan/**` and then syncing the corresponding page in `priv/pages/**`. Direct page edits are still fine for quick fixes.

## Link Audit

Run the site link audit:

```bash
mix site.link_audit --include-heex
```

Useful variants:

```bash
# Include external URL checks (slower)
mix site.link_audit --include-heex --check-external

# Temporarily allow known hidden route prefixes
mix site.link_audit --include-heex --allow-prefix /training
```

The audit writes `tmp/link_audit_report.md` by default and exits non-zero on blocking issues.

## Contributing

See `CONTRIBUTING.md`.
