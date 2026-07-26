# Jido Proof Inventory

Version: 2.0  
Last updated: 2026-07-23  
Positioning anchor: `Jido is the Elixir framework for long-running agent systems.` (`jido-e02`)
Primary inputs: `specs/positioning.md` §11 (Canon), `specs/audits/control-inventory-2026-07-23.md`

> **Refresh (2026-07-23):** Operations content is now published — incident playbooks, production-readiness checklist, and security-and-governance are live under `/docs/operations`. Retired `/training/*` modules are no longer proof assets; link to the Operations pages instead. See the Control Proof section for the operational-control claim fields (`jido-e02` T28/T44).

> **Purpose:** Map every positioning claim to concrete, verifiable proof. If a cell is empty, the claim is unsupported. Fill this in before publishing any major page.
>
> **Rule from positioning.md §8:** Every pillar must reference at least one package, one runnable example, and one training module.

---

## Pillar 1: Reliability by Architecture

> _Core message: Agents should fail safely and recover predictably._

| Proof type | Asset name / description | Location | Status | Notes |
|---|---|---|---|---|
| Training module | Agent Fundamentals — lifecycle, supervision basics | `priv/pages/training/agent-fundamentals.md` | 🟡 partial | TODO: Confirm failure-recovery coverage depth |
| Training module | Production Readiness — operational hardening | `priv/pages/training/production-readiness.md` | 🟡 partial | TODO: Does it include failure drill walkthroughs? |
| Runnable example | Counter Agent — basic agent lifecycle demo | `lib/agent_jido/demos/counter/counter_agent.ex` | ✅ exists | Needs review: does it demo crash/restart? |
| Content plan brief | Supervision and Fault Isolation feature page | `priv/content_plan/features/reliability-by-architecture.md` | 🟡 partial | Brief exists; page not built |
| Content plan brief | Retries, Backpressure, and Failure Recovery | `priv/content_plan/docs/guides/retries-backpressure-and-failure-recovery.md` | 🟡 partial | Brief exists; page not built |
| Content plan brief | Incident Playbooks | `priv/content_plan/docs/operations/incident-playbooks.md` | 🟡 partial | Brief exists; page not built |
| Content plan brief | Production Readiness Checklist | `priv/content_plan/docs/operations/production-readiness-checklist.md` | 🟡 partial | Brief exists; page not built |
| Ecosystem doc | `jido` core package — supervision primitives | `priv/ecosystem/jido.md` | ✅ exists | TODO: Verify supervision API coverage |
| Runnable example | **Failure drill demo** — kill agent, watch OTP restart it | `priv/examples/failure-drill-agent.md` + `test/agent_jido/demos/failure_drill_agent_test.exs` | ✅ exists | Proves restart behavior without claiming state recovery: the in-memory counter resets to 0 after the supervisor restarts the process (`jido-e08-t17`). Companion operations guide: `priv/pages/docs/operations/process-crash-and-restart.md` |
| Runnable example | **Provider timeout and fallback** — bounded retries + a defined fallback rule | `lib/agent_jido/demos/provider_timeout_fallback/provider_timeout_fallback.ex` + `test/agent_jido/demos/provider_timeout_fallback_test.exs` | ✅ exists | Proves a degrading LLM provider fails safely: a retryable error (timeout/rate-limit/transient 5xx) is retried a **bounded** number of times with backoff (never unbounded — the budget exhausts at `max_attempts`), then a **defined fallback rule** fires (cheaper model / cached result / safe default, tagged `source: :fallback`; or `:fail` to fail the Signal). Terminal errors (auth/refusal) skip retry and fire the fallback immediately (`jido-e08-t21`). Companion operations page: `priv/pages/docs/operations/provider-timeout-and-fallback.md` |
| Runnable example | **Long-running scheduled worker** — Schedule + persistence + restart recovery in one supervised agent | `lib/agent_jido/demos/long_running_reference/` + `test/agent_jido/demos/long_running_reference_test.exs` | ✅ exists | The integrated production case that combines all three concerns in one agent at the same time (`jido-e08-t22`): **Schedule** — the agent declares a `*/1 * * * *` CRON schedule routed to `reference.cron`, and a scheduled tick advances `cron_ticks`; **persistence** — `Persistence` wraps `Jido.Persist.hibernate/thaw` over an ETS store, so a checkpoint round-trips `processed` and `seen_work` and survives a restart; **restart recovery** — the supervisor restarts a killed `:permanent` AgentServer under the same id (a new pid), and a deployment restart resumes from the checkpoint. Reference architecture: `specs/operations-reference-architecture.md`; the four recovery boundaries are gated by `test/agent_jido/specs/recovery_boundary_matrix_test.exs`. |
| Runnable example | **Complete Phoenix application** — local Agent use to a deployed release | `rel/overlays/bin/server` + `Dockerfile` + `rel/env.sh.eex` + `config/runtime.exs` + `test/agent_jido/specs/phoenix_deployment_proof_test.exs` | ✅ exists | The workbench is itself a complete Phoenix 1.8 application, so an agent moves from **local Agent use** to a **deployed application path** unchanged: the same interactive examples served by `mix phx.server` (e.g. the failure-drill LiveView, `priv/examples/failure-drill-agent.md`, `jido-e08-t17`) run in the production release — `rel/overlays/bin/server` sets `PHX_SERVER=true` and starts `./agent_jido start` (honored by `config/runtime.exs`), the multi-stage `Dockerfile` builds the release (`mix release`) and packages it as a runnable image, and `rel/env.sh.eex` wires `RELEASE_NODE` from the `FLY_*` env for Fly.io deployment. This is the "deploy" step of the long-running linear path (`specs/operations-reference-architecture.md`); the Jido PHX Starter is the second main target (`priv/pages/docs/getting-started/phoenix-starter.md`). (`jido-e08-t23`) |
| Operational demo | **Supervision tree visualization** — LiveDashboard showing agent restarts | _TODO: create_ | ❌ missing | Could use `jido_live_dashboard` |
| Code snippet | Supervisor config for multi-agent tree | _TODO: create or extract_ | ❌ missing | Short, copy-pasteable snippet |
| Reference doc | **Production runbook** — restart procedures, escalation paths | _TODO: create_ | ❌ missing | Maps to SRE persona need |
| Architecture diagram | Agent supervision tree diagram | _TODO: create_ | ❌ missing | Visual proof for architect persona |

### Pillar 1 — Package coverage check

| Package | Role in this pillar | Proof referenced above? |
|---|---|---|
| `jido` | Core supervision, agent lifecycle | ✅ |
| `jido_live_dashboard` | Supervision visibility | ❌ TODO: create demo |
| `jido_flame` | Elastic scaling under failure | ❌ TODO: document |

---

## Pillar 2: Multi-Agent Coordination You Can Reason About

> _Core message: Complex agent behavior should be explicit and testable._

| Proof type | Asset name / description | Location | Status | Notes |
|---|---|---|---|---|
| Training module | Signals & Routing — inter-agent communication | `priv/pages/training/signals-routing.md` | ✅ exists | TODO: Confirm multi-agent scenario coverage |
| Training module | Directives & Scheduling — orchestration patterns | `priv/pages/training/directives-scheduling.md` | ✅ exists | TODO: Confirm testability examples |
| Training module | Actions & Validation — typed capability model | `priv/pages/training/actions-validation.md` | ✅ exists | |
| Runnable example | Demand Tracker Agent — multi-step workflow | `lib/agent_jido/demos/demand/demand_tracker_agent.ex` | ✅ exists | TODO: Does it show multi-agent coordination? |
| LiveView example | Demand Tracker LiveView | `lib/agent_jido_web/examples/demand_tracker_agent_live.ex` | ✅ exists | Interactive proof |
| Content plan brief | Signal Routing and Coordination feature page | `priv/content_plan/features/multi-agent-coordination.md` | 🟡 partial | Brief exists; page not built |
| Content plan brief | Directives and Scheduling feature page | `priv/content_plan/docs/learn/directives-scheduling.md` | 🟡 partial | Brief exists; page not built |
| Content plan brief | Multi-Agent Workflows build guide | `priv/content_plan/docs/learn/multi-agent-workflows.md` | 🟡 partial | Brief exists; page not built |
| Content plan brief | Schema-Validated Actions feature page | `priv/content_plan/docs/learn/actions-validation.md` | 🟡 partial | Brief exists; page not built |
| Ecosystem doc | `jido_signal` — signal routing primitives | `priv/ecosystem/jido_signal.md` | ✅ exists | |
| Ecosystem doc | `jido_action` — typed action model | `priv/ecosystem/jido_action.md` | ✅ exists | |
| Runnable example | **Signal routing demo** — two agents passing structured signals | `lib/agent_jido/demos/signal_trace/` + `test/agent_jido/demos/signal_trace_test.exs` | ✅ exists | Proves a Signal trace across two Agents: Agent A (`EmitterAgent`) emits a `work.ready` cause, Agent B (`FulfillmentAgent`) routes it to `FulfillAction` and records the result. The trace shows all four legs — cause, route, Action, result (`jido-e08-t19`). |
| Runnable example | **Directive composition demo** — chain/parallel/conditional | _TODO: create_ | ❌ missing | Shows "reasonability" claim |
| Operational demo | **Workflow trace visualization** — step-by-step signal/action flow | _TODO: create_ | ❌ missing | Could pair with telemetry pillar |
| Code snippet | Signal schema definition + dispatch example | _TODO: create or extract_ | ❌ missing | |
| Code snippet | Directive definition with test assertion | _TODO: create or extract_ | ❌ missing | Proves "testable" claim directly |
| Architecture diagram | Multi-agent signal flow diagram | _TODO: create_ | ❌ missing | |

### Pillar 2 — Package coverage check

| Package | Role in this pillar | Proof referenced above? |
|---|---|---|
| `jido_signal` | Signal routing | ✅ |
| `jido_action` | Typed actions | ✅ |
| `jido` | Directives, strategies | ✅ |
| `jido_behaviortree` | Complex decision flows | ❌ TODO: create example |
| `jido_runic` | Rule-based coordination | ❌ TODO: create example |

---

## Pillar 3: Production Operations and Observability

> _Core message: Real systems need telemetry, debugging workflows, and controls._

| Proof type | Asset name / description | Location | Status | Notes |
|---|---|---|---|---|
| Training module | Production Readiness — ops hardening | `priv/pages/training/production-readiness.md` | ✅ exists | TODO: Verify telemetry content depth |
| Runnable example | Counter Agent LiveView — live operational surface | `lib/agent_jido_web/examples/counter_agent_live.ex` | ✅ exists | TODO: Does it show telemetry/metrics? |
| Content plan brief | Production Telemetry feature page | `priv/content_plan/features/operations-observability.md` | 🟡 partial | Brief exists; page not built |
| Content plan brief | Troubleshooting and Debugging Playbook | `priv/content_plan/docs/guides/troubleshooting-and-debugging-playbook.md` | 🟡 partial | Brief exists; page not built |
| Content plan brief | Mixed-Stack Runbooks | `priv/content_plan/docs/guides/mixed-stack-runbooks.md` | 🟡 partial | Brief exists; page not built |
| Content plan brief | Testing Agents and Actions | `priv/content_plan/docs/guides/testing-agents-and-actions.md` | 🟡 partial | Brief exists; page not built |
| Content plan brief | Security and Governance | `priv/content_plan/docs/operations/security-and-governance.md` | 🟡 partial | Brief exists; page not built |
| Content plan brief | Long-Running Agent Workflows | `priv/content_plan/docs/guides/long-running-agent-workflows.md` | 🟡 partial | Brief exists; page not built |
| Ecosystem doc | `jido_live_dashboard` — agent dashboard plugin | `priv/ecosystem/jido_live_dashboard.md` | ✅ exists | Key proof package |
| Operational demo | **Dashboard instrumentation walkthrough** — metrics, counters, traces | _TODO: create_ | ❌ missing | Highest-priority proof for this pillar |
| Operational demo | **Trace narrative** — "follow a request through 3 agents" | _TODO: create_ | ❌ missing | Story-driven proof |
| Runnable example | **OpenTelemetry export** — verified OTel trace via the `jido_otel` bridge | `lib/agent_jido/demos/open_telemetry_export/` + `test/agent_jido/demos/open_telemetry_export_test.exs` | ✅ exists | States **Experimental** maturity and exports a verified trace: a `Jido.Observe.Tracer` bridge (the contract `jido_otel` consumes) is wired as the configured tracer, one unit of work runs through `Jido.Observe`, and the bridge exports one shared-trace-id, parent-linked span tree with OTel span names and attributes. `jido_otel` is unreleased/Experimental, so the bridge ships in the demo rather than as a hard dependency (`jido-e08-t20`). |
| Reference doc | **SRE checklist** — deploy, monitor, alert, respond | _TODO: create_ | ❌ missing | Maps to SRE persona |
| Reference doc | **Telemetry event catalog** — all emitted events, fields, units | _TODO: create_ | ❌ missing | Reference-grade proof |
| Code snippet | `:telemetry` handler setup for agent events | _TODO: create or extract_ | ❌ missing | |
| Code snippet | LiveDashboard configuration for agent metrics | _TODO: create or extract_ | ❌ missing | |
| Architecture diagram | Observability stack diagram (app → telemetry → dashboard/export) | _TODO: create_ | ❌ missing | |

### Pillar 3 — Package coverage check

| Package | Role in this pillar | Proof referenced above? |
|---|---|---|
| `jido_live_dashboard` | Agent visibility | ✅ |
| `jido` | Telemetry emission | 🟡 implied, needs explicit proof |
| `jido_shell` | Interactive debugging | ❌ TODO: create example |
| `jido_sandbox` | Safe execution environment | ❌ TODO: document |

---

## Pillar 4: Composable Ecosystem with Incremental Adoption

> _Core message: Adopt only what you need now, expand safely later._

| Proof type | Asset name / description | Location | Status | Notes |
|---|---|---|---|---|
| Training module | Agent Fundamentals — minimal starting point | `priv/pages/training/agent-fundamentals.md` | ✅ exists | |
| Training module | LiveView Integration — layer on UI | `priv/pages/training/liveview-integration.md` | ✅ exists | Shows incremental adoption path |
| Content plan brief | Installation quickstart | `priv/content_plan/docs/learn/installation.md` | 🟡 partial | Brief exists; page not built |
| Content plan brief | First Agent guide | `priv/content_plan/docs/learn/first-agent.md` | 🟡 partial | Brief exists; page not built |
| Content plan brief | Quickstarts by Persona | `priv/content_plan/docs/learn/quickstarts-by-persona.md` | 🟡 partial | Brief exists; page not built |
| Content plan brief | Composable Ecosystem feature page | `priv/content_plan/features/incremental-adoption.md` | 🟡 partial | Brief exists; page not built |
| Content plan brief | Mixed-Stack Integration build guide | `priv/content_plan/docs/learn/mixed-stack-integration.md` | 🟡 partial | Brief exists; page not built |
| Content plan brief | Reference Architectures | `priv/content_plan/docs/learn/reference-architectures.md` | 🟡 partial | Brief exists; page not built |
| Ecosystem docs | Full ecosystem package documentation | `priv/ecosystem/*.md` (19 packages) | ✅ exists | Foundation for package matrix |
| Reference doc | **Package matrix** — what each package does, dependencies, adoption order | _TODO: create_ | ❌ missing | Central proof for this pillar |
| Runnable example | **Minimal-stack quickstart** — `jido` only, no AI, no LiveView | _TODO: create_ | ❌ missing | Proves "adopt only what you need" |
| Runnable example | **Progressive adoption demo** — start with 1 package, add 3 more | _TODO: create_ | ❌ missing | Story-driven proof |
| Reference doc | **Migration guide** — from prototype to production-grade setup | _TODO: create_ | ❌ missing | Staff architect persona need |
| Reference doc | **Dependency map** — visual of which packages depend on which | _TODO: create_ | ❌ missing | |
| Architecture diagram | Ecosystem layer diagram (core → intelligence → tools → integrations) | _TODO: create_ | ❌ missing | Matches §8 structure |

### Pillar 4 — Package coverage check

| Package | Role in this pillar | Proof referenced above? |
|---|---|---|
| `jido` | Core, minimal starting point | ✅ |
| `jido_ai` | Intelligence layer add-on | 🟡 ecosystem doc exists, needs quickstart |
| `jido_action` | Standalone action package | 🟡 ecosystem doc exists, needs quickstart |
| `ash_jido` | Ash integration path | ❌ TODO: create adoption example |
| `jido_messaging` | Event bus integration | ❌ TODO: create adoption example |
| `agent_jido` | Full workbench reference app | ✅ (this repo is the proof) |

---

## Cross-Cutting Proof

These assets support multiple pillars and multiple personas simultaneously.

| Proof type | Asset name / description | Location | Status | Notes |
|---|---|---|---|---|
| Content plan brief | BEAM for AI Builders — why Elixir/OTP matters | `priv/content_plan/features/beam-for-ai-builders.md` | 🟡 partial | Brief exists; page not built |
| Content plan brief | Executive Brief — decision-maker overview | `priv/content_plan/features/executive-brief.md` | 🟡 partial | Brief exists; page not built |
| Content plan brief | Jido vs Framework-First Stacks | `priv/content_plan/features/jido-vs-framework-first-stacks.md` | 🟡 partial | Brief exists; page not built |
| Reference doc | **Why BEAM comparison** — Elixir/OTP vs Python/Node runtime semantics | _TODO: create_ | ❌ missing | Python AI engineer persona |
| Runnable example | **Mixed-stack integration demo** — Jido backend + JS/Python client | _TODO: create_ | ❌ missing | TS fullstack + Python personas |
| Reference doc | **Migration-without-rewrite playbook** — adopt Jido alongside existing stack | _TODO: create_ | ❌ missing | Staff architect persona |
| Reference doc | **API boundary spec** — REST/gRPC/WebSocket surface for non-Elixir clients | _TODO: create_ | ❌ missing | Polyglot persona proof |
| Content plan brief | Product Feature Blueprints | `priv/content_plan/docs/learn/product-feature-blueprints.md` | 🟡 partial | Brief exists; page not built |
| Content plan brief | AI Chat Agent build guide | `priv/content_plan/docs/learn/ai-chat-agent.md` | 🟡 partial | Brief exists; page not built |
| Ecosystem doc | `jido_ai` — AI/LLM integration layer | `priv/ecosystem/jido_ai.md` | ✅ exists | |
| Ecosystem doc | `req_llm` — unified LLM client | `priv/ecosystem/req_llm.md` | ✅ exists | |

---

## Persona-Specific Proof Requirements

_Sourced from positioning.md §7 — Persona-level promise map._

### 1. Elixir Platform Engineer

> Promise: "Agent systems aligned with OTP discipline"  
> First proof needed: Supervision and failure-pattern examples

| Required proof | Mapped to pillar | Asset exists? | Location |
|---|---|---|---|
| Supervision tree examples with agent processes | Pillar 1 | ❌ missing | _TODO_ |
| Failure-pattern catalog (crash, timeout, overload) | Pillar 1 | ❌ missing | _TODO_ |
| OTP-idiomatic agent design patterns | Pillar 1 + 2 | 🟡 partial | `priv/pages/training/agent-fundamentals.md` — needs review |
| LiveDashboard agent visibility | Pillar 3 | ❌ missing | _TODO: jido_live_dashboard demo_ |

### 2. AI Product Engineer

> Promise: "Ship AI features without runtime fragility"  
> First proof needed: End-to-end tool-calling examples

| Required proof | Mapped to pillar | Asset exists? | Location |
|---|---|---|---|
| End-to-end tool-calling example (LLM → action → result) | Pillar 2 | ❌ missing | _TODO_ |
| AI chat agent walkthrough | Pillar 2 + 4 | 🟡 partial | `priv/content_plan/docs/learn/ai-chat-agent.md` (brief only) |
| LiveView integration for AI features | Pillar 4 | ✅ exists | `priv/pages/training/liveview-integration.md` |
| `jido_ai` + `req_llm` quickstart | Pillar 4 | ❌ missing | _TODO_ |

### 3. Staff Architect / Tech Lead

> Promise: "Adoption path with governance and maintainability"  
> First proof needed: Reference architectures and migration playbooks

| Required proof | Mapped to pillar | Asset exists? | Location |
|---|---|---|---|
| Reference architecture document | Pillar 4 | 🟡 partial | `priv/content_plan/docs/learn/reference-architectures.md` (brief only) |
| Migration playbook (existing stack → Jido) | Pillar 4 | ❌ missing | _TODO_ |
| Package dependency / governance map | Pillar 4 | ❌ missing | _TODO_ |
| Executive brief | Cross-cutting | 🟡 partial | `priv/content_plan/features/executive-brief.md` (brief only) |

### 4. Python AI Engineer

> Promise: "Better runtime semantics for long-lived workloads"  
> First proof needed: Why-BEAM comparison and interoperability guide

| Required proof | Mapped to pillar | Asset exists? | Location |
|---|---|---|---|
| Why BEAM for AI — compared to Python runtime | Cross-cutting | 🟡 partial | `priv/content_plan/features/beam-for-ai-builders.md` (brief only) |
| Interoperability guide (Python ↔ Jido) | Cross-cutting | ❌ missing | _TODO_ |
| Performance/concurrency comparison (practical, not benchmarketing) | Cross-cutting | ❌ missing | _TODO_ |

### 5. TypeScript Fullstack Engineer

> Promise: "Stable backend for JS product surfaces"  
> First proof needed: API boundary and frontend integration examples

| Required proof | Mapped to pillar | Asset exists? | Location |
|---|---|---|---|
| API boundary examples (REST/WebSocket from JS client) | Cross-cutting | ❌ missing | _TODO_ |
| Mixed-stack integration guide | Cross-cutting | 🟡 partial | `priv/content_plan/docs/learn/mixed-stack-integration.md` (brief only) |
| Frontend ↔ agent communication patterns | Pillar 2 + 4 | ❌ missing | _TODO_ |

### 6. Platform / SRE Engineer

> Promise: "Operable system with clear SLO signals"  
> First proof needed: Telemetry model, runbooks, incident patterns

| Required proof | Mapped to pillar | Asset exists? | Location |
|---|---|---|---|
| Telemetry event catalog | Pillar 3 | ❌ missing | _TODO_ |
| Production runbooks | Pillar 1 + 3 | ❌ missing | _TODO_ |
| Incident pattern library | Pillar 3 | 🟡 partial | `priv/content_plan/docs/operations/incident-playbooks.md` (brief only) |
| SLO definition guide for agent systems | Pillar 3 | ❌ missing | _TODO_ |
| `jido_live_dashboard` SRE walkthrough | Pillar 3 | ❌ missing | _TODO_ |

---

## Summary Scorecard

| Pillar | Training modules | Runnable examples | Operational demos | Reference docs | Architecture diagrams |
|---|---|---|---|---|---|
| 1 — Reliability | 🟡 2 partial | 🟡 1 exists, 1 missing | ❌ 0 | ❌ 0 | ❌ 0 |
| 2 — Coordination | ✅ 3 exist | 🟡 1 exists, 2 missing | ❌ 0 | ❌ 0 | ❌ 0 |
| 3 — Operations | 🟡 1 partial | 🟡 1 exists | ❌ 0 | ❌ 0 | ❌ 0 |
| 4 — Composable | ✅ 2 exist | ❌ 0 purpose-built | ❌ 0 | ❌ 0 | ❌ 0 |

**Honest assessment:** Training module briefs and ecosystem docs provide a foundation, but there are zero operational demos, zero purpose-built reference docs, and zero architecture diagrams. The proof is light across every pillar. Content plan briefs exist for most gaps — the work is converting briefs into finished assets.

---

## Priority TODO List

_Ranked by positioning impact × effort._

1. ✅ **Failure drill demo** (Pillar 1) — Published as `failure-drill-agent`; proves restart without claiming state recovery (`jido-e08-t17`)
2. ✅ **Signal routing multi-agent demo** (Pillar 2) — Published as `signal_trace`; the trace shows cause, route, Action, and result across two Agents (`jido-e08-t19`)
3. ❌ **Dashboard instrumentation walkthrough** (Pillar 3) — Proves observability is real
4. ❌ **Package matrix** (Pillar 4) — Foundational reference for composability claim
5. ❌ **Minimal-stack quickstart** (Pillar 4) — Proves incremental adoption
6. ❌ **Why BEAM comparison** (Cross-cutting) — Unlocks Python/TS persona journeys
7. ❌ **Telemetry event catalog** (Pillar 3) — SRE persona table stakes
8. ❌ **Production runbook** (Pillar 1 + 3) — Operability proof
9. ❌ **Mixed-stack integration demo** (Cross-cutting) — Polyglot persona proof
10. ❌ **End-to-end tool-calling example** (Pillar 2) — AI product engineer entry point

---

_This document is a living inventory. Update status columns as assets are created. Every ❌ is a positioning claim without proof._

---

## Control Proof Fields (`jido-e02` T44, `jido-e12` T38)

Every operational-control claim names seven proof fields, all required before
the claim can back restricted control, security, or compliance copy:
**control point**, **configuration**, **test**, **limitation**, **owner**,
**version**, and **validation date**. Control proof does not use one concept
(e.g., telemetry) as proof of another (e.g., audit), and a claim whose `test`
points at a non-existent file is treated as unproven. This field set is enforced
in CI by `test/agent_jido/specs/operational_control_proof_test.exs`.

### Supervised lifecycle
- **Control point:** `Jido.AgentServer` linked under an OTP supervisor.
- **Configuration:** default OTP child spec; supervisor `restart: :permanent`.
- **Test:** `test/agent_jido/demos/controlled_agent_test.exs` (AgentServer starts linked with a stable identity and correlation IDs) and `test/agent_jido/demos/controlled_agent_persistence_test.exs` (approved state survives a restart).
- **Limitation:** Restart restores the process, not application state; persistence is application-supplied.
- **Owner:** Platform owner.
- **Version:** jido 2.3.2 (Stable).
- **Validation date:** 2026-07-24.

### Fail-closed authorization
- **Control point:** `Jido.Plugin.prepare_action/3` fail-closed hook plus `jido_ai` tool/effect allowlists.
- **Configuration:** plugin denies the protected Action when required principal/tenant context is missing; AI tool/effect policies configured.
- **Test:** `test/agent_jido/demos/controlled_agent_test.exs` (an unauthorized principal cannot run the protected Action) and `test/agent_jido/demos/tool_allowlist_agent_test.exs` (an allowlisted tool runs; a disallowed tool is denied before execution).
- **Limitation:** Integration point, not a built-in IAM/RBAC product; the application supplies the policy decision.
- **Owner:** Technical docs owner.
- **Version:** jido 2.3.2, jido_ai 2.2.0 (Stable hook; Beta AI policies).
- **Validation date:** 2026-07-24.

### Causal history
- **Control point:** durable `Jido.Signal.Journal` adapter.
- **Configuration:** explicit durable Journal adapter (ETS adapter under a fixed prefix in the test) plus an application-defined retention policy.
- **Test:** `test/agent_jido/demos/signal_journal_test.exs` (causal history is recorded and survives a journal restart against a durable store).
- **Limitation:** Default is not durable; retention/replay is application-defined; the Journal is not tamper-evident.
- **Owner:** Technical docs owner.
- **Version:** jido_signal 2.2.2 (durable only with an explicit adapter).
- **Validation date:** 2026-07-24.

### Correlated telemetry
- **Control point:** `Jido.Observe` / `Jido.Telemetry` correlated spans; optional `jido_otel` export.
- **Configuration:** `:telemetry` handlers attached to Action and lifecycle events.
- **Test:** `test/agent_jido/demos/redaction_test.exs` (action telemetry emits the action module only; a secret action param is excluded from metadata) and `test/agent_jido/demos/open_telemetry_export_test.exs` (the `jido_otel` bridge exports a verified trace — one shared trace id adopted from the incoming signal and one parent-linked span tree, Experimental maturity).
- **Limitation:** Telemetry is not an audit log; OTel export is Experimental.
- **Owner:** Platform owner.
- **Version:** jido 2.3.2 (Stable); jido_otel Experimental.
- **Validation date:** 2026-07-24.

### Cost/quota control
- **Control point:** `jido_ai` tool/effect/prompt/quota policies and AI budget directives.
- **Configuration:** per-agent token/request/tool budgets; the quota plugin rejects over-budget calls.
- **Test:** `test/agent_jido/demos/quota_control_agent_test.exs` (calls succeed up to the budget, then the next is rejected) and `test/agent_jido/demos/approval_boundary_agent_test.exs` (a high-impact effect waits for an explicit confirm decision).
- **Limitation:** The application sets the budgets; not a built-in spend-management product.
- **Owner:** Technical docs owner.
- **Version:** jido 2.3.2, jido_ai 2.2.0 (Beta AI policies).
- **Validation date:** 2026-07-24.

The unit tests above prove each control in isolation. The long-running reference
application (`specs/operations-reference-architecture.md`, built in `jido-e07-t29`)
is the end-to-end public proof: the seven documented failure drills run in one
command via `scripts/failure_drill.sh` (`jido-e07-t31`), each against its focused
test and then against the reference application end to end.
