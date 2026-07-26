defmodule AgentJido.Demos.ControlledAgentIngressTest do
  @moduledoc """
  Ingress verification for the controlled-agent reference path
  (`jido-e07-t38`).

  Acceptance: *Invalid or missing required context stops before Agent
  processing.*

  The `IngressPlugin` is the architecture spec's middle step — it runs
  `IncomingContext.validate/1` in `prepare_signal/2`, the earliest Jido hook,
  before routing, the policy hook (`prepare_action/3`), and the Action. This
  test locks the two halves of the task:

    * **verify** — a malformed or missing required context field makes
      `prepare_signal/2` return `{:error, {:invalid_context, {field, reason}}}`,
      and on the live path that stops the signal before the Action runs;
    * **enrich** — a verified Signal returns its five carried fields as a
      runtime-context delta.

  The protected Action (`ApproveAction`) increments `approved_count`. A signal
  the ingress gate stops leaves the counter at `0` and the call returns an
  error — that is "stops before Agent processing."

  The required field is `principal` (carried on `Signal.source`). `Signal.new!/3`
  already requires a non-empty `source`, so a missing principal cannot be built
  through the normal path; the `:principal, :missing` branch is the hook's
  defensive backstop for a raw `%Signal{}`, tested directly below.
  """

  use ExUnit.Case, async: false

  alias AgentJido.Demos.ControlledAgent
  alias AgentJido.Demos.ControlledAgent.IncomingContext
  alias AgentJido.Demos.ControlledAgent.IngressPlugin
  alias Jido.AgentServer
  alias Jido.Signal

  @full_context [
    principal: "alice",
    tenant: "acme",
    request: "req-7",
    correlation: "trace-7",
    causation: "sig-cause-7"
  ]

  # ===========================================================================
  # Verify + enrich: the prepare_signal/2 decision.
  # ===========================================================================

  describe "prepare_signal/2 verifies and enriches the incoming context" do
    test "a well-formed Signal verifies and is enriched with all five fields" do
      signal = Signal.new!("work.approve", %{}, IncomingContext.build(@full_context))

      assert {:ok, ^signal, delta} = IngressPlugin.prepare_signal(signal, context())

      carried = delta[:incoming_context]
      assert carried[:principal] == "alice"
      assert carried[:tenant] == "acme"
      assert carried[:request] == "req-7"
      assert carried[:correlation] == "trace-7"
      assert carried[:causation] == "sig-cause-7"
    end

    test "a Signal missing the required principal is rejected with :missing" do
      # The principal rides on Signal.source; a raw struct with a nil source is
      # the case the hook must defend even though Signal.new!/3 guards it
      # upstream (it requires a non-empty source).
      signal = %Signal{type: "work.approve", data: %{}, source: nil, id: "missing-principal"}

      assert {:error, {:invalid_context, {:principal, :missing}}} =
               IngressPlugin.prepare_signal(signal, context())
    end

    for {field, key} <- [
          {:tenant, "tenant"},
          {:request, "request_id"},
          {:correlation, "correlation_id"},
          {:causation, "causation_id"}
        ] do
      test "a malformed #{field} extension is rejected with :malformed" do
        {field, key} = unquote(Macro.escape({field, key}))

        signal = Signal.new!("work.approve", %{}, source: "alice", extensions: %{key => ""})

        assert {:error, {:invalid_context, {^field, :malformed}}} =
                 IngressPlugin.prepare_signal(signal, context())
      end
    end
  end

  # ===========================================================================
  # Stops before Agent processing: the live supervised path.
  # ===========================================================================

  describe "invalid or missing required context stops before Agent processing" do
    test "a fully valid context runs the protected Action" do
      {:ok, pid} = start_server()

      signal = Signal.new!("work.approve", %{note: "x"}, IncomingContext.build(@full_context))

      assert {:ok, _} = AgentServer.call(pid, signal)
      assert agent_state(pid).approved_count == 1
    end

    test "a valid principal with no extra context still runs (only principal is required)" do
      {:ok, pid} = start_server()

      signal = Signal.new!("work.approve", %{note: "x"}, source: "alice")

      assert {:ok, _} = AgentServer.call(pid, signal)
      assert agent_state(pid).approved_count == 1
    end

    for {field, key} <- [
          {:tenant, "tenant"},
          {:request, "request_id"},
          {:correlation, "correlation_id"},
          {:causation, "causation_id"}
        ] do
      test "a malformed #{field} stops before the Action runs" do
        {field, key} = unquote(Macro.escape({field, key}))
        {:ok, pid} = start_server()

        attrs = IncomingContext.build(principal: "alice") |> put_extension(key, "")
        signal = Signal.new!("work.approve", %{note: "x"}, attrs)

        # alice is allowed at the policy hook — but the ingress gate stops the
        # signal first, so the Action never runs and the counter stays at 0.
        assert {:error, error} = AgentServer.call(pid, signal)
        assert context_reason(error) == {:invalid_context, {field, :malformed}}
        assert agent_state(pid).approved_count == 0
      end
    end
  end

  # --- helpers ---

  # A minimal plugin context shape (only the fields the hook reads are absent;
  # the hook ignores context, so an empty stub is fine).
  defp context, do: %{}

  defp start_server do
    {:ok, pid} =
      AgentServer.start_link(
        jido: AgentJido.Jido,
        agent: ControlledAgent,
        id: "controlled-ingress-#{System.unique_integer([:positive])}"
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

  defp put_extension(attrs, key, value) do
    extensions = Map.get(attrs, :extensions, %{})
    %{attrs | extensions: Map.put(extensions, key, value)}
  end

  # The reason Jido attaches to a prepare_signal failure lives in the error's
  # details; tolerate Splode class-wrapping by reading details where present.
  defp context_reason(error) when is_struct(error) do
    error |> Map.get(:details, %{}) |> Map.get(:reason)
  end
end
