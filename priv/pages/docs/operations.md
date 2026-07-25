%{
  description: "Production readiness, security, and incident response for Jido systems.",
  title: "Operations",
  category: :docs,
  legacy_paths: [],
  tags: [:docs, :operations],
  order: 50,
  draft: false
}
---

You're shipping to production or already running there. Operations is the part of the Jido story that turns "it works on my machine" into "it keeps running." The pages below cover what you need before go-live, how to secure and observe your system, and what to do when things go wrong.

## The long-running agent path

Operate a Jido agent system by working through this ordered path. Each step names the Jido control surface and the part your application owns. (This section is being filled in across the operations pages; see `specs/audits/control-inventory-2026-07-23.md` for the control-point map.)

1. **Define what recovery means.** OTP supervision can restart a crashed `AgentServer` and bound failure scope. Durable recovery also needs a state policy, idempotent Actions, and explicit retry rules.
2. **Keep state across restart.** Decide what survives a process restart (memory), an application restart (persisted state), and a deployment. Persistence is an application choice.
3. **Handle failure modes.** Separate tool errors, HTTP/model failures, and crashes; use bounded retries and defined fallbacks for provider failure.
4. **Schedule and observe.** Add scheduling or event input, then telemetry and traces. Telemetry is for system understanding — it is not an audit log.
5. **Check health and deploy.** Define process, dependency, and work health; verify after every deploy.

## Operations pages

- [Supervision and failure boundaries](/docs/operations/supervision-and-failure-boundaries) - supervision topology, restart strategy, and restart intensity for bounding agent failure
- [Process crash and restart](/docs/operations/process-crash-and-restart) - a worked example: an AgentServer process crashes, the supervisor restarts it, and the observed state result is explicit
- [Retries, timeouts, and provider failure](/docs/operations/retries-timeouts-and-provider-failure) - separate retry, timeout, and fallback decisions for tool, HTTP, and model failures
- [Tool error and retry decision](/docs/operations/tool-error-and-retry-decision) - a worked example: a retryable tool error is retried inside a bounded budget, a terminal tool error is not retried at all
- [Scheduling and event input](/docs/operations/scheduling-and-event-input) - how timed work and external events enter an agent, and what survives a restart
- [Telemetry and traces](/docs/operations/telemetry-and-traces) - the two observation layers: the `:telemetry` events `jido` core emits for free, and the separate, optional `jido_otel` exporter
- [Health checks and readiness](/docs/operations/health-checks-and-readiness) - the three independent health axes a long-running agent exposes: process, dependency, and work health, plus repeatable post-deploy verification
- [Production readiness checklist](/docs/operations/production-readiness-checklist) - pre-launch verification for supervision trees, config, telemetry, and resource limits
- [Security and governance](/docs/operations/security-and-governance) - secret management, API key rotation, access controls, and data boundaries
- [Incident playbooks](/docs/operations/incident-playbooks) - step-by-step response procedures for common failure modes

> Backup and disaster-recovery guidance is not yet published. It is tracked as a follow-up rather than linked from this page.

## Next steps

- [Reference](/docs/reference) - API details, configuration options, and module specs
- [Guides](/docs/guides) - hands-on walkthroughs for building with Jido
