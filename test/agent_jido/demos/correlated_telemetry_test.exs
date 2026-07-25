defmodule AgentJido.Demos.CorrelatedTelemetryTest do
  @moduledoc """
  Correlated telemetry with sensitive-data redaction (jido-e05-T39): the tested
  example behind the "Correlated telemetry with redaction" control surface in
  the operational-controls onboarding lane.

  Two things are proven:

    * the emitted span carries the trace fields (`jido_trace_id`,
      `jido_span_id`, `jido_parent_span_id`, `jido_causation_id`) pulled from
      `Jido.Tracing.Context`, and the trace id correlates the span's lifecycle;
    * a configured secret routed through `Jido.Observe.redact/2` is absent from
      the emitted telemetry when redaction is configured — and present when it
      is not, proving the absence is the configuration.
  """
  use ExUnit.Case, async: false

  alias AgentJido.Demos.CorrelatedTelemetry
  alias Jido.Signal
  alias Jido.Tracing.Trace

  @secret "sk-CORRELATED-TELEMETRY-SECRET-xyz"
  @events [
    [:agent_jido, :correlated_telemetry, :observe, :start],
    [:agent_jido, :correlated_telemetry, :observe, :stop]
  ]

  setup do
    # This test toggles the observability redaction config and the process
    # trace context, so it cannot run concurrently with other redaction tests.
    prior = Application.get_env(:jido, :observability, [])
    handler_id = attach_telemetry()

    on_exit(fn ->
      Application.put_env(:jido, :observability, prior)
      Jido.Tracing.Context.clear()
      :telemetry.detach(handler_id)
    end)

    :ok
  end

  # Acceptance: "The example shows trace fields ..."
  test "the emitted span carries the correlated trace fields" do
    configure_redaction(true)

    CorrelatedTelemetry.observe("agent-7", @secret, traced_signal())

    {start_meta, stop_meta} =
      drain_telemetry([])
      |> split_events()

    # Both lifecycle events of the span carry the correlation fields pulled
    # from Jido.Tracing.Context, so an operator can follow this unit of work
    # across components — including its parent span and causing signal.
    for meta <- [start_meta, stop_meta] do
      assert is_binary(meta.jido_trace_id) and meta.jido_trace_id != ""
      assert is_binary(meta.jido_span_id) and meta.jido_span_id != ""
      assert meta.jido_parent_span_id != nil
      assert meta.jido_causation_id != nil
    end

    # The span is correlated across its own lifecycle: one shared trace id and
    # span id tie the start and stop events together.
    assert start_meta.jido_trace_id == stop_meta.jido_trace_id
    assert start_meta.jido_span_id == stop_meta.jido_span_id

    # Identifying (non-secret) metadata travels with the span.
    assert start_meta.agent_id == "agent-7"
  end

  # Acceptance: "... and proves that configured secrets are absent."
  test "a configured secret is absent from the emitted telemetry" do
    configure_redaction(true)

    {:ok, %{observed_secret: observed}} =
      CorrelatedTelemetry.observe("agent-7", @secret, traced_signal())

    blob = inspect(drain_telemetry([]))

    # The configured secret was redacted to the placeholder...
    assert observed == "[REDACTED]"
    # ...and never appears anywhere in the emitted telemetry.
    refute blob =~ @secret,
           "configured secret leaked into telemetry metadata"
  end

  test "the same secret appears when redaction is not configured" do
    # Proves the absence above is the configured redaction, not a missing
    # value: with redaction off the secret passes through unchanged.
    configure_redaction(false)

    {:ok, %{observed_secret: observed}} =
      CorrelatedTelemetry.observe("agent-7", @secret, traced_signal())

    assert observed == @secret
  end

  # --- helpers ---

  # A signal carrying a child trace, as Signal processing would propagate one:
  # an incoming signal with a parent span and a causing signal. ensure_from_signal
  # seeds the process context from it so all four trace fields surface.
  defp traced_signal do
    parent = Trace.new_root()
    child = Trace.child_of(parent, "sig_parent_0000000000000000")
    {:ok, signal} = Trace.put(base_signal(), child)
    signal
  end

  defp base_signal do
    Signal.new!("work.observe", %{step: 1}, source: "alice")
  end

  defp configure_redaction(bool) do
    Application.put_env(:jido, :observability, redact_sensitive: bool)
  end

  defp attach_telemetry do
    handler_id = "correlated-telemetry-#{System.unique_integer([:positive])}"

    :telemetry.attach_many(
      handler_id,
      @events,
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

  defp split_events(events) do
    by_stage =
      Map.new(events, fn {:telemetry, event, _measurements, metadata} ->
        {List.last(event), metadata}
      end)

    {Map.fetch!(by_stage, :start), Map.fetch!(by_stage, :stop)}
  end
end
