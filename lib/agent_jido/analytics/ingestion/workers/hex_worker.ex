defmodule AgentJido.Analytics.Ingestion.Workers.HexWorker do
  @moduledoc """
  Collects public Hex package and release download snapshots.
  """
  use Oban.Worker,
    queue: :analytics,
    max_attempts: 3,
    tags: ["analytics", "hex"],
    unique: [
      period: 82_800,
      states: [:available, :scheduled, :executing, :retryable, :suspended],
      fields: [:worker, :args]
    ]

  alias AgentJido.Analytics.Ingestion

  @source "hex"

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    packages = Ingestion.list_active_tracked_hex_packages()
    opts = fetch_opts(args)

    run =
      Ingestion.start_run(@source,
        date_from: opts[:snapshot_date],
        date_to: opts[:snapshot_date],
        metadata: %{"package_count" => length(packages)}
      )

    case fetch_and_store(packages, opts) do
      {:ok, rows_count, metadata} ->
        Ingestion.complete_run(run, rows_count, metadata)
        :ok

      {:error, reason} ->
        Ingestion.fail_run(run, reason)
        error_result(reason)
    end
  end

  defp fetch_and_store(packages, opts) do
    initial_metadata = %{"packages" => [], "skipped_packages" => []}

    Enum.reduce_while(packages, {:ok, 0, initial_metadata}, fn package, {:ok, rows_count, metadata} ->
      case Ingestion.config(:hex_client).fetch(package, opts) do
        {:ok, result} ->
          inserted_count = Ingestion.upsert_hex_package_stats(package, result)
          updated_metadata = Map.update!(metadata, "packages", &[package.package_name | &1])
          {:cont, {:ok, rows_count + inserted_count, updated_metadata}}

        {:error, {:hex_package_not_found, package_name}} ->
          updated_metadata = Map.update!(metadata, "skipped_packages", &[package_name | &1])
          {:cont, {:ok, rows_count, updated_metadata}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, rows_count, metadata} ->
        metadata =
          metadata
          |> Map.update!("packages", &Enum.reverse/1)
          |> Map.update!("skipped_packages", &Enum.reverse/1)

        {:ok, rows_count, metadata}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fetch_opts(args) do
    [
      snapshot_date: parse_date(args["snapshot_date"]) || parse_date(args["date_to"]) || Date.utc_today(),
      request_timeout_ms: Ingestion.config(:request_timeout_ms, 15_000)
    ]
  end

  defp error_result(reason), do: {:error, reason}

  defp parse_date(value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> date
      {:error, _reason} -> nil
    end
  end

  defp parse_date(_value), do: nil
end
