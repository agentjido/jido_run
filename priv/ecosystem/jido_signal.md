%{
  name: "jido_signal",
  title: "Jido Signal",
  graph_label: "Jido Signal",
  version: "2.2.2",
  tagline: "CloudEvents-based event-driven communication toolkit for Elixir",
  license: "Apache-2.0",
  visibility: :public,
  category: :core,
  atlas_facet: :primitives,
  tier: 1,
  tags: [:signals, :events, :pubsub, :cloudevents],
  hex_url: "https://hex.pm/packages/jido_signal",
  hexdocs_url: "https://hexdocs.pm/jido_signal",
  github_url: "https://github.com/agentjido/jido_signal",
  github_org: "agentjido",
  github_repo: "jido_signal",
  tech_lead: "@mikehostetler",
  elixir: "~> 1.17",
  maturity: :stable,
  support_level: :stable,
  hex_status: "2.1.1",
  api_stability: "evolving — 2.0 shipped, but expect continued API refinements across early 2.x",
  stub: false,
  support: :maintained,
  limitations: [
    "Early 2.x hardening may still introduce focused breaking changes",
    "Journal persistence backends are pluggable but no production adapters ship by default"
  ],
  control_capabilities: [
    "Signal envelope and routing — CloudEvents-based signals with a trie router give deterministic, auditable dispatch.",
    "Optional durable history — a configured durable Signal Journal adapter records signals as a durable, replayable record of what happened. Trace context (causation and correlation IDs) links each record to the rest of a trace, but is correlation metadata from core observation, not the record itself."
  ],
  control_limitations: [
    "Does not retain history by default — the default Journal is not durable, so a recorded signal is gone after a restart unless you choose a durable adapter.",
    "Does not prove tamper-evidence or authenticated audit identity — the Journal is a replayable history store, not a tamper-evident ledger. Signal and trace IDs are correlation metadata, not a verified caller; tamper-evidence and audit identity are application-owned."
  ],
  ecosystem_deps: [],
  key_features: [
    "CloudEvents v1.0.2 compliant message envelope",
    "Trie-based router with O(k) segment matching and wildcards",
    "GenServer-based signal bus with pub/sub, history, and replay",
    "9 built-in dispatch adapters (PID, PubSub, HTTP, Webhook, etc.)",
    "Circuit breaker fault isolation per adapter type",
    "Persistent subscriptions with checkpointing and DLQ",
    "Middleware pipeline with 4 interception points",
    "Partitioned dispatch for horizontal scaling",
    "W3C-compatible distributed tracing",
    "Multi-format serialization (JSON, MessagePack, ETF)",
    "Instance isolation for multi-tenant deployments"
  ],
  landing_summary: "CloudEvents-based event-driven communication toolkit for Elixir",
  landing_use_when: ["You are building an agent and need the Agent model, validated Actions, Signals, Directives, and the OTP runtime."],
  landing_not_for: ["You only need a thin LLM call without an agent model."]
}
---
## Overview

Jido Signal is a sophisticated event-driven communication toolkit for Elixir, providing the foundational messaging infrastructure for the Jido agent ecosystem. Built on the CloudEvents v1.0.2 specification, it defines a standardized signal (message envelope) format and provides a complete stack for routing, dispatching, persisting, and tracking signals across processes, nodes, and external systems.

## Purpose

Jido Signal is the nervous system of the Jido ecosystem. It provides the universal message format and delivery infrastructure that all other Jido packages use to communicate. Every event, command, agent message, and state change flows through the system as a Signal.

## Major Components

### Core Signal (`Jido.Signal`)
The central struct implementing CloudEvents v1.0.2 with required fields (`id`, `type`, `source`, `specversion`) and optional fields. Supports custom signal types with schema validation via `use Jido.Signal`.

### Signal Router (`Jido.Signal.Router`)
High-performance trie-based routing engine with O(k) path matching, single-level (`*`) and multi-level (`**`) wildcards, and priority-based handler ordering.

### Signal Bus (`Jido.Signal.Bus`)
GenServer-based in-memory pub/sub hub with subscriptions, routing, signal history, replay, snapshots, partitioned dispatch, rate limiting, persistent subscriptions, and middleware pipelines.

### Signal Dispatch (`Jido.Signal.Dispatch`)
Pluggable adapter-based delivery system with 9 built-in adapters supporting synchronous, asynchronous, and batched dispatch modes.

### Signal Journal (`Jido.Signal.Journal`)
Causality and conversation tracking via a directed graph of signals with temporal querying and pluggable persistence backends.

#### Signal Journal storage and durability

The Journal is where causal history is recorded, so its storage choice decides what survives a restart. The shipped adapters and their durability (tied to released behavior, and consistent with the [Journal Retention, Access, and Deletion](/docs/operations/journal-retention-access-and-deletion) operations page):

- **Default adapter — `InMemory`, not durable.** `Jido.Signal.Journal.new/1` defaults to the `InMemory` adapter, which holds history in process memory. A `Signal.Bus` does not wire a Journal adapter unless you set `:journal_adapter` (or the `:jido_signal, :journal_adapter` application config); the documented production choice is `ETS`.
- **Durable adapters — `ETS` and `Mnesia`.** `ETS` keeps history across a Journal restart; `Mnesia` (disc-backed, after `:mnesia.create_schema([node()])`) keeps it across a node restart. The durability you get is exactly the durability you choose.
- **Restart behavior.** Over `InMemory`, a recorded signal is gone after a restart. `ETS` survives a Journal restart but not a node restart; only `Mnesia` survives a node restart.
- **Retention.** No retention policy, TTL, or compaction ships — the Journal keeps every recorded signal until you delete it at the store (there is no `delete_signal` API). `Jido.Signal.Journal.query/2` (`after`/`before`/`type`/`source`) is a read filter, not a retention rule, so retention is application-owned.
- **Replay limits.** `Signal.Bus.replay/4` reads only the Bus's in-memory signal log (not the Journal), filtered by path and an optional start timestamp, and returns at most `:batch_size` matches (default 1,000). That log is bounded by `:max_log_size` (default 100,000 signals) and an optional `:log_ttl_ms` (default: none), so signals that aged out cannot be replayed, and replay is not durable across a Bus restart. For history that survives, point the Journal at a durable adapter.

### Distributed Tracing (`Jido.Signal.Trace`)
W3C Trace Context-compatible distributed tracing with 128-bit trace IDs, span linking, and causation chains.
