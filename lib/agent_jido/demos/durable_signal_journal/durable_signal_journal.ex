defmodule AgentJido.Demos.DurableSignalJournal do
  @moduledoc """
  Optional durable Signal Journal step (jido-e05-T40).

  The tested example behind the "Optional durable history" control surface in
  the operational-controls onboarding lane: the reader chooses a Journal adapter
  and sees what survives a restart.

  "What survives a restart?" is answered entirely by the adapter the reader
  chooses:

    1. The default adapter (`Jido.Signal.Journal.Adapters.InMemory`) is NOT
       durable. A new journal built from it is a fresh, empty store, so a signal
       recorded before a restart is gone after it.

    2. A durable adapter keeps recorded signals across a journal restart. This
       demo uses the ETS adapter under a stable store so the store outlives any
       one journal instance; a fresh journal over the same store still reads a
       previously recorded signal.

  Nothing is durable until the reader chooses an adapter; the default retains
  nothing. The end-to-end Signal Journal reference — disc-backed storage that
  survives a full node restart, retention, deletion, and audit duties — is
  published on the Operations path (jido-e07).
  """

  alias Jido.Signal
  alias Jido.Signal.Journal
  alias Jido.Signal.Journal.Adapters.ETS
  alias Jido.Signal.Journal.Adapters.InMemory

  @doc """
  Builds a durable journal by choosing the ETS adapter, returning the journal
  and its owning store so the caller can stop it.

  ## Example

      {:ok, journal, _store} = AgentJido.Demos.DurableSignalJournal.durable_journal()
      {:ok, journal} = AgentJido.Demos.DurableSignalJournal.record(journal, signal)
      reopened = AgentJido.Demos.DurableSignalJournal.restart(journal)
      [_] = Jido.Signal.Journal.get_conversation(reopened, signal.subject)
      AgentJido.Demos.DurableSignalJournal.stop(reopened)
  """
  @spec durable_journal() :: {:ok, Journal.t(), pid()}
  def durable_journal do
    journal = Journal.new(ETS)
    {:ok, journal, journal.adapter_pid}
  end

  @doc """
  Records `signal` in `journal`, returning the updated journal.
  """
  @spec record(Journal.t(), Signal.t()) :: {:ok, Journal.t()} | {:error, term()}
  def record(journal, %Signal{} = signal) do
    Journal.record(journal, signal, nil)
  end

  @doc """
  Simulates a journal restart and returns the reopened journal.

  What survives is decided by the adapter the reader chose:

    * `InMemory` (the default) is not durable — a restart is a brand-new, empty
      store, so a previously recorded signal is gone.
    * `ETS` is durable across a journal restart — a fresh journal instance over
      the same store still reads a previously recorded signal.

  Read the reopened journal with `Jido.Signal.Journal.get_conversation/2` to see
  whether a signal survived.
  """
  @spec restart(Journal.t()) :: Journal.t()
  def restart(%Journal{adapter: InMemory}) do
    # The default is not durable: Journal.new/1 starts a fresh Agent with empty
    # state. There is no shared store to reopen.
    Journal.new(InMemory)
  end

  def restart(%Journal{adapter: ETS, adapter_pid: store_pid})
      when not is_nil(store_pid) do
    # A durable adapter owns its store: a fresh journal instance over the same
    # owner process reopens the same tables, so recorded signals survive.
    %Journal{adapter: ETS, adapter_pid: store_pid}
  end

  @doc """
  Stops a durable journal's owning store. Safe to call once the store is gone.
  """
  @spec stop(Journal.t()) :: :ok
  def stop(%Journal{adapter: ETS, adapter_pid: store_pid}) do
    ETS.cleanup(store_pid)
  end

  def stop(_), do: :ok
end
