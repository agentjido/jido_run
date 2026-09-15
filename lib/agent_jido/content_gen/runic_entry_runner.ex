defmodule AgentJido.ContentGen.RunicEntryRunner do
  @moduledoc """
  Executes a single content generation entry through the Runic orchestrator.
  """

  alias AgentJido.ContentGen.Actions.Helpers
  alias AgentJido.ContentGen.OrchestratorAgent
  alias Jido.Agent.Strategy.State, as: StratState
  alias Runic.Workflow

  @default_timeout_ms 300_000

  @spec run_entry(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def run_entry(entry, run_opts) when is_map(entry) and is_map(run_opts) do
    with :ok <- ensure_runtime(),
         {:ok, pid} <- start_server(run_opts) do
      try do
        with :ok <- feed(pid, entry, run_opts),
             {:ok, completion} <- await(pid, run_opts),
             {:ok, entry_result} <- extract_entry_result(pid, completion) do
          {:ok, entry_result}
        else
          {:error, reason} ->
            {:error, format_error(reason)}
        end
      after
        stop_server(pid)
      end
    else
      {:error, reason} ->
        {:error, format_error(reason)}
    end
  end

  defp start_server(run_opts) do
    jido = Map.get(run_opts.opts, :jido_instance, AgentJido.Jido)
    debug? = Map.get(run_opts.opts, :runic_debug, false)

    case Jido.AgentServer.start_link(agent: OrchestratorAgent, jido: jido, debug: debug?) do
      {:ok, pid} -> {:ok, pid}
      {:error, reason} -> {:error, "failed to start content-gen orchestrator server: #{inspect(reason)}"}
    end
  end

  defp stop_server(pid) when is_pid(pid) do
    if Process.alive?(pid) do
      Process.exit(pid, :normal)
    end

    :ok
  end

  defp stop_server(_pid), do: :ok

  defp feed(pid, entry, run_opts) do
    signal =
      Jido.Signal.new!(
        "runic.feed",
        %{data: %{entry: entry, run_opts: Helpers.identity_safe(run_opts)}},
        source: "/content_gen/runic_entry_runner"
      )

    case Jido.AgentServer.cast(pid, signal) do
      :ok -> :ok
      {:error, reason} -> {:error, "failed to feed runic workflow: #{inspect(reason)}"}
    end
  end

  defp await(pid, run_opts) do
    timeout = Map.get(run_opts.opts, :runic_timeout_ms, @default_timeout_ms)

    case Jido.AgentServer.await_completion(pid, timeout: timeout) do
      {:ok, completion} -> {:ok, completion}
      {:error, reason} -> {:error, "runic workflow timed out or failed: #{inspect(reason)}"}
    end
  end

  defp extract_entry_result(pid, completion) do
    case Jido.AgentServer.state(pid) do
      {:ok, server_state} ->
        strat = StratState.get(server_state.agent)
        productions = Workflow.raw_productions(strat.workflow)

        extract_produced_entry_result(productions, completion)

      {:error, reason} ->
        {:error, "failed to inspect runic workflow state: #{inspect(reason)}"}
    end
  end

  defp extract_produced_entry_result(productions, completion) do
    case locate_entry_result(productions) do
      nil -> missing_entry_result_error(completion)
      entry_result -> {:ok, normalize_entry_result(entry_result)}
    end
  end

  defp missing_entry_result_error(%{status: :failed}), do: {:error, "runic workflow failed before producing entry_result"}
  defp missing_entry_result_error(_completion), do: {:error, "runic workflow completed without entry_result production"}

  defp locate_entry_result(productions) do
    candidates =
      productions
      |> Enum.reverse()
      |> Enum.map(&extract_from_production/1)
      |> Enum.reject(&is_nil/1)

    case candidates do
      [] ->
        nil

      _ ->
        Enum.max_by(candidates, &status_rank/1, fn -> List.first(candidates) end)
    end
  end

  defp extract_from_production(production) when is_map(production) do
    cond do
      is_map(Map.get(production, :entry_result)) ->
        merge_entry_result_with_top_level(Map.get(production, :entry_result), production)

      is_map(Map.get(production, "entry_result")) ->
        merge_entry_result_with_top_level(Map.get(production, "entry_result"), production)

      is_map(Map.get(production, :result)) ->
        extract_from_production(Map.get(production, :result))

      is_map(Map.get(production, "result")) ->
        extract_from_production(Map.get(production, "result"))

      Map.has_key?(production, :status) and Map.has_key?(production, :id) ->
        production

      true ->
        nil
    end
  end

  defp extract_from_production(_production), do: nil

  defp merge_entry_result_with_top_level(entry_result, production) when is_map(entry_result) do
    entry_result
    |> maybe_override_status(production)
    |> maybe_override_id(production)
    |> maybe_override_reason(production)
    |> maybe_override_verification(production)
  end

  defp maybe_override_status(entry_result, production) do
    entry_status = Map.get(entry_result, :status) || Map.get(entry_result, "status")
    top_status = Map.get(production, :status) || Map.get(production, "status")

    if entry_status in [nil, :unknown, "unknown"] and top_status not in [nil, :unknown, "unknown"] do
      put_key(entry_result, :status, top_status)
    else
      entry_result
    end
  end

  defp maybe_override_id(entry_result, production) do
    entry_id = Map.get(entry_result, :id) || Map.get(entry_result, "id")
    top_id = Map.get(production, :id) || Map.get(production, "id")

    if is_nil(entry_id) and not is_nil(top_id) do
      put_key(entry_result, :id, top_id)
    else
      entry_result
    end
  end

  defp maybe_override_reason(entry_result, production) do
    entry_reason = Map.get(entry_result, :reason) || Map.get(entry_result, "reason")
    top_reason = Map.get(production, :reason) || Map.get(production, "reason")

    if is_nil(entry_reason) and is_binary(top_reason) and top_reason != "" do
      put_key(entry_result, :reason, top_reason)
    else
      entry_result
    end
  end

  defp maybe_override_verification(entry_result, production) do
    entry_verification = Map.get(entry_result, :verification) || Map.get(entry_result, "verification")
    top_verification = Map.get(production, :verification) || Map.get(production, "verification")

    if is_nil(entry_verification) and is_map(top_verification) do
      put_key(entry_result, :verification, top_verification)
    else
      entry_result
    end
  end

  defp put_key(map, key, value) do
    cond do
      Map.has_key?(map, key) ->
        Map.put(map, key, value)

      Map.has_key?(map, Atom.to_string(key)) ->
        Map.put(map, Atom.to_string(key), value)

      true ->
        Map.put(map, key, value)
    end
  end

  defp status_rank(candidate) do
    status = Map.get(candidate, :status) || Map.get(candidate, "status")
    Map.get(status_ranks(), status, 50)
  end

  defp status_ranks do
    %{
      :written => 100,
      "written" => 100,
      :verification_failed => 95,
      "verification_failed" => 95,
      :audit_failed => 90,
      "audit_failed" => 90,
      :parse_failed => 90,
      "parse_failed" => 90,
      :generation_failed => 90,
      "generation_failed" => 90,
      :dry_run_candidate => 80,
      "dry_run_candidate" => 80,
      :audit_only_passed => 75,
      "audit_only_passed" => 75,
      :skipped_noop => 70,
      "skipped_noop" => 70,
      :skipped_non_file_target => 70,
      "skipped_non_file_target" => 70,
      :ready_to_persist => 10,
      "ready_to_persist" => 10,
      :unknown => 0,
      "unknown" => 0,
      nil => 0
    }
  end

  defp normalize_entry_result(result) do
    base = map_with_atom_keys(result)

    base
    |> Map.update(:verification, Helpers.default_verification(), &normalize_verification/1)
    |> Map.update(:workflow_step_failures, [], &List.wrap/1)
  end

  defp normalize_verification(verification) when is_map(verification) do
    key_map = %{
      "status" => :status,
      "checks" => :checks,
      "check_results" => :check_results,
      "livebook_test_file" => :livebook_test_file,
      "command_output_excerpt" => :command_output_excerpt
    }

    Enum.reduce(verification, %{}, fn
      {key, value}, acc when is_atom(key) ->
        Map.put(acc, key, value)

      {key, value}, acc when is_binary(key) ->
        case Map.get(key_map, key) do
          nil -> acc
          atom_key -> Map.put(acc, atom_key, value)
        end

      _pair, acc ->
        acc
    end)
  end

  defp normalize_verification(_), do: Helpers.default_verification()

  defp map_with_atom_keys(map) when is_map(map) do
    key_map = %{
      "id" => :id,
      "title" => :title,
      "section" => :section,
      "order" => :order,
      "route" => :route,
      "target_path" => :target_path,
      "read_path" => :read_path,
      "conversion_source_path" => :conversion_source_path,
      "format" => :format,
      "existed_before" => :existed_before,
      "update_mode" => :update_mode,
      "verification" => :verification,
      "status" => :status,
      "reason" => :reason,
      "workflow_step_failures" => :workflow_step_failures,
      "backend" => :backend,
      "backend_reason" => :backend_reason,
      "model" => :model,
      "planner_model" => :planner_model,
      "writer_model" => :writer_model,
      "backend_meta" => :backend_meta,
      "parse_mode" => :parse_mode,
      "audit" => :audit,
      "diff" => :diff,
      "citations" => :citations,
      "audit_notes" => :audit_notes,
      "content_hash" => :content_hash,
      "candidate_path" => :candidate_path,
      "output_excerpt" => :output_excerpt
    }

    Enum.reduce(map, %{}, fn
      {key, value}, acc when is_atom(key) ->
        Map.put(acc, key, value)

      {key, value}, acc when is_binary(key) ->
        case Map.get(key_map, key) do
          nil -> acc
          atom_key -> Map.put(acc, atom_key, value)
        end

      _pair, acc ->
        acc
    end)
  end

  defp ensure_runtime do
    with :ok <- ensure_app_started(:jido_signal) do
      ensure_jido_runtime_started()
    end
  end

  defp ensure_jido_runtime_started do
    registry = AgentJido.Jido.Registry

    case Process.whereis(registry) do
      pid when is_pid(pid) ->
        :ok

      nil ->
        case AgentJido.Jido.start_link([]) do
          {:ok, _pid} ->
            :ok

          {:error, {:already_started, _pid}} ->
            :ok

          {:error, reason} ->
            {:error, "failed to start AgentJido.Jido runtime: #{inspect(reason)}"}
        end
    end
  end

  defp ensure_app_started(app) when is_atom(app) do
    case Application.ensure_all_started(app) do
      {:ok, _apps} -> :ok
      {:error, reason} -> {:error, "failed to start #{app}: #{inspect(reason)}"}
    end
  end

  defp format_error(%{__exception__: true} = error), do: Exception.message(error)
  defp format_error(error) when is_binary(error), do: error
  defp format_error(error) when is_atom(error), do: Atom.to_string(error)
  defp format_error(error), do: inspect(error)
end
