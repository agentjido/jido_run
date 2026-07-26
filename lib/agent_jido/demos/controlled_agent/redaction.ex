defmodule AgentJido.Demos.ControlledAgent.Redaction do
  @moduledoc """
  Redaction across the controlled-agent observation path (`jido-e07-t48`).

  Element 7 of the controlled-agent design carries a redaction duty: a defined
  sensitive fixture — a provider key carried as a Signal param — must not appear
  in any captured operational data the reference app emits. This module is the
  tested example behind that duty, named by the architecture spec's threat and
  control model ("Provider keys → Leakage → Runtime config + redaction").

  It defines the sensitive fixtures, routes one through the controlled-agent
  observation path, and redacts it via `Jido.Observe.redact/2` at each of the
  four operational-data sinks an operator captures — **telemetry**, **logs**,
  the recorded **Journal entry**, and **error output**:

    * **telemetry** — the secret is redacted before it enters the span metadata
      a `:telemetry` handler (or `jido_otel` exporter) sees;
    * **logs** — the secret is redacted before it is logged;
    * **Journal entry** — the application redacts the secret in the recorded
      Signal's data before persisting, so the durable entry never holds a raw
      secret;
    * **error output** — the fail-closed authorization hook rejects a
      secret-carrying signal without echoing the secret, so error output never
      holds it.

  Whether redaction happens is driven by the `:redact_sensitive` observability
  flag: with it `true` the fixture becomes `"[REDACTED]"` everywhere; with it
  `false` the fixture passes through unchanged — proving the absence is the
  configured redaction, not a missing value.

  Jido supplies the redaction surface (`Jido.Observe.redact/2`, gated by the
  `:redact_sensitive` flag); the application owns the duty to apply it at each
  sink. Nothing here audits or tamper-proofs the recorded Signal — redaction is
  an application duty, not a Jido guarantee (see the Journal retention, access,
  and deletion page, `jido-e07-t45`).
  """

  alias AgentJido.Demos.ControlledAgent.AuthorizationPlugin
  alias Jido.Observe
  alias Jido.Signal
  alias Jido.Signal.Journal
  alias Jido.Signal.Journal.Adapters.InMemory
  alias Jido.Tracing.Context

  # The defined sensitive fixtures for the controlled-agent reference path: the
  # provider keys the threat model names as leakage assets. Each is a non-empty
  # binary an operator would never want in captured operational data.
  @fixtures [
    "sk-CONTROLLED-AGENT-PROVIDER-KEY-xyz",
    "sk-CONTROLLED-AGENT-BILLING-TOKEN-xyz"
  ]

  # The canonical :telemetry event prefix the path emits for one redacted span
  # of controlled-agent observation. A handler (or jido_otel exporter) attached
  # to the start/stop events sees the redacted span metadata.
  @telemetry_event [:jido, :controlled_agent, :redaction, :observe]

  @doc """
  The defined sensitive fixtures — the provider keys routed through the path.
  """
  @spec fixtures() :: [String.t()]
  def fixtures, do: @fixtures

  @doc """
  The `:telemetry` start/stop event names the path emits for one redacted span.

  A handler attached to these (or a `jido_otel` exporter) sees the redacted span
  metadata for one unit of controlled-agent observation.
  """
  @spec telemetry_events() :: [[atom()]]
  def telemetry_events, do: [@telemetry_event ++ [:start], @telemetry_event ++ [:stop]]

  @doc """
  Routes `secret` through the controlled-agent observation path, redacting it
  via `Jido.Observe.redact/2` at each of the four operational-data sinks.

  Emits one `Jido.Observe` span and one log line (captured by the caller) and
  returns the recorded Journal `Signal` (with the secret redacted in its data)
  and the authorization `error` (which never holds the secret). Whether
  redaction happens is driven by the `:redact_sensitive` observability config:
  with it `true` the secret becomes `"[REDACTED]"` everywhere; with it `false`
  the secret passes through, proving the absence is the configured redaction
  and not a missing value.

  Deterministic and side-effect free beyond the captured observation stream: no
  provider key, network, or runtime is required.

  ## Example

      # with redact_sensitive: true
      {:ok, %{journal: recorded, error: {:error, :unauthorized}}} =
        AgentJido.Demos.ControlledAgent.Redaction.run("sk-...")
  """
  @spec run(String.t()) :: {:ok, %{journal: Signal.t(), error: term()}}
  def run(secret) when is_binary(secret) do
    signal = build_signal(secret)

    # Seed the correlation context from the incoming Signal so the span carries
    # the trace fields an operator follows — exactly as Signal processing seeds
    # them.
    {_traced_signal, _trace} = Context.ensure_from_signal(signal)

    emit_telemetry_span(secret)
    log_observed_secret(secret)

    recorded = record_redacted(signal, secret)
    error = authorization_error(secret)

    {:ok, %{journal: recorded, error: error}}
  end

  # Telemetry sink: redact the secret before it enters the span metadata a
  # :telemetry handler (or jido_otel exporter) sees.
  defp emit_telemetry_span(secret) do
    Observe.with_span(
      @telemetry_event,
      %{agent_id: "controlled-agent", secret: Observe.redact(secret)},
      fn -> :ok end
    )
  end

  # Logs sink: redact the secret before it is written to the observation log.
  defp log_observed_secret(secret) do
    Observe.log(:info, "controlled-agent observed provider_key=#{Observe.redact(secret)}")
  end

  # Journal sink: the application redacts the secret in the recorded Signal's
  # data before persisting, so the durable entry never holds a raw secret. Jido
  # records the Signal as given; redaction is the application's duty.
  defp record_redacted(%Signal{} = signal, secret) do
    journal = Journal.new(InMemory)
    {:ok, _journal} = Journal.record(journal, redacted_signal(signal, secret), nil)
    [recorded] = Journal.get_conversation(journal, signal.subject)
    recorded
  end

  defp redacted_signal(%Signal{} = signal, secret) do
    redacted =
      Map.new(signal.data, fn
        {key, value} when value == secret -> {key, Observe.redact(secret)}
        pair -> pair
      end)

    %{signal | data: redacted}
  end

  # Error-output sink: the fail-closed authorization hook rejects a
  # secret-carrying signal without echoing the secret. The principal is not in
  # the allowlist, so the hook returns {:error, :unauthorized} — the secret in
  # the signal's data never appears in the error.
  defp authorization_error(secret) do
    # A secret-carrying signal from a principal the allowlist rejects. The hook
    # inspects only the principal; the secret never reaches the error output.
    signal = Signal.new!("work.observe", %{provider_key: secret}, source: "mallory")

    AuthorizationPlugin.prepare_action(
      signal,
      nil,
      %{config: %{allowed: ["alice"]}}
    )
  end

  defp build_signal(secret) do
    Signal.new!("work.observe", %{provider_key: secret},
      source: "alice",
      subject: "controlled-agent.redaction"
    )
  end
end
