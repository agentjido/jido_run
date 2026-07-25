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
application, and deployment restarts — with explicit operational control.

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
controlled-agent extension (authenticated ingress, `prepare_signal/2`,
fail-closed `prepare_action/3`, durable Journal, approval) is the tracked
follow-up `jido-e07-t35`, layered onto this same agent.

## Failure drills (each must have an expected observation)

1. **Tool error + retry decision:** retryable vs terminal errors take different paths.
2. **`AgentServer` crash:** supervisor restarts the process; observed state result is explicit.
3. **Application restart:** required state is restored from a real store.
4. **Deployment restart:** the workflow resumes or safely restarts with stated semantics.
5. **Duplicate Signal delivery:** the Action demonstrates idempotency.
6. **Provider timeout + fallback:** bounded retries and an explicit fallback rule.
7. **Poison work / dead-letter:** failed work is inspectable and replayable.

## Controlled-agent extension

The reference app extends to a controlled-agent architecture: ingress carries
authenticated application context; `prepare_signal/2` verifies/enriches it;
`prepare_action/3` is fail-closed; AI tools/effects/quotas are configured; a
durable Journal keeps causal history; correlated telemetry (with redaction)
joins the trace; one high-impact effect requires human approval.

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
