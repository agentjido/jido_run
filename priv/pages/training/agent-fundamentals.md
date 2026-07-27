%{
  title: "Agent fundamentals on the BEAM",
  category: :training,
  description: "Learn the core Jido mental model: agents as data, actions as transitions, and supervision-managed execution boundaries.",
  track: :foundations,
  difficulty: :beginner,
  duration_minutes: 45,
  order: 10,
  tags: ["agents", "state", "otp", "foundation"],
  prerequisites: [
    "Comfort reading Elixir modules and structs",
    "Basic understanding of OTP supervision trees"
  ],
  learning_outcomes: [
    "Explain why Jido models agents as data first",
    "Differentiate process lifecycle from agent state lifecycle",
    "Define a minimal agent schema and signal routing table"
  ]
}
---

## What you'll learn

- The difference between agent state and process runtime state
- Why immutable transitions improve debuggability and replayability
- How to model domain state with explicit schemas
- How signal routes map events to behavior

## Prerequisites

- You can read Elixir structs and modules comfortably
- You have seen an OTP supervisor in a Phoenix or Elixir app
- You understand that BEAM processes fail independently

## Lesson Breakdown

1. **Mental model**: an agent is a typed state container plus behavior contracts.
2. **State schema**: define required fields, defaults, and constraints up front.
3. **Routing**: map signal types to action modules using predictable naming.
4. **Execution**: keep domain transitions deterministic; isolate side effects.
5. **Failure**: rely on supervisor strategies for process-level recovery.

## Hands-on Exercise

Build a small `InventoryAgent` with fields `sku`, `quantity`, and `updated_at`.

1. Create the schema with defaults and type checks.
2. Add signal routes for `inventory.adjust` and `inventory.recount`.
3. Implement one action that increments/decrements quantity.
4. Add an out-of-bounds guard (`quantity` cannot go below zero).
5. Simulate two command calls and confirm each returns a new agent struct.

## Validation Checklist

- [ ] Agent schema rejects invalid `quantity` input.
- [ ] Route table includes both signal types.
- [ ] Action returns a state delta, not direct side effects.
- [ ] You can show old and new state in a deterministic diff.

## Next Module

Continue with [Actions and Schema Validation](/training/actions-validation).
