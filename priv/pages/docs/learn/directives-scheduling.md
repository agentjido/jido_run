%{
  title: "Directives, Scheduling, and Time-Based Behavior",
  category: :docs,
  legacy_paths: ["/training/directives-scheduling"],
  description: "Build recurring and delayed behavior using directives, including schedule-driven loops and safe shutdown logic.",
  track: :coordination,
  difficulty: :intermediate,
  duration_minutes: 65,
  order: 40,
  tags: ["directives", "schedule", "time", "emit"],
  prerequisites: [
    "Completed Signals and Routing module",
    "Understands delayed work and eventual consistency tradeoffs"
  ],
  learning_outcomes: [
    "Use directives to request side effects declaratively",
    "Implement recurring behavior with schedule chains",
    "Stop scheduled loops safely using state-driven guards"
  ]
}
---

## What you'll learn

- How directives separate state transitions from side effects
- How to schedule delayed or recurring signals cleanly
- How to avoid runaway loops in time-based workflows
- How to reason about clock, retries, and cancellation

## Prerequisites

- You understand action return tuples and signal routing
- You can reason about eventually delivered messages
- You are comfortable debugging asynchronous behavior

## Lesson Breakdown

1. **Directive fundamentals**: emit, schedule, and compose side effect instructions.
2. **Scheduling model**: one-shot schedules and self-rescheduling loops.
3. **Loop controls**: state flags and termination conditions.
4. **Failure handling**: retry windows, jitter, and dead-letter strategies.
5. **Testing time**: assert directives rather than sleeping in tests.

## Hands-on Exercise

Extend a demand tracker with auto-decay:

1. Toggle auto-decay with `listing.demand.auto_decay.toggle`.
2. Emit `listing.demand.changed` after each decay.
3. Schedule a future `listing.demand.tick` while auto mode is enabled.
4. Disable auto mode and confirm no future tick is scheduled.
5. Add tests asserting emitted directives and schedule payloads.

## Validation Checklist

- [ ] Actions return directives instead of executing side effects directly.
- [ ] Recurring behavior is state-controlled, not unconditional.
- [ ] Tests assert directive content and timing intent.
- [ ] Loop stops correctly when guard state flips.

## Next Module

Continue with [LiveView + Jido Integration Patterns](/docs/learn/liveview-integration).
