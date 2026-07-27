%{
  title: "Signals, routing, and agent communication",
  category: :training,
  description: "Coordinate agents through explicit signal contracts and routing strategies that keep producer and consumer responsibilities decoupled.",
  track: :coordination,
  difficulty: :intermediate,
  duration_minutes: 60,
  order: 30,
  tags: ["signals", "routing", "pubsub", "coordination"],
  prerequisites: [
    "Completed Actions and Schema Validation",
    "Basic understanding of pub/sub and event-driven design"
  ],
  learning_outcomes: [
    "Model cross-agent events with stable signal naming",
    "Route signals to actions without tight coupling",
    "Design idempotent handlers for duplicate or delayed delivery"
  ]
}
---

## What you'll learn

- Signal naming patterns that remain stable as systems grow
- How routing decouples producers from downstream execution
- How to handle out-of-order, delayed, or duplicate events
- How to design idempotent communication flows

## Prerequisites

- You can write validated action modules
- You know the difference between command and event messages
- You are comfortable with map-based payloads

## Lesson Breakdown

1. **Signal taxonomy**: separate intent (`*.command`) from fact (`*.changed`).
2. **Route design**: keep routing tables small and explicit.
3. **Payload discipline**: include identifiers and timestamps consistently.
4. **Idempotency**: protect handlers with dedupe keys or monotonic checks.
5. **Observability**: emit telemetry around route hits and failures.

## Hands-on Exercise

Model a two-agent workflow for order fulfillment:

1. `OrderAgent` emits `order.approved`.
2. `InventoryAgent` listens and reserves stock.
3. `ShippingAgent` listens for `inventory.reserved`.
4. Add idempotency key handling to prevent duplicate reservation.
5. Simulate duplicate `order.approved` events and verify safe behavior.

## Validation Checklist

- [ ] Signal names follow a consistent domain prefix.
- [ ] Each consumer route is explicit and traceable.
- [ ] Duplicate delivery does not double-apply state changes.
- [ ] Telemetry exists for routing success and failure paths.

## Next Module

Continue with [Directives, Scheduling, and Time-Based Behavior](/training/directives-scheduling).
