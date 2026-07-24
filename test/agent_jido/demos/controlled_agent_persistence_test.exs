defmodule AgentJido.Demos.ControlledAgentPersistenceTest do
  @moduledoc """
  State recovery for the controlled agent (jido-e07-T13): approved state
  survives an application restart via hibernate/thaw.
  """
  use ExUnit.Case, async: false

  alias AgentJido.Demos.ControlledAgent
  alias Jido.AgentServer
  alias Jido.Persist
  alias Jido.Signal
  alias Jido.Storage.ETS

  test "approved state survives a restart via hibernate/thaw" do
    table = String.to_atom("controlled_persist_#{System.unique_integer([:positive])}")
    storage = {ETS, table: table}

    {:ok, pid} =
      AgentServer.start_link(
        jido: AgentJido.Jido,
        agent: ControlledAgent,
        id: "controlled-restart-#{System.unique_integer([:positive])}"
      )

    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid, :normal) end)

    {:ok, _} = AgentServer.call(pid, Signal.new!("work.approve", %{note: "x"}, source: "alice"))
    {:ok, st} = AgentServer.state(pid)
    agent_id = st.agent.id
    assert st.agent.state.approved_count == 1

    # Simulate an application restart: persist, drop, restore.
    :ok = Persist.hibernate(storage, st.agent)
    assert {:ok, restored} = Persist.thaw(storage, ControlledAgent, agent_id)
    assert restored.state.approved_count == 1
  end
end
