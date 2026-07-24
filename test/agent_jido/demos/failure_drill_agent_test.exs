defmodule AgentJido.Demos.FailureDrillAgentTest do
  use ExUnit.Case, async: false

  alias AgentJido.Demos.FailureDrill.Supervisor, as: DrillSupervisor
  alias AgentJido.Demos.FailureDrill.TickAction
  alias AgentJido.Demos.FailureDrillAgent

  alias Jido.AgentServer
  alias Jido.Signal

  describe "FailureDrillAgent.new/0" do
    test "creates an agent with a zeroed tick counter" do
      agent = FailureDrillAgent.new()
      assert agent.state.ticks == 0
    end
  end

  describe "TickAction" do
    test "increments the tick counter through cmd/2" do
      agent = FailureDrillAgent.new()

      {agent, _directives} = FailureDrillAgent.cmd(agent, {TickAction, %{by: 1}})
      assert agent.state.ticks == 1

      {agent, _directives} = FailureDrillAgent.cmd(agent, {TickAction, %{by: 4}})
      assert agent.state.ticks == 5
    end
  end

  describe "supervised restart" do
    test "the supervisor restarts the AgentServer after a crash and resets in-memory state" do
      sup = start_supervised!(DrillSupervisor)

      pid1 = DrillSupervisor.agent_server_pid(sup)
      assert is_pid(pid1)

      # Accumulate state in the running process.
      Enum.each(1..3, fn _ ->
        {:ok, _agent} =
          AgentServer.call(pid1, Signal.new!("failure_drill.tick", %{by: 1}, source: "/test"))
      end)

      {:ok, %{agent: agent_before}} = AgentServer.state(pid1)
      assert agent_before.state.ticks == 3

      # Crash the process the way a real process-level failure would.
      Process.exit(pid1, :kill)

      # The supervisor restarts it with a fresh pid.
      pid2 = await_restart(sup, pid1)
      assert is_pid(pid2)
      assert pid2 != pid1
      assert Process.alive?(pid2)

      # OTP restarted the process, not its memory: the tick counter is gone.
      {:ok, %{agent: agent_after}} = AgentServer.state(pid2)
      assert agent_after.state.ticks == 0
    end

    test "the supervised AgentServer handles ticks after restart" do
      sup = start_supervised!(DrillSupervisor)

      pid1 = DrillSupervisor.agent_server_pid(sup)
      Process.exit(pid1, :kill)

      pid2 = await_restart(sup, pid1)

      {:ok, agent} =
        AgentServer.call(pid2, Signal.new!("failure_drill.tick", %{by: 2}, source: "/test"))

      assert agent.state.ticks == 2
    end
  end

  defp await_restart(sup, old_pid, attempts \\ 100)
  defp await_restart(_sup, _old_pid, 0), do: nil

  defp await_restart(sup, old_pid, attempts) do
    case DrillSupervisor.agent_server_pid(sup) do
      pid when is_pid(pid) and pid != old_pid ->
        pid

      _other ->
        Process.sleep(5)
        await_restart(sup, old_pid, attempts - 1)
    end
  end
end
