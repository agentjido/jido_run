# Production Case-Study Template

Status: Template (`jido-e11`, E11-T01/T02/T21/T22). Last updated: 2026-07-23.

Copy this template for each published case study. A study is not promotion —
it is qualified evidence. Every operational claim must be approved by the
project owner (E11-T02) and must stay inside the claim boundaries in
`specs/positioning.md` Section 11.

## Required fields

- **Project & owner:** name, team, public link (if any), and the person who
  approved the operational claims.
- **What they built:** the agent system in one paragraph.
- **Jido relationship:** state explicitly whether this uses the Jido runtime
  (`AgentServer`, Actions, Signals), adjacent packages only (e.g., ReqLLM), or
  Jido-inspired patterns (E11-T10/T11). Do not overstate Jido adoption.
- **Architecture:** a diagram showing ingress, Agent/AgentServer, store,
  provider, telemetry, and external effects.
- **Runtime profile:** how long it has run, single-node or cluster, and load
  (requests/time, concurrent agents) with the measurement window.
- **Package versions and support levels:** every Jido package used, with
  version and Stable/Beta/Experimental label.
- **Failure policy:** restart strategy, persistence, retry/idempotency, and
  what happens on provider failure.
- **Measured outcome:** the result that matters to the team, with method.
- **What did not work:** at least one tradeoff or failure (E11-T08).

## Operational-control fields (E11-T21/T22)

A controlled-agent study must separate these — none may stand in for another:

- **Identity source:** where the principal/tenant comes from (application/auth
  boundary), and confirmation that Agent/Signal IDs are correlation, not auth.
- **Authorization point:** the `prepare_action/3` (or equivalent) decision and
  what policy source it consults.
- **Policy:** tool/effect/prompt/quota controls configured.
- **Retained history:** the durable Signal Journal adapter, retention, and
  access control.
- **Observation path:** telemetry capture, redaction, and optional OTel export.
- **One denied-operation story (E11-T24):** what was denied, where, and how an
  operator found the evidence.
- **One incident/recovery story (E11-T25):** how supervision, causal history,
  telemetry, and operator action connected.

## Claim-approval section (E11-T02/T27)

- Operational claims reviewed with the evidence owner: ☐
- No unsupported security/compliance/tamper-evidence/complete-control language: ☐
- Benchmark and timing claims cite this study's method or are removed: ☐

## What this template is not

Filling it out with illustrative (non-real) numbers is not allowed. If a field
cannot be backed by real evidence, mark it "not yet measured" rather than
estimate. A study with mostly "not yet measured" fields is not ready to publish.
