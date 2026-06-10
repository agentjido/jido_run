defmodule AgentJido.Analytics.GitHub.Collector do
  @moduledoc """
  Collects GitHub traffic metrics and stores them as daily analytics snapshots.
  """

  require Logger

  alias AgentJido.Analytics.GitHub

  @default_request_timeout_ms 10_000
  @default_user_agent "AgentJido-GitHubTrafficCollector"

  defmodule Client do
    @moduledoc """
    Behaviour for GitHub traffic API clients.
    """

    @callback fetch_repo_traffic(String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  end

  defmodule DefaultClient do
    @moduledoc false
    @behaviour AgentJido.Analytics.GitHub.Collector.Client

    @impl true
    def fetch_repo_traffic(owner, repo, opts) when is_binary(owner) and is_binary(repo) do
      with {:ok, views} <- fetch(owner, repo, "/traffic/views?per=day", opts),
           {:ok, clones} <- fetch(owner, repo, "/traffic/clones?per=day", opts),
           {:ok, referrers} <- fetch(owner, repo, "/traffic/popular/referrers", opts),
           {:ok, paths} <- fetch(owner, repo, "/traffic/popular/paths", opts) do
        {:ok, %{views: views, clones: clones, referrers: referrers, paths: paths}}
      end
    end

    defp fetch(owner, repo, path, opts) do
      url = "https://api.github.com/repos/#{owner}/#{repo}#{path}"
      request_timeout_ms = Keyword.get(opts, :request_timeout_ms, 10_000)

      request = Finch.build(:get, url, headers(opts))

      case Finch.request(request, AgentJido.Finch, receive_timeout: request_timeout_ms) do
        {:ok, %Finch.Response{status: 200, body: body}} -> Jason.decode(body)
        {:ok, %Finch.Response{status: status, body: body}} -> {:error, {:http_error, status, body}}
        {:error, reason} -> {:error, reason}
      end
    end

    defp headers(opts) do
      [
        {"Accept", "application/vnd.github+json"},
        {"User-Agent", Keyword.get(opts, :user_agent, "AgentJido-GitHubTrafficCollector")}
      ]
      |> maybe_put_auth_header(Keyword.get(opts, :github_token))
    end

    defp maybe_put_auth_header(headers, token) when is_binary(token) and token != "" do
      [{"Authorization", "Bearer #{token}"} | headers]
    end

    defp maybe_put_auth_header(headers, _token), do: headers
  end

  @doc """
  Fetches and persists GitHub traffic for one repository.

  The `repo` argument may be either `"owner/name"` or `%{owner: owner, repo: repo}`.
  """
  @spec collect_repo(String.t() | %{required(:owner) => String.t(), required(:repo) => String.t()}, keyword()) ::
          {:ok, map()} | {:error, term()}
  def collect_repo(repo, opts \\ [])

  def collect_repo(repo, opts) when is_binary(repo) do
    case String.split(repo, "/", parts: 2) do
      [owner, name] -> collect_repo(%{owner: owner, repo: name}, opts)
      _other -> {:error, :invalid_repo}
    end
  end

  def collect_repo(%{owner: owner, repo: name}, opts) when is_binary(owner) and is_binary(name) do
    client = Keyword.get(opts, :client, config(:client, DefaultClient))
    fetched_at = DateTime.utc_now()
    repo_slug = "#{owner}/#{name}"

    request_opts = [
      request_timeout_ms: Keyword.get(opts, :request_timeout_ms, config(:request_timeout_ms, @default_request_timeout_ms)),
      user_agent: Keyword.get(opts, :user_agent, config(:user_agent, @default_user_agent)),
      github_token: Keyword.get(opts, :github_token, config(:github_token, nil))
    ]

    with {:ok, traffic} <- client.fetch_repo_traffic(owner, name, request_opts),
         {:ok, repo_rows} <- persist_repo_daily(repo_slug, traffic, fetched_at),
         snapshot_date = DateTime.to_date(fetched_at),
         referrers = normalize_referrers(traffic),
         {:ok, referrer_rows} <- GitHub.upsert_referrers(snapshot_date, repo_slug, referrers, fetched_at),
         {:ok, path_rows} <- GitHub.upsert_paths(snapshot_date, repo_slug, normalize_paths(traffic), fetched_at) do
      {:ok, %{repo_daily: repo_rows, referrers: referrer_rows, paths: path_rows}}
    else
      {:error, reason} = error ->
        Logger.warning("GitHub traffic collection failed for #{repo_slug}: #{inspect(reason)}")
        error
    end
  end

  def collect_repo(_repo, _opts), do: {:error, :invalid_repo}

  defp persist_repo_daily(repo, traffic, fetched_at) do
    rows = merge_daily_counts(repo, traffic, fetched_at)

    Enum.reduce_while(rows, {:ok, []}, fn attrs, {:ok, acc} ->
      case GitHub.upsert_repo_daily(attrs) do
        {:ok, row} -> {:cont, {:ok, [row | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, rows} -> {:ok, Enum.reverse(rows)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp merge_daily_counts(repo, traffic, fetched_at) do
    views_by_date = traffic |> Map.get(:views, Map.get(traffic, "views", %{})) |> daily_counts("views", "uniques")
    clones_by_date = traffic |> Map.get(:clones, Map.get(traffic, "clones", %{})) |> daily_counts("clones", "uniques")

    (Map.keys(views_by_date) ++ Map.keys(clones_by_date))
    |> Enum.uniq()
    |> Enum.map(fn date ->
      views = Map.get(views_by_date, date, %{count: 0, uniques: 0})
      clones = Map.get(clones_by_date, date, %{count: 0, uniques: 0})

      %{
        date: date,
        repo: repo,
        views: views.count,
        unique_visitors: views.uniques,
        clones: clones.count,
        unique_cloners: clones.uniques,
        fetched_at: fetched_at
      }
    end)
  end

  defp daily_counts(payload, count_key, uniques_key) when is_map(payload) do
    payload
    |> Map.get(count_key, [])
    |> daily_counts(count_key, uniques_key)
  end

  defp daily_counts(rows, count_key, uniques_key) when is_list(rows) do
    rows
    |> Enum.reduce(%{}, fn row, acc ->
      case parse_github_date(Map.get(row, "timestamp")) do
        {:ok, date} -> Map.put(acc, date, %{count: int(row["count"] || row[count_key]), uniques: int(row[uniques_key])})
        :error -> acc
      end
    end)
  end

  defp daily_counts(_payload, _count_key, _uniques_key), do: %{}

  defp normalize_referrers(traffic) do
    traffic
    |> Map.get(:referrers, Map.get(traffic, "referrers", []))
    |> Enum.map(&%{referrer: Map.get(&1, "referrer"), views: int(Map.get(&1, "count")), uniques: int(Map.get(&1, "uniques"))})
  end

  defp normalize_paths(traffic) do
    traffic
    |> Map.get(:paths, Map.get(traffic, "paths", []))
    |> Enum.map(&%{path: Map.get(&1, "path"), title: Map.get(&1, "title"), views: int(Map.get(&1, "count")), uniques: int(Map.get(&1, "uniques"))})
  end

  defp parse_github_date(<<date::binary-size(10), _rest::binary>>), do: Date.from_iso8601(date)
  defp parse_github_date(_timestamp), do: :error

  defp int(value) when is_integer(value) and value >= 0, do: value
  defp int(_value), do: 0

  defp config(key, default) do
    :agent_jido
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(key, default)
  end
end
