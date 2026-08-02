%{
  title: "LiveView + Jido Integration Patterns",
  category: :docs,
  legacy_paths: ["/training/liveview-integration"],
  description: "Connect LiveView UIs to agent state transitions with deterministic rendering, command handlers, and event-driven updates.",
  track: :integration,
  difficulty: :intermediate,
  duration_minutes: 55,
  order: 50,
  tags: ["liveview", "ui", "integration", "state"],
  prerequisites: [
    "Completed Directives and Scheduling module",
    "Experience building basic Phoenix LiveView screens"
  ],
  learning_outcomes: [
    "Model UI events as agent commands",
    "Render from immutable agent state in socket assigns",
    "Integrate emitted signals into real-time UI feedback"
  ]
}
---

## What you'll learn

- How to wire LiveView events to agent command execution
- How to keep UI state aligned with immutable agent outputs
- How to display side effects (emit/schedule) transparently to users
- How to avoid race-prone state updates in interactive flows

## Prerequisites

- You are comfortable with `handle_event/3` in LiveView
- You can read Phoenix templates and assigns
- You understand optimistic and confirmed UI update tradeoffs

## Lesson Breakdown

1. **Command boundary**: map each UI intent to a single agent command.
2. **State rendering**: render from the latest agent struct only.
3. **Directive visibility**: surface emitted/scheduled work in UI logs.
4. **Concurrency handling**: guard against stale events and rapid clicks.
5. **Testing**: verify DOM updates from known state transitions.

## Hands-on Exercise

Build a LiveView for the demand tracker:

1. Initialize an agent in `mount/3`.
2. Add `Boost`, `Cool`, and `Toggle Auto Decay` buttons.
3. On click, call the agent command and assign the new state.
4. Render a recent-events panel from emitted directive metadata.
5. Add a LiveView test asserting key state and labels change correctly.

## Validation Checklist

- [ ] Every UI action maps to an explicit agent command.
- [ ] Socket assigns hold the latest immutable agent state.
- [ ] Directive outcomes are visible for debugging.
- [ ] LiveView tests cover at least one multi-step user flow.

## Next Module

Continue with [Production Readiness: Supervision, Telemetry, and Failure Modes](/docs/learn/production-readiness).
