# AGENTS.md - Jido Workbench

## Work Management

This project tracks work with `bw` (Beadwork), which persists to git. Plans, progress, and decisions survive compaction, session boundaries, and context loss.

Always run `bw prime` before you start work. It provides the workflow context, current task state, and repository hygiene warnings.

Committing, closing issues, and syncing are part of completing a task.

## Commands

- **Setup:** `mix setup` (deps, assets)
- **Run server:** `mix phx.server` or `iex -S mix phx.server`
- **Test all:** `mix test`
- **Single test:** `mix test test/path/to/test_file.exs:LINE`
- **Format:** `mix format`
- **Lint:** `mix credo`

## Architecture

Phoenix 1.7+ LiveView app showcasing the Jido AI Agent Framework. Hosted on Fly.io.

- `lib/agent_jido/` - Core business logic (blog, documentation, agents, chat)
- `lib/agent_jido_web/` - Phoenix web layer (LiveViews, controllers, components)
- `config/` - Environment configs (dev.exs, test.exs, prod.exs, runtime.exs)
- Uses `jido` and `jido_ai` for AI agent functionality; set `LOCAL_JIDO_DEPS=true` for local dev

## Deployment Process

- Fly apps: staging is `agentjido-stage` at `stage.jido.run`; production is `agentjido-prod` at `jido.run`
- Default release flow is: commit to `main`, push, wait for the `CI` workflow to pass, and wait for `Deploy Fly STAGE` to auto-deploy staging
- After staging auto-deploys, verify the change on `stage.jido.run` before touching production
- Only trigger `Deploy Fly PROD` after staging verification is complete
- Production deploys should use Fly's `bluegreen` strategy for minimal downtime

## Code Style

- Format with `mix format`; use `@doc`/`@moduledoc` and `@spec` on public functions
- snake_case functions/variables, PascalCase modules
- Keep controllers thin; business logic in contexts under `lib/agent_jido/`
- Use changesets for validation; parameterized Ecto queries to prevent SQL injection
- Never log secrets; use `config/runtime.exs` for runtime secrets

## Release Hygiene

- Do not modify `CHANGELOG.md`; release notes are generated from Git history during release, so keep changes focused on proper Conventional Commits.
