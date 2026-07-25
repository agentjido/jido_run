defmodule AgentJido.Demos.LongRunningReference.IngestWorkAction do
  @moduledoc """
  Ingests one unit of work for the reference application.

  This is the "tool" step of the linear path. It does two things at once so the
  reference app proves them together:

    * **Idempotency.** Each work item carries a `work_id`. A duplicate Signal
      delivering the same `work_id` does not double-count: `processed` only
      advances for a `work_id` the agent has not seen. That is the duplicate-
      delivery failure drill from the architecture spec made observable.
    * **Telemetry.** The work is wrapped in a `Jido.Observe.with_span/3` span,
      so the reference app instruments its own request-driven work with
      correlated, redactable telemetry — the same surface
      `AgentJido.Demos.CorrelatedTelemetry` teaches, now wired into the running
      agent rather than a standalone helper.

  Deterministic and side-effect free: no API key, network, or runtime is
  required.
  """

  use Jido.Action,
    name: "reference_ingest_work",
    description: "Ingests one idempotent unit of work and emits an observation span",
    schema: [
      work_id: [type: :string, required: true],
      secret: [type: :string, required: false]
    ]

  alias Jido.Observe

  @impl true
  def run(params, %{state: state}) do
    work_id = Map.fetch!(params, :work_id)

    # A configured secret routed through redaction never enters telemetry
    # metadata unredacted. With redaction configured it becomes "[REDACTED]".
    # The secret is optional — most work carries none.
    redacted_secret =
      params
      |> Map.get(:secret)
      |> redact()

    Observe.with_span(
      [:agent_jido, :long_running_reference, :work],
      %{work_id: work_id, secret: redacted_secret},
      fn ->
        if work_id in state.seen_work do
          # Idempotent: the same work_id a second time advances nothing.
          {:ok, %{last_event: "work.duplicate:#{work_id}"}}
        else
          {:ok,
           %{
             processed: state.processed + 1,
             seen_work: state.seen_work ++ [work_id],
             status: :working,
             last_event: "work.processed:#{work_id}"
           }}
        end
      end
    )
  end

  defp redact(nil), do: nil
  defp redact(secret), do: Observe.redact(secret)
end
