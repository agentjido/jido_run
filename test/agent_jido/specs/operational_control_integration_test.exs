defmodule AgentJido.Specs.OperationalControlIntegrationTest do
  @moduledoc """
  Integrated controlled-Agent example CI gate (jido-e12-t39).

  The operational-control example is proven in CI by running its allowed and
  denied paths under the documented dependency set. The gate asserts:

    * the controlled-Agent example's documented dependency set is the set
      actually installed in the build;
    * that same set is recorded in `specs/proof.md`'s Fail-closed authorization
      claim, so dependencies and proof cannot drift independently;
    * the allowed path runs — an authorized principal can run the protected
      Action and an allowlisted tool runs; and
    * the denied path runs — an unauthorized principal cannot run the protected
      Action and a disallowed tool is denied before execution.

  Per-control regression tests live in `test/agent_jido/demos/`; this is the
  integration gate that runs them together with the dependency contract. The
  long-running reference application (`specs/operations-reference-architecture.md`)
  remains a follow-up build and is not claimed here.
  """
  use ExUnit.Case, async: false

  alias AgentJido.Demos.{ControlledAgent, ToolAllowlistAgent}
  alias Jido.AgentServer
  alias Jido.Signal

  @proof_path Path.expand("../../../specs/proof.md", __DIR__)

  # The controlled-Agent example's documented dependency set — the combination
  # `specs/proof.md` records for the Fail-closed authorization claim. Updating
  # the installed set requires updating this attribute and proof.md in the same
  # change; the tests below fail otherwise (version drift gate).
  @documented_dependency_set [
    jido: "2.3.2",
    jido_ai: "2.2.0"
  ]

  describe "documented dependency set" do
    test "the documented dependency set is installed in the build" do
      for {app, documented_version} <- @documented_dependency_set do
        installed =
          case Application.spec(app, :vsn) do
            nil -> nil
            vsn -> to_string(vsn)
          end

        assert installed != nil,
               "the controlled-Agent example documents #{app} but it is not loaded"

        assert installed == documented_version,
               "the controlled-Agent example documents #{app} #{documented_version} but " <>
                 "the build has #{app} #{installed}. Update the documented dependency set " <>
                 "(and specs/proof.md) in the same change."
      end
    end

    test "the documented dependency set is recorded in proof.md" do
      block = fail_closed_authorization_block()

      assert block != "",
             "specs/proof.md must keep a 'Fail-closed authorization' control claim"

      for {app, version} <- @documented_dependency_set do
        assert String.contains?(block, "#{app} #{version}"),
               "the documented dependency set records #{app} #{version}, but the " <>
                 "Fail-closed authorization claim in specs/proof.md does not. " <>
                 "Dependencies and proof must not drift."
      end
    end
  end

  describe "allowed path" do
    test "an authorized principal can run the protected Action" do
      {:ok, pid} = start_controlled_agent()

      {:ok, _agent} =
        AgentServer.call(pid, Signal.new!("work.approve", %{note: "ship"}, source: "alice"))

      assert controlled_state(pid).approved_count == 1
    end

    test "an allowlisted tool runs" do
      {:ok, pid} = start_tool_allowlist_agent()

      {:ok, _} =
        AgentServer.call(pid, Signal.new!("tool.search", %{q: "jido"}, source: "alice"))

      assert tool_state(pid).search_count == 1
    end
  end

  describe "denied path" do
    test "an unauthorized principal cannot run the protected Action" do
      {:ok, pid} = start_controlled_agent()

      # prepare_action/3 fails closed: the action never runs.
      _ = AgentServer.call(pid, Signal.new!("work.approve", %{note: "no"}, source: "mallory"))

      assert controlled_state(pid).approved_count == 0
    end

    test "a disallowed tool is denied before execution" do
      {:ok, pid} = start_tool_allowlist_agent()

      _ = AgentServer.call(pid, Signal.new!("tool.delete", %{id: "x"}, source: "alice"))

      assert tool_state(pid).delete_count == 0
    end
  end

  # --- helpers ---

  defp start_controlled_agent do
    start_server(ControlledAgent, "controlled-integration-")
  end

  defp start_tool_allowlist_agent do
    start_server(ToolAllowlistAgent, "tool-allowlist-integration-")
  end

  defp start_server(agent, id_prefix) do
    {:ok, pid} =
      AgentServer.start_link(
        jido: AgentJido.Jido,
        agent: agent,
        id: "#{id_prefix}#{System.unique_integer([:positive])}"
      )

    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid, :normal) end)
    {:ok, pid}
  end

  defp controlled_state(pid), do: agent_state(pid)
  defp tool_state(pid), do: agent_state(pid)

  defp agent_state(pid) do
    {:ok, st} = AgentServer.state(pid)
    st.agent.state
  end

  defp fail_closed_authorization_block do
    proof = File.read!(@proof_path)

    case Regex.run(~r/### Fail-closed authorization.*?(?=\n### |\z)/s, proof) do
      [block | _] -> block
      nil -> ""
    end
  end
end
