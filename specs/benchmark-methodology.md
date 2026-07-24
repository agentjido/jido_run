# Benchmark and Timing Claim Methodology

Status: Spec (`jido-e11`, E11-T17/T18/T19). Last updated: 2026-07-23.

The site must not publish scale or timing claims ("10,000+ supervised agents",
"restart in milliseconds", "first agent under ten minutes") without method.
This document defines the minimum a claim must state, or the claim is removed.

## Rule

A public scale, timing, or reliability claim is allowed only when it links to a
benchmark that states all of: workload, machine, code, limits, and measured
results. Otherwise the claim is rewritten to a tested behavior statement with no
number.

## Restart-time claims (E11-T18)

To claim a restart time, publish:

- **Topology:** supervision shape, number of agents, child layout.
- **Workload:** what the agent was doing when killed.
- **Measurement:** how restart time was measured (e.g., time from process exit
  to `AgentServer` ready), the distribution (min/median/p99), and sample size.
- **Machine:** CPU, memory, BEAM/OTP and Elixir versions.

Until these exist, do not state a restart duration. Say "supervision restarts
the process by your restart strategy" instead.

## Scale claims (E11-T17)

To claim a concurrent-agent count, publish:

- **Workload per agent:** idle vs active; message rate.
- **Machine:** cores, memory, and any scheduler/limit configuration.
- **Measurement:** how the count was reached and what "running" meant (started,
  responsive, under load).
- **Limits:** what failed first (memory, scheduler, ETS, provider rate limit).

Until these exist, do not state a number of agents. Say "the BEAM schedules many
concurrent processes without an application-level thread pool" instead.

## Onboarding-time claims (E11-T19)

To claim time-to-first-success, publish sample size, starting conditions
(including prior Elixir experience), and the median. Until then, use "build and
run one supervised Agent" as the CTA, not a duration.

## Proof levels (from `specs/style-voice.md`)

Map each claim to a level: (1) design intent, (2) tested behavior, (3)
benchmark, (4) production evidence. Numbers require level 3 or 4.
