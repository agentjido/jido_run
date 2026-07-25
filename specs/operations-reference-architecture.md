# Long-Running Agent Reference Architecture

Status: Spec + reference application (`jido-e07`, E07-T29..T51). Last updated:
2026-07-25.

The reference **application** — a runnable, tested implementation of this
architecture — is built (`jido-e07-t29`). It lives in
`lib/agent_jido/demos/long_running_reference/` and is proven end to end by
`test/agent_jido/demos/long_running_reference_test.exs`. This document fixes
the architecture, control surfaces, failure drills, and threat model so the
build is unambiguous; the sections below map each concern to where the
reference app covers it.

## Goal

One minimal, deployable Jido application that proves the long-running claim:
an agent that runs under supervision, takes scheduled and request-driven work,
persists state, retries failure, emits telemetry, and recovers across process,
application, node, and deployment restarts — with explicit operational control.

## Components

| Component | Jido surface | Application duty |
|---|---|---|
| Ingress | incoming Signal | Validate and attach principal/tenant/request/causation context |
| Runtime | `AgentServer` under OTP supervision | Restart strategy, intensity |
| Agent logic | `Jido.Agent` + Actions | State schema, deterministic transitions |
| Tools | typed Actions (pure or effectful) | Tool implementations, schemas |
| Authorization | `prepare_signal/2`, `prepare_action/3` | Policy source, fail-closed decisions |
| AI controls | `jido_ai` tool/effect/prompt/quota policies | Allowlists, budgets |
| History | durable Signal Journal adapter | Adapter choice, retention, access |
| Observation | `Jido.Observe` telemetry + optional `jido_otel` | Capture, redaction, export |
| Persistence | persistence package | State store, recovery on restart |
| Scheduling | Schedule/Sensor input | Trigger source, idempotency |

## Linear path (what a builder follows)

Define the agent → start it under a named Jido instance → add a tool → add scheduling or event input → add persistence → add retry and failure policy → add telemetry → add a health check → deploy → stop, restart, and recover.

## Reference application (E07-T29)

The runnable application under `lib/agent_jido/demos/long_running_reference/`
covers every concern the linear path names, and `test/agent_jido/demos/long_running_reference_test.exs`
proves each one — plus a final test that runs the whole path end to end against
a single deployment.

| Concern | Where it is covered |
|---|---|
| Supervision | `Supervisor` boots the `AgentServer` `:permanent`; a killed process is restarted by the surviving supervisor |
| Scheduling | the agent declares a CRON schedule; `HandleCronTickAction` handles the `reference.cron` route |
| Persistence | `Persistence` wraps `Jido.Persist.hibernate/thaw` over an ETS store; checkpoint then thaw round-trips state |
| Retries | `StartRetryAction` / `HandleRetryAction` recover a transient failure through bounded schedule directives |
| Telemetry | `IngestWorkAction` wraps work in a `Jido.Observe.with_span/3` span with redactable metadata |
| Health | `Health` implements the process / dependency / work axes over `Jido.AgentServer.status/1` |
| Deployment | `Supervisor` *is* the deployment; the whole tree is replaced on a redeploy and resumes from a checkpoint |

Idempotency (duplicate `work_id` does not double-count) is folded into
`IngestWorkAction`, satisfying the duplicate-delivery failure drill. The
controlled-agent extension — the nine-element design (ingress, principal
context, policy, Actions, effects, Journal, telemetry, approval, recovery) — is
specified in [Controlled-agent extension](#controlled-agent-extension) below
(`jido-e07-t35`), layered onto this same agent rather than spawning a second
one.

## Recovery boundaries (process, app, node, deploy)

A long-running agent recovers across four distinct restart boundaries. They
differ by **what dies** and **what survives**, so each has its own automated
test in the reference app (`jido-e07-t33`: "Each recovery boundary has an
automated or repeatable test"):

| Boundary | What dies | What survives | Automated test |
|---|---|---|---|
| Process | the `AgentServer` process only | identity — a surviving parent supervisor restarts it; in-memory state is lost | `:supervision` |
| Application | the running agent; required state is replayed from a store on boot | checkpointed state (`hibernate`/`thaw` round-trip) | `:persistence` |
| Node | the entire BEAM, including the in-memory store's owning process | only durable (disk-backed) state; in-memory state is lost | `:node_restart` |
| Deployment | the whole deployment tree — no surviving parent | resumed state when a checkpoint is restored; otherwise a safe restart at the initial state | `:deployment` |

Process and deployment restarts share a supervisor but sit at different levels:
a process restart leaves the supervisor (and the in-memory store's owner in
`Jido.Supervisor`) alive, so the same in-memory checkpoint that **resumes**
across a deployment restart is **lost** across a node restart — node restart
kills the owner too. That is why the node boundary needs a durable (disk-backed)
store, and why the reference app exposes both media
(`Persistence.storage_config(:memory | :durable)`) plus
`Persistence.simulate_node_restart/1` to make the loss observable in one test
process.

## Failure drills (each must have an expected observation)

Each drill lists four expected observations — **Logs**, **State**,
**Telemetry**, and **Recovery** — so an operator can read the expected result
before running the drill. They are derived from the reference application
(where a concern is wired into the agent) and the focused demo each drill
points at; the same observations are reproduced in the reference app
[README](../lib/agent_jido/demos/long_running_reference/README.md) (`jido-e07-t32`).

1. **Tool error + retry decision:** retryable vs terminal errors take different paths.

   | Observation | Expected |
   |---|---|
   | Logs | An Action error is returned at the call boundary (`{:error, _}`), not logged as a crash — the `AgentServer` stays up. |
   | State | The retry lane advances `attempts` up to `max_attempts`; `status` ends `:recovered`, `last_event` `"retry.recovered"`. |
   | Telemetry | `Jido.Action.Error.retryable?/1` classifies the error (`true` timeout / `false` invalid input). |
   | Recovery | Retryable recovers inside the budget (3 attempts, `max_retries: 3`); terminal is not retried (1 attempt). |

2. **`AgentServer` crash:** supervisor restarts the process; observed state result is explicit.

   | Observation | Expected |
   |---|---|
   | Logs | The OTP supervisor restarts the `:permanent` child; the logger reports the restart. |
   | State | Post-restart state is the **initial** state (`processed` resets, e.g. `3 → 0`); in-memory state is lost. |
   | Telemetry | `status/1` returns the new pid and same `agent_id`; `Health.process_health/1` goes `:process_down` then `:ok`. |
   | Recovery | A fresh process reclaims the same logical id; identity carries, memory does not. |

3. **Application restart:** required state is restored from a real store.

   | Observation | Expected |
   |---|---|
   | Logs | `Persistence.checkpoint/2` writes via `hibernate`; `restore/2` reads via `thaw`. |
   | State | The restored agent keeps `processed` and `seen_work` from the checkpoint. |
   | Telemetry | `Health.dependency_health/2` returns `:ok` (store reachable, hit or miss). |
   | Recovery | `restore/2` returns `{:ok, agent}` on a hit, `{:error, :not_found}` on a miss. |

4. **Deployment restart:** the workflow resumes or safely restarts with stated semantics.

   | Observation | Expected |
   |---|---|
   | Logs | `Supervisor.stop/1` tears down supervisor and agent together (no surviving parent); a fresh tree boots. |
   | State | Without persistence → initial state; with persistence → resumed (`processed` and `seen_work` preserved). |
   | Telemetry | `whereis(agent_id)` resolves to the new pid; `status/1` reports the reclaimed identity. |
   | Recovery | The whole tree is replaced and either safely restarts or resumes — the two semantics are stated. |

5. **Duplicate Signal delivery:** the Action demonstrates idempotency.

   | Observation | Expected |
   |---|---|
   | Logs | `last_event` reads `"work.duplicate:<work_id>"` on the repeat. |
   | State | `processed` advances once; `seen_work` lists the `work_id` once. |
   | Telemetry | The `IngestWork` span still fires (start/stop carry the `work_id`). |
   | Recovery | No double-application — a duplicate delivery is a no-op. |

6. **Provider timeout + fallback:** bounded retries and an explicit fallback rule.

   | Observation | Expected |
   |---|---|
   | Logs | The wrapper runs a bounded retry loop; the fallback fires on budget exhaustion. |
   | State | The attempt counter recovers inside the budget; a persistent timeout exhausts at exactly `max_attempts`. |
   | Telemetry | Result tagged `source: :primary` (recovered) or `source: :fallback` with a `reason`. |
   | Recovery | Fallback rule fires on exhaustion/terminal error, or the Signal fails; never unbounded. |

7. **Poison work / dead-letter:** failed work is inspectable and replayable.

   | Observation | Expected |
   |---|---|
   | Logs | Poison work is moved to the `DeadLetterStore` after the budget is exhausted. |
   | State | The entry carries `id`, original `work`, `reason`, `attempts` (== `max_attempts`), `replay_attempts`. |
   | Telemetry | `DeadLetterStore.entries/1` lists every item — inspectable, not dropped. |
   | Recovery | `replay/3` after a fix succeeds and removes the entry; a failed replay updates the same entry, not a duplicate. |

Run them in one command with the failure-drill script (`jido-e07-t31`):

    scripts/failure_drill.sh

The script runs every documented failure against its focused test and then
runs the reference application end to end, so each drill has an observable
result.

## Controlled-agent extension

The long-running reference app extends to a controlled-agent architecture. The
design fixes **nine** control elements, each mapped to the Jido surface it rides
on, the application duty that stays outside Jido, and where it is proven — in
the integrated `controlled_agent` demo, in the focused demo that isolates it, or
in the sibling task that builds it out. This section is the design the backlog
row `jido-e07-t35` pins down: *Complete when the design includes ingress,
principal context, policy, Actions, effects, Journal, telemetry, approval, and
recovery.*

| # | Element | Jido surface | Application duty | Where it is proven |
|---|---|---|---|---|
| 1 | **Ingress** | the incoming `Signal` (+ `prepare_signal/2`) | validate and attach principal/tenant/request/causation context at the boundary **in front of** Jido | `ControlledAgent` routes `work.approve`; `jido-e07-t37` carries the full context, `jido-e07-t38` enriches it |
| 2 | **Principal context** | `Signal.source` (and carried metadata) | issue a verified principal at the auth/IAM boundary; Jido carries it, never authenticates it | `controlled_agent_test.exs` — every Signal carries a `source`; `jido-e07-t37` |
| 3 | **Policy** | `prepare_signal/2`, `prepare_action/3` | the allow/deny decision is the application's; **fail-closed** | `AuthorizationPlugin` (`prepare_action/3`); `controlled_agent_test.exs` |
| 4 | **Actions** | `Jido.Action` | state schema and deterministic transitions | `ApproveAction` |
| 5 | **Effects** | typed Actions (pure or effectful) + AI tool/effect/quota policies | tool/effect implementations, allowlists, cost budgets | focused demos `AiToolAllowlist`, `QuotaControlAgent`; `jido-e07-t36`, `jido-e07-t38` |
| 6 | **Journal** | durable Signal Journal adapter | adapter choice, retention, access, deletion | focused demo `DurableSignalJournal`; `jido-e07-t45` |
| 7 | **Telemetry** | `Jido.Observe` (+ optional `jido_otel`) | capture, **redaction**, correlated-span export | focused demos `CorrelatedTelemetry`, `RedactedAction`; `jido-e07-t47`, `jido-e07-t48` |
| 8 | **Approval** | an Action that gates one high-impact effect | the human-approval boundary (who approves, how long it holds) | focused demo `ApprovalBoundaryAgent`; sibling task |
| 9 | **Recovery** | `AgentServer` under OTP supervision + persistence | restart strategy/intensity; state store; idempotency | `ControlledAgent.Supervisor` + `controlled_agent_persistence_test.exs`; the four recovery boundaries above |

The integrated `controlled_agent` demo implements elements 1–4 and 9 today
(authenticated ingress via `Signal.source`, the fail-closed policy hook, the
protected Action, and supervised + persisted recovery). Elements 5–8 are
isolated in their focused demos and built out under the sibling tasks named in
the last column; the design layers each onto this same agent instead of
spawning a second one.

### Controlled-agent linear path

A builder extends the long-running agent into a controlled agent in this order:

carry principal context on the incoming Signal → verify/enrich it in
`prepare_signal/2` → make `prepare_action/3` fail-closed against a policy →
garden the Actions and effects behind allowlists and quotas → keep causal
history in a durable Journal → join correlated, redacted telemetry → gate the
one high-impact effect behind human approval → recover supervised state across a
restart, with Journal history and telemetry surviving alongside it.

### What stays outside Jido

Authentication, identity, audit, durable retention, and compliance are
application or platform duties in front of and around Jido — Jido carries and
honors a principal but never verifies one. See the explicit non-goals below and
`/docs/operations/security-and-governance`.

## Threat and control model (E07-T50)

| Asset | Threat | Control |
|---|---|---|
| Tools/effects | Unauthorized or runaway work | `prepare_action/3` allowlist + quotas |
| Cost | Runaway tokens/requests | Token/request/tool quotas |
| Provider keys | Leakage | Runtime config + redaction |
| State | Loss on restart | Persistence + idempotency |
| Causal history | Loss/gap | Durable Journal + retention |
| Visibility | Hidden failure | Telemetry + health checks + incident playbooks |

## Explicit non-goals (E07-T51)

The reference path does **not** claim: complete IAM, complete audit, compliance
certification, tamper-evident history, or no downtime. Authentication, durable
retention, and compliance stay outside Jido (see
`/docs/operations/security-and-governance`).
