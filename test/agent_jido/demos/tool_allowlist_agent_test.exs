defmodule AgentJido.Demos.ToolAllowlistAgentTest do
  @moduledoc """
  Tool/effect allowlist (jido-e07-T41 / jido-e08-T40): an allowlisted tool
  runs; a disallowed tool is denied before execution.
  """
  use ExUnit.Case, async: false

  alias AgentJido.Demos.ToolAllowlistAgent
  alias Jido.AgentServer
  alias Jido.Signal

  test "an allowlisted tool runs and a disallowed tool is denied" do
    {:ok, pid} = start_server()

    {:ok, _} = AgentServer.call(pid, Signal.new!("tool.search", %{q: "x"}, source: "alice"))
    assert state(pid).search_count == 1

    _ = AgentServer.call(pid, Signal.new!("tool.delete", %{id: "x"}, source: "alice"))
    assert state(pid).delete_count == 0
  end

  defp start_server do
    {:ok, pid} =
      AgentServer.start_link(
        jido: AgentJido.Jido,
        agent: ToolAllowlistAgent,
        id: "tool-allowlist-#{System.unique_integer([:positive])}"
      )

    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid, :normal) end)
    {:ok, pid}
  end

  defp state(pid) do
    {:ok, st} = AgentServer.state(pid)
    st.agent.state
  end
end
