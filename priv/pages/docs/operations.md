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

Running the tested package set matters in production. The [stack compatibility matrix](/ecosystem#stack-compatibility) lists the explicit supported range for every package in each stack — the same ranges the onboarding dependency blocks install — so you can confirm your versions before go-live instead of inferring compatibility.

## The long-running agent path

Operate a Jido agent system by working through this ordered path. Each step names the Jido control surface and the part your application owns. (This section is being filled in across the operations pages; see `specs/audits/control-inventory-2026-07-23.md` for the control-point map.)

1. **Define what recovery means.** OTP supervision can restart a crashed `AgentServer` and bound failure scope. Durable recovery also needs a state policy, idempotent Actions, and explicit retry rules.
2. **Keep state across restart.** Decide what survives a process restart (memory), an application restart (persisted state), and a deployment. Persistence is an application choice.
3. **Handle failure modes.** Separate tool errors, HTTP/model failures, and crashes; use bounded retries and defined fallbacks for provider failure.
4. **Schedule and observe.** Add scheduling or event input, then telemetry and traces. Telemetry is for system understanding — it is not an audit log.
5. **Check health and deploy.** Define process, dependency, and work health; verify after every deploy.

Each operational-control claim on this path resolves to one place: run the [Controlled Agent](/examples/controlled-agent) example to watch one supervised agent prove the complete control path in a single run — who initiated work, what was allowed, what happened, and how failure was handled. The pages below then open one surface of that path at a time.

## Operations pages

- [Supervision and failure boundaries](/docs/operations/supervision-and-failure-boundaries) - supervision topology, restart strategy, and restart intensity for bounding agent failure
- [Process crash and restart](/docs/operations/process-crash-and-restart) - a worked example: an AgentServer process crashes, the supervisor restarts it, and the observed state result is explicit
- [Deployment restart](/docs/operations/deployment-restart) - a worked example: the whole supervised tree is torn down and rebuilt, and the workflow safely restarts at a stated state — or resumes, when the application owns persistence
- [Fly.io deployment](/docs/operations/fly-io-deployment) - how jido.run ships to Fly.io: the actual staging and production deploy workflows, release build, runtime config, and post-deploy verification, traced to the files in this repo
- [OTP release guidance](/docs/operations/otp-release) - how a Jido system is assembled into an OTP release: the build, runtime configuration, secrets, the `/status` deploy probe, and the migration boot order, traced to the release files in this repo
- [Cluster node loss](/docs/operations/cluster-node-loss) - a worked example: a node that owns keyed agent instances leaves a connected cluster, its work is orphaned, routing fails with a defined result, and a conservative rebalance re-homes only the lost node's keys onto the survivors
- [Retries, timeouts, and provider failure](/docs/operations/retries-timeouts-and-provider-failure) - separate retry, timeout, and fallback decisions for tool, HTTP, and model failures
- [Tool error and retry decision](/docs/operations/tool-error-and-retry-decision) - a worked example: a retryable tool error is retried inside a bounded budget, a terminal tool error is not retried at all
- [Provider timeout and fallback](/docs/operations/provider-timeout-and-fallback) - a worked example: a transient provider timeout is retried inside a bounded budget, and an explicit fallback rule fires when the budget is exhausted or a terminal error occurs
- [Poison work and dead-letter handling](/docs/operations/poison-work-and-dead-letter) - a worked example: a persistently failing item exhausts a bounded retry budget, is moved to a dead-letter store where it can be inspected, and is replayed once the underlying cause is fixed
- [Scheduling and event input](/docs/operations/scheduling-and-event-input) - how timed work and external events enter an agent, and what survives a restart
- [Telemetry and traces](/docs/operations/telemetry-and-traces) - the two observation layers: the `:telemetry` events `jido` core emits for free, and the separate, optional `jido_otel` exporter
- [Health checks and readiness](/docs/operations/health-checks-and-readiness) - the three independent health axes a long-running agent exposes: process, dependency, and work health, plus repeatable post-deploy verification
- [Backpressure and queue limits](/docs/operations/backpressure-and-queue-limits) - the four limit surfaces a long-running system exposes — mailbox, bus, task, and provider — and, for each, where the bound lives and what happens when it is exceeded
- [Rate limits and cost budgets](/docs/operations/rate-limits-and-cost-budgets) - the three budgets an AI workload must set deliberately — token, request, and tool — and, for each, where the bound lives and what happens when it is exceeded
- [Production readiness checklist](/docs/operations/production-readiness-checklist) - pre-launch verification for supervision trees, config, telemetry, and resource limits
- [Security and governance](/docs/operations/security-and-governance) - secret management, API key rotation, access controls, and data boundaries
- [Journal retention, access, and deletion](/docs/operations/journal-retention-access-and-deletion) - who owns the durable Signal Journal's retention duration, access, sensitive fields, and deletion process — and that Jido ships none of those rules
- [Incident playbooks](/docs/operations/incident-playbooks) - step-by-step response procedures for common failure modes
- [Operator investigation runbook](/docs/operations/operator-investigation-runbook) - follow one unit of work from a principal, request, trace, or Signal ID to the decisions and effects behind it

> Backup and disaster-recovery guidance is not yet published. It is tracked as a follow-up rather than linked from this page.

> Kubernetes deployment guidance is not yet published. This repository ships to Fly.io — [Fly.io deployment](/docs/operations/fly-io-deployment) and [OTP release guidance](/docs/operations/otp-release) are the tested reference for how jido.run is deployed today — and a Kubernetes page will be added only when a tested reference exists, tracked against the end-to-end reference application (jido-e07-t29). It is held here on purpose rather than published as a generic, untested deployment recipe.

## Next steps

- [Reference](/docs/reference) - API details, configuration options, and module specs
- [Guides](/docs/guides) - hands-on walkthroughs for building with Jido
