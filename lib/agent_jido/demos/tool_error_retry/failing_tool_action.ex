defmodule AgentJido.Demos.ToolErrorRetry.FailingToolAction do
  @moduledoc """
  A tool (Jido `Action`) that fails on demand to make the retry decision visible.

  This is the runnable example for the "Tool error and retry decision"
  operations page (`jido-e07-t11`). The same Action runs in three modes:

    * `:ok`        — succeeds on the first attempt.
    * `:retryable` — returns a `Jido.Action.Error.TimeoutError`. The exec layer
                     classifies a timeout as retryable, so the call is retried
                     with bounded exponential backoff.
    * `:terminal`  — returns a `Jido.Action.Error.InvalidInputError`. Bad input
                     is terminal: retrying the same input repeats the same
                     failure, so the exec layer does **not** retry it,
                     regardless of the configured budget.

  `fail_times` controls how many attempts fail before the Action succeeds, so a
  retryable failure can be observed both *recovering inside the budget*
  (`fail_times` <= `max_retries`) and *exhausting the budget*
  (`fail_times` > `max_retries`).

  The Action takes a `counter` pid from the call context — a simple `Agent`
  holding an integer — and bumps it on every invocation. The counter does two
  jobs: it tells the Action which attempt it is on (so it can decide whether to
  fail), and it lets a caller see exactly how many times the tool ran — the
  observable difference between a retried call and a terminal one. Because the
  counter is a separate process, it is correct whether the Action runs inline or
  under the exec layer's task timeout.
  """

  use Jido.Action,
    name: "failing_tool",
    description: "A tool that fails in a retryable or terminal way on demand.",
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

  # --- failure classification ------------------------------------------------

  # A timeout is the canonical *retryable* tool error: a transient stall that
  # may pass on the next attempt. The exec layer retries it by default.
  defp fail(:retryable, attempts) do
    {:error, Error.timeout_error("retryable tool error: timed out on attempt #{attempts}")}
  end

  # Bad input is the canonical *terminal* tool error: retrying the same bad
  # input reproduces the same failure, so the exec layer does not retry it.
  defp fail(:terminal, attempts) do
    {:error,
     Error.validation_error(
       "terminal tool error: invalid input on attempt #{attempts}",
       %{field: :mode, attempt: attempts}
     )}
  end

  # Default failure mode is a retryable execution failure (retryable by default,
  # overridable through the `:retry` hint). Kept for completeness.
  defp fail(_mode, attempts) do
    {:error,
     Error.execution_error(
       "retryable tool error: execution failed on attempt #{attempts}",
       %{retry: true}
     )}
  end

  # --- attempt accounting ----------------------------------------------------

  defp bump_attempts(%{counter: counter}) when is_pid(counter) do
    Agent.get_and_update(counter, fn n -> {n + 1, n + 1} end)
  end

  # No counter supplied: fall back to a process-local count so the Action is
  # still runnable in isolation (e.g. a quick IEx check with `timeout: 0`).
  defp bump_attempts(_context) do
    key = {__MODULE__, :attempts}
    attempts = Process.get(key, 0) + 1
    Process.put(key, attempts)
    attempts
  end
end
