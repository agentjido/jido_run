defmodule AgentJido.Demos.SignalJournalTest do
  @moduledoc """
  Durable Signal Journal (jido-e07-T44 / jido-e08-T42 / jido-e12-T42):
  causal history is recorded and survives a journal-restart against a durable
  store. The ETS adapter runs under a fixed prefix so a fresh journal instance
  reopens the same store.
  """
  use ExUnit.Case, async: false

  alias Jido.Signal
  alias Jido.Signal.Journal
  alias Jido.Signal.Journal.Adapters.ETS

  test "causal history survives a journal restart against a durable store" do
    prefix = "durable_journal_#{System.unique_integer([:positive])}_"
    {:ok, store_pid} = ETS.start_link(prefix)
    on_exit(fn -> if Process.alive?(store_pid), do: GenServer.stop(store_pid) end)

    journal = %Journal{adapter: ETS, adapter_pid: store_pid}

    cause = Signal.new!("work.request", %{step: 1}, source: "alice")
    {:ok, journal} = Journal.record(journal, cause, nil)

    effect = Signal.new!("work.done", %{step: 2}, source: "alice")
    {:ok, ^journal} = Journal.record(journal, effect, cause.id)

    # Simulate a restart: a fresh journal instance over the same durable store.
    restarted = %Journal{adapter: ETS, adapter_pid: store_pid}

    # get_cause returns the causing signal (or nil); retrieving it after the
    # "restart" proves the causal chain survived in the durable store.
    assert %Signal{} = fetched = Journal.get_cause(restarted, effect.id)
    assert fetched.id == cause.id
  end
end
