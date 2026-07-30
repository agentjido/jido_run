# Product vocabulary scan — 2026-07-30

Task: `jido-e03-t26`

## Definitions

- **framework** is Jido's public product category.
- **runtime** is the AgentServer and OTP lifecycle mechanism.
- **platform** is the host application, operations environment, or a named
  third-party managed product.
- **infrastructure** is an external technical system or a clearly named
  lower-level package layer.
- **ecosystem** is the optional Jido package set.

These definitions are now part of `specs/style-voice.md`.

## Scope and method

The scan covered all public Markdown and Livebook source under `priv/pages`.
Raw, case-insensitive occurrence counts were:

| Term | Occurrences |
|---|---:|
| framework | 58 |
| runtime | 447 |
| platform | 45 |
| infrastructure | 18 |
| ecosystem | 216 |

The review grouped these uses by context and checked category-defining phrases
separately from technical uses. The regression gate rejects these errors:

- Jido described as a runtime, platform, or infrastructure product
- Evaluation copy that uses runtime, platform, or infrastructure as Jido's
  category
- Copy that says the full Jido ecosystem is required

## Corrections

The scan corrected three public pages:

- `/features/beam-for-ai-builders` now uses the framework category and explains
  runtime-first architecture as an internal design.
- `/features/executive-brief` now describes a Jido framework evaluation and a
  Jido pilot, not runtime infrastructure.
- `/docs/contributors/roadmap` now describes persistence as a framework
  capability, not part of a Jido platform.

The internal Features module description also uses “Jido framework.”

## Final result

The final category-misuse scan found zero errors.

```bash
MIX_ENV=test mix test test/agent_jido/vocabulary_canon_lint_test.exs
```
