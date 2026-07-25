%{
  description: "A worked example of one tool-error retry decision: a retryable error is retried inside a bounded budget, a terminal error is not retried at all.",
  title: "Tool Error and Retry Decision",
  category: :docs,
  legacy_paths: [],
  tags: [:docs, :operations],
  order: 362,
  draft: false
}
---
# Tool Error and Retry Decision

[Retries, Timeouts, and Provider Failure](/docs/operations/retries-timeouts-and-provider-failure) states the rule: when a tool (a Jido `Action`) fails, the exec layer decides whether to retry based on the **error type**, not a guess. This page is the worked example. It takes one tool that can fail two ways and shows the decision playing out — a retryable error retried inside a bounded budget, and a terminal error that is not retried at all.

The retry decision lives at the call boundary, in `Jido.Exec`. It is separate from process-level recovery: a retry replays a call against the agent's current state, while [Supervision and Failure Boundaries](/docs/operations/supervision-and-failure-boundaries) restarts a crashed process. This example isolates the call-boundary decision so you can see it on its own.

## The decision rule

A tool `Action` returns `{:ok, result}`, `{:ok, result, effects}`, or `{:error, error}` from its `run/2`. On an error, the exec layer asks `Jido.Action.Error.retryable?/1` whether the error is worth retrying:

| Tool error | Retryable? | Why |
|---|---|---|
| `InvalidInputError` (validation) | **No** — terminal | Bad input. Retrying the same input repeats the same failure. |
| `ConfigurationError` | **No** — terminal | The Action is misconfigured; retry cannot fix it. |
| `TimeoutError` | **Yes** — retryable | A transient stall that may pass on the next attempt. |
| `ExecutionFailureError` | Yes by default | Transient runtime failure; overridable through a `:retry` hint. |

The split is by error type. A timeout is retryable; invalid input is terminal. An Action can also mark its own execution error terminal with a `retry: false` hint, so a tool that knows its failure is permanent does not burn the budget. The full table for tool, HTTP, and model failures is on the [retries guide](/docs/operations/retries-timeouts-and-provider-failure).

When an error is retryable, the exec layer retries with **bounded** exponential backoff: `max_retries` (default `1`) attempts after the first, `backoff` (default `250 ms`) doubling with each retry and capped at 30 s. The budget — not the classifier — is what stops a retryable error from looping forever.

## The example tool

The runnable example is a single Action, `AgentJido.Demos.ToolErrorRetry.FailingToolAction`, that fails on demand. It takes a `mode` and a `fail_times`:

- `mode: :retryable` returns a `TimeoutError` (retryable).
- `mode: :terminal` returns an `InvalidInputError` (terminal).
- `fail_times` is how many attempts fail before the Action succeeds, so a retryable failure can be watched both *recovering* and *exhausting the budget*.

```elixir
defmodule AgentJido.Demos.ToolErrorRetry.FailingToolAction do
  use Jido.Action,
    name: "failing_tool",
    schema: [
      mode: [type: :atom, default: :ok],
      fail_times: [type: :integer, default: 0]
    ]

  alias Jido.Action.Error

  @impl true
  def run(%{mode: mode, fail_times: fail_times}, context) do
    attempts = bump_attempts(context)

    if attempts <= fail_times do
      fail(mode, attempts)
    else
      {:ok, %{status: :ok, attempts: attempts}}
    end
  end

  # A timeout is the canonical retryable tool error.
  defp fail(:retryable, attempts) do
    {:error, Error.timeout_error("retryable tool error: timed out on attempt #{attempts}")}
  end

  # Bad input is the canonical terminal tool error.
  defp fail(:terminal, attempts) do
    {:error,
     Error.validation_error(
       "terminal tool error: invalid input on attempt #{attempts}",
       %{field: :mode, attempt: attempts}
     )}
  end
end
```

To see how many times the tool actually ran, the example carries a `counter` (a simple `Agent` holding an integer) in the call context. The Action bumps it on every invocation, so the count is observable whether it runs inline or under the exec layer's task timeout.

## A retryable error is retried

Fail twice with a retryable timeout, then succeed on the third attempt. With `max_retries: 3` the budget allows up to four attempts, so the call recovers:

```elixir
{:ok, counter} = Agent.start_link(fn -> 0 end)

{:ok, %{attempts: 3}} =
  Jido.Exec.run(
    FailingToolAction,
    %{mode: :retryable, fail_times: 2},
    %{counter: counter},
    max_retries: 3, backoff: 1, timeout: 0
  )

Agent.get(counter, & &1)   # => 3 — the tool ran three times
```

The tool ran three times. The transient timeout was retried, not abandoned.

If the failure never clears, the budget stops it. With `fail_times: 99`, every attempt fails, so the bounded budget is exhausted (one initial attempt plus three retries), and the call returns the error:

```elixir
{:error, %Jido.Action.Error.TimeoutError{} = error} =
  Jido.Exec.run(
    FailingToolAction,
    %{mode: :retryable, fail_times: 99},
    %{counter: counter},
    max_retries: 3, backoff: 1, timeout: 0
  )

Agent.get(counter, & &1)                  # => 4 — initial attempt + 3 retries
Jido.Action.Error.retryable?(error)       # => true (still classified retryable)
```

The error is still classified retryable. The classifier did not stop the retries — the budget did. That is the point of a bounded budget: a retryable error cannot loop without limit.

## A terminal error is not retried

Run the same tool with a terminal error and the same generous budget. The tool runs **once** and the call returns the failure immediately:

```elixir
{:ok, counter} = Agent.start_link(fn -> 0 end)

{:error, %Jido.Action.Error.InvalidInputError{} = error} =
  Jido.Exec.run(
    FailingToolAction,
    %{mode: :terminal, fail_times: 99},
    %{counter: counter},
    max_retries: 3, backoff: 1, timeout: 0
  )

Agent.get(counter, & &1)                  # => 1 — no retries
Jido.Action.Error.retryable?(error)       # => false
```

Invalid input is terminal. Retrying the same bad input would reproduce the same failure, so the exec layer does not spend the budget. The fix for a terminal error is upstream — correct the input, the schema, or the configuration — not another attempt.

## What this example shows and what it does not

This example proves one thing directly: the retry decision is by error type, and it is observable. A retryable tool error is retried inside a bounded budget; a terminal tool error is not retried at all.

It does not, by itself:

- **Recover process state.** A retry replays a call against current state; it does not reconstruct state lost to a crash. That is supervision's job — see [Supervision and Failure Boundaries](/docs/operations/supervision-and-failure-boundaries).
- **Make a side-effecting tool safe to retry.** Retrying a tool that writes externally requires idempotency keys or Signal IDs, wired before you raise a budget. See [Incident playbooks](/docs/operations/incident-playbooks) for poison-work and dead-letter handling.
- **Serve as an audit trail.** Telemetry on retries and failures is system understanding, not a tamper-evident audit log — see [Security and governance](/docs/operations/security-and-governance).

## Run it yourself

The example ships with a test that encodes the acceptance condition — a retryable error retried (and recovering), a retryable error exhausting the budget, and a terminal error not retried:

```
mix test test/agent_jido/demos/tool_error_retry_test.exs
```

The source is at `lib/agent_jido/demos/tool_error_retry/failing_tool_action.ex`.

## Next steps

- Read the full framework — tool, HTTP, and model failures, plus timeout and fallback rules — on [Retries, Timeouts, and Provider Failure](/docs/operations/retries-timeouts-and-provider-failure).
- Pair the retry budget with process-level recovery in [Supervision and Failure Boundaries](/docs/operations/supervision-and-failure-boundaries).
- Handle work that fails every time with the dead-letter path in [Incident playbooks](/docs/operations/incident-playbooks).
- Confirm your budgets and fallback rule against the [Production Readiness Checklist](/docs/operations/production-readiness-checklist).
