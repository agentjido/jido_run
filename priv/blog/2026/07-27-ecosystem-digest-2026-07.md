%{
  title: "Jido ecosystem digest — July 2026",
  author: "Mike Hostetler",
  tags: ~w(jido elixir ecosystem digest release jido_ai req_llm),
  description: "Issue 1 of the adopter-focused Jido ecosystem digest: what's stable now, examples you can run, how to upgrade inside the supported paths, and the issues we want you to know about before you adopt.",
  post_type: :announcement,
  audience: :general,
  journey_stage: :evaluation,
  content_intent: :reference,
  capability_theme: :community_adoption,
  evidence_surface: :package
}
---

This is **Issue 1** of the Jido ecosystem digest — a short, honest, recurring
round-up for adopters. Each issue covers the same four things: what is stable
now, examples you can run, how to upgrade, and the issues we want you to know
about before you commit. It is deliberately not a marketing round-up: it states
the version set, points at runnable code, names the upgrade contract, and
surfaces the limitations and open work. If a thing is not yet true — production
deployments, measured benchmarks, third-party case studies — this digest will say
so rather than imply it.

The headline for July: the core install stack is stable on the `2.x` / `1.x`
lines, the supported upgrade paths are published with their cross-package
constraints, several production-shaped examples have real deterministic code
behind them, and the first public fix note is out. What is still missing is real
production evidence — and that gap is named at the end, not papered over.

## Stable releases

The core install stack an adopter pins today, with the versions this project
itself runs (pinned in `mix.lock`):

| Package | Version | Line |
|---|---|---|
| `jido` | `2.3.2` | `~> 2.1` (`2.x`) |
| `jido_ai` | `2.2.0` | `~> 2.0` (`2.x`) |
| `req_llm` | `1.17.1` | `~> 1.7` (`1.x`) |
| `jido_action` | `2.3.1` | companion to `jido` `2.3.x` |
| `jido_signal` | `2.2.2` | companion to `jido` `2.3.x` |
| `llm_db` | `2026.7.2` | floor under `req_llm` `1.17.x` |

What "stable" means here, said plainly:

- **`jido`, `jido_ai`, `req_llm`, `jido_signal`, `jido_action`, `llm_db`** carry
  `maturity: :stable` in the ecosystem registry and are the packages the install
  guidance points at. `jido` is the runtime; `jido_ai` is the LLM layer; `req_llm`
  is the provider transport; `jido_action` / `jido_signal` are the action and
  signal contracts underneath; `llm_db` is the model registry floor.
- **Stable, not frozen.** `jido`'s own API-stability note is that `2.0` shipped
  but to expect continued API refinements across early `2.x`. "Stable" means the
  package is the one to build on and the `2.x` line is the supported path; it does
  not mean no breaking changes will ever land before `3.0`.
- **The wider stable surface** (packages like `jido_memory`, `jido_runic`,
  `jido_browser`, `jido_character`, `jido_behaviortree`, `jido_vfs`) is listed on
  the [ecosystem page](/ecosystem) with a maturity tag per package. Treat a `0.1`
  version that is tagged stable as "API intends to be stable, package is young" —
  read the per-package `limitations` before depending on it.

Every package above links to its Hex page and changelog from
[/ecosystem](/ecosystem); the table here is the pin set, the contract is on the
migrations page.

## Examples to try

A digest is only useful if it points at code you can actually run. The examples
below are the ones with **real deterministic implementations** (source under
`lib/agent_jido/demos/`), not simulated run-throughs — start here, and each links
to a full example page.

- **[Counter Agent](/examples/counter-agent)** and
  **[Demand Tracker Agent](/examples/demand-tracker-agent)** — the foundational
  pair. Counter shows the immutable-agent `cmd/2` contract with no side effects;
  Demand Tracker introduces Directives (state changes returned alongside effect
  instructions). Both run with no LLM and no external services.
- **[Data Pipeline Agent](/examples/data-pipeline-agent)** — a real ETL-shaped
  agent: collect from multiple sources, validate against schemas, transform the
  batch, load, summarize. No LLM required. Good shape to copy for a bounded
  production workflow.
- **[Operations Agent](/examples/operations-agent)** and
  **[Support Triage Agent](/examples/support-triage-agent)** — production-shaped
  agents (ops health roll-up; support ticket classification and routed reply)
  with real deterministic code behind them.
- **[Controlled Agent](/examples/controlled-agent)** and
  **[Failure Drill Agent](/examples/failure-drill-agent)** — the operational
  pair this site leans on for control evidence: where authorization is enforced,
  what supervision restarts (a fresh process) and what it does not (in-memory
  state), and how an operator reads the failure.

The thing to notice about this list: the strongest examples are the
**non-LLM, deterministic ones**. That is currently the most truthful surface to
evaluate Jido against, and it is where the example code is real end to end.

## Migrations

The supported upgrade paths are published in full on
[Migrations and upgrade paths](/docs/reference/migrations-and-upgrade-paths).
The short version an adopter needs:

- **`jido`**: `2.1.0` → `2.3.2`. Moving into `2.3.x` requires
  `jido_action ~> 2.3` and `jido_signal ~> 2.2`.
- **`jido_ai`**: `2.0.0` → `2.2.0`. This is the tightest coupling in the stack —
  moving into `2.2.x` requires `jido ~> 2.3` **and** `req_llm ~> 1.12`.
- **`req_llm`**: `1.7.0` → `1.17.1`. Moving past `1.12.0` requires
  `llm_db ~> 2026.7.0`. (The path past `1.2.0`, previously blocked by a
  `TypedStruct` conflict, is now open after the Zoi refactor.)

**Upgrade in dependency order, bottom-up:** `llm_db` then `req_llm`, then
`jido_action` and `jido_signal` then `jido`, then `jido_ai` last. Hex will refuse
an invalid set, but raising from the floor upward keeps each intermediate step
resolvable.

One honesty point the migrations page makes and this digest repeats: **Jido does
not own the deployment mechanics of an upgrade.** Hex resolves the version set;
your release process, database migrations, rollback plan, and any OTP hot-code
upgrade are application-owned. A Jido upgrade is a restart, not a hot-swap —
design for [state recovery across restart](/docs/operations/supervision-and-failure-boundaries).

## Known issues

This is the section a digest earns its keep on. Before you adopt, know these:

- **The first-LLM tutorial no longer fails on a provider mismatch.** An adopter
  hit a real first-run failure (OpenAI key paired with the `:fast` alias, which
  resolves to an Anthropic model). The cause, the correction (an explicit
  `openai:` model that matches the key), and the regression test that holds it
  are public: [Fix note: the first-LLM tutorial no longer fails on a provider
  mismatch](/blog/fix-first-llm-tutorial-provider-mismatch). The rule: the key
  provider and the model provider must match, and the model must be explicit on
  the first request.
- **Several `jido_ai` examples are still simulated, not deterministic.** The
  production-shaped examples above are real; a set of `jido_ai` / Runic examples
  (weather multi-turn, weather reasoning strategy suite, runic structured
  branching / adaptive researcher / delegating orchestrator, the operational
  agents pack) are still being replaced with real deterministic implementations
  (open Phase 2 work, tracked as issues #64–#68). Until that lands, evaluate
  against the deterministic examples first and read each `jido_ai` example page
  for whether it is a real run or a simulation.
- **Per-package limitations are real and named.** A few that affect adoption
  decisions: `jido` has no built-in persistence DB adapter (hibernate/thaw only)
  and distributed multi-node coordination requires manual setup; `jido_ai`'s
  Elixir floor is `~> 1.17`, which skews against `~> 1.18` runtime packages;
  `req_llm`'s provider coverage varies and its streaming depends on SSE, which
  may not work behind all proxies. Every package lists its own `limitations` on
  its ecosystem page — read the ones you depend on.

## What this digest does not claim

This is an adopter-focused digest, so it states the adoption evidence gap
directly: there are **no public production case studies and no measured
benchmarks for Jido yet**, because real production Jido deployments do not yet
exist in a form we can cite. That is the single biggest thing missing from the
ecosystem, and it is exactly what the [community failure-story
request](/community#community-failure-stories) and the case-study templates are
built to fill — so that when a real deployment exists, the evidence is bounded by
a template rather than asserted by a claim.

Until then: pin the versions above, run the deterministic examples, upgrade
inside the published paths, and tell us when something breaks. The next digest
will say what changed.

---

*The Jido ecosystem digest is a recurring, adopter-focused round-up. Issue 1 —
July 2026. [Suggest a topic or report a gap on GitHub](https://github.com/agentjido/agentjido_xyz/issues).*
