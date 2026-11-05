defmodule AgentJido.Demos.ScheduleDirectiveAgentTest do
  use ExUnit.Case, async: false

  alias AgentJido.Demos.ScheduleDirectiveAgent
  alias Jido.AgentServer
  alias Jido.Signal

  test "start_timer transitions to ticked via scheduled signal" do
    {:ok, pid} = start_server()

    {:ok, agent} =
      AgentServer.call(
        pid,
        Signal.new!("start_timer", %{delay_ms: 60, timer_id: "T-1"}, source: "/test")
      )

    assert agent.state.status == :waiting

    assert_eventually(fn ->
      {:ok, state} = AgentServer.state(pid)
      state.agent.state.status == :ticked
    end)

    {:ok, state} = AgentServer.state(pid)
    assert state.agent.state.tick_count == 1
  end

  test "start_retry completes after max attempts" do
    {:ok, pid} = start_server()

    {:ok, _agent} =
      AgentServer.call(
        pid,
        Signal.new!("start_retry", %{max_attempts: 3, retry_delay_ms: 30}, source: "/test")
      )

    assert_eventually(fn ->
      {:ok, state} = AgentServer.state(pid)
      state.agent.state.status == :completed
    end)

    {:ok, state} = AgentServer.state(pid)
    assert state.agent.state.attempts == 3
  end

  test "manual cron.tick increments cron counter" do
    {:ok, pid} = start_server()

    {:ok, agent} = AgentServer.call(pid, Signal.new!("cron.tick", %{}, source: "/test"))
    assert agent.state.cron_ticks == 1
  end

  defp start_server do
    {:ok, pid} =
      AgentServer.start_link(
        jido: AgentJido.Jido,
        agent: ScheduleDirectiveAgent,
        id: "schedule-test-#{System.unique_integer([:positive])}"
      )

    on_exit(fn ->
      AgentJido.TestProcess.stop(pid)
    end)

    {:ok, pid}
  end

  defp assert_eventually(fun, attempts \\ 60)

  defp assert_eventually(fun, attempts) when attempts > 0 do
    if fun.() do
      :ok
    else
      Process.sleep(25)
      assert_eventually(fun, attempts - 1)
    end
  end

  defp assert_eventually(_fun, 0), do: flunk("expected condition to become true")
end
