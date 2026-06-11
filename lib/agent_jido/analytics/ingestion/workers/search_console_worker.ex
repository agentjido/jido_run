defmodule AgentJido.Analytics.Ingestion.Workers.SearchConsoleWorker do
  @moduledoc """
  Collects Google Search Console search analytics rows.
  """
  use Oban.Worker,
    queue: :analytics,
    max_attempts: 3,
    tags: ["analytics", "search_console"],
    unique: [
      period: 82_800,
      states: [:available, :scheduled, :executing, :retryable, :suspended],
      fields: [:worker, :args]
    ]

  alias AgentJido.Analytics.Ingestion

  @source "search_console"

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    with {:ok, site_url} <- configured(:search_console_site_url, :missing_search_console_site_url),
         :ok <- require_credentials() do
      opts = date_opts(args)

      run =
        Ingestion.start_run(@source,
          date_from: opts[:date_from],
          date_to: opts[:date_to],
          metadata: %{"site_url" => site_url}
        )

      case Ingestion.config(:search_console_client).fetch(site_url, opts) do
        {:ok, %{rows: rows}} ->
          rows_count = Ingestion.upsert_search_console_daily(site_url, rows)
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

  defp require_credentials do
    if Ingestion.search_console_configured?(), do: :ok, else: {:error, :missing_search_console_credentials_json}
  end

  defp error_result(:missing_search_console_credentials_json), do: {:cancel, :missing_search_console_credentials_json}
  defp error_result(reason), do: {:error, reason}

  defp date_opts(args) do
    lag_days = Ingestion.config(:search_console_lag_days, 3)
    window_days = Ingestion.config(:search_console_window_days, 14)
    date_to = parse_date(args["date_to"]) || Date.add(Date.utc_today(), -lag_days)

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
