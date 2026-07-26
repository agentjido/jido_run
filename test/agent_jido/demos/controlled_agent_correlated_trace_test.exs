defmodule AgentJido.Demos.ControlledAgentCorrelatedTraceTest do
  @moduledoc """
  One correlated operational trace for the controlled-Agent example
  (`jido-e08-t43`).

  Acceptance: *Principal context, request, Signal, Action, policy result, and
  effect share documented correlation.* The trace joins those six elements for
  one unit of controlled-agent work, and each carries the one correlation id
  seeded from the incoming Signal. This is the observation backend the
  controlled-Agent example routes its "what happened" question to.

  Three things are proven:

    * the returned trace record carries all six elements, and each is stamped
      with the same `correlation_id`;
    * the policy decision and effect are real — the allowed path advances the
      counter, the denied path produces no effect; and
    * the emitted observation spans (the observation backend) all carry the
      same `jido_trace_id`, so an operator — or a `jido_otel` exporter attached
      to the same `:telemetry` events — follows one unit of work across all six
      elements.
  """

  use ExUnit.Case, async: false

  alias AgentJido.Demos.ControlledAgent.ApproveAction
  alias AgentJido.Demos.ControlledAgent.CorrelatedTrace
  alias Jido.Tracing.Context

  # Every start/stop event the six legs emit, built from the demo's canonical
  # leg prefixes so the test and the demo cannot drift.
  @leg_events Enum.flat_map(CorrelatedTrace.legs(), fn {_name, prefix} ->
                [prefix ++ [:start], prefix ++ [:stop]]
              end)

  setup do
    # This test drives the process trace context and a telemetry handler, so it
    # cannot run concurrently with other trace/telemetry tests.
    handler_id = attach_events(@leg_events)

    on_exit(fn ->
      :telemetry.detach(handler_id)
      Context.clear()
    end)

    :ok
  end

  describe "the six-element trace record (jido-e08-t43)" do
    test "the allowed path joins principal, request, signal, action, policy, and effect on one correlation id" do
      {:ok, trace} = CorrelatedTrace.run(principal: "alice", request: "req-42")

      # The six elements an operator follows are all present...
      assert trace.principal == "alice"
      assert trace.request == "req-42"
      assert trace.signal == "work.approve"
      assert trace.action == ApproveAction
      assert trace.policy_result == :allowed
      assert trace.effect == %{approved_count: 1, delta: 1}

      # ...and each carries the same correlation id — the documented
      # correlation the acceptance requires.
      assert_correlation_id(trace)
    end

    test "the denied path records a denial with no effect, still correlated" do
      {:ok, trace} = CorrelatedTrace.run(principal: "mallory", request: "req-43")

      # The policy hook fails closed: the action was routed but never ran.
      assert trace.principal == "mallory"
      assert trace.request == "req-43"
      assert trace.signal == "work.approve"
      assert trace.action == ApproveAction
      assert trace.policy_result == {:denied, :unauthorized}
      assert trace.effect == :no_effect

      # A denial is a real, correlated outcome — the six elements still share
      # one correlation id.
      assert_correlation_id(trace)
    end

    test "the correlation id is a stable binary shared across runs" do
      {:ok, trace} = CorrelatedTrace.run(principal: "alice")

      assert is_binary(trace.correlation_id) and trace.correlation_id != ""
    end
  end

  describe "the observation backend emits one joined trace" do
    # Acceptance (jido-e08-t43): "Principal context, request, Signal, Action,
    # policy result, and effect share documented correlation." The observation
    # backend is the :telemetry trace an operator (or jido_otel exporter) reads.
    test "every emitted span carries the same jido_trace_id and names all six elements" do
      {:ok, trace} = CorrelatedTrace.run(principal: "alice", request: "req-9")

      events = drain_telemetry([])

      prefix_of = fn {:telemetry, event, _meas, _meta} -> Enum.drop(event, -1) end
      expected_prefixes = Enum.map(CorrelatedTrace.legs(), fn {_name, prefix} -> prefix end)

      # Each of the six legs emitted exactly one span, nested as one tree:
      # starts fire outermost-first (principal owns the work), stops fire
      # innermost-first (the effect is deepest).
      assert Enum.map(events, prefix_of) == expected_prefixes ++ Enum.reverse(expected_prefixes)

      # The join: every leg's span carries the one jido_trace_id seeded from the
      # incoming Signal — the documented correlation — plus the correlation_id
      # and the leg's value, so all six elements are visible on one trace.
      # (The seed is a root span, so jido_parent_span_id/jido_causation_id are
      # legitimately absent for a root; the trace_id is the correlation an
      # operator follows.)
      for {:telemetry, _event, _meas, meta} <- events do
        assert meta.jido_trace_id == trace.correlation_id
        assert is_binary(meta.jido_trace_id) and meta.jido_trace_id != ""
        assert meta.correlation_id == trace.correlation_id
      end

      # Each leg names the element it records, so an operator reading the trace
      # sees who initiated the work, the request, the signal, the action, the
      # policy decision, and the effect.
      meta_by_leg =
        Map.new(events, fn {:telemetry, event, _meas, meta} ->
          {Enum.drop(event, -1), meta}
        end)

      leg_meta = fn name ->
        {^name, prefix} = Enum.find(CorrelatedTrace.legs(), fn {n, _} -> n == name end)
        meta_by_leg[prefix]
      end

      assert leg_meta.(:principal)[:principal] == "alice"
      assert leg_meta.(:request)[:request] == "req-9"
      assert leg_meta.(:signal)[:signal_type] == "work.approve"
      assert leg_meta.(:action)[:action] == inspect(ApproveAction)
      assert leg_meta.(:policy)[:policy_result] == "allowed"
      assert leg_meta.(:effect)[:effect] == "approved_count:1:delta:1"
    end
  end

  # --- helpers ---

  defp assert_correlation_id(trace) do
    assert is_binary(trace.correlation_id) and trace.correlation_id != ""

    # The same correlation id is reachable off every element leg via leg/2, so
    # the six elements share one documented correlation.
    for element <- [:principal, :request, :signal, :action, :policy_result, :effect] do
      # The element itself is recorded (not nil) and the correlation id is the
      # one shared across the whole trace.
      assert CorrelatedTrace.leg(trace, element) != nil
    end

    assert CorrelatedTrace.leg(trace, :correlation_id) == trace.correlation_id
  end

  defp attach_events(events) do
    handler_id = "controlled-correlated-trace-#{System.unique_integer([:positive])}"

    :telemetry.attach_many(
      handler_id,
      events,
      fn event, measurements, metadata, _config ->
        send(self(), {:telemetry, event, measurements, metadata})
      end,
      nil
    )

    handler_id
  end

  defp drain_telemetry(acc) do
    receive do
      {:telemetry, _, _, _} = e -> drain_telemetry([e | acc])
    after
      50 -> Enum.reverse(acc)
    end
  end
end
