<!-- 
  TEMPLATE: Build Guide
  Use for: /build/* pages (e.g., /build/mixed-stack-integration)
  Tone: See specs/style-voice.md — code-first, then explain why it works that way.
  Rules: content-outline.md §5 (clear claim, architecture explanation, runnable proof,
         training cross-link, docs/reference cross-link, CTA).
-->

# [GUIDE TITLE]

## What You'll Build

<!-- Outcome statement: What does the reader have at the end of this guide?
     Be concrete: "A running agent that processes webhooks and routes them to specialized handlers"
     not "Learn how to use Jido for integrations." -->

[ONE PARAGRAPH DESCRIBING THE CONCRETE OUTCOME. What will be running when they finish? What does it do?]

---

## Prerequisites

<!-- List what the reader needs before starting. Be specific about versions.
     All setup steps must be tested against current package versions (content-governance.md §10). -->

- Elixir [VERSION]+ and OTP [VERSION]+
- [PACKAGE_NAME] `~> [VERSION]` — [why this package is needed]
- [PACKAGE_NAME] `~> [VERSION]` — [why]
- [ANY OTHER PREREQUISITES — API keys, running services, prior guides completed]

---

## Architecture Overview

<!-- What packages are involved and how they connect. This is the "map" before the "directions."
     Include a diagram showing the components and data flow. -->

[2-3 SENTENCES EXPLAINING THE ARCHITECTURE OF WHAT YOU'RE BUILDING]

```mermaid
graph LR
    A[COMPONENT] -->|SIGNAL/DATA| B[COMPONENT]
    B --> C[COMPONENT]
```

---

## Implementation

<!-- Code-first, explain after (style-voice.md §Technical Depth by Section).
     Each step should have runnable code. Build incrementally — each step should
     work on its own before moving to the next. -->

### Step 1: [ACTION VERB — e.g., "Define the Agent"]

```elixir
[RUNNABLE CODE]
```

<!-- Explain what the code does and why it's structured this way. Keep it brief — 
     the code should be mostly self-explanatory. -->

[1-3 SENTENCES EXPLAINING THE CODE]

### Step 2: [ACTION VERB]

```elixir
[RUNNABLE CODE]
```

[EXPLANATION]

### Step 3: [ACTION VERB]

```elixir
[RUNNABLE CODE]
```

[EXPLANATION]

<!-- Add more steps as needed. Each step should be small enough to verify independently. -->

---

## Testing & Verification

<!-- How does the reader confirm it works? Provide a concrete test or verification step. -->

```elixir
# Verify the implementation
[TEST OR VERIFICATION CODE]
```

**Expected result:**

```
[EXPECTED OUTPUT]
```

---

## Control boundary

<!-- E06-T31: every guide draws the control boundary in one place, in this
     order, so a reader can tell where Jido ends and their application begins.
     State each part concretely for THIS guide — do not paste generic text.
     1) What Jido supplies: the primitives or control points this guide used.
     2) What an application must supply: the duties that stay on the
        application or platform (policy, identity, deployment, storage).
     3) What evidence remains after execution — and its limit. Telemetry and
        Agent/Signal/request/trace IDs are correlation, not authenticated
        principals; telemetry is for observation, not a tamper-evident audit
        log; nothing is durable until a Journal adapter is configured.
     Full claim boundaries live on the Security and governance page. -->

**What Jido supplies.** [THE PRIMITIVES OR CONTROL POINTS THIS GUIDE USED — e.g. typed, validated Actions; the Signal dispatch model; OTP supervision; the fail-closed `prepare_action/3` hook; `jido_ai` tool/effect/prompt/quota policies.]

**What your application must supply.** [THE DUTIES THAT STAY ON THE APPLICATION OR PLATFORM — e.g. authentication and verified identity in front of Jido; the authorization policy a plugin consults; the storage layer for durable history; deployment and restart strategy.]

**What evidence remains after execution.** [WHAT THIS GUIDE'S EXAMPLE LEAVES BEHIND — e.g. telemetry spans and Signal/trace IDs for correlating one unit of work — AND THE LIMIT: those IDs are correlation, not authenticated principals; telemetry is observation, not a tamper-evident audit log; nothing is durable until you configure a Signal Journal adapter. See [Security and governance](/docs/operations/security-and-governance).]

---

## Next Steps

<!-- Cross-links required (content-outline.md §5, §6).
     Build pages link to: training modules and docs. -->

- **Go deeper:** [TRAINING MODULE TITLE](/training/[MODULE-SLUG]) — [what they'll learn next]
- **Reference:** [DOCS PAGE](/docs/[PATH]) — [what they'll find there]
- **Related guide:** [ANOTHER BUILD GUIDE](/build/[SLUG]) — [how it extends what they just built]

---

## Get Building

<!-- CTA required (content-outline.md §5 rule 6). -->

[SENTENCE CONNECTING THIS GUIDE TO THE BROADER JIDO ECOSYSTEM OR A NATURAL NEXT ACTION]

[Get started with Jido](/build/getting-started) | [Explore the ecosystem](/ecosystem)

---

<!--
  ============================================================
  PUBLISHING CHECKLIST (content-governance.md §10)
  Remove this block before publishing.
  ============================================================

  Before publishing:
  [ ] Package references are real — every package in priv/ecosystem/*.md with visibility: public
  [ ] Code examples compile — tested against current package versions
  [ ] Links resolve — all cross-links point to real routes
  [ ] Claims are bounded
  [ ] CTA is present and routed
  [ ] Voice check — code-first, explanations after
  [ ] Cross-link chain — forward (training/docs) and backward (features/ecosystem)

  Build-specific checks:
  [ ] All setup steps tested against current package versions
  [ ] Prerequisites are listed completely
  [ ] Steps are runnable in sequence — each builds on the previous
  [ ] Control boundary block states what Jido supplies, what the application supplies, and what evidence remains (E06-T31)
-->
