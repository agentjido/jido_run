defmodule AgentJido.ContentIngest.EcosystemDocs.Crawler do
  @moduledoc """
  Supervised background crawler for published HexDocs ecosystem packages.
  """

  use GenServer

  alias AgentJido.ContentIngest.EcosystemDocs.Sync

  @default_refresh_interval_ms :timer.hours(24)
  @default_request_timeout_ms 15_000
  @default_page_concurrency 4
  @task_supervisor AgentJido.ContentIngest.EcosystemDocs.TaskSupervisor

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec sync() :: :ok | {:error, term()}
  def sync do
    GenServer.call(__MODULE__, :sync)
  end

  @spec sync_package(String.t()) :: :ok | {:error, term()}
  def sync_package(package_id) when is_binary(package_id) do
    GenServer.call(__MODULE__, {:sync_package, package_id})
  end

  @spec status() :: map()
  def status do
    case Process.whereis(__MODULE__) do
      pid when is_pid(pid) -> GenServer.call(__MODULE__, :status)
      _other -> default_status()
    end
  end

  @impl true
  def init(opts) do
    state =
      %{
        enabled: Keyword.get(opts, :enabled, config(:enabled, true)),
        refresh_interval_ms: Keyword.get(opts, :refresh_interval_ms, config(:refresh_interval_ms, @default_refresh_interval_ms)),
        startup_sync: Keyword.get(opts, :startup_sync, config(:startup_sync, true)),
        request_timeout_ms: Keyword.get(opts, :request_timeout_ms, config(:request_timeout_ms, @default_request_timeout_ms)),
        page_concurrency: Keyword.get(opts, :page_concurrency, config(:page_concurrency, @default_page_concurrency)),
        task_ref: nil,
        running: false,
        run_kind: nil,
        last_started_at: nil,
        last_finished_at: nil,
        last_summary: nil
      }

    if state.enabled do
      schedule_refresh(state.refresh_interval_ms)

      if state.startup_sync and collection_empty?() do
        send(self(), :startup_sync)
      end
    end

    {:ok, state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    {:reply, Map.take(state, [:enabled, :running, :run_kind, :last_started_at, :last_finished_at, :last_summary]), state}
  end

  def handle_call(:sync, _from, state) do
    case maybe_start_sync(:full, state) do
      {:ok, new_state} -> {:reply, :ok, new_state}
      {:error, reason, new_state} -> {:reply, {:error, reason}, new_state}
    end
  end

  def handle_call({:sync_package, package_id}, _from, state) do
    case maybe_start_sync({:package, package_id}, state) do
      {:ok, new_state} -> {:reply, :ok, new_state}
      {:error, reason, new_state} -> {:reply, {:error, reason}, new_state}
    end
  end

  @impl true
  def handle_info(:startup_sync, state) do
    {:noreply, start_scheduled_sync(state)}
  end

  def handle_info(:scheduled_sync, state) do
    schedule_refresh(state.refresh_interval_ms)
    {:noreply, start_scheduled_sync(state)}
  end

  def handle_info({ref, {:ok, summary}}, %{task_ref: ref} = state) do
    Process.demonitor(ref, [:flush])

    {:noreply,
     %{
       state
       | running: false,
         task_ref: nil,
         run_kind: nil,
         last_finished_at: DateTime.utc_now() |> DateTime.truncate(:second),
         last_summary: summary
     }}
  end

  def handle_info({ref, {:error, reason}}, %{task_ref: ref} = state) do
    Process.demonitor(ref, [:flush])

    failed_summary =
      summary_with_failure(state.run_kind, reason)

    {:noreply,
     %{
       state
       | running: false,
         task_ref: nil,
         run_kind: nil,
         last_finished_at: DateTime.utc_now() |> DateTime.truncate(:second),
         last_summary: failed_summary
     }}
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, %{task_ref: ref} = state) do
    failed_summary = summary_with_failure(state.run_kind, reason)

    {:noreply,
     %{
       state
       | running: false,
         task_ref: nil,
         run_kind: nil,
         last_finished_at: DateTime.utc_now() |> DateTime.truncate(:second),
         last_summary: failed_summary
     }}
  end

  def handle_info(_message, state), do: {:noreply, state}

  defp maybe_start_sync(_run_kind, %{running: true} = state), do: {:error, :already_running, state}

  defp maybe_start_sync(run_kind, state) do
    task =
      Task.Supervisor.async_nolink(@task_supervisor, fn ->
        try do
          {:ok, sync_for_run_kind(run_kind, state)}
        rescue
          error -> {:error, Exception.message(error)}
        catch
          kind, reason -> {:error, "#{kind}: #{inspect(reason)}"}
        end
      end)

    {:ok,
     %{
       state
       | running: true,
         task_ref: task.ref,
         run_kind: run_kind,
         last_started_at: DateTime.utc_now() |> DateTime.truncate(:second)
     }}
  rescue
    error ->
      {:error, Exception.message(error), state}
  end

  defp start_scheduled_sync(%{enabled: true, running: false} = state) do
    case maybe_start_sync(:full, state) do
      {:ok, new_state} -> new_state
      {:error, _reason, current_state} -> current_state
    end
  end

  defp start_scheduled_sync(state), do: state

  defp sync_for_run_kind(:full, state) do
    Sync.sync(
      request_timeout_ms: state.request_timeout_ms,
      page_concurrency: state.page_concurrency
    )
  end

  defp sync_for_run_kind({:package, package_id}, state) do
    Sync.sync_package(
      package_id,
      request_timeout_ms: state.request_timeout_ms,
      page_concurrency: state.page_concurrency
    )
  end

  defp collection_empty? do
    Sync.snapshot().total_documents == 0
  rescue
    _error -> false
  end

  defp schedule_refresh(interval_ms) when is_integer(interval_ms) and interval_ms > 0 do
    Process.send_after(self(), :scheduled_sync, interval_ms)
  end

  defp schedule_refresh(_interval_ms), do: :ok

  defp summary_with_failure(run_kind, reason) do
    package_failure =
      case run_kind do
        {:package, package_id} -> [%{package_id: package_id, reason: inspect(reason)}]
        _other -> [%{package_id: "*", reason: inspect(reason)}]
      end

    %{
      mode: :apply,
      dry_run: false,
      total_packages: if(match?({:package, _}, run_kind), do: 1, else: 0),
      eligible_packages: 0,
      skipped_unpublished_count: 0,
      total_sources: 0,
      inserted: 0,
      updated: 0,
      skipped: 0,
      deleted: 0,
      failed: package_failure,
      failed_count: length(package_failure),
      started_at: DateTime.utc_now() |> DateTime.truncate(:second),
      finished_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }
  end

  defp default_status do
    %{
      enabled: false,
      running: false,
      run_kind: nil,
      last_started_at: nil,
      last_finished_at: nil,
      last_summary: nil
    }
  end

  defp config(key, default) do
    case Application.get_env(:agent_jido, __MODULE__, []) do
      config when is_list(config) -> Keyword.get(config, key, default)
      config when is_map(config) -> Map.get(config, key, default)
      _other -> default
    end
  end
end
