# Production Failure-Story Submission Template

Status: Template (`jido-e11`, E11-T12). Last updated: 2026-07-23.

A production failure story is not a bug report for triage — it is the raw
material for a public fix note and a regression test. Submit one when Jido did
the wrong thing in a real system and you can hand us enough to reproduce and
lock the behavior. We publish the lesson; we do not name or blame the reporter
unless they ask to be credited.

This template pairs with the showcase-submission template (`jido-e11`, T09):
that one captures what worked, this one captures what did not.

## Summary

- **One-line symptom:** what an operator saw, not a stack trace title.
- **Impact:** who was affected and for how long (e.g., "500 agents stalled for
  90s during a provider timeout").

## Jido relationship and versions

- Jido relationship (pick one): Jido runtime / adjacent packages only / Jido-inspired.
- Every Jido package involved, with version (e.g., `jido 1.1.0`, `jido_signal 1.2.0`).
- Elixir, OTP, and runtime (single-node or cluster, distribution version).

## Expected and actual behavior

- **Expected:** the behavior you relied on.
- **Actual:** what happened, in operational terms.

## Reproduction

- The smallest sequence that reproduces the failure, or the closest you have.
- A runnable snippet, Livebook, or commit/SHA is ideal. If the failure needs a
  live provider or external system, say so and include the contract you observed.

## Evidence

- Logs, telemetry events, or traces around the failure — redacted of secrets and
  personal data. State what was redacted.
- If a Signal Journal or audit path was involved, note the relevant IDs as
  correlation, not as authenticated principals.

## Recovery and mitigation

- How supervision, restart strategy, retry/idempotency, or an operator action
  restored the system — or did not.
- Any workaround still in place.

## What should be documented

- The sentence a reader would need to find in the docs to avoid or recognize
  this failure next time.

## Maintainer conversion checklist

A submission is ready to convert when a maintainer can answer each of these from
the story above:

- [ ] Cause is identified or scoped to "cause unknown, reproduction locked."
- [ ] A public fix note can be written naming the cause and the correction (or
      the documented boundary that was crossed).
- [ ] A regression test can reproduce the failure and assert the corrected
      behavior — the test is the thing that survives.
- [ ] No claim exceeds the evidence (no "always," "guaranteed," or unsupported
      security/compliance language; see `specs/positioning.md` §11).

## What this template is not

A story with no reproduction and no evidence is a lead, not a failure story —
file it as an issue and come back when you can fill in the reproduction. A story
that turns out to be expected behavior still earns a fix note if the docs failed
to warn a careful reader.
