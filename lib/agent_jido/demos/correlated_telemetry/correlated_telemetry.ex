defmodule AgentJido.Demos.CorrelatedTelemetry do
  @moduledoc """
  Correlated telemetry through the supported observation path —
  `Jido.Observe` redaction (`jido-e05-T39`) and correlated-span export
  (`jido-e07-t47`).

  The tested example behind the "Correlated telemetry with redaction" control
  surface in the operational-controls onboarding lane, and the focused demo that
  proves the controlled-Agent architecture's Telemetry element: a trace joins
  Agent, Signal, Action, tool, and external-effect work. It shows the three
  things an operator needs from a production agent's observation stream:

    1. **Correlation.** `Jido.Observe` spans carry the trace fields pulled from
       `Jido.Tracing.Context` — `jido_trace_id`, `jido_span_id`,
       `jido_parent_span_id`, and `jido_causation_id` — so one unit of work can
       be followed across components. The context is seeded from the incoming
       Signal (`ensure_from_signal/1`), exactly as it is during Signal
       processing.

    2. **Redaction.** A configured secret (e.g. a provider API key) is routed
       through `Jido.Observe.redact/2` before it is attached to telemetry
       metadata. With `redact_sensitive: true`, the secret is replaced with
       `"[REDACTED]"` and never appears in the emitted metadata.

    3. **Correlated-span export (`jido-e07-t47`).** `joined_trace/2` runs one
       unit of work as a single trace that joins all five layers of the
       supported observation path — Agent, Signal, Action, tool, and external
       effect — through `Jido.Observe`. Every span carries the same
       `jido_trace_id`, so a `:telemetry` handler (or a `jido_otel` exporter
       attached to these same events) sees one trace from the agent that owns
       the work to the external effect it produced.

  Telemetry is for observation, not audit; the redaction rule keeps configured
  secrets out of the observation stream. The full end-to-end controlled-Agent
  telemetry reference is published on the Operations path (jido-e07).
  """

  alias Jido.Observe
  alias Jido.Signal
  alias Jido.Tracing.Context

  # The five layers of the supported observation path, in the order a real Jido
  # stack emits them for one unit of work: the agent that owns the work, the
  # signal that delivered it, the action that ran, the tool the action invoked,
  # and the external effect that tool produced. Each entry pairs a human label
  # with the canonical `:telemetry` event prefix the Jido surface emits for that
  # layer — exactly what a `jido_otel` exporter subscribes to.
  @joined_layers [
    {:agent, [:jido, :agent, :cmd]},
    {:signal, [:jido, :agent_server, :signal]},
    {:action, [:jido, :agent, :action, :run]},
    {:tool, [:jido, :ai, :tool, :execute]},
    {:effect, [:jido, :ai, :llm]}
  ]

  @doc """
  The five observation layers a single unit of work passes through, each paired
  with the canonical `:telemetry` event prefix the Jido surface emits for it.
  A handler (or `jido_otel` exporter) attached to these prefixes sees the whole
  joined trace.
  """
  @spec layers() :: [{:agent | :signal | :action | :tool | :effect, [atom()]}]
  def layers, do: @joined_layers

  @doc """
  Runs one unit of work as a single correlated trace that joins all five layers
  of the supported observation path — Agent, Signal, Action, tool, and external
  effect — through `Jido.Observe` (`jido-e07-t47`).

  The correlation context is seeded from `signal` exactly as Signal processing
  seeds it (`Jido.Tracing.Context.ensure_from_signal/1`), so every span the run
  emits carries the same `jido_trace_id` (plus `jido_span_id`,
  `jido_parent_span_id`, and `jido_causation_id`). An operator — or a
  `jido_otel` exporter attached to these same `:telemetry` events — can follow
  one unit of work from the agent that owns it, through the signal that
  delivered it and the action that ran, to the tool it called and the external
  effect it produced.

  Deterministic and side-effect free: the external effect is simulated, so no
  provider key, network, or runtime is required.

  ## Example

      signal = Jido.Signal.new!("work.observe", %{step: 1}, source: "alice")

      {:ok, %{trace_id: trace_id, layers: [:agent, :signal, :action, :tool, :effect]}} =
        AgentJido.Demos.CorrelatedTelemetry.joined_trace("agent-7", signal)

  Returns `{:ok, %{trace_id: trace_id, layers: [atom()]}}`, where `trace_id` is
  the shared correlation id every layer's span carries.
  """
  @spec joined_trace(agent_id :: String.t(), signal :: Signal.t()) :: {:ok, map()}
  def joined_trace(agent_id, %Signal{} = signal) do
    # Seed the correlation context from the incoming Signal exactly as Signal
    # processing does, so every span below carries the same `jido_trace_id`.
    {_traced_signal, trace} = Context.ensure_from_signal(signal)

    emit_joined_layers(agent_id, signal)

    {:ok,
     %{
       trace_id: trace[:trace_id],
       layers: Enum.map(@joined_layers, fn {name, _prefix} -> name end)
     }}
  end

  # Emits the five layers as one nested span tree — outermost (agent) first —
  # so the emitted :start/:stop events form one trace: agent owns the work, the
  # signal delivers it, the action runs, the tool is invoked, and the tool
  # produces an external effect. The layers are reversed before folding so the
  # outermost layer (agent) ends up wrapping every layer inside it. Each layer's
  # metadata names the agent plus one layer-specific identifying field, exactly
  # as the real stack would.
  defp emit_joined_layers(agent_id, signal) do
    @joined_layers
    |> Enum.reverse()
    |> Enum.reduce(fn -> :ok end, fn {_name, prefix}, inner ->
      fn -> Observe.with_span(prefix, layer_metadata(prefix, agent_id, signal), inner) end
    end)
    |> then(fn outer -> outer.() end)
  end

  defp layer_metadata([:jido, :agent, :cmd], agent_id, _signal),
    do: %{agent_id: agent_id}

  defp layer_metadata([:jido, :agent_server, :signal], agent_id, signal),
    do: %{agent_id: agent_id, signal_type: signal.type}

  defp layer_metadata([:jido, :agent, :action, :run], agent_id, _signal),
    do: %{agent_id: agent_id, action: "joined_trace"}

  defp layer_metadata([:jido, :ai, :tool, :execute], agent_id, _signal),
    do: %{agent_id: agent_id, tool_name: "simulate_tool"}

  defp layer_metadata([:jido, :ai, :llm], agent_id, _signal),
    do: %{agent_id: agent_id, model: "simulated-provider"}

  @doc """
  Emits one correlated observation span for `agent_id`, with the supplied
  `secret` redacted before it enters telemetry.

  Seeds the correlation context from `signal`, emits a `Jido.Observe` span, and
  returns the redacted metadata an operator would see.

  ## Example

      # A signal carrying correlation (trace) data, as Signal processing would.
      signal = Jido.Signal.new!("work.observe", %{step: 1}, source: "alice")

      {:ok, %{observed_secret: secret}} =
        AgentJido.Demos.CorrelatedTelemetry.observe("agent-7", api_key, signal)
  """
  @spec observe(agent_id :: String.t(), secret :: term(), signal :: Signal.t()) ::
          {:ok, map()}
  def observe(agent_id, secret, %Signal{} = signal) do
    # Seed the correlation context from the incoming Signal so the trace fields
    # (trace_id/span_id/parent_span_id/causation_id) flow into every span
    # Jido.Observe emits below.
    {_traced_signal, _trace} = Context.ensure_from_signal(signal)

    # Redact the configured secret before it is ever attached to telemetry.
    # Whether redaction happens is driven by the observability config
    # (redact_sensitive), so a configured secret is absent from the stream.
    redacted_secret = Observe.redact(secret)

    Observe.with_span(
      [:agent_jido, :correlated_telemetry, :observe],
      %{agent_id: agent_id, secret: redacted_secret},
      fn -> {:ok, %{agent_id: agent_id, observed_secret: redacted_secret}} end
    )
  end
end
