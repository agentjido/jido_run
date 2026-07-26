defmodule AgentJido.Demos.ControlledAgentTraceContinuityTest do
  @moduledoc """
  End-to-end trace continuity for the controlled-Agent example (`jido-e12-t43`).

  Acceptance: *Correlation and causation values remain connected from ingress to
  effect.*

  This is the operational-control "trace continuity" CI gate. The
  controlled-Agent example seeds one correlation id at ingress and emits the
  whole unit of work as one joined trace (`CorrelatedTrace`, `jido-e08-t43`).
  `jido-e08-t43` proves the correlation id joins all six elements; this test adds
  the missing half of the acceptance — the **causation** value — and drives one
  unit of work end to end to prove the two values an operator follows to tie a
  unit of work together stay connected from the ingress legs (principal, request,
  signal) through the effect legs (action, policy, effect).

  Three things are proven:

    * on the allowed path, the correlation and causation values supplied at
      ingress are still present — and identical — on the effect leg;
    * on the denied path, the same continuity holds: a denial is a real,
      correlated outcome, so the causation value stays connected to the
      no-effect result; and
    * when no causation is supplied at ingress, none is fabricated at the effect
      — a negative control proving the positive assertions are the carried
      values, not a default the trace invented.
  """

  use ExUnit.Case, async: false

  alias AgentJido.Demos.ControlledAgent.CorrelatedTrace
  alias Jido.Tracing.Context

  # Every start/stop event the six legs emit, built from the demo's canonical
  # leg prefixes so the test and the demo cannot drift.
  @leg_events Enum.flat_map(CorrelatedTrace.legs(), fn {_name, prefix} ->
                [prefix ++ [:start], prefix ++ [:stop]]
              end)

  # The two ends the acceptance says must stay connected: the ingress legs (who
  # initiated the work, which request, the signal) and the effect legs (the
  # action, the policy decision, the effect).
  @ingress_legs [:principal, :request, :signal]
  @effect_legs [:action, :policy, :effect]

  setup do
    # Drives the process trace context and a telemetry handler, so it cannot run
    # concurrently with other trace/telemetry tests.
    handler_id = attach_events(@leg_events)

    on_exit(fn ->
      :telemetry.detach(handler_id)
      Context.clear()
    end)

    :ok
  end

  describe "correlation and causation remain connected from ingress to effect (jido-e12-t43)" do
    test "on the allowed path, both values reach the effect leg unchanged" do
      {:ok, trace} =
        CorrelatedTrace.run(
          principal: "alice",
          request: "req-1",
          causation: "sig-cause-1"
        )

      # The effect ran and the causation value supplied at ingress reached the
      # trace record at the effect end (readable off the trace's own API, too).
      assert trace.policy_result == :allowed
      assert trace.effect == %{approved_count: 1, delta: 1}
      assert trace.causation_id == "sig-cause-1"
      assert CorrelatedTrace.leg(trace, :causation_id) == "sig-cause-1"
      assert is_binary(trace.correlation_id) and trace.correlation_id != ""

      meta_by_leg = leg_metadata(drain_telemetry([]))

      # Every leg — ingress through effect — carries the one correlation id and
      # the one causation value, so both stay connected across the whole path.
      for leg <- @ingress_legs ++ @effect_legs do
        assert leg_value(meta_by_leg, leg, :correlation_id) == trace.correlation_id
        assert leg_value(meta_by_leg, leg, :causation_id) == "sig-cause-1"
      end

      # The acceptance, said plainly: the value on an ingress leg equals the
      # value on the effect leg, for both correlation and causation.
      assert leg_value(meta_by_leg, :principal, :correlation_id) ==
               leg_value(meta_by_leg, :effect, :correlation_id)

      assert leg_value(meta_by_leg, :principal, :causation_id) ==
               leg_value(meta_by_leg, :effect, :causation_id)
    end

    test "on the denied path, causation stays connected to the no-effect outcome" do
      {:ok, trace} =
        CorrelatedTrace.run(
          principal: "mallory",
          request: "req-2",
          causation: "sig-cause-2"
        )

      # Denied at the fail-closed hook: the action never ran.
      assert trace.policy_result == {:denied, :unauthorized}
      assert trace.effect == :no_effect

      # A denial is still a correlated outcome — the causation value reached the
      # effect end of the trace.
      assert trace.causation_id == "sig-cause-2"

      meta_by_leg = leg_metadata(drain_telemetry([]))

      assert leg_value(meta_by_leg, :principal, :correlation_id) ==
               leg_value(meta_by_leg, :effect, :correlation_id)

      assert leg_value(meta_by_leg, :principal, :causation_id) ==
               leg_value(meta_by_leg, :effect, :causation_id)
    end
  end

  describe "negative control — no causation is fabricated when none is supplied" do
    test "a run with no causation carries no causation id to the effect" do
      # Proves the assertions above are the carried ingress values, not a default
      # the trace invented: with no causation supplied, none reaches the effect.
      {:ok, trace} = CorrelatedTrace.run(principal: "alice", request: "req-4")

      assert trace.causation_id == nil

      meta_by_leg = leg_metadata(drain_telemetry([]))

      for leg <- @ingress_legs ++ @effect_legs do
        # correlation is still connected (it is the trace id seeded at ingress)...
        assert leg_value(meta_by_leg, leg, :correlation_id) == trace.correlation_id
        # ...but no causation value was fabricated.
        assert leg_value(meta_by_leg, leg, :causation_id) == nil
      end
    end
  end

  # --- helpers ---

  defp attach_events(events) do
    handler_id = "controlled-trace-continuity-#{System.unique_integer([:positive])}"

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

  # Index the drained spans by their leg name. Each leg emits a start and a stop
  # span with identical metadata, so keeping the last per leg loses nothing.
  defp leg_metadata(events) do
    leg_of_prefix = Map.new(CorrelatedTrace.legs(), fn {name, prefix} -> {prefix, name} end)

    events
    |> Enum.map(fn {:telemetry, event, _meas, meta} -> {Enum.drop(event, -1), meta} end)
    |> Map.new(fn {prefix, meta} -> {Map.fetch!(leg_of_prefix, prefix), meta} end)
  end

  defp leg_value(meta_by_leg, leg, key), do: Map.fetch!(meta_by_leg, leg)[key]
end
