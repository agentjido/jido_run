defmodule AgentJido.Analytics.Ingestion.GitHubTrafficClient do
  @moduledoc """
  Finch-backed GitHub repository traffic API client.
  """

  alias AgentJido.Analytics.Ingestion
  alias AgentJido.Analytics.Ingestion.GitHubAppAuth
  alias AgentJido.Analytics.Ingestion.TrackedRepository

  @user_agent "AgentJido-AnalyticsIngestion"

  @doc """
  Fetches daily views/clones and current top path/referrer snapshots.
  """
  @spec fetch(TrackedRepository.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def fetch(%TrackedRepository{owner: owner, name: name}, opts \\ []) do
    with {:ok, token} <- token(opts),
         {:ok, views} <- get_json(owner, name, "traffic/views?per=day", token, opts),
         {:ok, clones} <- get_json(owner, name, "traffic/clones?per=day", token, opts),
         {:ok, paths} <- get_json(owner, name, "traffic/popular/paths", token, opts),
         {:ok, referrers} <- get_json(owner, name, "traffic/popular/referrers", token, opts) do
      {:ok,
       %{
         daily: merge_daily_series(views["views"] || [], clones["clones"] || []),
         paths: normalize_paths(paths),
         referrers: normalize_referrers(referrers),
         snapshot_date: Date.utc_today(),
         metadata: %{
           "views_total" => views["count"],
           "views_uniques_total" => views["uniques"],
           "clones_total" => clones["count"],
           "clones_uniques_total" => clones["uniques"]
         }
       }}
    end
  end

  defp get_json(owner, name, path, token, opts) do
    encoded_owner = URI.encode(owner)
    encoded_name = URI.encode(name)
    url = "https://api.github.com/repos/#{encoded_owner}/#{encoded_name}/#{path}"
    timeout = Keyword.get(opts, :request_timeout_ms, Ingestion.config(:request_timeout_ms, 15_000))

    headers = [
      {"Accept", "application/vnd.github+json"},
      {"Authorization", "Bearer #{token}"},
      {"X-GitHub-Api-Version", Ingestion.config(:github_api_version, "2026-03-10")},
      {"User-Agent", @user_agent}
    ]

    request = Finch.build(:get, url, headers)

    case Finch.request(request, AgentJido.Finch, receive_timeout: timeout) do
      {:ok, %Finch.Response{status: status, body: body}} when status in 200..299 ->
        Jason.decode(body)

      {:ok, %Finch.Response{status: 403, body: body}} ->
        {:error, {:github_forbidden, body}}

      {:ok, %Finch.Response{status: 404, body: body}} ->
        {:error, {:github_not_found, body}}

      {:ok, %Finch.Response{status: 429, body: body}} ->
        {:error, {:github_rate_limited, body}}

      {:ok, %Finch.Response{status: status, body: body}} ->
        {:error, {:github_http_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp merge_daily_series(views, clones) do
    view_days = Map.new(views, &{day_key(&1), &1})
    clone_days = Map.new(clones, &{day_key(&1), &1})

    (Map.keys(view_days) ++ Map.keys(clone_days))
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.map(fn day ->
      view = Map.get(view_days, day, %{})
      clone = Map.get(clone_days, day, %{})

      %{
        day: day,
        views_count: int(view["count"]),
        views_uniques: int(view["uniques"]),
        clones_count: int(clone["count"]),
        clones_uniques: int(clone["uniques"])
      }
    end)
  end

  defp normalize_paths(paths) when is_list(paths) do
    Enum.map(paths, fn row ->
      %{
        path: row["path"],
        title: row["title"],
        count: int(row["count"]),
        uniques: int(row["uniques"])
      }
    end)
  end

  defp normalize_paths(_paths), do: []

  defp normalize_referrers(referrers) when is_list(referrers) do
    Enum.map(referrers, fn row ->
      %{
        referrer: row["referrer"],
        count: int(row["count"]),
        uniques: int(row["uniques"])
      }
    end)
  end

  defp normalize_referrers(_referrers), do: []

  defp token(opts) do
    case GitHubAppAuth.fetch_installation_token(opts) do
      {:ok, token} ->
        {:ok, token}

      {:error, :missing_github_app_config} ->
        pat_token(opts)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp pat_token(opts) do
    case opts |> Keyword.get(:github_token, Ingestion.config(:github_token)) |> normalize_token() do
      nil -> {:error, :missing_github_auth}
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

  defp day_key(%{"timestamp" => timestamp}) when is_binary(timestamp), do: String.slice(timestamp, 0, 10)
  defp day_key(_row), do: nil

  defp int(value) when is_integer(value), do: value
  defp int(value) when is_float(value), do: trunc(value)
  defp int(_value), do: 0
end
