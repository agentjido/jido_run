# Recommended Package Stacks

Status: Spec (`jido-e09`, E09-T01..T11). Last updated: 2026-07-23.

Help a builder choose a small, correct package set before showing the full
catalog. Each stack lists what it is, a copyable dependency block, when to use
it, when not to, and the production next step. The ecosystem hub should surface
these stacks before the full 47-package catalog (E09-T38).

Support levels follow `priv/ecosystem/*.md` and `lib/agent_jido/ecosystem/layering.ex`.
Do not present Experimental packages as production-ready.

## Core Agent stack (E09-T01)

The deterministic foundation. No AI required.

- **Packages:** `jido`, `jido_action`, `jido_signal`
- **Use when:** you need supervised, typed, testable agents without an LLM.
- **Do not start here when:** you only want a thin LLM call wrapper.
- **Production next:** [Operations](/docs/operations) — supervision, persistence, telemetry.

## AI Agent stack (E09-T02)

Adds model access on top of the core.

- **Packages:** Core stack + `jido_ai`, `req_llm`, `llm_db`
- **Roles:** `jido_ai` is the optional AI layer (core Jido needs no LLM);
  `req_llm` performs provider requests; `llm_db` resolves model metadata and
  capabilities.
- **Use when:** the agent should reason or call a model.
- **Do not start here when:** you have not yet run a deterministic agent.
- **Production next:** AI tool/effect policies, quotas, and provider fallback.

## Durable long-running stack (E09-T03)

For work that must survive restart.

- **Packages:** AI or Core stack + a persistence package + an observability choice.
- **Use when:** agent state or causal history must survive process/app/deploy restart.
- **Do not start here when:** ephemeral agents are enough.
- **Production next:** [Production readiness checklist](/docs/operations/production-readiness-checklist).

## Browser Agent stack (E09-T04)

- **Packages:** AI stack + `jido_browser`
- **Roles:** stateless fetch, rich fetch, and browser-session workflows (three
  distinct lanes — do not mix them).
- **Use when:** the agent must retrieve or interact with web content.
- **Production next:** rate limits and retrieval-effect policy.

## Ash application stack (E09-T05)

- **Packages:** Core stack + `ash_jido`
- **Roles:** generate Jido Actions from Ash actions while preserving Ash
  authorization. The host Ash application still enforces authorization.
- **Use when:** your domain already lives in Ash.
- **Production next:** confirm actor/tenant context propagates into Actions.

## Messaging Agent stack (E09-T06)

- **Packages:** Core or AI stack + `jido_messaging` / `jido_chat` adapters.
- **Note:** some adapters are Experimental; label maturity at the point of choice.
- **Use when:** agents drive or consume chat/messaging channels.
- **Production next:** backpressure and queue limits.

## Workflow stack (E09-T07)

- **Packages:** Core Strategies, behavior trees, or `jido_runic` DAG workflows.
- **Roles:** distinguish core Strategies from Runic DAG workflows; Runic is not
  the default Jido orchestrator.
- **Use when:** multi-step coordination needs an explicit workflow definition.
- **Production next:** idempotency and durable Signal Journal for replay.

## Controlled-Agent stack (E09-T39/T40)

For governed, inspectable agent work.

- **Packages:** Core + AI + Signal Journal + observation (+ optional `jido_otel`
  export) + (`ash_jido` where Ash context applies).
- **Roles:** core lifecycle and plugin hooks for authorization; AI policy/quota
  controls; durable causal history; correlated telemetry with redaction.
- **Use when:** a platform, SRE, or security evaluator needs explicit control points.
- **Do not assume:** built-in IAM, automatic tamper-evident audit, or compliance
  (see `/docs/operations/security-and-governance`).

## Stack requirements (E09-T08..T11)

Every stack above needs, when rendered on the hub:

- a copyable dependency block that installs successfully;
- a tested minimal example with the stated versions;
- a "do not use this when" note;
- a production-next-step link.
