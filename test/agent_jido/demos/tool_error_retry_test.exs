defmodule AgentJido.Demos.ToolErrorRetryTest do
  @moduledoc """
  Runnable proof for the "Tool error and retry decision" example (jido-e07-t11).

  Acceptance: "The example shows retryable and terminal errors."

  These tests exercise the actual Jido exec-layer retry decision
  (`Jido.Exec.run/4` -> `Jido.Exec.Retry.should_retry?/4` ->
  `Jido.Action.Error.retryable?/1`) on a single tool (`FailingToolAction`) and
  assert the observable difference:

    * a *retryable* tool error (TimeoutError) is retried within the bounded
      budget — it can recover, and it stops once the budget is exhausted;
    * a *terminal* tool error (InvalidInputError) is not retried at all, no
      matter how large the budget is.

  Attempt counts are read from a `counter` `Agent` carried in the call context,
  which works whether the Action runs inline or under the exec layer's task
  timeout.
  """

  use ExUnit.Case, async: false

  alias AgentJido.Demos.ToolErrorRetry.FailingToolAction
  alias Jido.Action.Error
  alias Jido.Exec

  # `backoff: 1` keeps the suite fast while still exercising the real retry path.
  @run_opts [max_retries: 3, backoff: 1, timeout: 0]

  describe "retryable tool error (TimeoutError)" do
    test "is retried and recovers inside the budget" do
      counter = start_counter()

      # Fail twice with a retryable timeout, then succeed on the third attempt.
      # With max_retries: 3 the budget allows up to 4 attempts, so 3 runs recover.
      assert {:ok, %{attempts: 3}} =
               Exec.run(
                 FailingToolAction,
                 %{mode: :retryable, fail_times: 2},
                 %{counter: counter},
                 @run_opts
               )

      # The tool actually ran three times — the call was retried, not abandoned.
      assert counter_value(counter) == 3
    end

    test "stops once the retry budget is exhausted" do
      counter = start_counter()

      # fail_times above max_retries: every attempt fails, so the bounded
      # budget is exhausted (1 initial attempt + 3 retries = 4 runs).
      assert {:error, %Error.TimeoutError{} = error} =
               Exec.run(
                 FailingToolAction,
                 %{mode: :retryable, fail_times: 99},
                 %{counter: counter},
                 @run_opts
               )

      assert counter_value(counter) == 4

      # The error is classified retryable, but the budget — not the classifier —
      # is what stopped the retries.
      assert Error.retryable?(error) == true
    end
  end

  describe "terminal tool error (InvalidInputError)" do
    test "is not retried, regardless of the budget" do
      counter = start_counter()

      # Same generous budget as above, but the error is terminal: the tool runs
      # exactly once and the call returns the failure immediately.
      assert {:error, %Error.InvalidInputError{} = error} =
               Exec.run(
                 FailingToolAction,
                 %{mode: :terminal, fail_times: 99},
                 %{counter: counter},
                 @run_opts
               )

      assert counter_value(counter) == 1
      assert Error.retryable?(error) == false
    end
  end

  describe "the retryable/terminal classification itself" do
    test "a timeout is retryable and invalid input is terminal" do
      # The decision the exec layer consults, stated directly.
      assert Error.retryable?(Error.timeout_error("transient stall")) == true

      assert Error.retryable?(Error.validation_error("bad input", %{field: :mode})) == false
    end
  end

  defp start_counter do
    {:ok, pid} =
      Agent.start_link(fn -> 0 end, name: :"tool-error-counter-#{System.unique_integer([:positive])}")

    on_exit(fn -> if Process.alive?(pid), do: Agent.stop(pid) end)
    pid
  end

  defp counter_value(pid), do: Agent.get(pid, & &1)
end
