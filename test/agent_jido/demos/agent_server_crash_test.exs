defmodule AgentJido.Demos.AgentServerCrashTest do
  @moduledoc """
  Runnable proof for the "Process crash and restart" example (`jido-e07-t12`).

  Acceptance: "The process restarts and the observed state result is explicit."

  These tests start a supervised `Jido.AgentServer`, accumulate observable
  state in it, crash the process the way a real process-level failure would
  (`Process.exit/2` with `:kill`), and assert the two things the acceptance
  requires:

    * the process **restarts** — a new pid comes back under the same supervisor,
      live and serving; and
    * the observed state result is **explicit** — `Jido.AgentServer.status/1`
      and `Jido.AgentServer.state/1` return a concrete result (not a guess),
      and that result is the agent's *initial* state. That proves supervision
      restarts the process but does not recover the in-memory state lost when
      the process died.
  """

  use ExUnit.Case, async: false

  alias AgentJido.Demos.AgentServerCrash.Supervisor, as: CrashSupervisor
  alias AgentJido.Demos.AgentServerCrashAgent

  alias Jido.AgentServer
  alias Jido.Signal

  describe "AgentServerCrashAgent.new/0" do
    test "creates an agent with a zeroed event counter" do
      agent = AgentServerCrashAgent.new()
      assert agent.state.events == 0
    end
  end

  describe "supervised process crash and restart" do
    test "the supervisor restarts the AgentServer after a crash (new pid, live)" do
      sup = start_supervised!(CrashSupervisor)

      pid1 = CrashSupervisor.agent_server_pid(sup)
      assert is_pid(pid1)

      # Crash the process the way a real process-level failure would.
      Process.exit(pid1, :kill)

      # The supervisor restarts it with a fresh pid.
      pid2 = await_restart(sup, pid1)
      assert is_pid(pid2)
      assert pid2 != pid1
      assert Process.alive?(pid2)
    end

    test "the observed state result is explicit: fresh initial state after restart" do
      sup = start_supervised!(CrashSupervisor)

      pid1 = CrashSupervisor.agent_server_pid(sup)

      # Accumulate observable state in the running process.
      Enum.each(1..3, fn _ ->
        {:ok, _agent} =
          AgentServer.call(
            pid1,
            Signal.new!("agent_server_crash.record", %{by: 1}, source: "/test")
          )
      end)

      # Before the crash, the observed state reflects the accumulated work.
      {:ok, %{agent: agent_before}} = AgentServer.state(pid1)
      assert agent_before.state.events == 3

      # Crash and wait for the restart.
      Process.exit(pid1, :kill)
      pid2 = await_restart(sup, pid1)

      # The observed result is explicit, not assumed. status/1 returns the
      # restarted process (its pid and agent id); state/1 returns the agent's
      # initial state. The supervisor restarted the process — it did not
      # recover the in-memory counter.
      assert {:ok, status} = AgentServer.status(pid2)
      assert status.pid == pid2
      assert status.agent_id != nil

      assert {:ok, %{agent: agent_after}} = AgentServer.state(pid2)
      assert agent_after.state.events == 0
    end

    test "the restarted AgentServer serves new work after the crash" do
      sup = start_supervised!(CrashSupervisor)

      pid1 = CrashSupervisor.agent_server_pid(sup)
      Process.exit(pid1, :kill)
      pid2 = await_restart(sup, pid1)

      {:ok, agent} =
        AgentServer.call(
          pid2,
          Signal.new!("agent_server_crash.record", %{by: 2}, source: "/test")
        )

      assert agent.state.events == 2
    end
  end

  defp await_restart(sup, old_pid, attempts \\ 100)
  defp await_restart(_sup, _old_pid, 0), do: nil

  defp await_restart(sup, old_pid, attempts) do
    case CrashSupervisor.agent_server_pid(sup) do
      pid when is_pid(pid) and pid != old_pid ->
        pid

      _other ->
        Process.sleep(5)
        await_restart(sup, old_pid, attempts - 1)
    end
  end
end
