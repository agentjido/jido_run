<!-- 
  TEMPLATE: Docs Reference (API Reference Hub Page)
  Use for: /docs/reference/* pages — module-level API documentation
  Tone: See specs/style-voice.md — code-first, show implementation then explain.
  Rules: content-outline.md §5 (clear claim, architecture explanation, runnable proof,
         training cross-link, docs/reference cross-link, CTA).
  Note: This template is for hand-written reference hub pages that complement
        auto-generated HexDocs. Focus on context, examples, and connections
        that HexDocs doesn't provide.
-->

# `[MODULE NAME]`

## Overview

<!-- What does this module do and when would you use it? 1-2 paragraphs.
     This is the context that HexDocs @moduledoc often lacks. -->

[WHAT THIS MODULE DOES, WHEN TO USE IT, AND WHERE IT FITS IN THE JIDO ARCHITECTURE. Be direct — "This module defines the agent behaviour and provides the macros for creating new agent types."]

---

## Public API

<!-- Functions with arities and one-line descriptions. Must match current source
     (content-governance.md §10). Only include public functions. -->

| Function | Description |
|----------|-------------|
| `[FUNCTION]/[ARITY]` | [ONE-LINE DESCRIPTION] |
| `[FUNCTION]/[ARITY]` | [ONE-LINE DESCRIPTION] |
| `[FUNCTION]/[ARITY]` | [ONE-LINE DESCRIPTION] |
| `[FUNCTION]/[ARITY]` | [ONE-LINE DESCRIPTION] |

---

## Configuration

<!-- Table of configuration options. Only include if the module has runtime or
     compile-time configuration. Omit this section if not applicable. -->

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `:[KEY]` | `[TYPE]` | `[DEFAULT]` | [WHAT IT CONTROLS] |
| `:[KEY]` | `[TYPE]` | `[DEFAULT]` | [WHAT IT CONTROLS] |

---

## Types and Specs

<!-- Key typespecs that users need to know about. Show the actual typespec syntax. -->

```elixir
@type [TYPE_NAME] :: [DEFINITION]

@type [TYPE_NAME] :: [DEFINITION]
```

---

## Examples

<!-- 2-3 practical examples showing common usage. Under 30 lines each.
     Must compile (content-governance.md §10). -->

### [EXAMPLE TITLE — e.g., "Creating an Agent"]

```elixir
[RUNNABLE CODE]
```

**Output:**

```
[EXPECTED OUTPUT]
```

### [EXAMPLE TITLE — e.g., "Handling Signals"]

```elixir
[RUNNABLE CODE]
```

**Output:**

```
[EXPECTED OUTPUT]
```

---

## Control surface

<!-- For reference pages that document a control-bearing primitive or package
     (Agent, Action, Signal, Plugin, AI, Observe), draw the control surface as a
     table so a reader sees the control points it supplies at a glance. Each table
     names the hook, input, decision, output, failure behavior, and evidence
     (E06-T32). State the limit plainly and link to Security and governance for the
     full control-point map. Omit this section for reference pages that carry no
     control surface (e.g. a glossary). -->

| Hook | Input | Decision | Output | Failure behavior | Evidence |
|----------|-------|----------|--------|-------------------|----------|
| `[HOOK]` | `[INPUT]` | `[DECISION]` | `[OUTPUT]` | `[FAILURE BEHAVIOR]` | `[EVIDENCE + LIMIT]` |

---

## Related Modules

<!-- Link to other reference pages for modules that are commonly used together. -->

| Module | Relationship |
|--------|-------------|
| [`[MODULE]`](/docs/reference/[SLUG]) | [HOW THEY RELATE — e.g., "Defines the signals this module processes"] |
| [`[MODULE]`](/docs/reference/[SLUG]) | [HOW THEY RELATE] |

---

## Learn More

<!-- Cross-links required (content-outline.md §5). -->

- **Concept guide:** [CONCEPT PAGE](/docs/core-concepts/[SLUG]) — Understand the ideas behind this module
- **Training:** [MODULE TITLE](/training/[SLUG]) — Learn to use this module step by step
- **HexDocs:** [Full API documentation](https://hexdocs.pm/[PACKAGE]/[MODULE].html)

---

## Get Building

<!-- CTA required (content-outline.md §5 rule 6). -->

[Use [MODULE] in a project](/build/[RELEVANT-GUIDE]) | [Get started with Jido](/build/getting-started)

---

<!--
  ============================================================
  PUBLISHING CHECKLIST (content-governance.md §10)
  Remove this block before publishing.
  ============================================================

  Before publishing:
  [ ] Package references are real
  [ ] Code examples compile — real modules, functions, correct arities
  [ ] Links resolve — all routes exist
  [ ] Claims are bounded
  [ ] CTA is present and routed
  [ ] Voice check — technical reference tone
  [ ] Cross-link chain — forward (training/build) and backward (concepts/ecosystem)

  Docs-specific checks:
  [ ] API references match current module signatures
  [ ] Configuration keys are valid
  [ ] Types match current typespecs
  [ ] Function arities are correct
-->
