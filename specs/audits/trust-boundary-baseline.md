# Trust Boundary Review Baseline

Status: Living baseline, refreshed after each threat-and-control model review
(`jido-e12-t50`). Records, for every documented trust boundary in
`specs/operations-reference-architecture.md`, the content signature captured at its last review
and the last-reviewed date.

When the reference architecture changes a boundary so its current signature
no longer matches the signature recorded here, the boundary is **changed**
and `AgentJido.ThreatControlModel.review_queue/1` creates a documentation
and proof review — the reviewer re-reads the documented boundary and
re-verifies the operational-control proof claims that depend on it.

After a review, regenerate this file with
`AgentJido.ThreatControlModel.to_baseline_markdown/1`.


## Authentication boundary
- **Signature:** authentication is an application or platform boundary **in front of** jido, not something jido performs. the reference path splits identity handling into three stages, and only the middle one is jido's: | stage | who owns it | what happens | |---|---|---| | **authenticate** | application / platform (outside jido) | verify the caller — human or service — and issue a verified principal | | **carry** | jido | the incoming `signal` carries that principal on `signal.source` (with tenant/request/causation context); jido propagates it but never verifies it | | **authorize** | application policy via jido's hook | `prepare_signal/2` / `prepare_action/3` decide allow or deny against the application's policy; **fail-closed** | ```mermaid flowchart lr subgraph outside["application / platform — outside jido"] c([caller: user or service]) auth["authentication and iam\nverifies identity, issues principal"] end c --> auth auth -->|"verified principal\n(application-supplied)"| sig subgraph jido["jido — carries and honors the principal, never verifies it"] sig["incoming signal\nsource: principal"] ps["prepare_signal/2\nverify/enrich context"] pa["prepare_action/3\nfail-closed policy"] act["action then effect"] sig --> ps --> pa --> act end act -.->|"principal and correlation\nin telemetry and journal"| obs([operator]) ``` the controlled-agent demo's allowlist (`source in ["alice"]`) is the **authorize** stage — a policy decision, not a login. `alice` is a principal the boundary in front of jido already authenticated; the hook only decides whether that principal may run the action. **jido does not authenticate a user or service by itself.** see `/docs/operations/security-and-governance` for the full claim-boundary model.
- **Last reviewed:** 2026-07-27

## Recovery boundaries
- **Signature:** a long-running agent recovers across four distinct restart boundaries. they differ by **what dies** and **what survives**, so each has its own automated test in the reference app (`jido-e07-t33`: "each recovery boundary has an automated or repeatable test"): | boundary | what dies | what survives | automated test | |---|---|---|---| | process | the `agentserver` process only | identity — a surviving parent supervisor restarts it; in-memory state is lost | `:supervision` | | application | the running agent; required state is replayed from a store on boot | checkpointed state (`hibernate`/`thaw` round-trip) | `:persistence` | | node | the entire beam, including the in-memory store's owning process | only durable (disk-backed) state; in-memory state is lost | `:node_restart` | | deployment | the whole deployment tree — no surviving parent | resumed state when a checkpoint is restored; otherwise a safe restart at the initial state | `:deployment` | process and deployment restarts share a supervisor but sit at different levels: a process restart leaves the supervisor (and the in-memory store's owner in `jido.supervisor`) alive, so the same in-memory checkpoint that **resumes** across a deployment restart is **lost** across a node restart — node restart kills the owner too. that is why the node boundary needs a durable (disk-backed) store, and why the reference app exposes both media (`persistence.storage_config(:memory | :durable)`) plus `persistence.simulate_node_restart/1` to make the loss observable in one test process.
- **Last reviewed:** 2026-07-27

## What stays outside Jido
- **Signature:** authentication, identity, audit, durable retention, and compliance are application or platform duties in front of and around jido — jido carries and honors a principal but never verifies one. see the explicit non-goals below and `/docs/operations/security-and-governance`.
- **Last reviewed:** 2026-07-27

## Threat and control model
- **Signature:** | asset | threat | control | |---|---|---| | tools/effects | unauthorized or runaway work | `prepare_action/3` allowlist + quotas | | cost | runaway tokens/requests | token/request/tool quotas | | provider keys | leakage | runtime config + redaction | | state | loss on restart | persistence + idempotency | | causal history | loss/gap | durable journal + retention | | visibility | hidden failure | telemetry + health checks + incident playbooks |
- **Last reviewed:** 2026-07-27

## Explicit non-goals
- **Signature:** the reference path does **not** claim: complete iam, complete audit, compliance certification, tamper-evident history, or no downtime. authentication, durable retention, and compliance stay outside jido (see `/docs/operations/security-and-governance`).
- **Last reviewed:** 2026-07-27

