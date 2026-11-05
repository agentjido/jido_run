defmodule AgentJido.ContentOps.OrchestratorAgent do
  @moduledoc """
  ContentOps orchestrator agent — single coordinator for content operations.

  Runs on a schedule (hourly/nightly/weekly/monthly), creates run contexts,
  executes a jido_runic workflow pipeline, and ensures all output flows
  through `content.change_request` signals.

  ## Workflow Pipeline

      BuildRunContext → LoadPolicyBundle → SelectWork → CollectChangeRequests → DeliverySink → PublishRunReport

  ## Modes

  - `:hourly` / `:nightly` — maintenance only (no work selection, 0 change requests)
  - `:weekly` / `:monthly` — creation sprint (selects work, produces synthetic change requests)

  ## Signals

  - Consumes: `contentops.tick.*`, `contentops.run.requested`
  - Emits: `contentops.run.completed` (via PubSub broadcast)
  """

  require Logger

  use Jido.Agent,
    name: "contentops_orchestrator",
    description: "ContentOps orchestrator — coordinates content creation and maintenance",
    strategy: {AgentJido.ContentOps.RunicStrategy, workflow_fn: &__MODULE__.build_workflow/0},
    schema: [
      last_run_id: [type: :string, default: nil],
      last_run_mode: [type: :atom, default: nil],
      last_run_at: [type: :any, default: nil],
      total_runs: [type: :integer, default: 0]
    ]

  # ContentOps schedules temporarily disabled.
  # schedules: [
  #   {"0 * * * *", "contentops.tick.hourly", job_id: :hourly_tick},
  #   {"0 2 * * *", "contentops.tick.nightly", job_id: :nightly_tick},
  #   {"0 3 * * 1", "contentops.tick.weekly", job_id: :weekly_tick},
  #   {"0 4 1 * *", "contentops.tick.monthly", job_id: :monthly_tick}
  # ]

  alias AgentJido.ContentOps.Actions.{
    BuildRunContext,
    CollectChangeRequests,
    DeliverySink,
    LoadPolicyBundle,
    PublishRunReport,
    SelectWork
  }

  alias Jido.Agent.Strategy.State, as: StrategyState
  alias Runic.Workflow

  @server_name AgentJido.ContentOps.OrchestratorServer
  @active_server_statuses [:running, :processing, :waiting]
  @supported_modes [:hourly, :nightly, :weekly, :monthly]

  @doc "Returns the registered name of the singleton orchestrator server."
  @spec server_name() :: atom()
  def server_name, do: @server_name

  @doc false
  @spec plugin_specs() :: [Jido.Plugin.Spec.t()]
  def plugin_specs, do: []

  @doc """
  Returns `:ok` when the orchestrator server can accept a new run.
  """
  @spec check_ready() :: :ok | {:error, :already_running | term()}
  def check_ready do
    case Jido.AgentServer.status(@server_name) do
      {:ok, status} ->
        if status.snapshot.status in @active_server_statuses do
          {:error, :already_running}
        else
          :ok
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Build the orchestrator workflow DAG.

  All nodes run locally in the spike. The pipeline is linear:

      BuildRunContext → LoadPolicyBundle → SelectWork → CollectChangeRequests → DeliverySink → PublishRunReport
  """
  @spec build_workflow() :: struct()
  def build_workflow do
    Workflow.new(name: :contentops_pipeline)
    |> Workflow.add(BuildRunContext)
    |> Workflow.add(LoadPolicyBundle, to: :build_run_context)
    |> Workflow.add(SelectWork, to: :load_policy_bundle)
    |> Workflow.add(CollectChangeRequests, to: :select_work)
    |> Workflow.add(DeliverySink, to: :collect_change_requests)
    |> Workflow.add(PublishRunReport, to: :delivery_sink)
  end

  @doc """
  Run the orchestrator pipeline for a given mode.

  Sends a `runic.feed` signal to the singleton orchestrator server
  and waits for workflow completion.

  ## Options

    * `:mode` - Run mode (default: `:weekly`)
    * `:timeout` - Timeout in ms (default: `30_000`)

  ## Returns

  A map with `:mode`, `:status`, and `:productions`.
  """
  @spec run(keyword()) :: map()
  def run(opts \\ []) do
    mode = normalize_mode(Keyword.get(opts, :mode, :weekly))
    timeout = Keyword.get(opts, :timeout, 30_000)

    case check_ready() do
      :ok ->
        do_run(mode, timeout)

      {:error, :already_running} ->
        Logger.warning("[ContentOps] Run request ignored: already running")
        %{mode: mode, productions: [], status: {:error, :already_running}}

      {:error, reason} ->
        Logger.error("[ContentOps] Run request failed: orchestrator unavailable: #{inspect(reason)}")
        %{mode: mode, productions: [], status: {:error, reason}}
    end
  end

  defp do_run(mode, timeout) do
    Logger.info("[ContentOps] Starting #{mode} run")

    signal =
      Jido.Signal.new!(
        "contentops.run.requested",
        %{mode: mode},
        source: "/contentops/orchestrator"
      )

    Jido.AgentServer.cast(@server_name, signal)

    case Jido.AgentServer.await_completion(@server_name, timeout: timeout) do
      {:ok, %{status: :completed}} ->
        productions = current_productions()

        Logger.info("[ContentOps] #{mode} run COMPLETED — #{length(productions)} productions")

        %{
          mode: mode,
          productions: productions,
          status: :completed
        }

      {:ok, %{status: :failed}} ->
        Logger.error("[ContentOps] #{mode} run FAILED")
        %{mode: mode, productions: [], status: :failed}

      {:error, reason} ->
        Logger.error("[ContentOps] #{mode} run ERROR: #{inspect(reason)}")
        %{mode: mode, productions: [], status: {:error, reason}}
    end
  end

  @impl true
  def on_after_cmd(agent, _action, directives) do
    {:ok, maybe_update_run_state(agent), directives}
  end

  @doc "Extract the run report from pipeline results."
  @spec run_report(map()) :: map() | nil
  def run_report(%{productions: productions}) when is_list(productions) do
    productions
    |> Enum.reverse()
    |> Enum.find(fn
      %{type: "contentops.run.completed"} -> true
      %{"type" => "contentops.run.completed"} -> true
      _ -> false
    end)
  end

  def run_report(_), do: nil

  defp current_productions do
    case Jido.AgentServer.state(@server_name) do
      {:ok, server_state} ->
        strat = StrategyState.get(server_state.agent)
        Runic.Workflow.raw_productions(strat.workflow)

      {:error, _reason} ->
        []
    end
  end

  defp maybe_update_run_state(agent) do
    snapshot = strategy_snapshot(agent)

    with :success <- snapshot.status,
         productions when is_list(productions) <- snapshot.result,
         report when not is_nil(report) <- run_report(%{productions: productions}),
         run_id when is_binary(run_id) <- report[:run_id] || report["run_id"] do
      mode = normalize_mode(report[:mode] || report["mode"], nil)
      completed_at = report[:completed_at] || report["completed_at"] || DateTime.utc_now()
      state = agent.state

      total_runs =
        if state[:last_run_id] == run_id do
          state[:total_runs] || 0
        else
          (state[:total_runs] || 0) + 1
        end

      %{
        agent
        | state: %{
            state
            | last_run_id: run_id,
              last_run_mode: mode,
              last_run_at: completed_at,
              total_runs: total_runs
          }
      }
    else
      _other ->
        agent
    end
  end

  defp normalize_mode(mode, default \\ :weekly)
  defp normalize_mode(mode, _default) when mode in @supported_modes, do: mode

  defp normalize_mode(mode, default) when is_binary(mode) do
    case mode |> String.trim() |> String.downcase() do
      "hourly" -> :hourly
      "nightly" -> :nightly
      "weekly" -> :weekly
      "monthly" -> :monthly
      _other -> default
    end
  end

  defp normalize_mode(_mode, default), do: default
end
