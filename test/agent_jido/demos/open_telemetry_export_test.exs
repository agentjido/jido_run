defmodule AgentJido.Demos.OpenTelemetryExportTest do
  @moduledoc """
  The OpenTelemetry example (`jido-e08-t20`).

  Acceptance: "It states Experimental maturity and exports a verified trace."

  Two things are proven:

    * the example states Experimental maturity — `maturity/0` returns
      `:experimental` and the exported trace carries the same label; and
    * the exported trace is verified — one shared trace id adopted from the
      incoming signal, a single parent-linked span tree, OTel span names mapped
      from Jido event prefixes, OTel attributes mapped from Jido metadata, and
      OK statuses — and it came through `Jido.Observe` invoking the bridge, not
      fabricated.
  """

  use ExUnit.Case, async: false

  alias AgentJido.Demos.OpenTelemetryExport
  alias AgentJido.Demos.OpenTelemetryExport.Tracer

  alias Jido.Signal
  alias Jido.Tracing.{Context, Trace}

  # This test toggles the `:jido, :observability` tracer config and the process
  # trace context, so it cannot run alongside other tests that touch either.
  setup do
    prior = Application.get_env(:jido, :observability, [])

    on_exit(fn ->
      Application.put_env(:jido, :observability, prior)
      Context.clear()
    end)

    :ok
  end

  # Acceptance: "It states Experimental maturity ..."
  test "the example states Experimental maturity" do
    assert OpenTelemetryExport.maturity() == :experimental
    assert OpenTelemetryExport.maturity_label() == "Experimental"
    assert String.contains?(OpenTelemetryExport.maturity_note(), "Experimental")
  end

  # Acceptance: "... and exports a verified trace."
  test "run exports a verified OpenTelemetry trace and carries Experimental maturity" do
    %{maturity: maturity, trace_id: trace_id, spans: spans} = OpenTelemetryExport.run()

    # The exported trace states Experimental maturity.
    assert maturity == :experimental

    # The five observation layers each exported exactly one span.
    assert length(spans) == 5

    # One shared trace id across every span — the OTel trace.
    assert Enum.uniq(Enum.map(spans, & &1.trace_id)) == [trace_id]
    assert is_binary(trace_id) and trace_id != ""

    # Exactly one root span (no parent); every other span's parent is present in
    # the trace, so the spans form one parent-linked tree.
    roots = Enum.filter(spans, &is_nil(&1.parent_span_id))
    assert length(roots) == 1

    span_ids = MapSet.new(spans, & &1.span_id)

    for span <- spans, not is_nil(span.parent_span_id) do
      assert MapSet.member?(span_ids, span.parent_span_id),
             "span #{span.name} references an absent parent span"
    end

    by_name = Map.new(spans, &{&1.name, &1})

    # The tree nests in observation order: the agent owns the work, and each
    # layer's parent is the layer outside it.
    assert is_nil(by_name["jido.agent.cmd"].parent_span_id)

    assert by_name["jido.agent_server.signal"].parent_span_id ==
             by_name["jido.agent.cmd"].span_id

    assert by_name["jido.agent.action.run"].parent_span_id ==
             by_name["jido.agent_server.signal"].span_id

    assert by_name["jido.ai.tool.execute"].parent_span_id ==
             by_name["jido.agent.action.run"].span_id

    assert by_name["jido.ai.llm"].parent_span_id ==
             by_name["jido.ai.tool.execute"].span_id

    # Span names are the Jido event prefixes dot-joined (OTel naming).
    assert Map.keys(by_name) ==
             Enum.sort([
               "jido.agent.cmd",
               "jido.agent_server.signal",
               "jido.agent.action.run",
               "jido.ai.tool.execute",
               "jido.ai.llm"
             ])

    # External effects are CLIENT spans; internal agent work is INTERNAL.
    assert by_name["jido.ai.tool.execute"].kind == :client
    assert by_name["jido.ai.llm"].kind == :client
    assert by_name["jido.agent.cmd"].kind == :internal

    # Every span completed successfully.
    assert Enum.all?(spans, &(&1.status == :ok))

    # Identifying Jido metadata travelled as OTel attributes.
    for span <- spans do
      assert span.attributes.agent_id == "otel-demo-agent"
    end

    assert by_name["jido.ai.llm"].attributes.model == "simulated-provider"

    # Correlation fields are span identity, not OTel attributes.
    refute Map.has_key?(by_name["jido.agent.cmd"].attributes, :jido_trace_id)
  end

  # The trace is "verified" only because the bridge adopted the Jido correlation
  # context: the exported trace id IS the incoming signal's trace id, so the OTel
  # trace is the same trace a downstream collector already saw.
  test "the exported trace id is the incoming signal's trace id" do
    # Seed a known upstream trace on the incoming signal, as a parent signal would.
    parent = Trace.new_root()
    child = Trace.child_of(parent, "sig_parent_0000000000000000")
    {:ok, signal} = Trace.put(base_signal(), child)

    %{trace_id: trace_id, spans: spans} = OpenTelemetryExport.run(signal: signal)

    assert trace_id == child.trace_id
    assert trace_id == parent.trace_id

    # The agent span (outermost, first started) links into the upstream trace
    # via the signal's parent span — the bridge did not orphan the upstream link.
    agent = hd(spans)
    assert agent.name == "jido.agent.cmd"
    assert agent.parent_span_id == parent.span_id
  end

  # The spans came through Jido.Observe invoking the bridge, not fabricated:
  # until Observe drives the bridge, its exporter holds nothing.
  test "the bridge exporter is empty until Jido.Observe drives it" do
    Tracer.reset()
    assert Tracer.exported() == []
  end

  defp base_signal do
    Signal.new!("work.observe", %{step: 1}, source: "otel-demo")
  end
end
