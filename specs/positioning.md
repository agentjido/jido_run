# Jido Positioning Strategy

Version: 4.0  
Last updated: 2026-07-23  
Primary inputs: `specs/content-outline.md`, `specs/persona-journeys.md`, `priv/ecosystem/*.md`, `docs/Jido Positioning Review 2026-07-23.md`

> **Canon status:** Section 1 and the Positioning Canon (Section 11) supersede all
> earlier "locked" language on this page, including the former anchor "a runtime
> for reliable, multi-agent systems" and the former category "Reliable Multi-Agent
> Runtime Platform." Source: `jido-e02` (E02-T01..T45).

## 1) Core Positioning

### Public category (`E02-T01`)
`Jido is the Elixir framework for long-running agent systems.`

### Primary operational benefit (`E02-T31`, `E02-T32`)
`Build Agent systems you can supervise, constrain, and inspect.`

Operational control is the bridge between the production promise and the
reliability of the BEAM. It is a product benefit, not a claim that Jido is a
complete governance or compliance platform.

### One-line positioning statement
Jido gives Elixir teams explicit control points for long-running Agents —
supervised lifecycles, validated capabilities, fail-closed policy hooks, causal
Signals, and correlated telemetry — that fit an existing Phoenix or OTP
application.

### Primary audience (`E02-T06`)
Elixir engineers who need agent work to become part of a real Phoenix or OTP
application. Non-Elixir builders are a secondary evaluation route (`E02-T07`).

### Product posture
Jido is open source. Position calls-to-action around builder activation and
self-serve adoption. Core packages are Beta; no separate runtime service is
required.

### What Jido is not
- Not only a prompt-orchestration helper.
- Not only an LLM API wrapper.
- Not a separate deployment platform, IAM, or compliance product (see claim
  boundaries in Section 11).

## 2) Market Point of View

Most agent tools make it easy to start and hard to operate.  
Jido should be positioned as the platform for teams that care about what happens after launch:
- sustained uptime,
- predictable behavior under concurrency,
- explicit failure handling,
- real observability and runbooks.

The strategic message is simple:
`Prototyping is common. Reliable operation is rare. Jido is built for operation.`

## 3) Why Jido, Why Now

AI product teams are moving from "single LLM call" features to multi-step, tool-using, multi-agent workflows. This introduces:
- state and lifecycle complexity,
- cross-agent coordination risk,
- operational and compliance pressure,
- cost and latency management challenges.

Jido's value rises as complexity rises. The more concurrency, tooling, and cross-agent behavior a team needs, the stronger the runtime-first argument becomes.

## 4) Unique Selling Proposition

### Core USP
Jido treats multi-agent systems as a runtime architecture problem, not just a prompt design problem.

### Why Elixir/OTP matters
- Process isolation reduces blast radius of failures.
- Supervision gives clean restart and recovery semantics.
- Concurrency primitives support many long-lived agent processes.
- OTP operational model makes incident handling practical for production teams.

### Practical translation for buyers
- Fewer cascading failures.
- Faster debugging of weird runtime behavior.
- Safer scaling from one agent workflow to many.
- Better total cost over lifecycle, not just day-one implementation.

## 5) Multi-Agent Thesis

Jido's multi-agent story should be explicit:
- agents communicate through structured signals,
- capabilities are expressed as typed actions,
- orchestration behavior is modeled with directives and strategies,
- scheduling and temporal behavior are part of runtime design.

Message to repeat:
`Multi-agent in Jido is engineered coordination, not role-play in a single prompt.`

## 6) Differentiation Framing (CrewAI, Mastra, and similar)

Use a respectful "fit-for-purpose" narrative, not attack copy.

| Dimension | Prototype-first frameworks | Jido positioning |
|---|---|---|
| Primary optimization | Fast initial setup | Reliable long-term operation |
| Runtime model | App-layer orchestration centric | Runtime-layer supervision and lifecycle centric |
| Failure handling | Often ad hoc at app level | Explicit OTP supervision and containment |
| Multi-agent coordination | Commonly prompt/procedure heavy | Structured signals/actions/directives |
| Operations posture | Add observability later | Observability and operations as first-class |
| Best fit | Rapid experiments | Production multi-agent systems |

Comparison line:
`If you need to prove an idea quickly, many tools can work. If you need agents to run continuously and safely in production, Jido is the better fit.`

## 7) Persona Coverage

### Primary persona clusters
- BEAM-native builders.
- Polyglot technical builders.
- Decision and influence roles.

### Priority personas for first-wave messaging
1. Elixir platform engineer.
2. AI product engineer.
3. Staff architect or tech lead.
4. Python AI engineer evaluating production reliability.
5. TypeScript fullstack engineer needing a robust agent backend.
6. Platform/SRE engineer owning reliability outcomes.

### Persona-level promise map

| Persona | Primary promise | First proof needed |
|---|---|---|
| Elixir platform engineer | "Agent systems aligned with OTP discipline" | Supervision and failure-pattern examples |
| AI product engineer | "Ship AI features without runtime fragility" | End-to-end tool-calling examples |
| Staff architect | "Adoption path with governance and maintainability" | Reference architectures and migration playbooks |
| Python AI engineer | "Better runtime semantics for long-lived workloads" | Why-BEAM comparison and interoperability guide |
| TS fullstack engineer | "Stable backend for JS product surfaces" | API boundary and frontend integration examples |
| SRE/platform engineer | "Operable system with clear SLO signals" | Telemetry model, runbooks, incident patterns |

## 8) Ecosystem Proof Architecture

Positioning claims must connect to concrete packages and examples.

### Runtime and coordination core
- `jido`
- `jido_action`
- `jido_signal`

### Intelligence and model layer
- `jido_ai`
- `req_llm`
- `llm_db`
- `jido_claude`

### Tools and execution layer
- `jido_browser`
- `jido_code`
- `jido_sandbox`
- `jido_runic`
- `jido_behaviortree`
- `jido_live_dashboard`
- `jido_shell`
- `jido_vfs`

### Integrations and deployment layer
- `ash_jido`
- `jido_messaging`
- `jido_flame`
- `agent_jido`

Proof rule:
Every positioning pillar must reference at least one package, one runnable example, and one training module.

## 9) Messaging Pillars

### Pillar 1: Reliability by architecture
Core message: Agents should fail safely and recover predictably.  
Proof surfaces: supervision examples, failure drills, production runbooks.

### Pillar 2: Multi-agent coordination you can reason about
Core message: Complex agent behavior should be explicit and testable.  
Proof surfaces: signal routing patterns, directive examples, workflow traces.

### Pillar 3: Production operations and observability
Core message: Real systems need telemetry, debugging workflows, and controls.  
Proof surfaces: dashboard instrumentation, trace narratives, SRE checklists.

### Pillar 4: Composable ecosystem with incremental adoption
Core message: Adopt only what you need now, expand safely later.  
Proof surfaces: package matrix, minimal-stack quickstarts, migration guides.

## 10) Site Information Architecture Narrative

Top-level structure should map to buyer questions:

| Section | User question answered |
|---|---|
| Features | What capabilities matter and why do they matter? |
| Ecosystem | Which package solves which part of my architecture? |
| Build | How do I implement this in a real app? |
| Training | How do I level up my team quickly? |
| Docs | Where are the exact APIs/configs/migration details? |
| Community | How are other teams using this? |

This is the core storyline:
`Features -> Ecosystem -> Build -> Training -> Docs -> Community`

## 11) Persona Journey Templates

### Journey A: Elixir platform engineer
`/features` -> `/ecosystem/jido` -> `/training/agent-fundamentals` -> `/training/production-readiness` -> `/docs/reference`

### Journey B: AI product engineer
`/features` -> `/ecosystem/jido_ai` -> `/build` -> `/training/liveview-integration` -> `/docs/guides`

### Journey C: Non-Elixir evaluator (Python/TS)
`/features/beam-for-ai-builders` -> `/features` -> `/build` -> `/docs/reference` -> `/training`

### Journey D: Architect/lead buyer
`/features/executive-brief` -> `/ecosystem/matrix` -> `/docs/reference` -> `/training/manager-roadmap`

## 12) Objection Handling

### "We are not an Elixir shop."
Response:
- Use Jido as a bounded agent service first.
- Integrate via APIs/events from existing systems.
- Expand only when reliability gains are proven.

### "This looks heavier than other agent frameworks."
Response:
- It is intentionally production-oriented.
- Heavier upfront structure lowers long-term incident and maintenance cost.

### "Can this handle real multi-agent complexity?"
Response:
- Coordination is explicit via signals/actions/directives.
- Behavior can be inspected, tested, and traced.

### "How do we de-risk adoption?"
Response:
- Start with a single critical workflow.
- Use training + reference architecture checkpoints.
- Define go/no-go criteria around reliability and operability.

## 13) Claim Discipline

### Claims we should make
- Designed for reliable multi-agent runtime behavior on the BEAM.
- Built for production operation, not only prototype speed.
- Structured coordination model for complex agent workflows.

### Claims we should avoid
- "Best agent framework."
- "Solves every AI architecture problem."
- Unbounded performance claims without benchmarks and workload context.

## 14) Copy System

### Hero headline (locked)
`A runtime for reliable, multi-agent systems.`

### Supporting subhead (locked)
`Design, coordinate, and operate agent workflows that stay stable in production — built on Elixir/OTP for fault isolation, concurrency, and uptime.`

### CTA options
1. Get Building
2. Start Training
3. Explore Features
4. See the Ecosystem
5. Build Your First Agent

## 15) Content Strategy Guardrails

### Required proof chain for every major page
- Narrative claim.
- Concrete architecture explanation.
- Runnable example.
- Training module.
- Relevant section-level reference docs.

### Editorial posture
- Practical, technical, and testable.
- Confident but not hype-driven.
- Honest about tradeoffs and adoption cost.

## 16) Success Metrics for Positioning

### Adoption funnel metrics
- Time to first working agent workflow.
- Percentage of users moving from one package to three-plus packages.
- Training module start and completion rates.
- Conversion from feature pages to build/training pages.

### Trust and production metrics
- Operate/reference page engagement from active teams.
- Number of production-readiness checklist completions.
- Reduction in support questions caused by unclear architecture boundaries.

## 17) Canonical Pitch Variants

### 10-second pitch
`Jido is a runtime for reliable, multi-agent systems.`

### 30-second pitch
`Jido is a runtime for reliable, multi-agent systems. Built on Elixir/OTP, it gives teams fault-tolerant concurrency, explicit multi-agent coordination, and operational tooling to run safely under real load.`

### 2-minute pitch
`Most teams can prototype agents quickly, but production is where systems break. Jido is built for that reality. Jido is a runtime for reliable, multi-agent systems, built on Elixir/OTP for fault-tolerant concurrency and production-grade reliability. Agent behavior is explicit, coordinated, and observable: actions define capabilities, signals handle communication, directives model orchestration, and OTP supervision provides failure containment and recovery. Instead of optimizing only for day-one speed, Jido optimizes for day-100 reliability. That makes it a strong fit for teams building serious multi-agent products that must keep working when traffic, complexity, and operational pressure increase.`

## 18) Positioning Checklist (Before Publishing Any Major Page)

1. Does the page reinforce the runtime-first thesis?
2. Does it explain why BEAM matters in practical terms?
3. Does it include concrete multi-agent proof, not generic AI language?
4. Does it map to a persona and next-step journey?
5. Does it connect to training and reference documentation?

## 19) Voice and Tone Guide

See `specs/style-voice.md` for the full voice, tone, and style/mechanical conventions guide.

---

## 11) Positioning Canon (v4, 2026-07-23) — `jido-e02`

This section is the single source of truth for writers and components. Where
earlier sections of this document conflict with Section 11, Section 11 wins.

### Message house

| Level | Message |
|---|---|
| Category | The Elixir framework for long-running agent systems |
| Main promise | Build supervised, observable agent workflows that fit your existing Elixir application |
| Runtime reason | Elixir/OTP gives each running Agent an isolated process and an explicit supervision policy |
| Design reason | Typed Actions, Signals, and Directives keep behavior testable and side effects visible |
| Adoption reason | Start with one Agent; add AI, persistence, tools, and coordination as the work requires |
| Operational benefit | Build Agent systems you can supervise, constrain, and inspect |
| Proof | Runnable failure drill, state-recovery example, workflow trace, and real project story |
| Tradeoff | More explicit structure than a prompt script; better fit for work that must run and change over time |

### Operational-control pillars (`E02-T33`)

| Pillar | Mechanism | Proof requirement |
|---|---|---|
| Lifecycle | `AgentServer` + OTP supervision, restart policy | Failure-drill example |
| Capability | typed Actions, tool allowlists, `prepare_action/3` policy hooks, effect policies, quotas | Deny/allow example |
| Traceability | causal Signals, Signal Journal, correlated telemetry | Cross-restart causal-history + trace example |
| Failure response | supervision, retry, idempotency, state recovery, queue/quota limits | Recovery example per boundary |

Every "production" or "control" claim must name at least one lifecycle control and
one inspection control (`E02-T45`).

### Vocabulary canon (`E02-T10..T17`)

| Term | Definition |
|---|---|
| Agent | Immutable data (a struct) with explicit state and behavior. Not a process. |
| AgentServer | The process and lifecycle layer that runs an Agent under OTP supervision. |
| Action | A validated execution unit. Can be pure or effectful; do not claim all Actions are pure. |
| Signal | A structured event envelope and routing input. Not a generic message. |
| Directive | A description of a runtime-owned effect, kept outside the decision step. |
| runtime | The `AgentServer` and OTP lifecycle mechanism. Not the public product category. |
| ecosystem | The optional package set (AI, model access, memory, browser, observability, workflow, data, integrations). Not required. |
| Strategy / Plugin / Sensor / Thread / Memory | Defined in the glossary; one approved short definition each. |

Brand form for prose: **Jido**. Remove "Agent Jido," "JIDO," and lowercase prose
uses, or explain them (`E02-T17`).

### Claim boundaries (`E02-T34..T38`)

These words have one bounded meaning. Copy must not imply more.

| Term | Safe current meaning | Do not imply |
|---|---|---|
| Identity | Agent lifecycle/profile state and runtime correlation IDs | Authentication, IAM, verified human identity |
| Authorization | A fail-closed Plugin hook (`prepare_action/3`) + integration-specific policy | A complete RBAC/ABAC product |
| Audit | Optional durable causal Signal history plus application records | Automatic coverage, tamper evidence, retention, compliance |
| Observability | Jido telemetry, correlated spans, metrics, logs, optional OTel export | Durable audit evidence or automatic incident response |
| Policy | Action, tool, effect, prompt, quota, and integration control points | Central policy administration across every package |
| Production | Explicit lifecycle, failure, policy, and inspection mechanisms with tested examples | No downtime, complete safety, compliance |

### Integration posture (`E02-T43`)

Jido integrates with IAM, policy, storage, SIEM, and telemetry systems; it does
not replace them. Authentication is an application/platform boundary, not
something Jido performs by itself (`E07-T36`).

### Claim policy and proof levels (`E02-T18..T22`)

- **Restricted (reject unless an approved proof reference is cited):**
  self-healing, no downtime, uptime guarantees, observe everything, secure by
  default, compliance-ready, enterprise governance, complete audit trail.
- **Proof-required (needs named evidence):** production-grade, production-ready,
  production-proven.
- **Definition-required (must define scope, controls, stop conditions):**
  autonomous.
- **Qualifier (name the tested behavior or package maturity):** reliable,
  recover, durable, scale, safe, tracing, identity-aware, authorized, auditable,
  governed, controlled.

Proof levels: (1) design intent, (2) tested behavior, (3) benchmark,
(4) production evidence. Each claim should name its level (`E02-T22`,
`specs/proof.md`).

### Control contrast and audience (`E02-T40..T42`)

Jido provides explicit control points; do not describe other frameworks as
unsafe. A secondary control-evaluation audience (platform, SRE, security,
regulated environments) follows the proof route in `specs/persona-journeys.md`,
secondary to Elixir builders.
