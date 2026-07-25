defmodule AgentJido.Demos.ProviderTimeoutFallbackTest do
  @moduledoc """
  Runnable proof for the "Provider timeout and fallback" example (jido-e07-t16).

  Acceptance: "The example has bounded retries and an explicit fallback rule."

  These tests exercise the application wrapper (`complete/2`) over a scripted,
  simulated provider and assert both halves of the acceptance:

    * **bounded retries** — a transient provider timeout is retried inside the
      budget (and recovers); a persistent timeout is retried only up to
      `max_attempts` (and stops — never unbounded);
    * **an explicit fallback rule** — when the budget is exhausted the
      fallback fires and the result is tagged `source: :fallback`; a terminal
      error fires the fallback immediately, with no retries; and "fail the
      Signal" is a valid fallback rule too.

  Attempt counts are read from a `counter` `Agent` carried alongside the
  options, which stays correct across the wrapper's retry loop.
  """

  use ExUnit.Case, async: false

  alias AgentJido.Demos.ProviderTimeoutFallback, as: Demo

  # backoff_ms: 1 keeps the suite fast while still exercising the real
  # bounded-retry loop. The fallback is a cheaper "fallback-model" answer.
  @opts [
    max_attempts: 4,
    backoff_ms: 1,
    fallback: {:ok, %{model: "fallback-model", answer: "safe"}}
  ]

  describe "bounded retries" do
    test "a transient timeout is retried and recovers inside the budget" do
      counter = start_counter()

      # The provider times out twice, then answers. With max_attempts: 4 the
      # budget allows up to four attempts, so three calls recover.
      assert {:ok, %{model: "primary-model"}, %{source: :primary, attempts: 3}} =
               Demo.complete(%{mode: :timeout, fail_times: 2}, put_counter(@opts, counter))

      # The provider was actually called three times — the call was retried,
      # not abandoned.
      assert counter_value(counter) == 3
    end

    test "a persistent timeout retries only up to the budget, never unbounded" do
      counter = start_counter()

      # The provider never answers. The bounded budget is exhausted at exactly
      # max_attempts calls — the loop does not run forever.
      assert {:ok, _result, %{source: :fallback, attempts: 4}} =
               Demo.complete(%{mode: :timeout, fail_times: 99}, put_counter(@opts, counter))

      assert counter_value(counter) == 4
    end
  end

  describe "the explicit fallback rule" do
    test "fires on budget exhaustion and tags the result as fallback" do
      counter = start_counter()

      assert {:ok, fallback_result, meta} =
               Demo.complete(%{mode: :rate_limit, fail_times: 99}, put_counter(@opts, counter))

      # The fallback result is the caller's rule (a cheaper model), not a
      # primary answer, and it records why it fired.
      assert meta.source == :fallback
      assert fallback_result == %{model: "fallback-model", answer: "safe"}
      assert meta.reason == :rate_limit
    end

    test "fires immediately for a terminal error, with no retries" do
      counter = start_counter()

      # Auth is terminal: the budget is never spent. The fallback fires on the
      # first attempt.
      assert {:ok, _result, %{source: :fallback, attempts: 1, reason: :auth}} =
               Demo.complete(%{mode: :auth, fail_times: 0}, put_counter(@opts, counter))

      assert counter_value(counter) == 1
    end

    test "can fail the Signal when that is the chosen rule" do
      counter = start_counter()

      opts = [max_attempts: 2, backoff_ms: 1, fallback: :fail]

      assert {:error, {:provider_unavailable, %{status: :timeout}}} =
               Demo.complete(%{mode: :timeout, fail_times: 99}, put_counter(opts, counter))

      # Still bounded: the budget ran out at max_attempts, then the call
      # surfaced an error rather than looping.
      assert counter_value(counter) == 2
    end
  end

  defp start_counter do
    {:ok, pid} =
      Agent.start_link(fn -> 0 end, name: :"provider-counter-#{System.unique_integer([:positive])}")

    on_exit(fn -> if Process.alive?(pid), do: Agent.stop(pid) end)
    pid
  end

  defp counter_value(pid), do: Agent.get(pid, & &1)
  defp put_counter(opts, counter), do: Keyword.put(opts, :counter, counter)
end
