defmodule AgentJido.Demos.DurableSignalJournalTest do
  @moduledoc """
  Optional durable Signal Journal step (jido-e05-T40): the tested example
  behind the "Optional durable history" control surface in the
  operational-controls onboarding lane. The reader chooses an adapter and sees
  what survives a restart.

  Two things are proven:

    * choosing the default `InMemory` adapter: a recorded signal is gone after a
      journal restart — the default is not durable;
    * choosing a durable adapter (`ETS`): a recorded signal survives a journal
      restart, because the store outlives the journal instance.

  Disc-backed storage that survives a full node restart is published on the
  Operations path (jido-e07); this onboarding example covers the adapter choice.
  """
  use ExUnit.Case, async: false

  alias AgentJido.Demos.DurableSignalJournal
  alias Jido.Signal
  alias Jido.Signal.Journal
  alias Jido.Signal.Journal.Adapters.InMemory

  describe "the reader chooses the default InMemory adapter" do
    # Acceptance: "The reader chooses an adapter and sees what survives restart."
    # With the default adapter, nothing does.
    test "a recorded signal is gone after a journal restart" do
      journal = Journal.new(InMemory)

      signal = recorded_signal()
      {:ok, journal} = DurableSignalJournal.record(journal, signal)

      # Sanity: the signal is present before the restart.
      [before] = Journal.get_conversation(journal, signal.subject)
      assert before.id == signal.id

      # The default adapter is not durable: a restart is a fresh, empty store.
      reopened = DurableSignalJournal.restart(journal)

      assert Journal.get_conversation(reopened, signal.subject) == []
    end
  end

  describe "the reader chooses a durable adapter" do
    # Acceptance: "... sees what survives restart." With a durable adapter, the
    # recorded signal survives.
    test "a recorded signal survives a journal restart" do
      {:ok, journal, _store} = DurableSignalJournal.durable_journal()
      on_exit(fn -> DurableSignalJournal.stop(journal) end)

      signal = recorded_signal()
      {:ok, journal} = DurableSignalJournal.record(journal, signal)

      # A fresh journal instance over the same durable store — the restart.
      reopened = DurableSignalJournal.restart(journal)

      [survivor] = Journal.get_conversation(reopened, signal.subject)
      assert survivor.id == signal.id
    end
  end

  defp recorded_signal do
    Signal.new!("work.recorded", %{step: 1},
      source: "alice",
      subject: "onboarding.order-42"
    )
  end
end
