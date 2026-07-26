defmodule AgentJido.Demos.OpenTelemetryExport do
  @moduledoc """
  Export a verified OpenTelemetry trace through the `jido_otel` bridge
  (`jido-e08-t20`).

  The backlog comment flagged an OpenTelemetry example as not yet built. This
  module is it: it wires the `jido_otel` tracer bridge (`OpenTelemetryExport.Tracer`,
  which implements the `Jido.Observe.Tracer` contract that package consumes) as
  the configured `Jido.Observe` tracer, runs one unit of work through the real
  `Jido.Observe` surface, and exports the spans the bridge recorded as a
  verified OTel trace.

  A verified trace, here, is one an operator (or a downstream collector) can
  trust: every span shares one trace id adopted from the incoming signal's
  correlation context, the spans nest as one parent-linked tree, the span names
  come from the Jido event prefixes, and the attributes come from the Jido
  metadata — all produced by `Jido.Observe` invoking the bridge, not fabricated.

  ## Maturity: Experimental

  `jido_otel` is unreleased and its API is unstable (Experimental). This example
  ships a faithful bridge against the documented `Jido.Observe.Tracer` contract
  rather than the GitHub package, so the export is real-runtime without taking a
  hard dependency on an Experimental package. `maturity/0` returns
  `:experimental` and the exported trace carries it, so the example states its
  maturity directly.

  The observation layers mirror the supported five-layer path (agent, signal,
  action, tool, external effect) documented for correlated telemetry
  (`jido-e07-t47`); the OTel export is that trace rendered for OpenTelemetry.
  """

  alias AgentJido.Demos.OpenTelemetryExport.{Span, Tracer}

  alias Jido.Observe
  alias Jido.Signal
  alias Jido.Tracing.Context

  @maturity :experimental
  @maturity_label "Experimental"

  defstruct [:trace_id, :spans, :maturity]

  @type t :: %__MODULE__{
          trace_id: String.t() | nil,
          spans: [Span.t()],
          maturity: atom()
        }

  # The supported five-layer observation path, each paired with the canonical
  # Jido event prefix and the identifying metadata a real stack emits for that
  # layer. The bridge turns these prefixes into OTel span names and this
  # metadata into OTel attributes.
  @layers [
    {:agent, [:jido, :agent, :cmd], %{agent_id: "otel-demo-agent"}},
    {:signal, [:jido, :agent_server, :signal], %{agent_id: "otel-demo-agent", signal_type: "work.observe"}},
    {:action, [:jido, :agent, :action, :run], %{agent_id: "otel-demo-agent", action: "ingest"}},
    {:tool, [:jido, :ai, :tool, :execute], %{agent_id: "otel-demo-agent", tool_name: "simulate_tool"}},
    {:effect, [:jido, :ai, :llm], %{agent_id: "otel-demo-agent", model: "simulated-provider"}}
  ]

  @doc """
  The example's maturity. `jido_otel` and this bridge are Experimental.
  """
  @spec maturity :: :experimental
  def maturity, do: @maturity

  @doc """
  The human-readable maturity label.
  """
  @spec maturity_label :: String.t()
  def maturity_label, do: @maturity_label

  @doc """
  Why the maturity is Experimental.
  """
  @spec maturity_note :: String.t()
  def maturity_note do
    "jido_otel is unreleased and its API is unstable. This example ships a faithful bridge that " <>
      "implements the documented Jido.Observe.Tracer contract — the surface jido_otel consumes — " <>
      "so the export is real-runtime without a hard dependency on an Experimental package."
  end

  @doc """
  Runs one unit of work through `Jido.Observe` with the `jido_otel` bridge as the
  configured tracer, and returns the exported, verified OTel trace.

  The correlation context is seeded from `signal` exactly as Signal processing
  seeds it (`Jido.Tracing.Context.ensure_from_signal/1`), so the exported
  trace's id is the incoming signal's trace id. The five observation layers run
  as one nested span tree. The configured tracer is restored afterwards.

  ## Options

    * `:signal` — the incoming `Jido.Signal.t()` to seed the trace from
      (default: a fresh `work.observe` signal, which seeds a root trace).

  ## Example

      %{maturity: :experimental, trace_id: trace_id, spans: spans} =
        AgentJido.Demos.OpenTelemetryExport.run()

  Returns `%__MODULE__{maturity: :experimental, trace_id: binary, spans: [Span.t()]}`.
  """
  @spec run(keyword()) :: t()
  def run(opts \\ []) do
    signal = Keyword.get_lazy(opts, :signal, fn -> base_signal() end)

    # Seed the correlation context exactly as Signal processing does, so the
    # bridge adopts the incoming signal's trace id.
    Context.ensure_from_signal(signal)

    prior = observability_config()
    put_tracer(Tracer)
    Tracer.reset()

    try do
      emit_layers(@layers)
    after
      put_config(prior)
      Context.clear()
    end

    spans = Tracer.exported()

    %__MODULE__{
      trace_id: trace_id_for(spans),
      spans: spans,
      maturity: @maturity
    }
  end

  # Emits the layers as one nested span tree — outermost (agent) first — through
  # the real Jido.Observe surface. The configured bridge receives every span.
  defp emit_layers(layers) do
    layers
    |> Enum.reverse()
    |> Enum.reduce(fn -> :ok end, fn {_name, prefix, meta}, inner ->
      fn -> Observe.with_span(prefix, meta, inner) end
    end)
    |> then(fn outer -> outer.() end)
  end

  defp trace_id_for([]), do: nil
  defp trace_id_for([span | _]), do: span.trace_id

  defp base_signal do
    Signal.new!("work.observe", %{step: 1}, source: "otel-demo")
  end

  defp observability_config, do: Application.get_env(:jido, :observability, [])

  defp put_tracer(tracer) do
    config = Keyword.put(observability_config(), :tracer, tracer)
    put_config(config)
  end

  defp put_config(config), do: Application.put_env(:jido, :observability, config)
end
