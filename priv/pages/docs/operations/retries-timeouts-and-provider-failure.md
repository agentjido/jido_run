%{
  description: "Separate retry, timeout, and fallback decisions for tool errors, HTTP transport failures, and model/provider failures.",
  title: "Retries, Timeouts, and Provider Failure",
  category: :docs,
  legacy_paths: [],
  tags: [:docs, :operations],
  order: 357,
  draft: false
}
---
# Retries, Timeouts, and Provider Failure

Supervision keeps a crashed agent process alive. It does not retry the work the process was doing — a crashed process loses the in-flight call. This page is about the other failure boundary: recovering from work that fails at the **call boundary**, where a tool, an HTTP request, or a model response goes wrong. These are three distinct layers, and each needs its own timeout, retry budget, and fallback decision.

Retrying without a budget is how agent systems burn provider budget and amplify outages. Every path on this page ends the same way: a **bounded** number of retries, an explicit timeout, and a defined fallback for provider failure — never unbounded retry. Contrast this with [Supervision and Failure Boundaries](/docs/operations/supervision-and-failure-boundaries), which is process-level recovery.

## Three failure layers

A long-running agent fails at three different places. Keep them in separate code paths so you can reason about — and configure — each one:

| Layer | Where it fails | Typical cause | Owns the retry decision |
|---|---|---|---|
| **Tool** | An Action's `run/2` | bad input, bad output, downstream hiccup | Jido exec layer (per-Action) |
| **HTTP** | The provider transport | network errors, connection reset, 5xx | The AI client / your adapter |
| **Model** | The provider's response | rate-limit, auth, policy refusal, bad completion | Your application's fallback rule |

The retryable/terminal split differs in each layer. A tool timeout is retryable; a tool's malformed input is terminal. An HTTP 5xx is retryable; a model auth error is terminal. Decide each deliberately.

## Tool failures

A tool Action returns one of three shapes from its `run/2` callback:

```elixir
# Jido.Action run/2 return shapes
{:ok, result}                 # success — result merged into agent state
{:ok, result, effects}        # success with side-effect directives
{:error, error}               # failure — surfaces as a Directive.Error
```

Tool failures split into retryable and terminal based on the **error type**, not a guess:

| Tool error | Retryable? | Why |
|---|---|---|
| `InvalidInputError` / validation error | No | Bad params or a schema mismatch. Retrying the same input repeats the same failure. |
| `ConfigurationError` | No | The Action is misconfigured; retry cannot fix it. |
| `TimeoutError` | Yes | The Action exceeded its time budget — a transient stall. |
| `ExecutionFailureError` / `InternalError` | Yes by default | Transient runtime failures, overridable with a `retryable:` hint. |

Typed Action schemas turn malformed output into a terminal validation error at the boundary, so a tool that returns the wrong shape is caught before it drives a downstream effect — it is not retried into correctness.

When an error is retryable, the Jido execution layer retries it with exponential backoff. Configure the budget per command through `Jido.Agent.cmd/3`, which threads these options into each instruction:

- `:timeout` — maximum time in milliseconds for one Action run (default `30_000`, configurable as `:jido_action, :default_timeout`). Exceeding it raises a retryable `TimeoutError`.
- `:max_retries` — retry attempts after the first failure (default `1`, configurable as `:jido_action, :default_max_retries`).
- `:backoff` — initial backoff in milliseconds; it **doubles with each retry, capped at 30 seconds** (default `250`, configurable as `:jido_action, :default_backoff`).

```elixir
# Bounded retry for a tool Action: 3 attempts, 250ms → 500ms → 1000ms backoff,
# 5s per attempt. A validation error stops immediately; a timeout retries.
Jido.Agent.cmd(agent, MyApp.Actions.SearchDocs,
  max_retries: 3,
  backoff: 250,
  timeout: 5_000
)
```

An Action that knows its own failure is terminal can mark it so the budget is not spent:

```elixir
def run(%{query: query}, _ctx) do
  case search(query) do
    {:ok, results} ->
      {:ok, %{results: results}}

    {:error, :bad_query} ->
      # Malformed input — do not retry; fix the caller. The `:retry` hint in
      # the details map marks this execution error terminal.
      {:error, Jido.Action.Error.execution_error("invalid query", %{retry: false})}

    {:error, :upstream_timeout} ->
      # Transient — a timeout error is retryable by default.
      {:error, Jido.Action.Error.timeout_error("search timed out")}
  end
end
```

Action and command execution emit telemetry — including the `[:jido, :agent, :cmd, :exception]` event — with `:error_type` and `:retryable?` fields, so an operator can tell a retryable blip from a terminal defect. See [Telemetry and observability](/docs/reference/telemetry-and-observability).

## HTTP failures

The model provider is reached over HTTP (via Req). Transport failures are almost always transient, which makes them the strongest candidate for bounded retry — and the easiest place to retry without a budget if you are not careful.

HTTP failures are retryable: network errors, connection resets, and provider 5xx responses. Give the call an explicit receive timeout and a bounded retry budget so a slow provider cannot hold a Signal indefinitely:

- Set the request **timeout** on the AI request (call functions default to `5_000` ms; the AI request default is `30_000` ms). It is threaded through as the HTTP receive timeout.
- For streaming responses, set `:stream_timeout_ms` to bound inactivity between chunks, so a stalled stream does not hang.

```elixir
# Bounded HTTP-level timeout and a fallback model when the provider is degraded.
{:ok, request} =
  Jido.AI.Request.new(model: "primary-model", prompt: prompt, timeout: 10_000)
```

Retrying HTTP failures is only safe when the effect is idempotent (see [Incident playbooks](/docs/operations/incident-playbooks)). Set `:max_retries` and `:backoff` deliberately and treat hitting the ceiling as a signal to alert — a provider that keeps returning 5xx needs a fallback path, not more retries.

## Model failures

Model failures come from the provider's *response* rather than the transport. They are the layer most likely to need a fallback rather than a retry, because many model errors are terminal:

| Model error | Retryable? | What to do |
|---|---|---|
| Rate limit (HTTP 429) | Yes | Retry with backoff; honor the provider's retry window. |
| Transient 5xx | Yes | Bounded retry, then fallback. |
| Auth / permission | No | Terminal. Fix credentials; do not retry. |
| Bad request / unsupported input | No | Terminal. Fix the request. |
| Content-policy refusal | No | Terminal. Do not retry into a refusal. |
| Empty or malformed completion | Depends | Validate; fall back or surface to the caller. |
| Structured-output validation failure | No | Terminal. Fix the schema or the prompt. |

The AI request exposes its outcome as a status — `:completed`, `:failed`, or `:timeout` — so your application can branch on which kind of failure happened:

```elixir
case MyApp.Agent.complete(request) do
  %{status: :completed, result: result} ->
    {:ok, result}

  %{status: :timeout} ->
    # Provider stalled — fall back to a cheaper model or a cached result.
    MyApp.Agent.complete(%{request | model: "fallback-model"})

  %{status: :failed, error: error} ->
    # Terminal model failure — do not retry without limit.
    Logger.warning("model failure: #{inspect(error)}")
    safe_default()
end
```

Provider failure is the case that needs a **defined fallback rule**, not a retry loop: when the primary provider is degraded, route to a cheaper model, a cached result, or a safe default — then switch back when it recovers and confirm no work was duplicated with idempotency keys. A circuit breaker that opens after repeated provider failures is an application concern; Jido does not ship one, but the bounded retry budget gives you the signal to trip it. Do not retry a provider outage without limit.

## Decide deliberately

For each agent class, write down three numbers and one rule:

- **Timeouts** — one per Action run, one per provider request, one per stream window.
- **Retry budget** — how many retries and what backoff, per layer.
- **Fallback rule** — what happens when the retry budget is exhausted (cheaper model, cached result, safe default, or fail the Signal).

| Layer | Retryable example | Terminal example | On budget exhaustion |
|---|---|---|---|
| Tool | timeout, transient execution | invalid input, config error | surface the `Directive.Error`; dead-letter the work |
| HTTP | network error, 5xx | — | alert; fall back provider |
| Model | 429, transient 5xx | auth, bad request, refusal | fall back model or safe default |

Poison work that fails every time should move to a dead-letter path for inspection, not be retried forever — see [Incident playbooks](/docs/operations/incident-playbooks).

## What retry does not do

Bounded retries and fallbacks recover calls. They do not, by themselves:

- **Recover process state.** A retry replays a call against the agent's current state; it does not reconstruct state lost to a crash. Process recovery is supervision's job; state recovery is an application choice.
- **Make work idempotent for you.** Retrying a side-effecting Action safely requires idempotency keys or Signal IDs. Wire those before raising a retry budget.
- **Guarantee success.** A bounded budget with a fallback bounds the blast radius of provider failure; it is not a guarantee the call will succeed. Confirm the failure path with a drill.
- **Serve as an audit trail.** Telemetry on retries and failures is system understanding, not a tamper-evident audit log — see [Security and governance](/docs/operations/security-and-governance).

## Next steps

- Confirm your timeouts, retry budgets, and fallback rule against the [Production Readiness Checklist](/docs/operations/production-readiness-checklist).
- Practice a provider-timeout-and-fallback drill with the [Incident playbooks](/docs/operations/incident-playbooks).
- Pair the retry budget with process-level recovery in [Supervision and Failure Boundaries](/docs/operations/supervision-and-failure-boundaries).
- Build the controls end to end from the [Operational controls](/docs/getting-started/operational-controls) onboarding lane.
