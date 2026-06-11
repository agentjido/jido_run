defmodule AgentJido.Analytics.Ingestion.Workers.PlausibleWorker do
  @moduledoc """
  Collects Plausible daily site and dimension metrics.
  """
  use Oban.Worker,
    queue: :analytics,
    max_attempts: 3,
    tags: ["analytics", "plausible"],
    unique: [
      period: 3600,
      states: [:available, :scheduled, :executing, :retryable, :suspended],
      fields: [:worker, :args]
    ]

  alias AgentJido.Analytics.Ingestion

  @source "plausible"

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    with {:ok, site_id} <- configured(:plausible_site_id, :missing_plausible_site_id),
         :ok <- require_config(:plausible_api_key, :missing_plausible_api_key) do
      opts = date_opts(args)

      run =
        Ingestion.start_run(@source,
          date_from: opts[:date_from],
          date_to: opts[:date_to],
          metadata: %{"site_id" => site_id}
        )

      case Ingestion.config(:plausible_client).fetch(site_id, opts) do
        {:ok, %{daily: daily, dimensions: dimensions}} ->
          rows_count =
            Ingestion.upsert_plausible_site_daily(site_id, daily) +
              Ingestion.upsert_plausible_dimension_daily(site_id, dimensions)

          Ingestion.complete_run(run, rows_count)
          :ok

        {:error, reason} ->
          Ingestion.fail_run(run, reason)
          error_result(reason)
      end
    else
      {:error, reason} -> {:cancel, reason}
    end
  end

  defp configured(key, reason) do
    case Ingestion.config(key) do
      value when is_binary(value) ->
        normalized = String.trim(value)
        if normalized == "", do: {:error, reason}, else: {:ok, normalized}

      _value ->
        {:error, reason}
    end
  end

  defp require_config(key, reason) do
    case configured(key, reason) do
      {:ok, _value} -> :ok
      {:error, _reason} = error -> error
    end
  end

  defp error_result(:missing_plausible_api_key), do: {:cancel, :missing_plausible_api_key}
  defp error_result(reason), do: {:error, reason}

  defp date_opts(args) do
    date_to = parse_date(args["date_to"]) || Date.add(Date.utc_today(), -1)
    window_days = Ingestion.config(:plausible_window_days, 30)

    [
      date_from: parse_date(args["date_from"]) || Date.add(date_to, -max(window_days - 1, 0)),
      date_to: date_to,
      request_timeout_ms: Ingestion.config(:request_timeout_ms, 15_000)
    ]
  end

  defp parse_date(value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> date
      {:error, _reason} -> nil
    end
  end

  defp parse_date(_value), do: nil
end
