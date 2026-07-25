defmodule AgentJido.Demos.CorrelatedTelemetry do
  @moduledoc """
  Correlated telemetry with sensitive-data redaction (jido-e05-T39).

  The tested example behind the "Correlated telemetry with redaction" control
  surface in the operational-controls onboarding lane. It shows the two things
  an operator needs from a production agent's observation stream:

    1. Correlation. `Jido.Observe` spans carry the trace fields pulled from
       `Jido.Tracing.Context` — `jido_trace_id`, `jido_span_id`,
       `jido_parent_span_id`, and `jido_causation_id` — so one unit of work can
       be followed across components. The context is seeded from the incoming
       Signal (`ensure_from_signal/1`), exactly as it is during Signal
       processing.

    2. Redaction. A configured secret (e.g. a provider API key) is routed
       through `Jido.Observe.redact/2` before it is attached to telemetry
       metadata. With `redact_sensitive: true`, the secret is replaced with
       `"[REDACTED]"` and never appears in the emitted metadata.

  Telemetry is for observation, not audit; the redaction rule keeps configured
  secrets out of the observation stream. The full end-to-end controlled-Agent
  telemetry reference is published on the Operations path (jido-e07).
  """

  alias Jido.Observe
  alias Jido.Signal
  alias Jido.Tracing.Context

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
