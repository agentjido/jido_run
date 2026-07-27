%{
  description: "Supported upgrade paths and version ranges for jido, jido_ai, and req_llm — what each major line covers, which cross-package constraint you must satisfy, and the order to upgrade in.",
  title: "Migrations and upgrade paths",
  category: :docs,
  legacy_paths: ["/docs/migrations-and-upgrade-paths"],
  tags: [:docs, :reference],
  order: 310,
  draft: false
}
---
# Migrations and Upgrade Paths

Jido ships as a small stack of independently versioned packages — `jido`, `jido_ai`, and `req_llm` at the core, with `jido_action`, `jido_signal`, and `llm_db` underneath them. Each major line moves on its own schedule, and the packages constrain one another through Hex version requirements. Upgrading is therefore not "bump every line at once" — it is "move each supported path inside its version range, in dependency order, satisfying the floor the package above it demands." This page names each supported upgrade path, gives its version range, states the cross-package constraint that gates the move, and fixes the order.

The central honesty point: **Jido does not own the deployment mechanics of an upgrade.** Hex resolves the version set; your release process, your database migrations, your rollback plan, and any OTP hot-code upgrade are application-owned. Jido owns which version combinations are valid; you own how a running system moves between them. Treat the ranges below as the contract — the thing your `mix.exs` must satisfy — and the coordination section as the sequence.

| Package | Supported upgrade range | Floor for the current band | Cross-package constraint you must satisfy |
|---|---|---|---|
| **jido** | `2.1.0` → `2.3.2` | `~> 2.1` (`2.1.0` – `< 3.0.0`) | moving into `2.3.x` requires `jido_action ~> 2.3` and `jido_signal ~> 2.2` |
| **jido_ai** | `2.0.0` → `2.2.0` | `~> 2.0` (`2.0.0` – `< 3.0.0`) | moving into `2.2.x` requires `jido ~> 2.3` and `req_llm ~> 1.12` |
| **req_llm** | `1.7.0` → `1.17.1` | `~> 1.7` (`1.7.0` – `< 2.0.0`) | moving past `1.12.0` requires `llm_db ~> 2026.7.0`; the path past `1.2.0` was previously blocked and is now open |

Each row is one supported upgrade path, and each carries a version range. The ranges are the floor declared in this project's `mix.exs` up to the version currently pinned in `mix.lock` (`jido` `2.3.2`, `jido_ai` `2.2.0`, `req_llm` `1.17.1`). They are the set of moves Hex will accept on the `2.x` / `1.x` lines today; a jump to a future `3.0` is a separate, not-yet-supported migration and will get its own page when it exists.

## jido: 2.1.0 → 2.3.2

`jido` is the core agent framework — agents, actions, signals, directives, and the runtime. Its supported upgrade path is the `2.x` line, range `2.1.0` → `2.3.2` (this project declares `~> 2.1`, which means `>= 2.1.0 and < 3.0.0`).

**The constraint that gates the move into `2.3.x`.** `jido` `2.3.x` depends on `jido_action ~> 2.3` (so `jido_action >= 2.3.0`) and `jido_signal ~> 2.2` (so `jido_signal >= 2.2.0`). The current pin set is `jido` `2.3.2`, `jido_action` `2.3.1`, `jido_signal` `2.2.2`. If you are below `jido_action` `2.3.0` or `jido_signal` `2.2.0`, Hex refuses to resolve `jido` `2.3.x` — raise those two first, then move `jido`.

`jido` `2.3.x` is a minor release line. Within the `~> 2.1` range, point releases are backward-compatible; review the [`jido` changelog](https://hexdocs.pm/jido/changelog.html) for the behavioral notes on each minor before you cross a minor boundary (for example, `2.1` → `2.2` → `2.3`).

## jido_ai: 2.0.0 → 2.2.0

`jido_ai` is the LLM integration layer — model aliases, reasoning strategies, tools, and the `Quota` plugin. Its supported upgrade path is the `2.x` line, range `2.0.0` → `2.2.0` (this project declares `~> 2.0`).

**The constraint that gates the move into `2.2.x`.** `jido_ai` `2.2.x` depends on `jido ~> 2.3` (so `jido >= 2.3.0`) **and** `req_llm ~> 1.12` (so `req_llm >= 1.12.0`). This is the tightest coupling in the stack: you cannot land `jido_ai` `2.2.0` without first landing `jido` `2.3.x` and `req_llm` `1.12.x` or later. If your `jido` is pinned below `2.3.0`, or your `req_llm` below `1.12.0`, Hex will reject `jido_ai` `2.2.0` — upgrade `jido` and `req_llm` first.

`jido_ai` `2.2.x` is the line that introduced the opt-in cost and call budgets (the `Jido.AI.Plugins.Quota` plugin's `max_total_tokens` and `max_requests` windows). If you are moving up from `2.0.x` or `2.1.x`, the agent defaults did not change, but the budget surface is new — see [Rate Limits and Cost Budgets](/docs/operations/rate-limits-and-cost-budgets) for the control behavior that arrives with this band, and review the [`jido_ai` changelog](https://hexdocs.pm/jido_ai/changelog.html) for strategy-level changes.

## req_llm: 1.7.0 → 1.17.1

`req_llm` is the provider-agnostic LLM HTTP client that `jido_ai` builds on — retries, rate-limit handling, streaming, and request/response normalization. Its supported upgrade path is the `1.x` line, range `1.7.0` → `1.17.1` (this project declares `~> 1.7`, which means `>= 1.7.0 and < 2.0.0`).

**The constraint that gates the move past `1.12.0`.** `req_llm` `1.17.x` depends on `llm_db ~> 2026.7.0` (so `llm_db >= 2026.7.0`). The current pin is `llm_db` `2026.7.2`. Because `jido_ai` `2.2.x` itself requires `req_llm ~> 1.12`, the practical floor for a stack that runs `jido_ai` `2.2.x` is `req_llm` `1.12.0`; raise `llm_db` alongside it.

`req_llm` carries the most concrete upgrade history in this stack, and two of its paths are worth knowing before you cross them:

- **The path past `1.2.0` is now open.** Earlier in the `1.x` line, upgrading past `1.2.0` was blocked by a `TypedStruct` dependency conflict (req_llm#356). That conflict was resolved by replacing `TypedStruct` with Zoi schemas (req_llm#376). If you are still below `1.2.0`, the path forward is unblocked — the Zoi refactor is what made the `1.2.0` → `1.17.1` range reachable.
- **The `1.x` line has carried real provider-endpoint and transitive-dependency upgrades.** The xAI `/v1/messages` endpoint was deprecated and req_llm migrated off it (req_llm#351), and the Server-Sent-Events dependency was upgraded to `1.0.0` (req_llm#648). These are behavioral changes inside the `1.7.0` → `1.17.1` range, not version jumps — review the [`req_llm` changelog](https://hexdocs.pm/req_llm/changelog.html) and your provider usage before crossing them.

See [ReqLLM and LLMDB](/docs/reference/req-llm-and-llmdb) for the package's role and basic usage.

## Upgrade in dependency order

Hex will refuse an invalid set, but to move deliberately — and to keep each intermediate step resolvable — upgrade from the bottom of the dependency stack upward:

1. **`llm_db` and `req_llm` first.** Raise `llm_db` to `>= 2026.7.0`, then `req_llm` to your target inside `1.7.0` → `1.17.1`. This satisfies the floor `jido_ai` `2.2.x` will demand.
2. **`jido_action` and `jido_signal`, then `jido`.** Raise `jido_action` to `>= 2.3.0` and `jido_signal` to `>= 2.2.0`, then `jido` to your target inside `2.1.0` → `2.3.2`.
3. **`jido_ai` last.** With `jido >= 2.3.0` and `req_llm >= 1.12.0` already landed, move `jido_ai` to your target inside `2.0.0` → `2.2.0`.

`mix deps.update jido jido_ai req_llm jido_action jido_signal llm_db` will move every pin inside its declared `~>` band; `mix deps.update --all` does the same across the whole tree. Pin a lower bound deliberately in `mix.exs` rather than relying on the resolver's choice, so the supported range is the one you intended.

## What this page does not cover

These packages bound one another through Hex; they do not, by themselves:

- **Own your deployment mechanics.** How a running system swaps to the new code — a rolling restart, a blue/green cutover, a release upgrade — is application-owned. [Deployment Restart](/docs/operations/deployment-restart) describes what a deploy looks like; it is your release tooling that performs it.
- **Provide a data migration path.** Jido's core stores no business data; any storage your application owns (databases, journals, queues) needs its own migration and rollback plan. State recovery is covered separately from version upgrades.
- **Guarantee hot-code upgrades.** OTP supports hot code upgrades for long-lived processes, but Jido does not ship appups/relups. Treat an upgrade as a restart, and design for [state recovery across restart](/docs/operations/supervision-and-failure-boundaries).
- **Replace your verification step.** After the version set resolves, verify the running system against the new combination — the [Production Readiness Checklist](/docs/operations/production-readiness-checklist) is the gate, and [Configuration](/docs/reference/configuration) lists the config keys whose defaults may have shifted.

## Next steps

- Confirm the LLM control surface underneath these versions in [ReqLLM and LLMDB](/docs/reference/req-llm-and-llmdb).
- Check the config keys a new band may have changed in [Configuration](/docs/reference/configuration).
- Gate the upgraded combination before go-live with the [Production Readiness Checklist](/docs/operations/production-readiness-checklist).
- See how a deploy restart (the mechanical side of an upgrade) behaves in [Deployment Restart](/docs/operations/deployment-restart).
