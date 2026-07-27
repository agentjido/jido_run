%{
  description: "Go-live gate for reliability, observability, and recovery readiness.",
  title: "Production readiness checklist",
  category: :docs,
  legacy_paths: ["/docs/production-readiness-checklist", "/docs/reference/production-readiness-checklist"],
  tags: [:docs, :operations],
  order: 360,
  control_types: [:authorization, :policy, :observation],
  control_intent: :evaluate,
  draft: false
}
---
# Production Readiness Checklist

A go-live gate for running Jido agents in production. Each item names the Jido control surface and the part your application owns. Treat "production" as a set of explicit mechanisms with tested examples, not a guarantee of uptime or safety.

## Lifecycle and supervision

- [ ] Each long-running `AgentServer` runs under an explicit supervisor with a chosen restart strategy (`:one_for_one`, `:rest_for_one`, etc.).
- [ ] Restart intensity and period are set deliberately, not left at defaults, for your workload.
- [ ] You have decided what process restart means for your agent: which in-memory state is lost and how it is reconstructed.
- [ ] Agents that must survive a process or node restart restore state from a real store (persistence is an application choice; a restart is not state recovery).

## Capabilities and authorization

- [ ] Tool Actions are validated with compile-time schemas; effectful Actions are identified as such.
- [ ] A `prepare_action/3` plugin enforces fail-closed authorization for any protected capability (missing or denied context never runs the effect).
- [ ] AI tool and effect allowlists are configured where the agent can call external tools.
- [ ] Request, token, and tool quotas are set for AI-backed work — see [Rate limits and cost budgets](/docs/operations/rate-limits-and-cost-budgets) for where each bound lives.

## Failure and recovery

- [ ] Tool errors, HTTP/model failures, and crashes are handled by separate code paths with bounded retries.
- [ ] Provider failure has a defined fallback or circuit-breaker rule, not unbounded retry.
- [ ] Idempotent Actions or Signal IDs protect against duplicate delivery.
- [ ] You have run a failure drill: crash an `AgentServer`, an application restart, and a deploy, and recorded the observed recovery behavior.

## Observability

- [ ] Jido telemetry events are captured for lifecycle and Action execution.
- [ ] Correlation IDs (request, run, Signal, tool-call) propagate from ingress to effect so an operator can follow one unit of work.
- [ ] Optional OpenTelemetry export via `jido_otel` is evaluated against its current maturity (Experimental).
- [ ] Telemetry is treated as system understanding, **not** an audit log.

## Secrets, health, and deploy

- [ ] Provider keys and credentials come from runtime config (`config/runtime.exs`) or a secret manager — never committed source.
- [ ] Logs, telemetry, and error output redact secrets, prompts, tool arguments, and principal data per your configured rules.
- [ ] A health check distinguishes process health, dependency health, and work health.
- [ ] A repeatable post-deploy verification runs after every release.

## What this checklist is not

This checklist helps you operate Jido agents deliberately. It is not a compliance certification, a tamper-evident audit, or a guarantee of no downtime. Authentication, durable retention, and compliance remain application and platform responsibilities — see [Security and governance](/docs/operations/security-and-governance).

## Next steps

- Map each control point above to your application's duties in [Security and governance](/docs/operations/security-and-governance).
- Prepare for the failures you cannot prevent with the [Incident playbooks](/docs/operations/incident-playbooks).
- Build the controls end to end from the [Operational controls](/docs/getting-started/operational-controls) onboarding lane.
