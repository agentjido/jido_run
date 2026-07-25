defmodule AgentJido.Demos.PoisonWorkDeadLetterTest do
  @moduledoc """
  Runnable proof for the "Poison work and dead-letter handling" example
  (jido-e07-t17).

  Acceptance: "Failed work can be inspected and replayed."

  These tests exercise the orchestration (`process/2`, `replay/3`) over a
  scripted `Worker` (the external dependency) and a `DeadLetterStore`, and
  assert both halves of the acceptance:

    * **inspected** — poison work that exhausts the bounded budget is moved to
      the dead-letter store as an entry carrying the original work, the failure
      reason, the attempt count, and an id — so the failure is inspectable, not
      dropped;
    * **replayed** — a dead-lettered entry can be re-submitted; once the
      underlying cause is fixed (`Worker.fix/1`) the replay succeeds and the
      entry leaves the store, and a replay that still fails updates the same
      entry rather than creating a duplicate.

  They also pin the framing: the budget is bounded (a poison item is tried
  exactly `max_attempts` times, never unbounded), and healthy work is never
  dead-lettered.
  """

  use ExUnit.Case, async: false

  alias AgentJido.Demos.PoisonWorkDeadLetter, as: Demo
  alias AgentJido.Demos.PoisonWorkDeadLetter.DeadLetterStore
  alias AgentJido.Demos.PoisonWorkDeadLetter.Worker

  # The external dependency the work calls. :broken => every run fails (poison
  # work); :healthy => every run succeeds. backoff_ms: 0 keeps the suite fast
  # while still exercising the real bounded-retry loop.
  @charge %{id: "charge-1", amount: 42, dep: :payment_gateway}

  describe "healthy work is processed, not dead-lettered" do
    test "succeeding work returns ok and leaves the store empty" do
      worker = start_worker(mode: :healthy)
      store = start_store()
      counter = start_counter()

      assert {:ok, %{processed: @charge}} =
               Demo.process(@charge, opts(worker, store, counter, max_attempts: 3))

      # The worker answered on the first attempt — no retries, no dead-letter.
      assert counter_value(counter) == 1
      assert DeadLetterStore.entries(store) == []

      stop(worker)
      stop(store)
    end
  end

  describe "poison work is bounded, then dead-lettered" do
    test "a persistent failure is retried only up to the budget, never unbounded" do
      worker = start_worker(mode: :broken)
      store = start_store()
      counter = start_counter()

      # The dependency is down, so every attempt fails. The bounded budget is
      # exhausted at exactly max_attempts calls — the loop does not run forever.
      assert {:dead_lettered, _entry_id} =
               Demo.process(@charge, opts(worker, store, counter, max_attempts: 3))

      assert counter_value(counter) == 3

      stop(worker)
      stop(store)
    end

    test "the dead-lettered work lands in the store exactly once" do
      worker = start_worker(mode: :broken)
      store = start_store()
      counter = start_counter()

      assert {:dead_lettered, _entry_id} =
               Demo.process(@charge, opts(worker, store, counter, max_attempts: 3))

      assert length(DeadLetterStore.entries(store)) == 1

      stop(worker)
      stop(store)
    end
  end

  describe "failed work can be inspected" do
    test "the entry carries the original work, the reason, the attempt count, and an id" do
      worker = start_worker(mode: :broken)
      store = start_store()
      counter = start_counter()

      assert {:dead_lettered, entry_id} =
               Demo.process(@charge, opts(worker, store, counter, max_attempts: 3))

      entry = DeadLetterStore.get(store, entry_id)

      # The acceptance condition: the failure is inspectable. The entry exposes
      # what failed (the original work), why (the reason), how many times it was
      # tried (attempts), and a stable id to act on.
      assert entry.id == entry_id
      assert entry.work == @charge
      assert entry.reason == {:dependency_down, :payment_gateway}
      assert entry.attempts == 3

      stop(worker)
      stop(store)
    end

    test "the store lists every dead-lettered item for an operator to review" do
      worker = start_worker(mode: :broken)
      store = start_store()
      counter = start_counter()

      # Two distinct poison items.
      Demo.process(@charge, opts(worker, store, counter, max_attempts: 2))

      other = %{id: "charge-2", amount: 7, dep: :payment_gateway}
      Demo.process(other, opts(worker, store, counter, max_attempts: 2))

      entries = DeadLetterStore.entries(store)
      assert length(entries) == 2
      assert Enum.map(entries, & &1.work) |> Enum.member?(@charge)
      assert Enum.map(entries, & &1.work) |> Enum.member?(other)

      stop(worker)
      stop(store)
    end
  end

  describe "failed work can be replayed" do
    test "after the cause is fixed, replay succeeds and the entry leaves the store" do
      worker = start_worker(mode: :broken)
      store = start_store()
      counter = start_counter()

      assert {:dead_lettered, entry_id} =
               Demo.process(@charge, opts(worker, store, counter, max_attempts: 3))

      # The dependency comes back. Replaying the dead-lettered entry now
      # succeeds — the work has left the failed state.
      Worker.fix(worker)

      assert {:ok, %{processed: @charge}} =
               Demo.replay(store, entry_id, opts(worker, store, counter, max_attempts: 3))

      # The entry is gone from the dead-letter store.
      assert DeadLetterStore.get(store, entry_id) == nil
      assert DeadLetterStore.entries(store) == []

      stop(worker)
      stop(store)
    end

    test "a replay that still fails updates the same entry, not a duplicate" do
      worker = start_worker(mode: :broken)
      store = start_store()
      counter = start_counter()

      assert {:dead_lettered, entry_id} =
               Demo.process(@charge, opts(worker, store, counter, max_attempts: 3))

      # The dependency is still down, so the replay fails again — but it must
      # not spawn a second dead-letter entry.
      assert {:dead_lettered, ^entry_id} =
               Demo.replay(store, entry_id, opts(worker, store, counter, max_attempts: 3))

      entries = DeadLetterStore.entries(store)
      assert length(entries) == 1
      assert hd(entries).id == entry_id
      # The replay-attempt counter advanced on the renewed failure.
      assert hd(entries).replay_attempts == 1

      stop(worker)
      stop(store)
    end
  end

  # --- helpers ----------------------------------------------------------------

  defp start_worker(opts) do
    {:ok, pid} = Worker.start_link(opts)
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    pid
  end

  defp start_store do
    {:ok, pid} = DeadLetterStore.start_link([])
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    pid
  end

  defp start_counter do
    {:ok, pid} =
      Agent.start_link(fn -> 0 end, name: :"dlq-counter-#{System.unique_integer([:positive])}")

    on_exit(fn -> if Process.alive?(pid), do: Agent.stop(pid) end)
    pid
  end

  defp counter_value(pid), do: Agent.get(pid, & &1)

  defp opts(worker, store, counter, overrides) do
    [worker: worker, store: store, counter: counter, backoff_ms: 0]
    |> Keyword.merge(overrides)
  end

  defp stop(pid), do: GenServer.stop(pid, :normal, :infinity)
end
