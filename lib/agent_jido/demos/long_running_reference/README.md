# Long-Running Reference Application (`jido-e07-t29`)

The single runnable agent the [long-running reference architecture][spec]
calls for. It runs under supervision, takes scheduled and request-driven
work, persists state, retries transient failure, emits telemetry, exposes a
health check, and recovers across a process, application, and deployment
restart — every concern wired into **one agent at the same time**, not seven
separate demos.

[spec]: ../../../../specs/operations-reference-architecture.md

The agent is deterministic and side-effect free — no API key, network, or
runtime is required — so the whole path runs in a normal `mix test` process.

## What this proves

| Concern | Where it is covered |
|---|---|
| Supervision | `Supervisor` boots the `AgentServer` `:permanent`; a killed process is restarted by the surviving supervisor. |
| Scheduling | the agent declares a CRON schedule; `HandleCronTickAction` handles the `reference.cron` route. |
| Persistence | `Persistence` wraps `Jido.Persist.hibernate/thaw` over an ETS store; a checkpoint then thaw round-trips state. |
| Retries | `StartRetryAction` / `HandleRetryAction` recover a transient failure through bounded schedule directives. |
| Telemetry | `IngestWorkAction` wraps work in a `Jido.Observe.with_span/3` span with redactable metadata. |
| Health | `Health` implements the process / dependency / work axes over `Jido.AgentServer.status/1`. |
| Deployment | `Supervisor` *is* the deployment; the whole tree is replaced on a redeploy and resumes from a checkpoint. |

Idempotency (a duplicate `work_id` does not double-count) is folded into
`IngestWorkAction`, satisfying the duplicate-delivery failure drill.

## Run it

End-to-end proof of every concern above:

```
mix test test/agent_jido/demos/long_running_reference_test.exs
```

All seven documented failure drills — including this application end to end —
run in one command:

```
scripts/failure_drill.sh
```

## Module map

```
long_running_reference/
├── long_running_reference_agent.ex   # the agent: state schema, CRON schedule, signal routes
├── supervisor.ex                     # the deployment + process restart boundary
├── persistence.ex                    # hibernate/thaw over an ETS store
├── health.ex                         # process / dependency / work health axes
└── actions/
    ├── ingest_work_action.ex         # tool + idempotency + telemetry
    ├── handle_cron_tick_action.ex    # scheduling
    ├── start_retry_action.ex         # retry and failure policy
    └── handle_retry_action.ex        # one bounded retry attempt
```

Observable state an operator reads to tell the concerns apart:

| Field | Meaning |
|---|---|
| `processed` / `seen_work` | distinct work items ingested, with idempotency on `work_id` |
| `cron_ticks` | scheduled ticks observed |
| `attempts` / `max_attempts` / `retry_delay_ms` | a bounded retry loop driven by schedule directives |
| `status` / `last_event` | the most recent transition (the work-health axis) |

## Expected observations per failure

The architecture spec fixes seven documented failure drills, each with an
**expected observation**. The observations below are what the reference app
(and the focused demo each drill points at) actually produces, grouped into
the four categories an operator checks: **logs**, **state**, **telemetry**,
and **recovery result**. They are the contract `scripts/failure_drill.sh`
guards, reproduced here so an operator can read the expected result before
running the drill.

### 1. Tool error + retry decision

Retryable and terminal errors take different paths (`tool_error_retry_test.exs`;
the reference app's retry lane is `StartRetryAction` / `HandleRetryAction`).

| Observation | Expected |
|---|---|
| **Logs** | An Action error is returned at the call boundary (`{:error, %Jido.Action.Error.TimeoutError{}}` or `{:error, %Jido.Action.Error.InvalidInputError{}}`); it does **not** crash the `AgentServer`, so the process stays up. |
| **State** | In the reference app's retry lane, `attempts` advances up to `max_attempts`, `status` goes `:retrying → :recovered`, and `last_event` ends at `"retry.recovered"`. |
| **Telemetry** | `Jido.Action.Error.retryable?/1` classifies the error — `true` for a timeout, `false` for invalid input — which is the decision the exec layer consults. |
| **Recovery result** | A retryable error recovers inside the budget (3 attempts with `max_retries: 3`); a terminal error is not retried at all (1 attempt), regardless of budget. |

### 2. AgentServer crash

The supervisor restarts the process; the observed state result is explicit
(`agent_server_crash_test.exs`; the reference app's supervision test).

| Observation | Expected |
|---|---|
| **Logs** | The OTP supervisor restarts the `:permanent` child (`max_restarts: 1000, max_seconds: 1`); the logger reports the restart. |
| **State** | Post-restart state is the **initial** state — `processed == 0`, `seen_work == []` — because in-memory state is lost (the test asserts the counter reads `3`, then `0`). |
| **Telemetry** | `Jido.AgentServer.status/1` returns the **new pid** and the same `agent_id`; `Health.process_health/1` reads `{:error, :process_down}` while the process is dead and `:ok` once restarted. |
| **Recovery result** | A fresh process reclaims the same logical identity (`AgentJido.Jido.whereis(agent_id) == restarted`), live and serving. Identity carries across the restart; memory does not. |

### 3. Application restart

Required state is restored from a real store (`persistence_storage_agent_test.exs`;
the reference app's persistence test).

| Observation | Expected |
|---|---|
| **Logs** | `Persistence.checkpoint/2` writes via `Jido.Persist.hibernate/2`; `Persistence.restore/2` reads via `Jido.Persist.thaw/3`. |
| **State** | The restored agent keeps `processed` and `seen_work` from the checkpoint (e.g. `processed == 1`, `seen_work == ["w-p1"]`). |
| **Telemetry** | `Health.dependency_health/2` returns `:ok` — the store answers (hit or miss). |
| **Recovery result** | `restore/2` returns `{:ok, agent}` on a hit and `{:error, :not_found}` on a miss — never a silent guess. |

### 4. Deployment restart

The workflow resumes or safely restarts with stated semantics
(`deployment_restart_test.exs`; the reference app's deployment test).

| Observation | Expected |
|---|---|
| **Logs** | `Supervisor.stop/1` tears the supervisor and agent down together — there is no surviving parent; a fresh supervisor then boots a fresh tree. |
| **State** | **Without** persistence, the new deployment boots at the initial state (`processed == 0`); **with** persistence, it resumes (`processed` and `seen_work` preserved across the redeploy). |
| **Telemetry** | `AgentJido.Jido.whereis(agent_id)` resolves to the **new** pid; `status/1` reports the reclaimed identity behind that new process. |
| **Recovery result** | The whole tree is **replaced** (old supervisor and agent dead, new ones live) and the workflow either safely restarts or resumes from a checkpoint — the two semantics are stated, not conflated. |

### 5. Duplicate Signal delivery

The Action demonstrates idempotency (`idempotent_credit_agent_test.exs`;
the reference app's idempotency test, folded into `IngestWorkAction`).

| Observation | Expected |
|---|---|
| **Logs** | `last_event` reads `"work.duplicate:<work_id>"` on the repeat delivery. |
| **State** | `processed` advances **once**; `seen_work` lists the `work_id` exactly once. |
| **Telemetry** | The `IngestWork` span still fires (start and stop carry the `work_id`), so the duplicate delivery is visible in the observation stream without double-counting. |
| **Recovery result** | No double-application — a duplicate delivery is a no-op. |

### 6. Provider timeout + fallback

Bounded retries and an explicit fallback rule (`provider_timeout_fallback_test.exs`).

| Observation | Expected |
|---|---|
| **Logs** | The wrapper runs a bounded retry loop; the configured fallback fires when the budget is exhausted. |
| **State** | The attempt counter recovers at 3 attempts under `max_attempts: 4`; a persistent timeout exhausts the budget at exactly `max_attempts`. |
| **Telemetry** | The result is tagged `source: :primary` when it recovers, or `source: :fallback` with a `reason` (`:timeout`, `:rate_limit`, or `:auth`). |
| **Recovery result** | The explicit fallback rule fires (a `:fallback` result) on budget exhaustion or a terminal error, or the Signal fails (`{:error, {:provider_unavailable, _}}`); the loop is never unbounded. |

### 7. Poison work / dead-letter

Failed work is inspectable and replayable (`poison_work_dead_letter_test.exs`).

| Observation | Expected |
|---|---|
| **Logs** | Poison work is moved to the `DeadLetterStore` after the bounded budget is exhausted. |
| **State** | The dead-letter entry carries an `id`, the original `work`, the `reason`, `attempts` (== `max_attempts`), and a `replay_attempts` counter. |
| **Telemetry** | `DeadLetterStore.entries/1` lists every dead-lettered item, so the failure is inspectable rather than dropped. |
| **Recovery result** | `replay/3` after the cause is fixed (`Worker.fix/1`) succeeds and removes the entry; a replay that still fails **updates the same entry** (incrementing `replay_attempts`) rather than creating a duplicate. |
