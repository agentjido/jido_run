defmodule AgentJido.FirstAgentPersistenceLinkTest do
  @moduledoc """
  E05-T15: the first-agent Livebook links to persistence as the next operation
  step, at the point where the reader has just learned that in-memory state is
  lost on restart. Recovery is not implied before persistence is configured —
  the notebook names persistence as a deliberate, later step rather than
  something the default lifecycle provides.
  """
  use ExUnit.Case, async: true

  @livebook_path "priv/pages/docs/getting-started/first-agent.livemd"

  setup do
    %{source: File.read!(@livebook_path)}
  end

  test "the notebook links to the Persistence page", %{source: source} do
    # The persistence concept page is the next-operation-step destination.
    assert source =~ ~r{docs/concepts/persistence},
           "the notebook must link to the Persistence page as the next operation step"
  end

  test "persistence is framed as the next operation step", %{source: source} do
    # The recovery question is raised in the "What is lost on restart" section;
    # the answer points forward to persistence, not to an implicit recovery.
    assert source =~ ~r/next operation step/i,
           "the notebook must frame persistence as the next operation step"
  end

  test "recovery is not implied before persistence is configured", %{source: source} do
    # The notebook must state that recovery is not implied without persistence.
    assert source =~ ~r/recovery is not implied/i,
           "the notebook must state that recovery is not implied before persistence is configured"

    # The default lifecycle must not be described as recovering state on its own.
    refute source =~ ~r/state\s+(is|are)\s+(recovered|restored|preserved|persisted)/i,
           "the first-agent notebook must not claim state is recovered across a restart"

    refute source =~ ~r/(recovers|preserves|restores|rehydrates)\s+(its|the)\s+(state|count)/i,
           "the first-agent notebook must not claim the default lifecycle recovers state"
  end
end
