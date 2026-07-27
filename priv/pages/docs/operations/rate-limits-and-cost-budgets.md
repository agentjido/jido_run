%{
  description: "The three budgets a long-running Jido AI system must set deliberately — token, request, and tool — and, for each, where the bound lives and what happens when it is exceeded.",
  title: "Rate limits and cost budgets",
  category: :docs,
  legacy_paths: [],
  tags: [:docs, :operations],
  order: 367,
  draft: false
}
---
# Rate Limits and Cost Budgets

Supervision keeps a crashed agent alive; retries recover a failed call; [backpressure and queue limits](/docs/operations/backpressure-and-queue-limits) bound the backlog before it threatens the node. None of them answers the question an AI workload adds on top: **how do you keep a long-running agent from spending too much money, calling the model too often, or looping on tools forever?** That is the job of three distinct budgets — token, request, and tool — and a long-running Jido system must set each one deliberately. This page names all three, states where the bound lives (Jido or your application), and says what happens when it is exceeded.

The central honesty point: **out of the box, Jido does not enforce a token or request budget at all.** The only built-in runaway guard is the tool-iteration cap. Everything that bounds spend and call rate is opt-in (the `Jido.AI.Plugins.Quota` plugin) or application-owned (a limiter you put upstream of the call). A newly started agent with no quota wired up will happily call the model until your provider returns a 429 or your bill surprises you. Treat that as a feature — the right budget is a property of your provider contract and your tenant model, not the framework's — and then set the budgets anyway.

| Budget | What it bounds | Default | Who owns the bound | Exceeded behavior |
|---|---|---|---|---|
| **Token** | tokens spent per response and per window | `max_tokens` `4_096` per response; per-window token budget **off** | Jido caps each response; the per-window budget is opt-in | response is truncated (`:length`); or the call is denied with `:quota_exceeded` |
| **Request** | LLM calls per window and in flight | per-window request budget **off**; 8 in flight; 1 per agent | Jido caps concurrency; the per-window budget is opt-in or app-owned | checkout waits, or `:busy`, or `:quota_exceeded`, or the provider returns 429 |
| **Tool** | tool-use rounds and tool calls per run | `max_iterations` `10`; per-tool `15_000` ms, 1 retry, 4 parallel | Jido | run completes with `:max_iterations`; a tool times out with a `TimeoutError` |

The three budgets are not interchangeable. A truncated response (`:length`), a denied call (`:quota_exceeded`), and a run that stops at `max_iterations` all look like "the agent gave up," but they trip different controls and need different responses. Keep them separate. Pair this page with [Backpressure and Queue Limits](/docs/operations/backpressure-and-queue-limits) (where load is bounded), [Retries, Timeouts, and Provider Failure](/docs/operations/retries-timeouts-and-provider-failure) (where a failed call is retried inside a budget), and [Security and Governance](/docs/operations/security-and-governance) (where the tool set and effects are authorized).

## Token budget: how many tokens a run may spend

The token budget has two layers — a per-response cap that ships by default, and a per-window budget that you must opt into.

**Per response.** `max_tokens` caps how many tokens a single model response may produce. The `jido_ai` agent default is `4_096` (`Jido.AI.Agent`, overridable per agent or per request). When the model reaches the cap, the response is truncated and the finish reason is `:length` — the call succeeds, but the answer is cut short, and you still pay for the tokens. This is a length knob, not a spend limit: it bounds one response, not a run, a tenant, or a day.

**Per window.** The opt-in `Jido.AI.Plugins.Quota` plugin is the real token budget. Enable it on an agent (`quota: true`) and set `max_total_tokens`. Its defaults are:

- `max_total_tokens` — `nil`. **Nil means no token budget is enforced.** Set it to the token ceiling for the window.
- `window_ms` — `60_000`. A rolling 60-second window.
- `scope` — defaults to the agent's id. Set it to a tenant or principal id for per-tenant budgets (the wiring is yours).
- `max_requests` — `nil` (see [Request budget](#request-budget-how-many-llm-calls-may-happen)).

On every `ai.usage` signal the plugin adds the call's `total_tokens` to an in-memory (ETS) rolling-window counter for the scope. On the next budgeted call (`chat.*`, `ai.*.query`, `reasoning.*.run`), if the scope is over budget, the plugin rewrites the signal to an `ai.request.error` with `reason: :quota_exceeded` — the call never reaches the provider. Inspect the counter with the `quota.status` action and reset it with `quota.reset`.

What you always get for free is **reporting**: every response carries a normalized usage map (`input_tokens`, `output_tokens`, `total_tokens`, plus `input_cost`, `output_cost`, `total_cost`), jido_ai emits an `ai.usage` signal, and req_llm emits the `[:req_llm, :token_usage]` telemetry event. So you always know what a call cost — but reporting is not enforcement. Wire those events to an alert in [Telemetry and Traces](/docs/operations/telemetry-and-traces) before spend drifts.

Two honesty points finish this budget:

- **There is no input-token pre-validation.** jido_ai guards prompt *size* in bytes (`@max_input_length`, `100_000` bytes), not token count. It does not tokenize the input and reject an oversized request before sending. LLMDB supplies model metadata (context window, max output) that `jido_ai` consults, but an input that exceeds the model's context window surfaces reactively from the provider — as a `:length` finish reason — after you have paid for the attempt. Size your context deliberately.

- **The Quota store is in-memory.** The rolling counter lives in ETS, not a durable store. A node restart resets the window to zero. For a spend ceiling that survives restarts, back it with an application-owned store.

## Request budget: how many LLM calls may happen

The request budget bounds *how many* LLM calls happen — per window, in flight, and per agent — and Jido owns only some of it.

**Per window.** The same `Jido.AI.Plugins.Quota` plugin enforces a requests-per-window budget through `max_requests` (default `nil` — disabled, same opt-in as the token budget, same `:quota_exceeded` denial on budgeted signals). Set `max_requests` and `window_ms` together to get a requests-per-minute ceiling.

**In flight.** The only concurrency bound on outbound LLM calls is the HTTP pool. req_llm runs every request through a Finch pool whose default is **8 concurrent in-flight requests** — HTTP/1.1, `stream_pool_count: 8` × `stream_pool_size: 1`. When all connections are busy, a new request waits for a checkout (up to the pool timeout) instead of opening another socket — that is backpressure to the caller, not a failure. There is no library-level semaphore on LLM calls; tune the pool for high-concurrency streaming (see [Backpressure and Queue Limits](/docs/operations/backpressure-and-queue-limits)).

**Per agent.** A `jido_ai` agent runs one request at a time by default: the request-concurrency policy is `:reject`, so a second concurrent request to the *same agent instance* returns `ai.request.error` with `reason: :busy` rather than queuing behind the first. If you need to queue, that is an application choice in front of the agent.

**The provider's rate limit.** The one rate bound Jido does not own is the provider's own. A 429 response is handled reactively: req_llm auto-retries a 429 honoring the provider's `Retry-After` header, `max_retries` default `3` (four total attempts), for both streaming and non-streaming calls, and jido_ai classifies it as a retryable `:rate_limit`. It recovers from a 429; it does not prevent one. See [Retries, Timeouts, and Provider Failure](/docs/operations/retries-timeouts-and-provider-failure).

Per-tenant or per-principal request gating — the RPM each customer is allowed — is **application-owned**. Add a limiter upstream of the call, or key the Quota plugin's `scope` on a tenant id. Jido does not impose it because the right ceiling is a property of your provider contract and your tenant model.

## Tool budget: how many tool calls a run may make

The tool budget bounds the agent's tool-use loop. This is the only budget Jido enforces by default, and it is the runaway-loop guard.

**Per run — `max_iterations`.** The ReAct reasoning loop is capped by `max_iterations`, default `10`. It bounds the number of LLM-plus-tool rounds in a single run. When the agent reaches the cap without a final answer, the run completes gracefully — status `:completed` (not an error), result text "Maximum iterations reached without a final answer.", termination reason `:max_iterations`. Override it per agent or per request (`:max_iterations` on the call). The cap bounds *turns*, not *cost*: a single turn can still fan out to parallel tools and a full-length response.

Sibling reasoning strategies carry their own iteration-style caps — `CallWithTools` `max_turns` (default `10`, hard ceiling `50`), Tree-of-Thoughts `max_tool_round_trips` (default `3`), TRM `max_supervision_steps` (default `5`), and Graph/Tree-of-Thoughts `max_depth` (default `5`/`3`). Set the one your strategy exposes.

**Per tool, per round.** Inside the ReAct loop, each tool call is bounded by the `tool_exec` block: `timeout_ms` `15_000`, `max_retries` `1`, `retry_backoff_ms` `200`, and `concurrency` `4` (parallel tool calls in one round). These are distinct from the directive queue and the action-level timeout.

**Per action.** A standalone Action runs under `Jido.Exec`, whose default timeout is `30_000` ms (overridable via `config :jido_action, :default_timeout`; `0` means no timeout). A timed-out action returns `%Jido.Action.Error.TimeoutError{}`. The `ExecuteTool` action carries the same `30_000` ms default.

**The tool set.** `max_iterations` bounds the tool *count*; the tool *allowlist* and effect policy bound the tool *set*. Configured through `jido_ai` plugins, a disallowed tool or effect is rejected before it runs — see [Security and Governance](/docs/operations/security-and-governance). Set both: cap how many tool calls a run may make, and decide which tools it may make at all.

Two honesty points finish this budget:

- **No cap on the number of tools passed to a model.** jido_ai converts every given Action into a tool definition with no library limit. Any cap on tool count per request is provider-imposed and application-owned.
- **No per-signal cap on directive count.** A single signal may emit any number of directives; the only bound is the shared `max_queue_size` (`10_000`) directive queue, which drops directives on overflow — see [Backpressure and Queue Limits](/docs/operations/backpressure-and-queue-limits).

## Decide deliberately

For each AI-backed agent class, write down the budget contract across all three surfaces:

- **Token.** What is `max_tokens` per response? Is the Quota plugin mounted, and what is `max_total_tokens` per window, scoped to what? Where do you alert on `ai.usage`?
- **Request.** Is `max_requests` set per window? How many concurrent in-flight calls can this class generate, and does that fit inside the 8-connection pool? Is per-tenant gating wired upstream?
- **Tool.** What is `max_iterations` for this agent's workload? What is the per-tool timeout and retry count? Which tools are on the allowlist?

| Budget | Default | Exceeded behavior | Observable signal |
|---|---|---|---|
| Token (per response) | `max_tokens` 4_096 | response truncated | finish reason `:length`; `usage` map on the response |
| Token (per window) | off (`nil`) | call denied before the provider | `:quota_exceeded`; `quota.status` |
| Request (per window) | off (`nil`) | call denied before the provider | `:quota_exceeded`; `quota.status` |
| Request (in flight) | 8 connections | checkout waits | pool timeout |
| Request (per agent) | 1, `:reject` | second call denied | `:busy` |
| Tool (per run) | `max_iterations` 10 | run completes | `:max_iterations` termination reason |
| Tool (per call) | 15_000 ms, 1 retry | tool fails | `TimeoutError`; tool-error telemetry |
| Action | 30_000 ms | action fails | `%Jido.Action.Error.TimeoutError{}` |

## What budgets do not do

These bounds limit spend, call rate, and loop length. They do not, by themselves:

- **Enforce themselves.** Token and request budgets are off until you mount the Quota plugin and set a non-nil ceiling. A default agent has no spend guard.
- **Replace authorization.** A `:quota_exceeded` denial is a cost control, not a permission decision. Whether an actor may call a tool at all is a `prepare_action/3` authorization boundary — see [Security and Governance](/docs/operations/security-and-governance).
- **Replace recovery.** A run that stops at `max_iterations` or a call denied by quota is work that did not complete. Bounded retries, fallbacks, and a dead-letter path still carry that work — see [Retries, Timeouts, and Provider Failure](/docs/operations/retries-timeouts-and-provider-failure) and [Provider Timeout and Fallback](/docs/operations/provider-timeout-and-fallback).
- **Bound the provider proactively.** The request budget and the pool throttle *your* calls; the provider's 429 is still the final word on its own rate. Staying under a provider budget is an application-owned limiter.
- **Survive a restart.** The Quota store is in-memory. A node restart zeroes the rolling window.
- **Serve as an audit trail.** Token counts and quota denials are operational telemetry, not a tamper-evident record — see [Security and Governance](/docs/operations/security-and-governance).

## Next steps

- Bound the load these budgets sit on top of in [Backpressure and Queue Limits](/docs/operations/backpressure-and-queue-limits).
- Send denied or failed calls to a recovery path in [Retries, Timeouts, and Provider Failure](/docs/operations/retries-timeouts-and-provider-failure) and [Provider Timeout and Fallback](/docs/operations/provider-timeout-and-fallback).
- Authorize the tool set behind these counts in [Security and Governance](/docs/operations/security-and-governance), and gate every budget before go-live in the [Production Readiness Checklist](/docs/operations/production-readiness-checklist).
- See the LLM control surface these budgets are part of in [ReqLLM and LLMDB](/docs/reference/req-llm-and-llmdb).
