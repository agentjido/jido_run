%{
  title: "Actions and schema validation",
  category: :training,
  description: "Design robust action contracts with clear input schemas, defaults, and validation failures that are safe to expose to callers.",
  track: :foundations,
  difficulty: :beginner,
  duration_minutes: 50,
  order: 20,
  tags: ["actions", "validation", "contracts", "safety"],
  prerequisites: [
    "Completed Agent Fundamentals module",
    "Comfort with maps, pattern matching, and return tuples"
  ],
  learning_outcomes: [
    "Create actions with explicit parameter contracts",
    "Fail fast on invalid input before state mutation",
    "Return actionable validation errors to upstream callers"
  ]
}
---

## What you'll learn

- Why validation belongs at action boundaries
- How defaults and required fields reduce caller ambiguity
- How to structure return tuples for success and failure
- How to keep actions composable and testable

## Prerequisites

- You understand the agent schema and route concepts
- You can write simple ExUnit tests
- You are familiar with tuple-based success/error flow

## Lesson Breakdown

1. **Action contract design**: define required fields and defaults clearly.
2. **Validation flow**: reject malformed input before touching state.
3. **Return shape**: standardize `{:ok, state_delta}` and `{:error, reason}`.
4. **Domain errors**: separate validation errors from business rule conflicts.
5. **Testing strategy**: test happy path, boundary values, and failure payloads.

## Hands-on Exercise

Implement `SetPriceAction` for a listing agent:

1. Input schema: `price_cents` (required integer), `currency` (default `"USD"`).
2. Reject prices below `100` or above `50_000_00`.
3. Return structured errors: `%{field: ..., message: ...}`.
4. Apply a successful update and stamp `last_updated_at`.
5. Add tests for invalid type, missing field, and boundary values.

## Validation Checklist

- [ ] Invalid payloads fail before action logic runs.
- [ ] Defaults are applied deterministically.
- [ ] Error payloads include field-level detail.
- [ ] Tests cover lower and upper boundary values.

## Next Module

Continue with [Signals, Routing, and Agent Communication](/training/signals-routing).
