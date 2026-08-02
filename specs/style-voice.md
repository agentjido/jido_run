# Voice, Tone, and Style Guide

Version: 2.0
Last updated: 2026-07-23
Positioning anchor: `Jido is the Elixir framework for long-running agent systems.` (see `specs/positioning.md` Section 11; `jido-e02`)

## Register

Technical and direct. Write for a senior engineer evaluating tools on a weekday, not a conference keynote audience. Default to showing before telling — code examples, architecture diagrams, and concrete behavior over abstract claims.

## Point of View

Address the reader as "you." Reference teams and organizations as "teams" or "your team." Jido is "Jido" on first use per page, then "it" or "the runtime."

## What We Sound Like

- A thoughtful staff engineer explaining an architecture decision to a peer.
- Confident in what we've built but honest about tradeoffs.
- Specific over vague. "Supervision restarts crashed agents" over "built-in resilience."

## What We Do Not Sound Like

- Marketing copy that could describe any product. No "unlock the power of" or "supercharge your workflow."
- Insider shorthand. Write "Elixir/OTP's process isolation" not "let it crash" without context.
- Breathless hype. No "revolutionary," "game-changing," or "the future of."

## Technical Depth by Section

- **Features / Ecosystem:** Concept-first, then one code example per capability. Enough to evaluate, not enough to implement.
- **Build / Docs:** Code-first. Show the implementation, then explain why it works that way.
- **Training:** Pedagogical. Build concepts incrementally. Every code block should be runnable.
- **Community:** Outcome-first. Show what teams achieved and how they got there.

## Comparison and Competitor References

Name competitors when the comparison is specific and technical (e.g., "Unlike CrewAI's prompt-chain model, Jido uses typed signals for inter-agent communication"). Use category labels ("prototype-first frameworks") when making general positioning claims. Never disparage — frame as fit-for-purpose differences.

## Code Example Conventions

- Use realistic module and function names, not `Foo` or `MyApp`.
- Keep examples under 30 lines when inline; link to full examples for longer code.
- Always show the result or output, not just the setup.
- Prefer examples from the Jido ecosystem packages (jido, jido_ai, jido_action, jido_signal).

## Style and Mechanical Conventions

### Terminology and Capitalization
- Jido — always capitalized, never "JIDO" or "jido" in prose (only lowercase in code/package names)
- BEAM — always all-caps
- OTP — always all-caps
- Elixir/OTP — use this compound form when referencing the platform advantage
- LiveView — one word, capital L capital V
- Phoenix — capitalized
- GenServer — capital G, capital S
- multi-agent — hyphenated as adjective ("multi-agent systems"), no hyphen as noun where applicable
- runtime-first — hyphenated when used as compound adjective
- tool-calling — hyphenated as adjective
- fault-tolerant — hyphenated
- open-source — hyphenated as adjective, "open source" as noun
- hex.pm — lowercase
- jido.run — lowercase
- HexDocs — one word, capital H capital D

### Jido-Specific Terms (use consistently)
- Action (capitalized when referring to the Jido concept, e.g., "define an Action")
- Signal (capitalized when referring to the Jido concept)
- Directive (capitalized when referring to the Jido concept)
- Agent (capitalized when referring to a Jido Agent specifically, lowercase for general "agent" concept)
- Sensor (capitalized for Jido concept)
- Plugin (capitalized for Jido concept)
- Strategy (capitalized for Jido concept — orchestration strategies)
- Workflow — lowercase unless starting a sentence; this is a general concept, not a Jido-specific type
- Runtime — lowercase unless starting a sentence; describes Jido's operational model

### Product vocabulary boundaries

| Term | Defined use |
|---|---|
| **framework** | Jido's public product category: “the Elixir framework for long-running agent systems.” |
| **runtime** | The `AgentServer` and OTP lifecycle mechanism inside the framework. Do not use “runtime” as a replacement product category. |
| **platform** | The host application, operations environment, or a named third-party managed product. Jido is not a separate deployment platform. |
| **infrastructure** | External technical systems or a clearly named lower-level package layer, such as LLM HTTP infrastructure. Do not use “infrastructure” as Jido's product category. |
| **ecosystem** | The optional Jido package set. A builder can use the core framework without installing the full ecosystem. |

### Headings
- Use sentence case for all headings ("Getting started with signals" not "Getting Started With Signals")
- Exception: proper nouns and Jido-specific terms remain capitalized in headings ("Getting started with Jido Signals")

### Code Blocks
- Always specify the language: ```elixir, ```bash, ```json, etc.
- Use `iex>` prefix for interactive examples
- Use `$` prefix for shell commands
- Always show expected output when demonstrating behavior
- Keep inline examples under 30 lines; link to full source for longer
- Use realistic module names from the Jido ecosystem, never `Foo`, `Bar`, `MyModule`
- Dependency examples always use Hex format: `{:jido, "~> 1.0"}`

### Links
- Internal cross-links: use relative paths (`/docs/guides/...`)
- Package references: link to hex.pm (`https://hex.pm/packages/jido`)
- API references: link to HexDocs (`https://hexdocs.pm/jido`)
- Ecosystem overview: link to jido.run
- Never link to internal workspace files, GitHub source, or contributor-only paths in public content

### Status Labels (for pre-release / maturity)
- Use these exact labels when describing package maturity:
  - **Stable** — API is settled, suitable for production use
  - **Beta** — functional and usable, API may change
  - **Experimental** — early development, expect breaking changes
  - **Planned** — not yet implemented
- Always include a status label on ecosystem/package pages
- Never describe an experimental package using production-confidence language

### Structural Conventions
- Use bullet lists for 3+ items; use prose for 1-2 items
- Use tables for comparisons and structured data
- Use admonition blocks (> **Note:**, > **Warning:**, > **Tip:**) sparingly — max 2 per page
- Every page needs a clear "what's next" link at the bottom
- Prerequisites go at the top, before content

### Avoided Phrases
- "Unlock the power of" / "supercharge" / "turbocharge"
- "Revolutionary" / "game-changing" / "the future of"
- "Simply" / "just" / "easily" (implies trivial, alienates struggling readers)
- "Production-ready" without specific evidence backing the claim
- "Best-in-class" / "world-class" / "enterprise-grade" (empty superlatives)
- "Let it crash" without explaining what it means for non-BEAM readers
- "Users" — say "you" or "teams" instead

### Primary CTA Convention
- Default CTA across the site: **Get Building**
- Section-specific alternatives: "Start Training", "Explore Features", "See the Ecosystem"
- CTA must always link to a real, populated destination

### Secondary CTA convention

Use these labels for these exact tasks:

| Label | Use | Destination |
|---|---|---|
| **See examples** | Show runnable proof after a feature, capability, or build claim. | `/examples` for the catalog, or one published `/examples/<slug>` page for direct proof. |
| **Read the guide** | Move from an overview or proof into implementation instructions. | One specific published `/docs/...` guide. Do not use this label for the Docs hub. |
| **Compare packages** | Help a builder compare package role, maturity, dependencies, and support. | `/ecosystem#compare`. Do not use this label for competitor comparisons. |

Write secondary CTA labels in sentence case. An arrow can follow the label, but
it is not part of the label. Do not replace these labels with vague text such
as "Learn more."

---

## Claim Policy (`jido-e02`, E02-T18..T22, E02-T38)

Copy must stay inside the claim boundaries in `specs/positioning.md` Section 11.
The release claim linter (`jido-e12`, E12-T01/T02/T37) enforces the lists below.

### Restricted claims — reject unless an approved proof reference is cited
self-healing, no downtime, uptime guarantees, observe everything, secure by
default, compliance-ready, enterprise governance, complete audit trail.

### Proof-required claims — need named evidence
production-grade, production-ready, production-proven.

### Definition-required claims — must define scope, controls, and stop conditions
autonomous.

### Qualifier claims — name the tested behavior or package maturity
reliable, recover, durable, scale, safe, tracing, identity-aware, authorized,
auditable, governed, controlled.

### Proof levels
1. Design intent
2. Tested behavior
3. Benchmark
4. Production evidence

Each public claim should be able to name its proof level.

### Operational-control copy rules (E02-T30..T33)
- Prefer: long-running, supervised, explicit, typed, observable, stateful,
  event-driven, bounded failure, restart policy, existing Elixir application,
  add AI when needed.
- "Control" must name the exact type: lifecycle, capability, authorization,
  quota, trace, or recovery control. Avoid bare "control" as an adjective.
- Telemetry is not an audit log. Agent IDs are not authenticated principals.
  State these distinctions where a reader could infer compliance.

### Default SEO/category language (E03-T01)
Title: `Jido: the Elixir framework for long-running agent systems`.
Description: `Build supervised agents, typed tools, and explicit workflows on
Elixir/OTP. Start with one Agent in your current application and add AI when you
need it.`
