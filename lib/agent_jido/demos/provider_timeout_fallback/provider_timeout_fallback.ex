defmodule AgentJido.Demos.ProviderTimeoutFallback do
  @moduledoc """
  A worked example of provider timeout and fallback for the
  "Provider timeout and fallback" operations page (`jido-e07-t16`).

  The model-failure layer is the one a long-running agent most often needs a
  **fallback rule** for, rather than a retry loop: when the primary provider
  is degraded, route to a cheaper model, a cached result, or a safe default —
  then switch back when it recovers. That rule is an *application* concern;
  Jido ships the call surface (`Jido.AI.Request`), not the fallback policy.

  This example makes both halves of the rule observable:

    * **bounded retries** — a retryable provider error (timeout, rate limit,
      transient 5xx) is retried a bounded number of times with backoff,
      never unbounded;
    * **an explicit fallback rule** — when the bounded budget is exhausted,
      or a terminal error occurs, the fallback fires and the returned result
      is tagged `source: :fallback`, so a caller can tell a primary answer
      from a recovered one.

  The provider call is simulated (`Provider`) so the decision plays out
  without a real provider key or network. `Provider` returns the same outcome
  shape the AI request exposes — `:completed | :timeout | :failed` — so the
  wrapper's retry/fallback branching is the code under test.

  See `priv/pages/docs/operations/provider-timeout-and-fallback.md` and the
  acceptance test `test/agent_jido/demos/provider_timeout_fallback_test.exs`.
  """

  # The nested simulated provider. Aliased so the wrapper calls read as
  # `Provider.call/2`, not the global `Provider`.
  alias __MODULE__.Provider

  # Default bounded retry budget. Bounded, not unbounded — this is the whole
  # point: a retryable provider timeout cannot loop without limit.
  @default_max_attempts 4
  @default_backoff_ms 1

  @doc """
  Run one completion against the (simulated) provider with bounded retries
  and an explicit fallback rule.

  ## Options

    * `:max_attempts` — total attempts including the first (default
      `#{@default_max_attempts}`). The budget that bounds a retryable timeout.
    * `:backoff_ms` — base backoff in ms, doubled per retry and capped at
      30 s (default `#{@default_backoff_ms}`).
    * `:fallback` — **required**. The explicit fallback rule applied when the
      budget is exhausted or a terminal error occurs. `{:ok, value}` models a
      cheaper-model / cached / safe-default result; `:fail` models failing the
      Signal (another valid fallback rule).
    * `:counter` — a pid (an `Agent` holding an integer) bumped on every
      provider attempt, so the bounded retry count is observable across the
      loop.

  ## Returns

    * `{:ok, result, %{source: :primary, attempts: n}}` when the provider
      answered within the budget.
    * `{:ok, result, %{source: :fallback, attempts: n, reason: atom}}` when
      the fallback rule fired (budget exhausted or terminal error).
    * `{:error, {:provider_unavailable, outcome}}` when the fallback rule is
      `:fail`.
  """
  def complete(request, opts \\ []) do
    max_attempts = Keyword.get(opts, :max_attempts, @default_max_attempts)
    backoff_ms = Keyword.get(opts, :backoff_ms, @default_backoff_ms)
    fallback = Keyword.fetch!(opts, :fallback)

    request
    |> do_complete(1, max_attempts, backoff_ms, fallback, Keyword.get(opts, :counter))
  end

  defp do_complete(request, attempt, max_attempts, backoff_ms, fallback, counter) do
    outcome = Provider.call(request, counter)

    case outcome do
      %{status: :completed, result: result} ->
        {:ok, result, %{source: :primary, attempts: attempt}}

      %{retryable?: true} when attempt < max_attempts ->
        # Bounded retry: a retryable provider error (timeout, 429, transient
        # 5xx) is retried with backoff — but only inside the budget.
        Provider.sleep_for(backoff_ms, attempt)
        do_complete(request, attempt + 1, max_attempts, backoff_ms, fallback, counter)

      _exhausted_or_terminal ->
        # A retryable error that exhausted the budget, OR a terminal error
        # (auth, refusal) that is never retried. Either way: stop retrying and
        # apply the explicit fallback rule.
        apply_fallback(outcome, attempt, fallback)
    end
  end

  defp apply_fallback(outcome, attempt, {:ok, value}) do
    {:ok, value, %{source: :fallback, attempts: attempt, reason: outcome.status}}
  end

  defp apply_fallback(outcome, _attempt, :fail) do
    # "Fail the Signal" is a valid fallback rule too. The bounded budget
    # bounds the blast radius; it does not promise success.
    {:error, {:provider_unavailable, outcome}}
  end

  # --- the simulated provider -------------------------------------------------

  defmodule Provider do
    @moduledoc """
    A scripted, in-process stand-in for an LLM provider call.

    It returns the outcome shape the AI request exposes
    (`%{status: :completed, result: result}`, `%{status: :timeout, ...}`, or
    `%{status: :failed, ...}`) and tags each failure `retryable?` so the
    wrapper's retry/fallback decision is the code under test — not a real
    network.

    The `request` is a script: `mode` selects which failure the provider
    returns and `fail_times` how many attempts fail before it answers, so a
    retryable failure can be watched both *recovering inside the budget* and
    *exhausting the budget*.
    """

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

    # Backoff doubles per attempt and caps at 30 s — the same shape as the
    # exec layer's tool-retry backoff.
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

    # Observable attempt accounting — mirrors the tool-error worked example.
    # A separate counter process is correct across the retry loop; without
    # one, a process-local count keeps the provider runnable in isolation.
    defp bump(nil) do
      key = {__MODULE__, :attempts}
      attempts = Process.get(key, 0) + 1
      Process.put(key, attempts)
      attempts
    end

    defp bump(counter) when is_pid(counter) do
      Agent.get_and_update(counter, fn n -> {n + 1, n + 1} end)
    end
  end
end
