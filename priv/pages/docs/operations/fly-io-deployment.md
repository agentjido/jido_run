%{
  description: "How the jido.run workbench ships to Fly.io — the actual staging and production deploy workflows, release build, runtime config, and post-deploy verification, traced to the files in this repo.",
  title: "Fly.io deployment",
  category: :docs,
  legacy_paths: [],
  tags: [:docs, :operations],
  order: 369,
  control_types: [:observation],
  control_intent: :observe,
  draft: false
}
---
# Fly.io deployment

The live site at [jido.run](https://jido.run) runs on Fly.io. This page documents the *actual* staging and production deploy process for this repository — the two GitHub Actions workflows, the Fly app configurations, the release build, and the post-deploy verification — so an operator can trace every production-deploy claim to a real file in the repo. It is a reference for how this app ships, not a generic Fly.io tutorial; Jido itself is deployment-agnostic and runs in any BEAM release on any host.

The acceptance for this page is narrow and literal: **it matches this repo's staging and production process.** Every section below cites the file it describes, and nothing here is aspirational — if a workflow or value changes, this page changes with it.

## Two environments, one pipeline

Stage and prod share one codebase and one release image. They differ in *when* they deploy and *how* they roll out — staging is fast and disposable, production is gated and zero-downtime.

| | Staging | Production |
|---|---|---|
| Fly app | `agentjido-stage` | `agentjido-prod` |
| Host | `stage.jido.run` | `jido.run` |
| Region | `ord` | `ord` |
| Workflow | `.github/workflows/fly-stage.yml` | `.github/workflows/fly-prod.yml` |
| Trigger | automatic after CI on `main`, or manual | manual only |
| Rollout strategy | `immediate` | `bluegreen` |
| Running machines | 0–1 (autoscale to zero) | min 2, never auto-stop |

## The staging deploy

`.github/workflows/fly-stage.yml` deploys staging. It runs in two cases:

- **automatically**, when CI completes successfully on `main` — a `workflow_run` trigger that fires only when CI's conclusion is `success` on a `push` to `main`, and checks out the exact head SHA CI ran against; or
- **manually**, via `workflow_dispatch`.

A concurrency group (`deploy-fly-stage-<branch>`, `cancel-in-progress: true`) cancels any in-progress staging deploy for the same branch, so a fast-moving `main` never stacks half-finished deploys.

The deploy step is a single `flyctl` call:

```
flyctl deploy -c build/agentjido-stage.toml -a agentjido-stage --remote-only
```

`build/agentjido-stage.toml` sets the staging shape: a `shared-cpu-2x` VM in `ord`, a 60s `kill_timeout`, the `immediate` deploy strategy, and an HTTP service on internal port `8080` that can auto-stop to zero machines and auto-start on traffic, capped at one running machine (`max_machines_running = 1`, `min_machines_running = 0`). `PHX_HOST` and `CANONICAL_HOST` are `stage.jido.run`, and PostHog analytics is disabled.

## The production deploy

`.github/workflows/fly-prod.yml` deploys production. It has exactly one trigger — `workflow_dispatch` — and nothing else. Production never auto-deploys; a person runs it, deliberately.

```
flyctl deploy -c build/agentjido-prod.toml -a agentjido-prod --remote-only --strategy bluegreen
```

`build/agentjido-prod.toml` sets a deliberately more conservative shape than staging:

- **Blue-green rollout** (`--strategy bluegreen`): Fly starts new machines, waits for them to pass health checks, then shifts traffic and stops the old ones. Traffic never points at a machine that has not passed its check.
- **A two-machine floor** (`min_machines_running = 2`) with `auto_stop_machines = false`: production keeps two machines warm at all times, so a single machine restart or a blue-green cutover never takes the site down.
- **A 300s `kill_timeout`**: old machines get five minutes to drain after `SIGTERM` before Fly forces a kill — long enough for in-flight requests and long-running work to finish.
- A `shared-cpu-2x` VM with 512MB memory and 512MB swap in `ord`, `PHX_HOST`/`CANONICAL_HOST` = `jido.run`, and PostHog analytics enabled (browser, server, autocapture, and session replay sampled at 0.25).

The asymmetry is the point: staging absorbs every green build on `main` automatically so a broken deploy is caught there first; production is a manual, blue-green, always-warm promotion.

## What the deploy builds and runs

Both environments deploy the same Elixir release, built by `Dockerfile` and run on Fly's remote builders (`--remote-only` — no local Docker daemon is used; the build happens on Fly's infrastructure):

- **Build.** `Dockerfile` installs deps and assets, runs `mix assets.deploy`, compiles the release with `mix release`, and produces a minimal Debian runner image containing only the release plus its runtime libraries and `hivemind`. The git `COMMIT` is baked in as `APP_REVISION`, so a running image is traceable to a commit.
- **Boot.** The image entrypoint (`build/entrypoint.sh`, copied to `/app/bin/entrypoint`) runs `AgentJido.Release.migrate()` against the configured database, then hands control to `hivemind`, which reads `Procfile` — `web: /app/bin/server` — to start the Phoenix endpoint. Migrations run on every boot, ahead of the health check.
- **Clustering.** `rel/env.sh.eex` configures distributed Erlang over IPv6 (`-proto_dist inet6_tcp`) and builds the node name from `FLY_APP_NAME`, the image ref, and `FLY_PRIVATE_IP`, so machines on Fly's private network can reach each other by Fly-provided addresses.
- **Runtime config.** `config/runtime.exs` reads environment variables set in each `fly.toml` — `PHX_HOST`, `CANONICAL_HOST`, `DATABASE_URL`, `POOL_SIZE`, `PRIMARY_REGION` — so the same release code runs in both environments. Stage and prod differ in the `fly.toml` env and machine shape, not in the application code or the release.

## How a deploy is verified

Every deploy, stage and prod, is gated by the same health check: Fly polls `GET /status` every 30s, with a 180s grace period on a fresh machine and a 3s timeout. A machine that does not pass within grace never receives traffic. `/status` is served by the `AgentJidoWeb.Plug.Heartbeat` plug — a deployment-validation endpoint that returns `200 ok` (and, at `/status/<hash>`, checks the running build hash). That is the same surface, and the same three health axes, documented on [Health checks and readiness](/docs/operations/health-checks-and-readiness); a production blue-green rollout simply waits on it before cutting over.

What a deploy does to in-flight agent work is a separate question, answered on [Deployment restart](/docs/operations/deployment-restart): the whole supervised tree is replaced, and the workflow either safely restarts at its initial state or resumes — depending on whether the application wired persistence outside the BEAM. Fly's blue-green strategy changes *how* machines are swapped; it does not change *what* an agent does when its process is replaced.

## What this repo owns, and what Jido does not

Hosting on Fly.io is a choice this repository made, not a property of Jido. Jido is deployment-agnostic: an `AgentServer` runs under OTP supervision in any BEAM release, on any host. Concretely, this repo — not Jido — owns:

- the **Fly apps, regions, and machine shapes** in `build/agentjido-*.toml`;
- the **rollout strategy** (immediate vs blue-green) and the **machine floor** (autoscale-to-zero vs always-warm);
- the **release build** (`Dockerfile`), **migrations** (`AgentJido.Release`), and **runtime configuration** (`config/runtime.exs`);
- **secrets** — `FLY_API_TOKEN` lives in GitHub Actions secrets and drives both workflows; provider and database credentials live in Fly secrets, never in the repo;
- the **database and its durability** — Fly Postgres or any external store. Jido does not ship a database.

If you run your own Jido system, you make every one of these choices yourself against your own target. This page is the worked example: how jido.run does it, today, against the files in this repository.

## Run it yourself

The deploy is driven entirely from files already in the repo — there is no separate deploy script. To trace any claim above:

- staging and production workflows: `.github/workflows/fly-stage.yml`, `.github/workflows/fly-prod.yml`
- Fly app configuration: `build/agentjido-stage.toml`, `build/agentjido-prod.toml`
- release build and boot: `Dockerfile`, `build/entrypoint.sh`, `Procfile`, `rel/env.sh.eex`
- runtime configuration: `config/runtime.exs`

A manual production deploy (with `FLY_API_TOKEN` available and the `fly` CLI installed) is the same command the workflow runs:

```
flyctl deploy -c build/agentjido-prod.toml -a agentjido-prod --remote-only --strategy bluegreen
```

## Next steps

- [Deployment restart](/docs/operations/deployment-restart) — what happens to in-flight agent work when the whole supervised tree is replaced on a deploy.
- [Health checks and readiness](/docs/operations/health-checks-and-readiness) — the three health axes behind the `/status` check every deploy waits on.
- [Production readiness checklist](/docs/operations/production-readiness-checklist) — the go-live gate; record the observed deploy and restart behavior there.
- [Supervision and failure boundaries](/docs/operations/supervision-and-failure-boundaries) — the supervision topology a freshly booted machine starts.
