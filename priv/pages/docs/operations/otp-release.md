%{
  description: "How a Jido system is assembled into an OTP release — the build, runtime configuration, secrets, the deploy probe, and the migration boot order — traced to the release files in this repo.",
  title: "OTP release guidance",
  category: :docs,
  legacy_paths: [],
  tags: [:docs, :operations],
  order: 370,
  control_types: [:observation, :redaction],
  control_intent: :evaluate,
  draft: false
}
---
# OTP release guidance

A Jido agent runs under OTP supervision inside a BEAM release. This page documents how *this repository* assembles that release — the build, the runtime configuration, the secrets, the probe a deploy waits on, and the order migrations run at boot — so an operator can trace every claim to a real file. It is the host-agnostic foundation the [Fly.io deployment](/docs/operations/fly-io-deployment) page builds on: how the artifact is built and configured, independent of where it ships.

The acceptance for this page is narrow and literal: **configuration, secrets, probes, and migration order are covered.** Each gets its own section below, and every section cites the file it describes. Nothing here is aspirational — the release is what `Dockerfile`, `config/`, `rel/`, and `entrypoint` produce today.

Jido itself ships no release, no database, and no secret manager. The release is this repo's assembly; an `AgentServer` runs under OTP supervision in any BEAM release, on any host. Concretely, this repo — not Jido — owns the build, the configuration, the secrets, the probe, and the migration boot order.

## Configuration

Configuration is split across three files by *when* they take effect: two are compile-time (baked into the release once), one is runtime (re-evaluated on every boot). Keeping that split straight is the whole job.

| File | When it runs | What lives here |
|---|---|---|
| `config/config.exs` | compile-time, all envs | shared compile-time config — endpoints, repos, adapters |
| `config/prod.exs` | compile-time, prod only | prod-only compile config — static manifest, mailer client, logger level |
| `config/runtime.exs` | at boot, after compile | env-driven values — host, port, pool, feature flags, secrets |

`config/runtime.exs` is the file that matters operationally. It is executed after compilation and before the system starts, which is exactly why runtime values — `PHX_HOST`, `CANONICAL_HOST`, `PORT`, `POOL_SIZE`, `ECTO_IPV6`, `PRIMARY_REGION`, and the feature flags (`ENABLE_ANALYTICS`, the `POSTHOG_*` family, `AGENTJIDO_RUNTIME_ENABLED`) — are read from environment variables there and not baked in. The `Dockerfile` copies it in *after* `mix compile` precisely so a change to runtime config never forces a recompile:

```dockerfile
# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/
COPY rel rel
RUN mix release
```

The payoff is that **one release runs in both environments.** Stage and prod deploy the same image; they differ only in the environment each `fly.toml` sets — not in application code and not in the release. `PHX_HOST`/`CANONICAL_HOST` resolve to `stage.jido.run` or `jido.run`, `POOL_SIZE` and the analytics flags differ, but the compiled artifact is identical. (How those two environments ship is documented on [Fly.io deployment](/docs/operations/fly-io-deployment); this page is about the release itself.)

## Secrets

Secrets follow one rule: they enter through `config/runtime.exs` from the environment, never from source. In production, four values are required and the release **fails closed** if any is missing — `runtime.exs` raises and the boot stops before the endpoint serves:

- `DATABASE_URL` — the Postgres connection string (`ecto://USER:PASS@HOST/DATABASE`).
- `SECRET_KEY_BASE` — signs and encrypts cookies; generate one with `mix phx.gen.secret`.
- `BREVO_API_KEY` — the transactional mailer key.
- `OPENAI_API_KEY` — required when the Arcana embedder is `:openai` (the only supported remote embedder; local embedders are disabled in this project).

```elixir
# config/runtime.exs — prod fails closed on a missing required secret
database_url =
  System.get_env("DATABASE_URL") ||
    raise """
    environment variable DATABASE_URL is missing.
    ...
    """
```

Fail-closed is the enforcement: a release booted without its required secrets never reaches the probe, so a misconfigured machine fails the deploy gate rather than serving with partial credentials. Optional integrations gate their own secrets behind a feature flag, so they only fail-closed when the feature is on — `CONTENTOPS_CHAT_ENABLED` requires `TELEGRAM_BOT_TOKEN` and `DISCORD_BOT_TOKEN`; `CONTENT_ASSISTANT_REQUIRE_TURNSTILE` requires the Turnstile site and secret keys; the analytics ingestion keys (Plausible, Google Search Console, the GitHub app) are optional throughout.

Where the values live is an application and platform choice — Jido provides no secret manager. This repo injects them through the host's secret store (Fly secrets for runtime, `FLY_API_TOKEN` in GitHub Actions secrets for the deploy workflow) so no credential is ever committed. Treat secret hygiene as ongoing, not just boot-time: logs, telemetry, and error output must redact secrets, prompts, tool arguments, and principal data per your configured rules — see [Security and governance](/docs/operations/security-and-governance).

## Probes

A release exposes one probe surface for deploy validation: the `/status` endpoint, served by the `AgentJidoWeb.Plug.Heartbeat` plug (`lib/agent_jido_web/plugs/heartbeat_plug.ex`). It answers two questions a deploy pipeline and an on-call engineer both ask.

| Route | Returns | Question it answers |
|---|---|---|
| `GET /status` | `200 ok` | Is the endpoint up and serving? |
| `GET /status/<hash>` | `200 ok` / `500` | Is the running build the one we shipped? |

`/status` is the liveness probe a load balancer and a deploy pipeline poll. `/status/<hash>` compares the requested hash against the build hash written under `priv/` at build time, returning `500` on mismatch — so a deploy that looks healthy but is serving yesterday's code fails the gate before traffic reaches it. Both deploy workflows gate on this surface: Fly polls `GET /status` every 30s with a 180s grace period and a 3s timeout, and a production blue-green rollout waits for a passing check before cutting traffic over.

The probe is the **deploy/build gate**, distinct from the runtime health contract. It confirms the new build is serving; the three independent health axes — process, dependency, and work health — are a separate, deeper check documented on [Health checks and readiness](/docs/operations/health-checks-and-readiness). Order matters: migrations run before the endpoint boots (below), so a machine that passes `/status` has already applied its schema.

## Migration order

At boot, the release runs schema migrations **before** it serves a single request. The entrypoint script (copied into the image as `/app/bin/entrypoint`) is the whole boot sequence in two lines:

```sh
# entrypoint
/app/bin/agent_jido eval "AgentJido.Release.migrate()"
/app/bin/hivemind /app/Procfile
```

That ordering is the acceptance: **migrate first, serve second.** `AgentJido.Release.migrate/0` (in `lib/agent_jido/release.ex`) runs `Ecto.Migrator.run(repo, :up, all: true)` for every configured repo — applying all pending migrations, blocking — and only then does `hivemind` read the `Procfile` (`web: /app/bin/server`) and start the Phoenix endpoint. A new release therefore never serves against a stale schema, and because `/status` cannot pass until the endpoint is up, a machine that takes traffic has already migrated.

The migration surface, all in `lib/agent_jido/release.ex`:

- `migrate/0` — apply all pending migrations (`:up`). This is what the entrypoint runs on every boot.
- `migrate_and_ingest/0` — migrations followed by Arcana content indexing, for a one-step release.
- `rollback(repo, version)` — roll a repo back to a version.
- `create_db/0` — create the database if it does not exist.
- `ingest_content/0` — idempotent first-party content indexing.

The migrations themselves are timestamped files under `priv/repo/migrations/` (the current set runs from `20260211124047_create_arcana_tables.exs` through `20260605170000_harden_analytics_storage.exs`). To run migrations as a discrete step — or where the database may not be up when the machine boots — the release also ships a `bin/migrate` overlay (`rel/overlays/bin/migrate`) that waits for the database host to resolve in DNS, then runs `agent_jido eval AgentJido.Release.migrate` inside a bounded retry budget (`MIGRATE_MAX_ATTEMPTS=12`, `MIGRATE_RETRY_SECONDS=5`).

This is **database-schema** migration at boot — distinct from *package* upgrade order. Which Hex versions to move between, and the dependency order to move them in, is a separate question answered on [Migrations and upgrade paths](/docs/reference/migrations-and-upgrade-paths). And the database itself is an application choice: Jido does not ship a database, so the store, its durability, and the migration mechanic stay application-owned.

## What the release builds

Both environments deploy the same Elixir release, produced by `Dockerfile`:

- **Build stage.** A `hexpm/elixir` image (Elixir 1.19.2, OTP 28.3.2, Debian Bookworm) installs deps, compiles assets (`mix assets.deploy`), compiles the app, then runs `mix release`. The release is named `agent_jido` (the `:app` in `mix.exs`), so its control script is `bin/agent_jido`.
- **Runner stage.** A minimal `debian:bookworm` image carrying only the compiled release, its runtime libraries, and `hivemind`. The git `COMMIT` is baked in as `APP_REVISION`, so a running image is traceable to a commit. The release ships `bin/server` (`PHX_SERVER=true exec ./agent_jido start`) and `bin/migrate` as overlays from `rel/overlays/bin/`.
- **Distributed Erlang.** `rel/env.sh.eex` configures the VM at boot — distributed Erlang over IPv6 (`-proto_dist inet6_tcp`), named distribution, and a node name built from `FLY_APP_NAME` and `FLY_PRIVATE_IP` — so machines on a private network can reach each other.

## What this repo owns, and what Jido does not

The release is a choice this repository made, not a property of Jido. Jido is deployment-agnostic: an `AgentServer` runs under OTP supervision in any BEAM release, on any host. This repo — not Jido — owns:

- the **release build** (`Dockerfile`, `mix release`) and the **boot sequence** (`entrypoint`, `Procfile`);
- the **configuration** (`config/config.exs`, `config/prod.exs`, `config/runtime.exs`) and the **secrets** injected through it;
- the **deploy probe** (`AgentJidoWeb.Plug.Heartbeat`, `/status`) and the **migration surface** (`AgentJido.Release`, `priv/repo/migrations/`);
- the **database and its durability** — Postgres or any external store. Jido does not ship a database.

If you run your own Jido system, you make every one of these choices yourself against your own target. This page is the worked example: how jido.run assembles and boots its release, today, against the files in this repository.

## Next steps

- [Fly.io deployment](/docs/operations/fly-io-deployment) — how this release ships to Fly.io: the staging and production workflows, the runtime config, and the post-deploy verification that waits on `/status`.
- [Health checks and readiness](/docs/operations/health-checks-and-readiness) — the three health axes (process, dependency, work) behind the `/status` probe every deploy waits on.
- [Migrations and upgrade paths](/docs/reference/migrations-and-upgrade-paths) — package *upgrade* order and version ranges; the companion to this page's database-schema migration boot order.
- [Production readiness checklist](/docs/operations/production-readiness-checklist) — the go-live gate; record the configured secrets, the probe, and the migration behavior there.
