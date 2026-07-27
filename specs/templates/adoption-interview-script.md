# Adoption Interview Script

Status: Template (`jido-e11`, E11-T16). Last updated: 2026-07-27.

A semi-structured script for interviewing a Jido adopter about their real
journey. Run it as a recorded conversation (with consent), then route the
answers into qualified evidence: a case study (`case-study.md`, E11-T01), a
showcase submission (`showcase-submission.md`, E11-T09), a production failure
story (`production-failure-story.md`, E11-T12), and doc gaps filed as issues.

Every interview asks about four things — first success, package choice,
failures, and missing docs — because those are the answers that turn an
anecdote into evidence or a doc fix. The context questions help place those
answers; they do not stand in for the four.

## Before the interview

- Confirm consent to record, quote, and attribute (or stay anonymous). Record
  the consent decision with the answers.
- Capture the basics up front so the four questions get the time: name, team,
  Jido relationship (runtime / adjacent packages only / Jido-inspired), and
  every Jido package and version in use.
- Aim for concrete answers (what happened, when, with which version) over
  impressions. Do not coach toward a flattering story.

## Required questions

These four blocks are not optional. Every interview covers all four. If an
adopter cannot answer one, record that honestly — a blank is evidence too.

### 1. First success

What was the first thing that actually worked — the moment Jido stopped being
evaluation and started being used?

- What did you build first, and what made it feel like a success (a working
  Agent, a Signal flowing through, an Action completing)?
- How long did it take from "decided to try Jido" to that first success, and
  what unblocked you when you got stuck?
- What is it doing now — still running, replaced, or abandoned? Be specific.

### 2. Package choice

Which Jido packages did you choose, and why those?

- Which packages do you depend on (`jido`, `jido_signal`, adjacent packages
  such as `req_llm`), and which did you try and reject?
- Why this set — did you choose by stability, by scope, or because an example
  or a doc pointed you there?
- What is the real Jido relationship: Jido runtime, adjacent packages only, or
  Jido-inspired? This sets the label for any resulting case study (E11-T10/T11).

### 3. Failures

What did not work?

- What broke, surprised you, or cost you time — in setup, in the runtime, or
  at a provider boundary?
- Was it a bug, a docs gap, an expectation mismatch, or a real limitation?
- How did you recover (supervision, restart, retry, an operator action), and is
  anything still working around it? A reproducible one becomes a
  `production-failure-story.md` (E11-T12).

### 4. Missing docs

What did you wish the docs said?

- Where did you get stuck because the docs were missing, wrong, or assumed
  knowledge you did not have?
- Is there a sentence that, if it existed, would have saved you the most time?
- Would you be willing to have that gap turned into a public fix note and a
  regression test, with or without your name on it?

## Context (helps place the answers — does not replace the four)

- Runtime profile: how long it has run, single-node or cluster, and rough load.
- Failure policy: restart strategy, persistence, retry/idempotency.
- One outcome that matters to the team, with method (or "not yet measured").

## After the interview

- Route each answer to its evidence artifact:
  - First success + package choice + outcome → `case-study.md` (E11-T01) /
    `showcase-submission.md` (E11-T09).
  - A reproducible failure → `production-failure-story.md` (E11-T12).
  - A missing-docs gap → a docs issue, and ideally a fix note plus a regression
    test.
- Claim approval (E11-T02/T27): before anything is published, confirm the
  operational claims with the interviewee and strip anything beyond the
  evidence (no unsupported security/compliance/complete-control language; see
  `positioning.md` §11).

## What this script is not

It is not a survey for marketing quotes, and it is not a request for
endorsements. A "first success" that was actually a tutorial counts; a success
we cannot place in time or version does not. An interview that records no
failure and no docs gap is incomplete — record the silence, do not fill it in.
