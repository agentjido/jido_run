%{
  description: "Who owns the durable Signal Journal's retention, access, sensitive fields, and deletion — and what Jido ships (an adapter surface) versus what the application owns (everything else).",
  title: "Journal Retention, Access, and Deletion",
  category: :docs,
  legacy_paths: [],
  tags: [:docs, :operations],
  order: 371,
  draft: false
}
---
# Journal Retention, Access, and Deletion

A durable Signal Journal is how a long-running agent keeps causal history that survives a restart: who initiated work, which signals caused which, and what an Action did in response. When you configure one, it records the full Signal, and that record is now **data with a lifecycle** — it has an owner, a duration, sensitive fields, and a deletion process. This page states each of those four duties and, for each one, who owns it: Jido or your application.

The central honesty point: **Jido ships the Journal *adapter* surface and the record/query API. It ships no retention policy, no access control, no redaction, and no signal-deletion path.** Everything that governs the recorded history — how long it lives, who may read it, which fields are sensitive, and how it is removed — is an application or platform duty in front of and around the Journal. Treat that as a feature: the right retention, access, and deletion rules are a property of your data classification and your compliance regime, not the framework's. Then define them anyway.

| Duty | What Jido supplies | What the application/platform owns |
|---|---|---|
| **Owner** | the durable Journal *adapter* surface (`InMemory`, `ETS`, `Mnesia`) and the `record`/`query` API | deciding to keep history at all; the storage and compliance regime around it |
| **Duration** | `query/2` time filters (`after`/`before`) | the retention window, the prune/compaction job, and any legal hold |
| **Access** | none — the adapter is a read/write store | authentication, authorization, tenant isolation, and export controls on the store |
| **Sensitive fields** | none — the Journal records the full Signal verbatim | redaction rules, applied before recording or enforced at the store |
| **Deletion** | `delete_checkpoint`, `delete_dlq_entry`, `clear_dlq` (dead-letter and checkpoint only) | deleting recorded Signals at the storage layer, under governed process |

The default is **not durable**. A freshly built `Jido.Signal.Journal` over the `InMemory` adapter retains nothing across a restart; choosing the `ETS` adapter keeps history across a journal restart, and `Mnesia` (disc-backed) keeps it across a node restart. See the durable-history step in [Operational Controls](/docs/getting-started/operational-controls) for the adapter choice, and [Telemetry and Traces](/docs/operations/telemetry-and-traces) for why observation is a different concern from durable history.

## Owner: the application, not Jido

The owner of the recorded history is your application or platform, not Jido. Jido's role is narrow: it gives you the durable Journal adapter surface and the API to write to and read from it. The moment you choose to keep causal history, every duty around that history — storage, access control, retention, export, deletion, and compliance — moves to the side of the line your application owns.

This matches the audit claim boundary in [Security and Governance](/docs/operations/security-and-governance): Jido supplies an *optional* durable Signal Journal when you configure one; your application owns the retention, access control, tamper evidence, export, and compliance around it. Concretely, that means:

- **The adapter choice is yours.** `InMemory` (default, not durable), `ETS` (durable across a journal restart), or `Mnesia` (durable across a node restart). The durability you get is exactly the durability you choose.
- **The store is yours.** The Mnesia schema, disc paths, backups, and replication are application-owned. The Journal does not manage its own operational lifecycle.
- **Compliance is yours.** Whether the recorded history satisfies a regulatory or contractual record-keeping requirement is a property of how you deployed and governed the store, not of Jido.

The Journal is causal-history storage. It is **not** an audit-of-record, and a tamper-evident, append-only audit store is an explicit non-goal (see [Deletion process](#deletion-process) below and the reference architecture's non-goals).

## Duration: none is shipped

Jido ships **no retention policy, no time-to-live, and no compaction.** The Journal API has no retention knob, and the adapters expose no expiry. A freshly started durable journal keeps every Signal you record, indefinitely, until you delete it or the underlying store is destroyed.

What Jido gives you for time-bounded queries is the `Jido.Signal.Journal.query/2` filter set — `after` and `before` let you select Signals inside a time window, alongside `type` and `source` filters. That is a read filter, not a retention rule: `query/2` returns the aged Signals; it does not remove them. Enforcing a retention duration is application code:

- **Pick a window.** Decide the retention duration for each class of history (for example, 30 or 90 days) from your data-classification and compliance rules — not from Jido.
- **Prune on a schedule.** Run an application-owned job that calls `query/2` with a `before` cutoff and deletes the returned Signals at the storage layer (see [Deletion process](#deletion-process)). The Journal does not run this for you.
- **Hold what you must.** Legal-hold and WORM (write-once, read-many) semantics — object lock, time-bucketed tables, an immutable export store — are application-owned. The Mnesia disc store is mutable and freely rewriteable.

Two honesty points finish the duration duty:

- **The window is not enforced by existence.** A Journal left unattended grows without bound. Retention is something you do, not something Jido does.
- **A restart does not age data.** Durability and retention are independent: a disc-backed Mnesia journal survives a node restart *and* keeps everything, forever, unless you prune.

## Sensitive fields

A recorded Signal is the full event, persisted verbatim. Several of its fields are operationally sensitive, and the Journal redacts **none** of them. Treat these fields as needing protection before recording or at the store:

| Field | What it carries | Why it is sensitive |
|---|---|---|
| `source` | the authenticated principal / caller identity (and any user id carried) | re-identifies who initiated the work |
| `data` | the payload — prompts, tool arguments and results, request/response bodies | may contain PII, credentials, or secrets passed through |
| `extensions` | tenant, request, correlation, and causation ids | re-identify a user, tenant, or single unit of work across components |
| `subject` | the conversation or entity key | groups a thread of identifiable activity |

Redaction is an application-defined rule. [Security and Governance](/docs/operations/security-and-governance) names redaction over "logs, telemetry, Journal entries, and error output" as a control point you wire up — so the same rules that redact a tool result in telemetry must also redact it before it reaches the Journal. The practical options:

- **Redact before recording.** Strip or mask the sensitive fields on the Signal (or its `data` payload) before `Journal.record/3`, so the durable copy never holds them.
- **Gate at the store.** If you must record the raw event, enforce read access, tenant isolation, and field-level encryption at the storage layer, because the Journal will hand back exactly what you wrote.

This is why the Journal cannot serve as an audit-of-record on its own: it stores what it is given, including sensitive data, with no tamper evidence and no built-in access control. Pair it with the redaction rule above and the access controls in [Owner](#owner-the-application-not-jido) before relying on it for governed work.

## Deletion process

Deleting recorded causal history is an application-owned process, because **Jido's Journal ships no `delete_signal` API.** The only deletion surfaces the adapters provide operate on the dead-letter queue and subscription checkpoints, not on recorded Signals:

- `delete_checkpoint/2` — drops a subscription's replay checkpoint.
- `delete_dlq_entry/2` and `clear_dlq/2` — remove dead-letter entries (see [Poison Work and Dead-Letter Handling](/docs/operations/poison-work-and-dead-letter), where the DLQ *does* have a governed delete surface).

There is no callback in the Journal persistence behaviour for removing a recorded Signal. To delete history, work at the storage layer under your own governed process:

1. **Select what to remove.** Use `Jido.Signal.Journal.query/2` (by `before` time, `type`, or `source`) to find the Signals to delete.
2. **Delete at the store.** Remove the rows directly — drop the Mnesia rows for those ids, recreate the ETS table, or rebuild the store — because the Journal offers no record-level delete call.
3. **Govern the deletion.** Record who deleted what, when, and under what authority, in a separate system. The Journal is mutable and freely rewriteable, so it cannot attest to its own deletion history.

A tamper-evident, append-only audit store is an **explicit non-goal.** Jido does not provide immutable history, cryptographic chaining of records, or proof that a recorded Signal was never altered or removed. If your workload requires that, layer an append-only, WORM, or hash-chained store of your own in front of or alongside the Journal — and keep the deletion governance outside the mutable Journal entirely.

## What the Journal does not do

These duties are real, but the Journal does not, by itself:

- **Enforce its own retention.** There is no TTL. A journal left alone keeps everything you record.
- **Control its own access.** There is no authentication or authorization on the adapter; any caller with the struct can read it.
- **Redact its own contents.** Sensitive fields are recorded verbatim unless you redact before recording.
- **Delete its own records.** No `delete_signal` exists; only checkpoint and dead-letter deletion ship.
- **Attest to its own integrity.** No tamper evidence, no append-only guarantee — it is mutable causal-history storage, not an audit-of-record.
- **Serve as a tamper-evident audit trail.** That is an explicit non-goal, owned by the application or platform around the Journal.

## Next steps

- Read the full claim-boundary model — including the audit row this page deepens — in [Security and Governance](/docs/operations/security-and-governance).
- Separate durable history from observation in [Telemetry and Traces](/docs/operations/telemetry-and-traces): telemetry is for understanding, the Journal is for causal history, and neither is an audit log.
- See the one place a governed delete surface *does* ship in [Poison Work and Dead-Letter Handling](/docs/operations/poison-work-and-dead-letter).
- Choose the adapter and confirm every duty is wired before go-live in the [Production Readiness Checklist](/docs/operations/production-readiness-checklist).
