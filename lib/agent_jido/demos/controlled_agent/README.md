# Controlled-Agent Reference Application (`jido-e07-t35`)

The controlled-agent extension of the [long-running reference app][ref]. One
supervised `Jido.AgentServer` proves the full control path in a single run:
**who initiated work, what was allowed, what happened, and how failure was
handled** — and the design names every control element a production controlled
agent composes, even the ones this demo isolates in a focused demo and the ones
a sibling task builds out.

[ref]: ../long_running_reference/README.md

The agent is deterministic and side-effect free — no API key, network, or
runtime is required — so the whole path runs in a normal `mix test` process.

## The nine-element design

The [architecture spec][spec], "Controlled-agent extension", fixes nine control
elements. This demo implements the ones an integrated run can prove today and
points at where the rest live; the design layers all nine onto this same agent
rather than spawning a second one.

[spec]: ../../../../specs/operations-reference-architecture.md

| # | Element | Jido surface | In this demo | Where the rest is proven |
|---|---|---|---|---|
| 1 | Ingress | the incoming `Signal` | `ControlledAgent` routes `work.approve`; `IncomingContext` carries principal/tenant/request/correlation/causation (`jido-e07-t37`) | `jido-e07-t38` enriches context via `prepare_signal/2` |
| 2 | Principal context | `Signal.source` | every Signal carries the caller's `source`; the hook inspects it | `IncomingContext` (`jido-e07-t37`) |
| 3 | Policy | `prepare_action/3` | `AuthorizationPlugin` is **fail-closed** (`["alice"]`) | `jido-e07-t38` enriches context via `prepare_signal/2` |
| 4 | Actions | `Jido.Action` | `ApproveAction` advances the counter | — |
| 5 | Effects | typed Actions + AI tool/effect/quota policies | (designed; not wired here) | focused demos `AiToolAllowlist`, `QuotaControlAgent` |
| 6 | Journal | durable Signal Journal adapter | (designed; not wired here) | focused demo `DurableSignalJournal`; `jido-e07-t45` |
| 7 | Telemetry | `Jido.Observe` (+ `jido_otel`) | Signals carry correlation IDs | focused demos `CorrelatedTelemetry`, `RedactedAction` |
| 8 | Approval | an Action that gates a high-impact effect | (designed; not wired here) | focused demo `ApprovalBoundaryAgent` |
| 9 | Recovery | `AgentServer` under OTP supervision + persistence | `Supervisor` restarts the process; state recovers via hibernate/thaw | the four recovery boundaries in the long-running spec |

This demo implements elements 1–4 and 9; elements 5–8 are isolated in their
focused demos so each can be studied on its own, then layered back on here under
the sibling tasks named in the table.

## What this proves

| Control question | What this example proves |
|---|---|
| **Who initiated work** | Every `work.approve` Signal carries a `source` principal; the hook inspects it, so each piece of work is attributable to the caller, not the agent. |
| **What was allowed** | `AuthorizationPlugin.prepare_action/3` is fail-closed: the Action runs only when the principal is in the allowlist. Run as `mallory` and the Action never executes. |
| **What happened** | The `approved_count` counter and the control log record exactly what ran — approved work increments, denied work is rejected with a reason — and Signals carry correlation IDs you can follow. |
| **How failure was handled** | The `AgentServer` runs under an OTP supervisor (`:permanent`, `max_restarts: 1000`). Crash it and supervision restarts a fresh process; approved state survives a full restart via hibernate/thaw. |

## Incoming context (`jido-e07-t37`)

An incoming controlled-agent Signal carries five context fields, defined once in
`IncomingContext`. Each field has a **source** (the Signal location it rides
on), a **validation rule**, and a **propagation test**
(`controlled_agent_incoming_context_test.exs`) — locked by the task's
acceptance: *each field has a source, validation rule, and propagation test.*

| field | source | validation rule |
|---|---|---|
| `principal` | `Signal.source` | required, non-empty binary |
| `tenant` | `Signal.extensions["tenant"]` | optional; when present, non-empty binary |
| `request` | `Signal.extensions["request_id"]` | optional; when present, non-empty binary |
| `correlation` | `Signal.extensions["correlation_id"]` | optional; when present, non-empty binary |
| `causation` | `Signal.extensions["causation_id"]` | optional; when present, non-empty binary |

```elixir
alias AgentJido.Demos.ControlledAgent.IncomingContext

attrs = IncomingContext.build(
  principal: "alice",
  tenant: "acme",
  request: "req-7",
  correlation: "trace-7",
  causation: "sig-cause-7"
)

signal = Jido.Signal.new!("work.approve", %{note: "x"}, attrs)
IncomingContext.validate(signal)   # => :ok
IncomingContext.get(signal, :principal)   # => "alice"
```

`principal` is the already-authenticated caller, verified at the boundary in
front of Jido (see [Authentication boundary](#authentication-boundary)). The
other four are application-supplied context that same boundary attaches;
`correlation` ties one unit of work across components and `causation` names the
signal or request that caused this one. This module carries and validates the
context — it does not verify identity (the boundary does) or authorize work (the
`AuthorizationPlugin` does). Enriching the context onto the live path via
`prepare_signal/2` is `jido-e07-t38`.

## Authentication boundary

Authentication is a boundary **in front of** Jido, not something this agent (or
Jido) performs. The path has three stages, and only the middle one is Jido's:

| Stage | Owner | In this demo |
|---|---|---|
| **Authenticate** | application / platform (outside Jido) | the caller's identity is verified and a principal issued before the Signal exists |
| **Carry** | Jido | every `work.approve` Signal carries the caller on `Signal.source` |
| **Authorize** | application policy via Jido's hook | `AuthorizationPlugin.prepare_action/3` allows `alice`, denies everyone else — fail-closed |

```mermaid
flowchart LR
  C([Caller]) --> AUTH["AuthN / IAM\n(outside Jido)"]
  AUTH -->|"verified principal"| SIG["Signal.source"]
  SIG --> PA["prepare_action/3\nfail-closed"]
  PA --> ACT[ApproveAction]
```

The allowlist (`["alice"]`) is the **Authorize** stage — a policy decision, not a
login. `alice` is a principal the boundary in front of Jido already
authenticated; the hook only decides whether that principal may run the Action.
**Jido does not authenticate a user or service by itself.** The spec's
[Authentication boundary][spec] section draws the same line, and
[security and governance](/docs/operations/security-and-governance) owns the full
claim-boundary model.

## Recovery in this demo

Recovery has two layers here, matching the long-running spec's process and
application boundaries:

- **Process restart** — `Supervisor` boots the `AgentServer` `:permanent`; a
  killed process is restarted by the surviving supervisor. In-memory state is
  lost, so the counter resets — exactly what supervision recovers (the process)
  and what it does not (memory).
- **Application restart** — `controlled_agent_persistence_test.exs` checkpoints
  approved state via `Jido.Persist.hibernate/thaw` and restores it on a fresh
  boot, so `approved_count` survives a restart.

The node and deployment boundaries (durable, disk-backed state) are proven in
the [long-running reference app][ref]; the design carries the same semantics
here once a durable Journal and store are layered on.

## Run it

```
mix test test/agent_jido/demos/controlled_agent_test.exs
mix test test/agent_jido/demos/controlled_agent_persistence_test.exs
mix test test/agent_jido/demos/controlled_agent_incoming_context_test.exs
```

The design coverage itself is locked by:

```
mix test test/agent_jido/demos/controlled_agent_design_test.exs
```

## Module map

```
controlled_agent/
├── controlled_agent.ex     # the agent: state schema, signal route, authorization plugin
├── incoming_context.ex     # the five incoming-Signal context fields (sources + rules)
├── authorization_plugin.ex # fail-closed prepare_action/3 (the policy)
├── approve_action.ex       # the protected Action
└── supervisor.ex           # the process-restart boundary
```

## Key concept

**The hook is an integration point, not an IAM product.** Jido does not
authenticate callers. Verified identity is established at the authentication and
IAM boundary you put in front of Jido, and the principal it issues is what each
incoming Signal carries. The hook decides whether that principal may run the
Action — your application supplies the policy decision. See
[security and governance](/docs/operations/security-and-governance) for the full
model, and the spec's [explicit non-goals][spec] for which duties stay outside
Jido.
