defmodule AgentJido.Demos.ControlledAgentTest do
  @moduledoc """
  Controlled-agent reference demo (jido-e07): proves the fail-closed
  authorization hook. An unauthorized principal cannot run the protected
  Action; an allowed principal can. Covers jido-e05-T35, jido-e07-T39,
  jido-e08-T38, jido-e12-T40.
  """
  use ExUnit.Case, async: false

  alias AgentJido.Demos.ControlledAgent
  alias Jido.AgentServer
  alias Jido.Signal

  test "an unauthorized principal cannot run the protected Action" do
    {:ok, pid} = start_server()

    # prepare_action/3 fails closed: the action never runs.
    _ = AgentServer.call(pid, Signal.new!("work.approve", %{note: "x"}, source: "mallory"))

    assert agent_state(pid).approved_count == 0
  end

  test "an allowed principal can run the protected Action" do
    {:ok, pid} = start_server()

    {:ok, _agent} =
      AgentServer.call(pid, Signal.new!("work.approve", %{note: "x"}, source: "alice"))

    assert agent_state(pid).approved_count == 1
  end

  defp start_server do
    {:ok, pid} =
      AgentServer.start_link(
        jido: AgentJido.Jido,
        agent: ControlledAgent,
        id: "controlled-#{System.unique_integer([:positive])}"
      )

    on_exit(fn ->
      if Process.alive?(pid), do: GenServer.stop(pid, :normal)
    end)

    {:ok, pid}
  end

  defp agent_state(pid) do
    {:ok, st} = AgentServer.state(pid)
    st.agent.state
  end
end
