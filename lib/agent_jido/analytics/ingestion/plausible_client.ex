defmodule AgentJido.Analytics.Ingestion.PlausibleClient do
  @moduledoc """
  Finch-backed Plausible Stats API client.
  """

  alias AgentJido.Analytics.Ingestion

  @aggregate_metrics ["visitors", "visits", "pageviews", "bounce_rate", "visit_duration", "events"]
  @dimension_metrics ["visitors", "visits", "pageviews", "events"]
  @default_dimensions [
    "event:page",
    "visit:source",
    "visit:channel",
    "visit:utm_campaign",
    "visit:utm_source",
    "visit:utm_medium",
    "visit:referrer",
    "visit:entry_page",
    "visit:exit_page",
    "visit:device",
    "visit:browser",
    "visit:os",
    "visit:country"
  ]

  @doc """
  Fetches bounded daily site and dimension metrics from Plausible.
  """
  @spec fetch(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def fetch(site_id, opts \\ []) when is_binary(site_id) do
    with {:ok, api_key} <- api_key(opts),
         {:ok, daily} <- query(api_key, aggregate_query(site_id, opts), opts),
         {:ok, dimensions} <- fetch_dimensions(api_key, site_id, opts) do
      {:ok, %{daily: daily, dimensions: dimensions}}
    end
  end

  defp aggregate_query(site_id, opts) do
    %{
      "site_id" => site_id,
      "metrics" => @aggregate_metrics,
      "date_range" => date_range(opts),
      "dimensions" => ["time:day"]
    }
  end

  defp dimension_query(site_id, dimension, opts) do
    %{
      "site_id" => site_id,
      "metrics" => @dimension_metrics,
      "date_range" => date_range(opts),
      "dimensions" => ["time:day", dimension],
      "pagination" => %{"limit" => Ingestion.config(:plausible_dimension_limit, 500)}
    }
  end

  defp fetch_dimensions(api_key, site_id, opts) do
    Enum.reduce_while(plausible_dimensions(), {:ok, []}, fn dimension, {:ok, acc} ->
      case query(api_key, dimension_query(site_id, dimension, opts), opts) do
        {:ok, rows} -> {:cont, {:ok, acc ++ rows}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp plausible_dimensions do
    :plausible_dimensions
    |> Ingestion.config(@default_dimensions)
    |> case do
      dimensions when is_list(dimensions) ->
        dimensions
        |> Enum.map(&normalize_dimension/1)
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq()

      _value ->
        @default_dimensions
    end
  end

  defp query(api_key, payload, opts) do
    base_url = Ingestion.config(:plausible_api_base_url, "https://plausible.io")
    timeout = Keyword.get(opts, :request_timeout_ms, Ingestion.config(:request_timeout_ms, 15_000))

    headers = [
      {"Authorization", "Bearer #{api_key}"},
      {"Content-Type", "application/json"}
    ]

    request = Finch.build(:post, "#{base_url}/api/v2/query", headers, Jason.encode!(payload))

    case Finch.request(request, AgentJido.Finch, receive_timeout: timeout) do
      {:ok, %Finch.Response{status: status, body: body}} when status in 200..299 ->
        parse_response(body, payload["dimensions"], payload["metrics"])

      {:ok, %Finch.Response{status: 401, body: body}} ->
        {:error, {:plausible_unauthorized, body}}

      {:ok, %Finch.Response{status: 429, body: body}} ->
        {:error, {:plausible_rate_limited, body}}

      {:ok, %Finch.Response{status: status, body: body}} ->
        {:error, {:plausible_http_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_response(body, dimensions, metrics) do
    with {:ok, %{"results" => results}} when is_list(results) <- Jason.decode(body) do
      {:ok, Enum.map(results, &parse_row(&1, dimensions, metrics))}
    end
  end

  defp parse_row(%{"dimensions" => dimension_values, "metrics" => metric_values}, ["time:day"], metrics) do
    metric_map = Enum.zip(metrics, metric_values) |> Map.new()

    %{
      day: Enum.at(dimension_values, 0),
      visitors: metric_map["visitors"],
      visits: metric_map["visits"],
      pageviews: metric_map["pageviews"],
      bounce_rate: metric_map["bounce_rate"],
      visit_duration: metric_map["visit_duration"],
      events: metric_map["events"]
    }
  end

  defp parse_row(%{"dimensions" => dimension_values, "metrics" => metric_values}, ["time:day", dimension], metrics) do
    metric_map = Enum.zip(metrics, metric_values) |> Map.new()

    %{
      day: Enum.at(dimension_values, 0),
      dimension: dimension,
      value: Enum.at(dimension_values, 1),
      visitors: metric_map["visitors"],
      visits: metric_map["visits"],
      pageviews: metric_map["pageviews"],
      events: metric_map["events"]
    }
  end

  defp date_range(opts) do
    [
      Keyword.fetch!(opts, :date_from) |> Date.to_iso8601(),
      Keyword.fetch!(opts, :date_to) |> Date.to_iso8601()
    ]
  end

  defp api_key(opts) do
    case opts |> Keyword.get(:plausible_api_key, Ingestion.config(:plausible_api_key)) |> normalize_token() do
      nil -> {:error, :missing_plausible_api_key}
      token -> {:ok, token}
    end
  end

  defp normalize_token(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      token -> token
    end
  end

  defp normalize_token(_value), do: nil

  defp normalize_dimension(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      dimension -> dimension
    end
  end

  defp normalize_dimension(_value), do: nil
end
