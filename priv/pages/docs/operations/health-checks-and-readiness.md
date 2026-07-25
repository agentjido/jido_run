%{
  description: "The three independent health axes a long-running agent exposes — process health, dependency health, and work health — and the repeatable post-deploy verification that confirms each.",
  title: "Health Checks and Readiness",
  category: :docs,
  legacy_paths: [],
  tags: [:docs, :operations],
  order: 361,
  draft: false
}
---
# Health Checks and Readiness

Supervision recovers a process; retries recover a call; telemetry shows you what the agent is doing. None of them answers the question a load balancer, a deploy pipeline, and an on-call engineer all ask at once: **is this agent healthy, and did the last deploy actually take?** This page defines the three health checks that answer it — and why they are three checks, not one.

There are three health axes, and they fail independently:

- **Process health** asks whether the `AgentServer` process is alive and answering calls right now. It catches a crashed process or a crash loop.
- **Dependency health** asks whether the external services the agent needs — the LLM provider, the persistence store, any tool API — are reachable and answering. It catches a provider outage: the process is up but cannot do useful work.
- **Work health** asks whether the agent is actually making progress — draining its directive queue, running its strategy, not stuck waiting or erroring. It catches a live process with live dependencies that is nonetheless stalled or backlogged.

Confusing the three is the common operational mistake. A process-health check passes during a provider outage; a dependency-health check passes while the queue silently grows. The table separates them before the detail does.

| Axis | Question it answers | Failure it catches | Who owns the check |
|---|---|---|---|
| **Process health** | Is the `AgentServer` process up and responsive? | Crashed process, crash loop | Application, over Jido's supervision and registry |
| **Dependency health** | Are the LLM provider and stores reachable? | Provider or store outage | Application — Jido does not know your dependencies |
| **Work health** | Is the agent draining work and not stuck? | Stuck strategy, queue saturation, error storm | Application, over Jido's `Status` API and telemetry |

Contrast this with [Supervision and Failure Boundaries](/docs/operations/supervision-and-failure-boundaries) (process recovery), [Retries, Timeouts, and Provider Failure](/docs/operations/retries-timeouts-and-provider-failure) (call and provider recovery), and [Telemetry and Traces](/docs/operations/telemetry-and-traces) (observation).

## Process health

A process-health probe answers "is the agent process alive and answering calls right now?" — not "has it ever crashed." Resolve the registered name to a process and confirm it responds within a bounded timeout. `Jido.AgentServer.status/1` is a convenient combined probe: it returns `{:ok, status}` when the process is alive and responsive, and `{:error, :not_found}` when it is gone.

```elixir
# lib/my_app/health.ex
defmodule MyApp.Health do
  def process_health(name) do
    case Jido.AgentServer.status(name) do
      {:ok, _status} -> :ok
      {:error, :not_found} -> {:error, :process_down}
      {:error, :invalid_server} -> {:error, :invalid_server}
    end
  end
end
```

A process that answers `status/1` can still be in a restart loop — alive for milliseconds between restarts. Pair the liveness probe with the supervision restart-intensity budget: when a supervisor exceeds `max_restarts` in `max_seconds`, it escalates and the failure becomes visible instead of restarting silently. See [Supervision and Failure Boundaries](/docs/operations/supervision-and-failure-boundaries). Wire agent lifecycle `:telemetry` events to an alert so a restart storm trips the check before it steadies — see [Telemetry and Traces](/docs/operations/telemetry-and-traces).

What to decide, explicitly:

- **Liveness vs. responsiveness.** A `Process.alive?/1` check catches a dead process but not a wedged one. Probe responsiveness with a bounded call so a process that is alive but not answering also fails the check.
- **Timeout budget.** Health checks must answer fast. Cap the probe (for example, a `GenServer.call` with a short timeout) so a slow agent does not stall the checker.

## Dependency health

A dependency-health probe answers "can the agent reach the services it needs to do work?" — the LLM provider endpoint, the persistence store, any tool API. This is **not a Jido concept**: Jido does not know which provider or store your agent uses, so it cannot check them for you. Your application pings its own dependencies and reports their state.

```elixir
def dependency_health do
  with :ok <- ping_llm_provider(),
       :ok <- ping_persistence_store() do
    :ok
  end
end

defp ping_llm_provider do
  # A bounded call to the provider's status or auth endpoint (via Req).
  # Failure here means the agent is up but cannot reach the model.
end
```

Decoupling dependency health from process health is the point. A process-health check passes during a provider outage — the agent is alive, it just cannot do useful work. Retries and fallbacks (see [Retries, Timeouts, and Provider Failure](/docs/operations/retries-timeouts-and-provider-failure)) keep a single call resilient; dependency health tells the platform whether the whole dependency is degraded.

What to decide, explicitly:

- **Which dependencies, and how deep.** Listing the LLM provider is obvious; the persistence store, your tool APIs, and any cache are dependencies too. Decide whether each is pinged directly or inferred from recent error rates.
- **Readiness vs. liveness.** A failed dependency usually means "not ready" — stop sending new traffic — rather than "restart the process." Let the probe set readiness, not trigger a supervisor restart.

## Work health

A work-health probe answers "is the agent actually making progress?" — draining its directive queue, running its strategy, not stuck waiting or erroring. Jido exposes this through the `Jido.AgentServer.Status` API: `Jido.AgentServer.status/1` returns a `Status` struct whose `queue_length` is the directive backlog and whose `status` is the strategy state (`:running`, `:waiting`, `:idle`, `:success`, `:failure`).

```elixir
@queue_warn_threshold 1_000

def work_health(name) do
  case Jido.AgentServer.status(name) do
    {:ok, status} ->
      queue = Jido.AgentServer.Status.queue_length(status)

      cond do
        queue > @queue_warn_threshold -> {:error, :queue_backlog}
        Jido.AgentServer.Status.status(status) == :waiting -> {:warn, :waiting}
        true -> :ok
      end

    {:error, _} = error ->
      error
  end
end
```

The directive queue has a `max_queue_size` (default `10_000`); when work arrives faster than the agent drains it, the queue grows toward that ceiling and overflows with a `:queue_overflow` error. A growing queue paired with a `:waiting` strategy — often waiting on an LLM response that never comes — is a stuck agent that process and dependency checks miss: the process is alive and the provider answers a ping, but real work is not completing. Track Action and signal error rates through `:telemetry` (see [Telemetry and Traces](/docs/operations/telemetry-and-traces)) so an error storm trips work health even when the queue looks shallow.

What to decide, explicitly:

- **Backlog thresholds.** Decide a queue depth that means "backed up" for each agent class relative to `max_queue_size`, and a `:waiting` duration that means "stuck" rather than "thinking."
- **Progress signal.** Pair queue depth with a "last completed at" timestamp so a flat queue with no recent completion is caught as well as a growing one.

## Post-deploy verification

The second half of "check health and deploy" is proving the deploy itself took. After every release, run a repeatable verification that confirms the new code is serving — not the old — followed by the three health checks against the freshly deployed agents. Confirm the build first: expose a deploy stamp or build hash from the application and compare it against the artifact you shipped, so a rolled-back or stuck-on-old-code deploy fails the gate before traffic reaches it. (This site, for example, serves a `/status/<hash>` endpoint that the deploy pipeline checks against the build.)

What to decide, explicitly:

- **A version or hash probe.** Confirm the running build is the one you shipped, every time. A deploy that looks healthy but is serving yesterday's code is a silent failure this probe catches.
- **A scripted post-deploy run.** The health checks must run the same way every deploy — the same probes, the same thresholds — so a pass is comparable across releases. Record the observed result each time.

## Decide deliberately

For each agent class, write down the health contract:

- **Three checks, three alerts.** Process, dependency, and work health fail independently. Alert on each separately so a provider outage (dependency) is not misread as a crashed agent (process) and a stalled queue (work) is not misread as either.
- **What each check controls.** Decide which check gates routing (readiness), which pages an on-call engineer (work), and which implies a restart (process — driven by supervision, not by the health check itself).
- **Redaction.** Health output is logs and metrics. Redact secrets, prompts, and principal data by the same rules you apply to your telemetry — see [Security and Governance](/docs/operations/security-and-governance).

## What health checks do not do

Health checks tell the platform whether to send traffic and whether to investigate. They do not, by themselves:

- **Recover state.** A process-health failure that triggers a restart rebuilds a fresh process; whatever was in memory is gone. Persistence is an application choice — a restart is not state recovery. See [Production Readiness Checklist](/docs/operations/production-readiness-checklist).
- **Guarantee correctness.** A passing health check means the process answers and the queue is draining. It does not mean the agent's output is correct or that its authorization decisions are right.
- **Serve as an audit log.** Health output is an ephemeral operational signal, not a tamper-evident record. Audit and retention are application-owned duties — see [Security and Governance](/docs/operations/security-and-governance).
- **Know your dependencies.** Jido cannot report on your provider or store. Dependency health is an application responsibility.

## Next steps

- Pair process health with restart budgets in [Supervision and Failure Boundaries](/docs/operations/supervision-and-failure-boundaries).
- Track the queue depth and error rates that feed work health in [Telemetry and Traces](/docs/operations/telemetry-and-traces).
- Handle a failed dependency in [Retries, Timeouts, and Provider Failure](/docs/operations/retries-timeouts-and-provider-failure).
- Wire the three checks into the go-live gate in [Production Readiness Checklist](/docs/operations/production-readiness-checklist).
- Build the controls end to end from the [Operational controls](/docs/getting-started/operational-controls) onboarding lane.
