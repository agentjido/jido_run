defmodule AgentJidoWeb.CanonClaimScanTest do
  @moduledoc """
  Guards the global positioning surfaces against superseded category language
  and unproven claims. This is the thin end of the E12 restricted-claim linter
  (E12-T01/T02), scoped to the highest-traffic surfaces normalized in jido-e03.
  """
  use ExUnit.Case, async: true

  # Phrases that the E02 canon removed or that require proof we do not have.
  @banned [
    "Autonomous Agent Framework",
    "10,000+ supervised agents",
    "Infrastructure for Agent Systems",
    "production-grade autonomous"
  ]

  @global_surfaces [
    "lib/agent_jido_web/seo.ex",
    "lib/agent_jido_web/components/layouts/root.html.heex",
    "lib/agent_jido_web/components/jido/marketing_layouts.ex",
    "lib/agent_jido_web/live/page_live.html.heex"
  ]

  test "global surfaces carry no superseded or unproven claims" do
    for file <- @global_surfaces,
        content = File.read!(file),
        banned <- @banned do
      refute content =~ banned,
             "#{file} still contains superseded/unproven claim: #{inspect(banned)}"
    end
  end

  test "homepage copy keeps Agent data separate from AgentServer processes" do
    homepage = File.read!("lib/agent_jido_web/live/jido_home_live.ex")

    assert homepage =~ "supervised AgentServer processes"
    assert homepage =~ "Each AgentServer runs in its own lightweight process"
    assert homepage =~ "restart AgentServers"

    refute homepage =~ "supervised Agent processes"
    refute homepage =~ "Each Agent runs in its own lightweight process"
    refute homepage =~ "restart Agents by your restart strategy"
  end
end
