defmodule AgentJido.Demos.ControlledAgentIncomingContextTest do
  @moduledoc """
  Incoming-Signal context for the controlled-agent reference path
  (`jido-e07-t37`).

  Acceptance: *Each field has a source, validation rule, and propagation test.*

  The five fields an incoming Signal carries — `principal`, `tenant`, `request`,
  `correlation`, `causation` — are defined once in `IncomingContext`. This test
  locks, for every field:

    * **source** — `IncomingContext.source_of/1` names the Signal location, and a
      Signal built from the field actually carries it there (`get/2` reads it
      back);
    * **validation rule** — `valid?/2` accepts a well-formed value and rejects a
      malformed one, and `validate/1` enforces it on a Signal;
    * **propagation** — the field survives onto the Signal that reaches the
      ingress/policy point (`AuthorizationPlugin.prepare_action/3`) and, for the
      principal, through the full `AgentServer` path.

  Wiring that validation onto the live path is `jido-e07-t38` — the
  `IngressPlugin` runs `validate/1` in `prepare_signal/2`, locked by
  `controlled_agent_ingress_test.exs`. This task is the carrying contract.
  """

  use ExUnit.Case, async: true

  alias AgentJido.Demos.ControlledAgent
  alias AgentJido.Demos.ControlledAgent.AuthorizationPlugin
  alias AgentJido.Demos.ControlledAgent.IncomingContext
  alias Jido.AgentServer
  alias Jido.Signal

  # The full, well-formed context used across the propagation tests.
  @full_context [
    principal: "alice",
    tenant: "acme",
    request: "req-7",
    correlation: "trace-7",
    causation: "sig-cause-7"
  ]

  # --- the contract names exactly five fields ---

  test "the contract names exactly the five required fields, in ingress order" do
    assert IncomingContext.fields() ==
             [:principal, :tenant, :request, :correlation, :causation]
  end

  # ===========================================================================
  # Source: each field rides on a declared Signal location.
  # ===========================================================================

  describe "source — each field rides on a declared Signal location" do
    test "principal rides on Signal.source" do
      assert IncomingContext.source_of(:principal) == {:source, nil}
    end

    for {field, expected} <- [
          {:tenant, {:extension, "tenant"}},
          {:request, {:extension, "request_id"}},
          {:correlation, {:extension, "correlation_id"}},
          {:causation, {:extension, "causation_id"}}
        ] do
      test "#{field} rides on its declared extension" do
        {field, expected} = unquote(Macro.escape({field, expected}))

        assert IncomingContext.source_of(field) == expected,
               "#{field} must ride on #{inspect(expected)}"
      end
    end

    test "a built Signal carries every field at its declared source" do
      signal = Signal.new!("work.approve", %{}, IncomingContext.build(@full_context))

      # principal on source; the rest on extensions.
      assert IncomingContext.get(signal, :principal) == "alice"
      assert IncomingContext.get(signal, :tenant) == "acme"
      assert IncomingContext.get(signal, :request) == "req-7"
      assert IncomingContext.get(signal, :correlation) == "trace-7"
      assert IncomingContext.get(signal, :causation) == "sig-cause-7"
    end

    test "a field that was not supplied reads back as nil, not a crash" do
      signal =
        Signal.new!(
          "work.approve",
          %{},
          IncomingContext.build(principal: "alice", tenant: "acme")
        )

      assert IncomingContext.get(signal, :correlation) == nil
      assert IncomingContext.get(signal, :causation) == nil
    end
  end

  # ===========================================================================
  # Validation rule: each field has an enforceable rule.
  # ===========================================================================

  describe "validation rule — principal is required and must be a non-empty binary" do
    test "a well-formed principal satisfies the rule" do
      assert IncomingContext.valid?(:principal, "alice")
    end

    test "nil and an empty binary fail the rule" do
      refute IncomingContext.valid?(:principal, nil)
      refute IncomingContext.valid?(:principal, "")
    end

    test "a non-binary value fails the rule" do
      refute IncomingContext.valid?(:principal, 42)
    end
  end

  describe "validation rule — optional fields accept nil or a non-empty binary" do
    for field <- [:tenant, :request, :correlation, :causation] do
      test "#{field}: a well-formed value and nil both satisfy the rule" do
        field = unquote(field)

        assert IncomingContext.valid?(field, "value-1")
        assert IncomingContext.valid?(field, nil)
      end

      test "#{field}: an empty or non-binary value fails the rule" do
        field = unquote(field)

        refute IncomingContext.valid?(field, "")
        refute IncomingContext.valid?(field, :atom)
      end
    end
  end

  describe "validate/1 enforces every field's rule on a Signal" do
    test "a Signal carrying all five well-formed fields validates" do
      signal = Signal.new!("work.approve", %{}, IncomingContext.build(@full_context))

      assert IncomingContext.validate(signal) == :ok
    end

    for {field, key} <- [
          {:tenant, "tenant"},
          {:request, "request_id"},
          {:correlation, "correlation_id"},
          {:causation, "causation_id"}
        ] do
      test "validate/1 rejects a malformed #{field} extension" do
        {field, key} = unquote(Macro.escape({field, key}))

        signal =
          Signal.new!("work.approve", %{}, source: "alice", extensions: %{key => ""})

        assert {:error, {^field, :malformed}} = IncomingContext.validate(signal)
      end
    end

    test "a Signal carrying only a valid principal still validates" do
      # The four application fields are optional; principal alone is enough.
      signal =
        Signal.new!("work.approve", %{}, IncomingContext.build(principal: "alice"))

      assert IncomingContext.validate(signal) == :ok
    end
  end

  # ===========================================================================
  # Propagation: the carried context reaches the ingress/policy point.
  # ===========================================================================

  describe "propagation — the context reaches the ingress/policy point" do
    # The AuthorizationPlugin's prepare_action/3 is the ingress/policy point: it
    # is exactly the %Signal{} Jido routes there. Proving the five fields are
    # readable from that argument proves they propagated onto the Signal Jido
    # hands to the policy hook.
    @plugin_context %{config: %{allowed: ["alice"]}}

    test "the Signal handed to prepare_action/3 carries all five fields" do
      signal = Signal.new!("work.approve", %{}, IncomingContext.build(@full_context))

      # The hook runs (alice is allowed) — the carried context did not break the
      # path — and the same Signal argument still carries every field.
      assert {:ok, _} = AuthorizationPlugin.prepare_action(signal, %{}, @plugin_context)

      assert IncomingContext.get(signal, :principal) == "alice"
      assert IncomingContext.get(signal, :tenant) == "acme"
      assert IncomingContext.get(signal, :request) == "req-7"
      assert IncomingContext.get(signal, :correlation) == "trace-7"
      assert IncomingContext.get(signal, :causation) == "sig-cause-7"
    end

    test "a caller outside the tenant context is still denied at the policy point" do
      # Propagation is carrying, not authorizing: an unknown principal is denied
      # regardless of what tenant/request/causation context it carries.
      signal =
        Signal.new!(
          "work.approve",
          %{},
          IncomingContext.build(
            principal: "mallory",
            tenant: "acme",
            request: "req-9",
            correlation: "trace-9",
            causation: "sig-cause-9"
          )
        )

      assert {:error, :unauthorized} =
               AuthorizationPlugin.prepare_action(signal, %{}, @plugin_context)
    end
  end

  describe "propagation — the principal travels the full AgentServer path" do
    # End-to-end: the principal carried on Signal.source authorizes the Action
    # through the real supervised path, so the carried context is not just
    # readable at the hook — it drives work to completion.
    test "a full-context Signal runs the protected Action (approved_count increments)" do
      {:ok, pid} = start_server()

      signal = Signal.new!("work.approve", %{note: "x"}, IncomingContext.build(@full_context))

      assert {:ok, _} = AgentServer.call(pid, signal)
      assert agent_state(pid).approved_count == 1
    end
  end

  # --- helpers ---

  defp start_server do
    {:ok, pid} =
      AgentServer.start_link(
        jido: AgentJido.Jido,
        agent: ControlledAgent,
        id: "controlled-ctx-#{System.unique_integer([:positive])}"
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
