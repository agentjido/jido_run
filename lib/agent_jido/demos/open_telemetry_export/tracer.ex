defmodule AgentJido.Demos.OpenTelemetryExport.Tracer do
  @moduledoc """
  OpenTelemetry tracer bridge for `Jido.Observe` (`jido-e08-t20`).

  This is the `jido_otel` integration point made concrete. `jido_otel` is the
  package that implements `Jido.Observe.Tracer` so a Jido stack's observation
  spans flow to an OpenTelemetry collector; its documented components are to map
  Jido event prefixes to OTel span names, Jido metadata/measurements to OTel
  attributes, and Jido exceptions to OTel exception events.

  `jido_otel` is unreleased and Experimental, so this bridge ships in the demo
  rather than as a hard dependency. It implements the documented
  `Jido.Observe.Tracer` contract — `Jido.Observe` invokes `span_start/2`,
  `span_stop/2`, and `span_exception/4` on this module exactly as it would on
  `jido_otel`; nothing here is mocked. The bridge maintains its own OTel span
  stack (parent links come from nesting, not from a single seeded value), adopts
  the incoming signal's `jido_trace_id` as the OTel trace id, and records each
  finished span to an in-process exporter the demo reads back as a verified
  trace.

  Maturity: Experimental — the bridge and `jido_otel` both track unstable Jido
  Observe and OpenTelemetry APIs.
  """

  @behaviour Jido.Observe.Tracer

  alias AgentJido.Demos.OpenTelemetryExport.Span

  @stack_key {__MODULE__, :span_stack}
  @export_key {__MODULE__, :exported_spans}

  # The correlation fields `Jido.Observe` enriches metadata with. They are span
  # identity (trace/span/parent), not OTel attributes, so the bridge consumes
  # them and drops them from the attribute map.
  @identity_keys [
    :jido_trace_id,
    :jido_span_id,
    :jido_parent_span_id,
    :jido_causation_id,
    :jido_instance
  ]

  @doc """
  Resets the in-process span stack and exporter. The demo calls this before a
  run so the exporter only holds the spans from that run.
  """
  @spec reset :: :ok
  def reset do
    Process.delete(@stack_key)
    Process.put(@export_key, [])
    :ok
  end

  @doc """
  The spans exported since the last `reset/0`, in start order (outermost span
  first), one finished OTel span each.
  """
  @spec exported :: [Span.t()]
  def exported, do: Process.get(@export_key, [])

  @impl true
  @spec span_start(Jido.Observe.Tracer.event_prefix(), Jido.Observe.Tracer.metadata()) :: map()
  def span_start(event_prefix, metadata) do
    {trace_id, parent_span_id} = identity(metadata)
    span_id = Span.new_id()

    span = %Span{
      name: span_name(event_prefix),
      kind: span_kind(event_prefix),
      trace_id: trace_id,
      span_id: span_id,
      parent_span_id: parent_span_id,
      status: :unset,
      attributes: attributes(metadata)
    }

    push(span)
    %{span_id: span_id}
  end

  @impl true
  @spec span_stop(Jido.Observe.Tracer.tracer_ctx(), Jido.Observe.Tracer.measurements()) :: :ok
  def span_stop(%{span_id: span_id}, measurements) do
    finalize(span_id, fn span ->
      %Span{span | status: :ok, duration_ns: Map.get(measurements, :duration)}
    end)
  end

  @impl true
  @spec span_exception(Jido.Observe.Tracer.tracer_ctx(), atom(), term(), list()) :: :ok
  def span_exception(%{span_id: span_id}, kind, reason, _stacktrace) do
    finalize(span_id, fn span ->
      %Span{
        span
        | status: :error,
          exception: %{kind: kind, message: exception_message(reason)},
          duration_ns: span.duration_ns
      }
    end)
  end

  # Resolve the OTel trace id and parent span id for a new span. The bridge
  # adopts the Jido correlation context: the OTel trace id is the incoming
  # signal's jido_trace_id (so the exported trace is the same trace a downstream
  # collector already saw). Parent links come from the bridge's own span stack
  # for nested work; the root links to the signal's upstream parent span.
  defp identity(metadata) do
    trace_id = metadata[:jido_trace_id] || Span.new_trace_id()

    parent_span_id =
      case stack() do
        [top | _] -> top.span_id
        [] -> metadata[:jido_parent_span_id]
      end

    {trace_id, parent_span_id}
  end

  defp finalize(span_id, update) do
    case Enum.find(stack(), &(&1.span_id == span_id)) do
      nil -> :ok
      span -> span |> update.() |> record()
    end

    pop(span_id)
    :ok
  end

  # Maps a Jido event prefix to an OTel span name — dot-joined — exactly as
  # jido_otel maps event prefixes into span naming conventions.
  defp span_name(event_prefix) do
    event_prefix |> Enum.map_join(".", &to_string/1)
  end

  # External effects (LLM call, tool call) leave the process, so they map to OTel
  # CLIENT spans; internal agent/signal/action work is INTERNAL.
  defp span_kind([:jido, :ai, :llm | _]), do: :client
  defp span_kind([:jido, :ai, :tool | _]), do: :client
  defp span_kind(_), do: :internal

  # The identifying metadata an operator needs travels as OTel attributes; the
  # correlation fields are span identity and are dropped.
  defp attributes(metadata) do
    metadata
    |> Map.drop(@identity_keys)
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp exception_message(%{message: message}), do: to_string(message)
  defp exception_message(reason), do: inspect(reason)

  defp stack, do: Process.get(@stack_key, [])
  defp push(span), do: Process.put(@stack_key, [span | stack()])

  defp pop(span_id),
    do: Process.put(@stack_key, Enum.reject(stack(), &(&1.span_id == span_id)))

  defp record(span), do: Process.put(@export_key, [span | exported()])
end
