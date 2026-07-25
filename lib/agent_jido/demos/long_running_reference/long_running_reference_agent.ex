defmodule AgentJido.Demos.LongRunningReferenceAgent do
  @moduledoc """
  The one end-to-end long-running reference application (`jido-e07-t29`).

  This is the single agent the architecture spec
  (`specs/operations-reference-architecture.md`) calls for: it runs under
  supervision, takes scheduled and request-driven work, persists state, retries
  transient failure, emits telemetry, exposes a health check, and recovers
  across a deployment restart — each concern wired in at the same time, so the
  standalone demos (`deployment_restart`, `schedule_directive`,
  `persistence_storage`, `correlated_telemetry`, ...) fold into one runnable
  app.

  The agent keeps the observable state an operator needs to tell the concerns
  apart:

    * `processed` / `seen_work` — distinct work items ingested, with idempotency
      on `work_id` (duplicate Signal delivery does not double-count).
    * `cron_ticks` — scheduled ticks observed (the declared CRON schedule).
    * `attempts` / `max_attempts` / `retry_delay_ms` — a bounded retry loop
      driven by schedule directives.
    * `status` / `last_event` — the most recent transition, for the work-health
      axis.

  Signal routes map the linear path a builder follows (`specs/operations-reference-architecture.md`,
  "Linear path"):

      reference.work        → IngestWork        (tool + idempotency + telemetry)
      reference.cron        → HandleCronTick    (scheduling)
      reference.start_retry → StartRetry        (retry and failure policy)
      reference.retry       → HandleRetry       (bounded retry loop)

  Supervision, persistence, health, and deployment restart are owned by the
  surrounding `Supervisor`, `Persistence`, and `Health` modules in this
  directory — they are the application duties the spec assigns to the builder,
  exercised end-to-end in `test/agent_jido/demos/long_running_reference_test.exs`.
  """

  alias AgentJido.Demos.LongRunningReference.{
    HandleCronTickAction,
    HandleRetryAction,
    IngestWorkAction,
    StartRetryAction
  }

  use Jido.Agent,
    name: "long_running_reference_agent",
    description: "End-to-end long-running reference application (jido-e07-t29)",
    schema: [
      processed: [type: :integer, default: 0],
      seen_work: [type: {:list, :string}, default: []],
      cron_ticks: [type: :integer, default: 0],
      status: [type: :atom, default: :idle],
      attempts: [type: :integer, default: 0],
      max_attempts: [type: :integer, default: 3],
      retry_delay_ms: [type: :integer, default: 40],
      last_event: [type: :string, default: ""]
    ],
    schedules: [
      {"*/1 * * * *", "reference.cron", job_id: :reference_minute}
    ],
    signal_routes: [
      {"reference.work", IngestWorkAction},
      {"reference.cron", HandleCronTickAction},
      {"reference.start_retry", StartRetryAction},
      {"reference.retry", HandleRetryAction}
    ]

  @doc false
  @spec plugin_specs() :: nonempty_list(Jido.Plugin.Spec.t())
  def plugin_specs, do: super()

  @doc false
  @spec plugin_schedules() :: nonempty_list(Jido.Plugin.Schedules.schedule_spec())
  def plugin_schedules, do: super()
end
