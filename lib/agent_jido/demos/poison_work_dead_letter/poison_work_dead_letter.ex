defmodule AgentJido.Demos.PoisonWorkDeadLetter do
  @moduledoc """
  A worked example of poison-work and dead-letter handling for the
  "Poison work and dead-letter handling" operations page (`jido-e07-t17`).

  Acceptance: "Failed work can be inspected and replayed."

  When a piece of work fails every time — *poison work* — retrying it without
  limit poisons the queue: it burns budget, blocks later work, and loops
  without end. The dead-letter pattern bounds that. After a **bounded** retry
  budget is exhausted, the failed work is moved to a dead-letter store, where
  an operator can **inspect** it (what failed, why, how many times it was
  tried) and later **replay** it once the underlying cause is fixed.

  Jido does not ship a dead-letter queue. The Signal Journal is the closest
  durable-history surface, and the routing, retention, and replay policy is an
  **application concern**. This example isolates that rule so you can see
  inspect-and-replay on its own, the same way the tool-error and
  provider-timeout worked examples isolate their layers.

  The example makes both halves of the acceptance observable:

    * **inspected** — a dead-lettered entry carries the original work, the
      failure reason, the attempt count, and an id, so the failure is
      inspectable rather than dropped or lost in a log.
    * **replayed** — a dead-lettered entry can be re-submitted to the worker;
      once the underlying cause is fixed the replay succeeds and the entry
      leaves the dead-letter store.

  See `priv/pages/docs/operations/poison-work-and-dead-letter.md` and the
  acceptance test `test/agent_jido/demos/poison_work_dead_letter_test.exs`.
  """

  alias __MODULE__.DeadLetterStore
  alias __MODULE__.Worker

  # Default bounded retry budget. Bounded, not unbounded — this is the whole
  # point: poison work cannot loop without limit.
  @default_max_attempts 3
  @default_backoff_ms 0

  @doc """
  Process one work item against `worker` with a bounded retry budget.

  ## Options

    * `:worker` — **required**. The pid of a started `Worker` (models the
      external dependency the work calls).
    * `:store` — **required**. The pid of a started `DeadLetterStore`.
    * `:max_attempts` — total attempts including the first (default
      `#{@default_max_attempts}`). The budget that bounds a poison item.
    * `:backoff_ms` — base backoff in ms, doubled per retry and capped at
      30 s (default `#{@default_backoff_ms}`).
    * `:counter` — a pid (an `Agent` holding an integer) bumped on every worker
      attempt, so the bounded retry count is observable across the loop.

  ## Returns

    * `{:ok, result}` when the worker answered within the budget.
    * `{:dead_lettered, entry_id}` when the budget was exhausted (poison work).
      The work is moved to the dead-letter store for inspection and replay.
  """
  def process(work, opts) do
    worker = Keyword.fetch!(opts, :worker)
    store = Keyword.fetch!(opts, :store)
    max_attempts = Keyword.get(opts, :max_attempts, @default_max_attempts)
    backoff_ms = Keyword.get(opts, :backoff_ms, @default_backoff_ms)
    counter = Keyword.get(opts, :counter)

    case run_with_budget(worker, work, 1, max_attempts, backoff_ms, counter) do
      {:ok, result, _attempts} ->
        {:ok, result}

      {:error, reason, attempts} ->
        # Budget exhausted — poison work. Move it to the dead-letter store for
        # inspection and later replay, rather than retrying without limit.
        entry_id = DeadLetterStore.put(store, %{work: work, reason: reason, attempts: attempts})
        {:dead_lettered, entry_id}
    end
  end

  @doc """
  Replay a dead-lettered entry: re-run its work against `worker` with a bounded
  retry budget.

  On success the entry is removed from the dead-letter store (the work has left
  the failed state) and `{:ok, result}` is returned. On renewed failure the
  *same* entry is updated in place — no duplicate — and `{:dead_lettered,
  entry_id}` is returned again.

  `store` is the store the entry lives in. The remaining options are the same
  as `process/2` (`:worker` is required; `:max_attempts`, `:backoff_ms`, and
  `:counter` are optional).
  """
  def replay(store, entry_id, opts) do
    entry = DeadLetterStore.get(store, entry_id)
    worker = Keyword.fetch!(opts, :worker)
    max_attempts = Keyword.get(opts, :max_attempts, @default_max_attempts)
    backoff_ms = Keyword.get(opts, :backoff_ms, @default_backoff_ms)
    counter = Keyword.get(opts, :counter)

    case run_with_budget(worker, entry.work, 1, max_attempts, backoff_ms, counter) do
      {:ok, result, _attempts} ->
        # The underlying cause is fixed — the replay succeeded, so the work
        # leaves the dead-letter store.
        DeadLetterStore.remove(store, entry_id)
        {:ok, result}

      {:error, reason, attempts} ->
        # Still failing — keep the same entry (no duplicate), updated in place.
        DeadLetterStore.update(store, entry_id, %{reason: reason, attempts: attempts})
        {:dead_lettered, entry_id}
    end
  end

  defp run_with_budget(worker, work, attempt, max_attempts, backoff_ms, counter) do
    bump(counter)

    case Worker.run(worker, work) do
      {:ok, result} ->
        {:ok, result, attempt}

      {:error, _reason} when attempt < max_attempts ->
        # Bounded retry: a transient failure is retried with backoff — but only
        # inside the budget.
        Worker.sleep_for(backoff_ms, attempt)
        run_with_budget(worker, work, attempt + 1, max_attempts, backoff_ms, counter)

      {:error, reason} ->
        # Budget exhausted. Stop retrying and hand the work to the caller,
        # which moves it to the dead-letter store.
        {:error, reason, attempt}
    end
  end

  # Observable attempt accounting — mirrors the tool-error and provider-timeout
  # worked examples. A separate counter process stays correct across the retry
  # loop.
  defp bump(nil), do: :ok

  defp bump(counter) when is_pid(counter) do
    Agent.get_and_update(counter, fn n -> {n + 1, n + 1} end)
  end

  # --- the simulated worker (models an external dependency) -------------------

  defmodule Worker do
    @moduledoc """
    A scripted, in-process stand-in for the external dependency a piece of work
    calls (a payment gateway, a downstream API). The worker has a `mode` the
    operator controls: `:healthy` runs succeed; `:broken` runs fail with a
    reason.

    `break/1` and `fix/1` model the dependency going down and coming back —
    the moment a dead-lettered item can be replayed to success. Poison work is
    simply work processed while the dependency is `:broken`.
    """

    use GenServer

    @capped_backoff_ms 30_000

    def start_link(opts \\ []) do
      mode = Keyword.get(opts, :mode, :healthy)
      GenServer.start_link(__MODULE__, mode)
    end

    def run(worker, work), do: GenServer.call(worker, {:run, work})
    def break(worker), do: GenServer.call(worker, {:set_mode, :broken})
    def fix(worker), do: GenServer.call(worker, {:set_mode, :healthy})
    def mode(worker), do: GenServer.call(worker, :get_mode)

    # Backoff doubles per attempt and caps at 30 s — the same shape as the exec
    # layer's tool-retry backoff.
    def sleep_for(base_ms, attempt) do
      backoff = trunc(base_ms * :math.pow(2, attempt - 1))
      Process.sleep(min(backoff, @capped_backoff_ms))
    end

    @impl true
    def init(mode), do: {:ok, %{mode: mode}}

    @impl true
    def handle_call({:run, work}, _from, %{mode: mode} = state) do
      result =
        case mode do
          :healthy -> {:ok, %{processed: work}}
          :broken -> {:error, {:dependency_down, work[:dep] || :downstream}}
        end

      {:reply, result, state}
    end

    @impl true
    def handle_call({:set_mode, mode}, _from, state) do
      {:reply, :ok, %{state | mode: mode}}
    end

    @impl true
    def handle_call(:get_mode, _from, state) do
      {:reply, state.mode, state}
    end
  end

  # --- the dead-letter store --------------------------------------------------

  defmodule DeadLetterStore do
    @moduledoc """
    An in-process store for work that exhausted its retry budget.

    Each entry carries the original work, the failure reason, and the attempt
    count, so a failed item can be **inspected** (what failed and why) and
    **replayed** (re-submitted once the underlying cause is fixed).

    Jido does not ship this. The Signal Journal is the closest durable-history
    surface; the routing, retention, and replay policy is an application
    concern. This in-memory store is the tested stand-in — durable backing,
    retention windows, and tamper-evidence are the application-owned follow-ons
    named on the page.
    """

    use GenServer

    defstruct [:id, :work, :reason, :attempts, :replay_attempts, :recorded_at]

    def start_link(opts \\ []) do
      GenServer.start_link(__MODULE__, :ok, opts)
    end

    def put(store, fields) when is_map(fields) do
      GenServer.call(store, {:put, fields})
    end

    def get(store, id), do: GenServer.call(store, {:get, id})
    def entries(store), do: GenServer.call(store, :entries)
    def update(store, id, fields), do: GenServer.call(store, {:update, id, fields})
    def remove(store, id), do: GenServer.call(store, {:remove, id})
    def clear(store), do: GenServer.call(store, :clear)

    @impl true
    def init(:ok), do: {:ok, %{entries: %{}, seq: 0}}

    @impl true
    def handle_call({:put, fields}, _from, %{seq: seq} = state) do
      seq = seq + 1
      id = entry_id(seq)

      entry = %__MODULE__{
        id: id,
        work: Map.get(fields, :work),
        reason: Map.get(fields, :reason),
        attempts: Map.get(fields, :attempts),
        replay_attempts: 0,
        recorded_at: DateTime.utc_now()
      }

      state = %{state | seq: seq, entries: Map.put(state.entries, id, entry)}
      {:reply, id, state}
    end

    @impl true
    def handle_call({:get, id}, _from, state) do
      {:reply, Map.get(state.entries, id), state}
    end

    @impl true
    def handle_call(:entries, _from, state) do
      {:reply, state.entries |> Map.values() |> Enum.sort_by(& &1.id), state}
    end

    @impl true
    def handle_call({:update, id, fields}, _from, state) do
      case Map.fetch(state.entries, id) do
        {:ok, entry} ->
          # A renewed failure on replay bumps the replay-attempt counter and
          # refreshes the reason/attempts — the same entry, not a duplicate.
          updated =
            entry
            |> struct(Map.take(fields, [:reason, :attempts]))
            |> Map.update!(:replay_attempts, &(&1 + 1))

          {:reply, :ok, %{state | entries: Map.put(state.entries, id, updated)}}

        :error ->
          {:reply, {:error, :not_found}, state}
      end
    end

    @impl true
    def handle_call({:remove, id}, _from, state) do
      {:reply, :ok, %{state | entries: Map.delete(state.entries, id)}}
    end

    @impl true
    def handle_call(:clear, _from, state) do
      {:reply, :ok, %{state | entries: %{}}}
    end

    defp entry_id(seq), do: "dlq-#{seq}"
  end
end
