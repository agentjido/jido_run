defmodule AgentJido.FirstAgentRestartTest do
  @moduledoc """
  E05-T13: the first-agent Livebook shows the reader how to stop a running
  agent process and start it again, and does so without claiming that agent
  state is recovered across the restart. In-memory state is lost when the
  process stops; persistence is a separate, later concern (E05-T14/T15).
  """
  use ExUnit.Case, async: true

  @livebook_path "priv/pages/docs/getting-started/first-agent.livemd"

  setup do
    %{source: File.read!(@livebook_path)}
  end

  test "the supervised-process section stops and restarts the running process", %{source: source} do
    # Stop the running AgentServer under the runtime supervisor.
    assert source =~ "Jido.stop_agent(runtime, pid)",
           "the notebook must stop the running supervised process"

    # Show the stopped process is gone from the registry.
    assert source =~ "Jido.whereis(runtime, agent_id)",
           "the notebook must show the stopped process is no longer registered"

    # Start the agent again with the same id, as a fresh process.
    assert source =~ "Jido.start_agent(runtime, SignalCounterAgent, id: agent_id)",
           "the notebook must restart the agent with the same id"
  end

  test "the restart does not claim agent state is recovered", %{source: source} do
    # The reader sees the restarted process boots from defaults and the
    # previous in-memory count is gone.
    assert source =~ "schema defaults",
           "the notebook must state the restarted process boots from defaults"

    assert source =~ ~r/the count .* is gone/i,
           "the notebook must state the previous in-memory state is not retained"

    # No state-recovery claim: the notebook never asserts that state survives,
    # is recovered, restored, persisted, or preserved across the restart.
    refute source =~ ~r/state\s+(is|are)\s+(recovered|restored|preserved|persisted)/i,
           "the first-agent notebook must not claim state is recovered across a restart"

    refute source =~ ~r/state\s+(survives|persists)/i,
           "the first-agent notebook must not claim state survives a restart"

    refute source =~ ~r/(recovers|preserves|restores|rehydrates)\s+(its|the)\s+(state|count)/i,
           "the first-agent notebook must not claim the process recovers its state"
  end
end
