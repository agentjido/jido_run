defmodule AgentJido.FirstAgentStateBoundaryTest do
  @moduledoc """
  E05-T14: the first-agent Livebook states the process-state boundary
  explicitly — what is lost on restart (in-memory state held by the running
  process) and what survives (the agent definition in the compiled module).
  A restart boots a fresh process from defaults; it is not state recovery.
  Persistence is a separate, later concern (E05-T15).
  """
  use ExUnit.Case, async: true

  @livebook_path "priv/pages/docs/getting-started/first-agent.livemd"

  setup do
    %{source: File.read!(@livebook_path)}
  end

  test "the notebook states what is lost on restart", %{source: source} do
    # The boundary is named: in-memory state held by the running process is
    # what goes away on a restart.
    assert source =~ ~r/in-memory/i,
           "the notebook must name the in-memory state that is lost on restart"

    assert source =~ ~r/lost/i,
           "the notebook must state that state is lost on restart"
  end

  test "the notebook states what survives a restart", %{source: source} do
    # The agent definition (module/schema/defaults) survives the restart and is
    # what the restarted process boots from.
    assert source =~ ~r/agent definition/i,
           "the notebook must name the agent definition that survives a restart"

    assert source =~ ~r/survives/i,
           "the notebook must state that the definition survives the restart"
  end

  test "the notebook frames a restart as not state recovery", %{source: source} do
    # Matches the canonical operations language: a restart is not state recovery.
    assert source =~ ~r/not state recovery/i,
           "the notebook must state that a restart is not state recovery"
  end

  test "the boundary is a learning outcome", %{source: source} do
    # The front matter lists the boundary as something the reader learns.
    assert source =~ ~r/process-state boundary/i,
           "the learning outcomes must name the process-state boundary"
  end
end
