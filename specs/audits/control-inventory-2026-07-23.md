# Control-Surface Inventory — 2026-07-23

Status: Baseline (M0). Source epic: `jido-e00`.
Covers `E00-T13` (identity), `E00-T14` (authorization/policy), `E00-T15`
(audit/history), `E00-T16` (observability), `E00-T17` (risk-to-control matrix).

Purpose: record, from the current package source, which control surfaces exist,
where they live, and what they do **not** do. This is the factual basis for the
claim boundaries enforced in `E02`, `E03`, and `E12`.

Conventions used below:

- **Lifecycle/correlation** = runtime state used for grouping and tracing. Not authentication.
- **Authenticated principal** = identity verified outside Jido by the host application.

## Identity fields (`E00-T13`)

| Field | Source | Kind | Note |
|---|---|---|---|
| Agent `id` | `Jido.Agent.new(id: ...)` (`deps/jido/lib/jido/agent.ex`) | Lifecycle/profile state | Stable Agent identity for persistence and lookup; not a principal |
| Signal `id` | `Jido.Signal` (`deps/jido_signal/lib/jido_signal/id.ex`) | Correlation metadata | Unique per Signal; not authentication |
| Request / run / tool-call IDs | Jido execution + `jido_ai` tool calls | Correlation metadata | Join work across components; not authenticated identity |
| Trace / causation IDs | `jido_signal` trace (`trace.ex`, `trace_context.ex`) | Correlation metadata | Causation chain; not an audit identity |

Conclusion: no Jido field is an authenticated principal. Principal, actor, and
tenant context must be supplied by the application (see `E02-T34`, `E05-T34`,
`E07-T37`).

## Authorization and policy control points (`E00-T14`)

| Control point | Source | Maturity | Default behavior |
|---|---|---|---|
| `Jido.Plugin.prepare_signal/2` | `deps/jido/lib/jido/plugin.ex:296` | Stable (hook) | No-op pass-through; verify/enrich runtime context when implemented |
| `Jido.Plugin.prepare_action/3` | `deps/jido/lib/jido/plugin.ex:319` | Stable (hook) | No-op pass-through; fail-closed authorization point when implemented |
| Action contract validation | `Jido.Action` params | Stable | Validates Action args; not an authorization decision |
| Jido AI effect policy / tool allowlist / prompt policy / quota | `jido_ai` plugins | Beta | Optional scoped AI controls |
| Ash authorization | `ash_jido` | Beta | Preserves Ash actor/tenant/authorization; host Ash app enforces |

Conclusion: Jido supplies **integration points** for authorization, not a built-in
IAM/RBAC product. `prepare_action/3` is the fail-closed hook used by the
controlled-Agent path (`E05-T35`, `E07-T39`).

## Audit and history surfaces (`E00-T15`)

| Surface | Source | Durability | Retention/replay |
|---|---|---|---|
| Signal Journal | `deps/jido_signal/lib/jido_signal/journal/` | Only with an explicit durable adapter | Application-defined |
| Thread / in-memory history | `jido` runtime state | Process lifetime | None across restart |
| Persistence | `jido` persistence packages | Adapter-dependent | Adapter-dependent |
| Telemetry events | `Jido.Telemetry` / `Jido.Observe` | Ephemeral stream | None (not a log store) |
| Logs | Application logger | Application-defined | Application-defined |

Conclusion: a durable causal history requires an explicitly configured durable
Journal adapter plus a retention policy (`E07-T44`, `E07-T45`). Telemetry and
in-memory history are **not** audit records (`E02-T36`, `E06-T34`).

## Observability surfaces (`E00-T16`)

| Surface | Source | Maturity | Role |
|---|---|---|---|
| `Jido.Observe` correlated telemetry | `jido` core | Stable | Lifecycle and Action events, spans |
| `Jido.Telemetry` | `jido` core | Stable | `:telemetry` events |
| `jido_signal` tracing | `jido_signal` `trace/`, `telemetry.ex` | Stable | Signal causation/correlation |
| `jido_otel` OTel export | `jido_otel` | Experimental | OpenTelemetry bridge (optional) |
| LiveDashboard / AI telemetry | Phoenix / `jido_ai` | Stable | Operational view |

Conclusion: core telemetry is Stable; OTel export is Experimental and must not be
presented as built-in (`E03-T15`, `E04-T17`, `E09-T45`).

## Operational risk-to-control matrix (`E00-T17`)

Each operational risk maps to the Jido control point, the application's duty, and
the current gap. Gaps become proof work in `E07`/`E08`/`E12`.

| Risk | Jido control point | Application duty | Current gap |
|---|---|---|---|
| Tool misuse / unauthorized work | `prepare_action/3`, AI tool allowlist | Supply principal + policy | No public controlled-Agent example (`E07-T39`, `E08-T37`) |
| Runaway cost | AI quota plugin, effect policy | Set token/request/tool budgets | No quota example (`E05-T38`, `E07-T42`) |
| Lost state on restart | Supervision (process restart) | Persistence + idempotent Actions | State-recovery example missing (`E07-T03`, `E08-T18`) |
| Hidden failure | Supervision, telemetry | Health checks, alerting | Operations content is draft (`E07`) |
| Duplicate work | Idempotent Actions, Signal id | Dedup keys | Idempotency example missing (`E07-T04`, `E07-T15`) |
| Provider failure | ReqLLM retries | Fallback policy, circuit breaker | Provider-fallback example missing (`E07-T16`, `E08-T21`) |
| Sensitive-data leakage | Telemetry, Journal | Redaction rules | Redaction regression test missing (`E12-T41`) |

## Related artifacts

- Master baseline: `specs/audits/baseline-2026-07-23.md`
- Content inventory: `specs/audits/content-inventory-baseline-2026-07-23.md`
- Link audit: `specs/audits/link-audit-baseline-2026-07-23.md`
