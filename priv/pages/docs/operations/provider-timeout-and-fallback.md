%{
  description: "A worked example of a provider timeout and fallback: a transient timeout is retried inside a bounded budget, and an explicit fallback rule fires when the budget is exhausted or a terminal error occurs.",
  title: "Provider timeout and fallback",
  category: :docs,
  legacy_paths: [],
  tags: [:docs, :operations],
  order: 364,
  draft: false
}
---
# Provider Timeout and Fallback

[Retries, Timeouts, and Provider Failure](/docs/operations/retries-timeouts-and-provider-failure) states the rule for the model layer: when the primary provider is degraded, you do not retry without limit — you retry a **bounded** number of times, then apply an **explicit fallback rule** (a cheaper model, a cached result, or a safe default), or fail the Signal. This page is the worked example. It takes one provider that can time out, rate-limit, or refuse auth on demand and shows both halves playing out — a transient timeout retried inside the budget, and a defined fallback firing when the budget runs out.

Provider failure is the layer most likely to need a fallback rather than a retry, because many model errors are terminal. And unlike a [tool error](/docs/operations/tool-error-and-retry-decision) — where the Jido exec layer owns the retry decision at the `run/2` boundary — the fallback rule for a provider is an **application concern**. Jido ships the call surface (`Jido.AI.Request`); it does not ship a circuit breaker or a fallback policy. This example isolates the application's bounded-retry-and-fallback rule so you can see the decision on its own.

## The rule

Two things must hold for provider failure, and the example makes both observable:

1. **Bounded retries.** A retryable provider error — a timeout, a rate limit (HTTP 429), a transient 5xx — is retried with backoff, but only inside a budget (`max_attempts`, including the first attempt). The budget — not the classifier — is what stops a retryable timeout from looping forever. A terminal error (auth, permission, refusal) is not retried at all.
2. **An explicit fallback rule.** When the budget is exhausted (or a terminal error occurs), the fallback fires. The rule is explicit and observable: the result comes back tagged `source: :fallback`, so a caller can tell a primary answer from a recovered one. Failing the Signal is a valid fallback rule too.

| Provider outcome | Retryable? | What happens |
|---|---|---|
| `:completed` | — | Return the primary result. |
| `:timeout`, `:rate_limit`, transient `:failed` (5xx) | Yes | Retry with backoff, up to `max_attempts`. Then fallback. |
| `:auth`, refusal, bad request | No — terminal | No retry. Fallback immediately. |

## The example provider

The runnable example is a single module, `AgentJido.Demos.ProviderTimeoutFallback`, with a wrapper (`complete/2`) around a scripted, simulated provider. The provider returns the same outcome shape the AI request exposes — `%{status: :completed, result: result}`, `%{status: :timeout, retryable?: true}`, or `%{status: :auth, retryable?: false}` — so the wrapper's retry/fallback decision is the code under test, with no real provider key or network.

The `request` is a script: `mode` selects which failure the provider returns and `fail_times` how many attempts fail before it answers, so a retryable failure can be watched both *recovering inside the budget* and *exhausting the budget*.

```elixir
defmodule AgentJido.Demos.ProviderTimeoutFallback.Provider do
  @capped_backoff_ms 30_000

  def call(%{mode: mode, fail_times: fail_times}, counter) do
    attempts = bump(counter)

    outcome =
      case {mode, attempts <= fail_times} do
        {:auth, _} ->
          # Auth/permission is terminal: retrying does not fix it.
          %{status: :auth, retryable?: false}

        {mode, true} when mode in [:timeout, :rate_limit, :transient_5xx] ->
          retryable_failure(mode)

        _answers ->
          %{status: :completed, result: %{model: "primary-model", answer: "ok"}}
      end

    Map.put(outcome, :attempts, attempts)
  end

  # Backoff doubles per attempt and caps at 30 s — the same shape as the exec
  # layer's tool-retry backoff.
  def sleep_for(base_ms, attempt) do
    base_ms
    |> backoff_for(attempt)
    |> min(@capped_backoff_ms)
    |> Process.sleep()
  end

  defp backoff_for(base_ms, attempt), do: trunc(base_ms * :math.pow(2, attempt - 1))
  defp retryable_failure(:timeout), do: %{status: :timeout, retryable?: true}
  defp retryable_failure(:rate_limit), do: %{status: :rate_limit, retryable?: true}
  defp retryable_failure(:transient_5xx), do: %{status: :transient_5xx, retryable?: true}
  # ... attempt accounting elided; see the source.
end
```

The wrapper is where the rule lives. It retries a retryable outcome only while `attempt < max_attempts`, and on the first terminal outcome — or the first outcome after the budget is spent — it applies the fallback:

```elixir
defp do_complete(request, attempt, max_attempts, backoff_ms, fallback, counter) do
  outcome = Provider.call(request, counter)

  case outcome do
    %{status: :completed, result: result} ->
      {:ok, result, %{source: :primary, attempts: attempt}}

    %{retryable?: true} when attempt < max_attempts ->
      # Bounded retry: a retryable provider error is retried with backoff —
      # but only inside the budget.
      Provider.sleep_for(backoff_ms, attempt)
      do_complete(request, attempt + 1, max_attempts, backoff_ms, fallback, counter)

    _exhausted_or_terminal ->
      # A retryable error that exhausted the budget, OR a terminal error that
      # is never retried. Either way: stop retrying and apply the rule.
      apply_fallback(outcome, attempt, fallback)
  end
end
```

To see how many times the provider actually ran, the example carries a `counter` (a simple `Agent` holding an integer) alongside the options. The provider bumps it on every call, so the count is observable whether the call recovers or exhausts the budget.

## A transient timeout is retried

Fail twice with a retryable timeout, then answer on the third attempt. With `max_attempts: 4` the budget allows up to four attempts, so the call recovers:

```elixir
{:ok, counter} = Agent.start_link(fn -> 0 end)

{:ok, %{model: "primary-model"}, %{source: :primary, attempts: 3}} =
  AgentJido.Demos.ProviderTimeoutFallback.complete(
    %{mode: :timeout, fail_times: 2},
    max_attempts: 4, backoff_ms: 1,
    fallback: {:ok, %{model: "fallback-model", answer: "safe"}},
    counter: counter
  )

Agent.get(counter, & &1)   # => 3 — the provider was called three times
```

The provider ran three times. The transient timeout was retried, not abandoned, and the result is tagged `source: :primary` — the primary model answered.

## The budget is bounded, then the fallback fires

If the timeout never clears, the budget stops it. With `fail_times: 99`, every attempt times out, so the bounded budget is exhausted at exactly `max_attempts` calls and the explicit fallback fires:

```elixir
{:ok, counter} = Agent.start_link(fn -> 0 end)

{:ok, fallback_result, %{source: :fallback, attempts: 4, reason: :timeout}} =
  AgentJido.Demos.ProviderTimeoutFallback.complete(
    %{mode: :timeout, fail_times: 99},
    max_attempts: 4, backoff_ms: 1,
    fallback: {:ok, %{model: "fallback-model", answer: "safe"}},
    counter: counter
  )

Agent.get(counter, & &1)        # => 4 — exactly max_attempts, never unbounded
fallback_result                 # => %{model: "fallback-model", answer: "safe"}
```

The provider ran exactly four times — never unbounded. Then the fallback fired and the result is tagged `source: :fallback`, so a caller can tell this is a recovered answer, not a primary one. A rate limit (`:rate_limit`) or a transient 5xx (`:transient_5xx`) take the same path: retry inside the budget, then the fallback on exhaustion, with the `:reason` recording which retryable error cleared the budget.

## A terminal error fires the fallback immediately

Run the same wrapper against an auth failure with the same generous budget. The provider is called **once** — auth is terminal, so the budget is never spent — and the fallback fires on the first attempt:

```elixir
{:ok, counter} = Agent.start_link(fn -> 0 end)

{:ok, _result, %{source: :fallback, attempts: 1, reason: :auth}} =
  AgentJido.Demos.ProviderTimeoutFallback.complete(
    %{mode: :auth, fail_times: 0},
    max_attempts: 4, backoff_ms: 1,
    fallback: {:ok, %{model: "fallback-model", answer: "safe"}},
    counter: counter
  )

Agent.get(counter, & &1)   # => 1 — no retries
```

Auth does not fix itself by retrying. The wrapper applies the fallback immediately rather than burning the budget. Failing the Signal is a valid fallback rule too — pass `fallback: :fail` and the call surfaces `{:error, {:provider_unavailable, outcome}}` once the budget is exhausted or a terminal error occurs, instead of returning a fallback value.

## What this example shows and what it does not

This example proves two things directly: provider retries are bounded (a transient timeout is retried inside the budget; a persistent one stops at `max_attempts`), and the fallback is an explicit, observable rule (it fires on exhaustion or a terminal error, and the result is tagged `:fallback`).

It does not, by itself:

- **Recover process state.** A retry or a fallback recovers a call; it does not reconstruct state lost to a crash. Process recovery is supervision's job — see [Supervision and Failure Boundaries](/docs/operations/supervision-and-failure-boundaries).
- **Make work idempotent for you.** Falling back to a cheaper model or a cached result, then switching back when the primary recovers, requires idempotency keys or Signal IDs to confirm no work was duplicated. Wire those before raising a budget.
- **Ship a circuit breaker.** The bounded budget gives you the signal to trip one (a provider that keeps failing), but the breaker itself is an application concern; Jido does not ship one.
- **Guarantee success.** A bounded budget with a fallback bounds the blast radius of provider failure; it is not a guarantee the call will succeed. Confirm the failure path with a drill.
- **Serve as an audit trail.** Telemetry on provider failures is system understanding, not a tamper-evident audit log — see [Security and governance](/docs/operations/security-and-governance).

## Run it yourself

The example ships with a test that encodes the acceptance condition — a transient timeout retried (and recovering), a persistent timeout exhausting the budget at exactly `max_attempts`, the fallback firing on exhaustion and on a terminal error, and "fail the Signal" as a fallback rule:

```
mix test test/agent_jido/demos/provider_timeout_fallback_test.exs
```

The source is at `lib/agent_jido/demos/provider_timeout_fallback/provider_timeout_fallback.ex`.

> The end-to-end long-running reference application (`jido-e07-t29`) is the tracked follow-up that will fold this provider-timeout-and-fallback path into one runnable app. Until it lands, the example ships as a self-contained, tested demo — the same pattern the [tool error](/docs/operations/tool-error-and-retry-decision) and [process crash](/docs/operations/process-crash-and-restart) worked examples use.

## Next steps

- Read the full framework — tool, HTTP, and model failures, plus timeout and fallback rules — on [Retries, Timeouts, and Provider Failure](/docs/operations/retries-timeouts-and-provider-failure).
- See the retryable/terminal split play out at the tool layer in the [Tool Error and Retry Decision](/docs/operations/tool-error-and-retry-decision) worked example.
- Confirm your budgets and fallback rule against the [Production Readiness Checklist](/docs/operations/production-readiness-checklist).
- Practice a provider-timeout-and-fallback drill with the [Incident playbooks](/docs/operations/incident-playbooks).
