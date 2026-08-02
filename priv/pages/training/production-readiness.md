%{
  title: "Production Readiness: Supervision, Telemetry, and Failure Modes",
  category: :training,
  description: "Harden agent workloads for production with explicit supervision strategy, telemetry instrumentation, and controlled failure recovery.",
  track: :operations,
  difficulty: :advanced,
  duration_minutes: 75,
  order: 60,
  tags: ["production", "supervision", "telemetry", "reliability"],
  prerequisites: [
    "Completed LiveView + Jido Integration Patterns",
    "Understands OTP restart strategies and Phoenix observability basics"
  ],
  learning_outcomes: [
    "Choose supervision strategies aligned with agent workload patterns",
    "Instrument agent paths with actionable telemetry events",
    "Design recovery playbooks for common failure modes"
  ]
}
---

## What you'll learn

- How to choose restart and isolation strategy by workload type
- How to instrument command latency, queue depth, and error classes
- How to define SLO-oriented alerting for agent systems
- How to practice failure drills before incidents

## Prerequisites

- You are comfortable reading supervision trees
- You have used telemetry events in Phoenix or Elixir systems
- You understand transient vs persistent failures

## Lesson Breakdown

1. **Supervision strategy**: map agent classes to restart policies.
2. **Back-pressure controls**: monitor queue depth and command latency.
3. **Telemetry design**: emit events with stable dimensions and cardinality limits.
4. **Failure modes**: dependency outage, malformed signal bursts, hot loop bugs.
5. **Runbooks**: define triage, containment, recovery, and postmortem steps.

## Hands-on Exercise

Create a production-readiness checklist for one critical agent flow:

1. Draw the supervision tree and identify blast radius boundaries.
2. Add telemetry around command duration and failures.
3. Simulate an upstream outage and verify graceful degradation.
4. Simulate malformed signal floods and validate rate limiting behavior.
5. Write a runbook with rollback and verification steps.

## Validation Checklist

- [ ] Supervision strategy and restart intensity are documented.
- [ ] Telemetry covers latency, failures, and throughput.
- [ ] At least one outage drill has been run in a staging environment.
- [ ] On-call runbook includes concrete rollback and verification commands.

## Next Module

You completed the initial curriculum. Revisit [Your first agent](/docs/getting-started/first-agent) to onboard teammates, then iterate with workload-specific guides.
