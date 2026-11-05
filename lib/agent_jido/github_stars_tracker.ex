defmodule AgentJido.GithubStarsTracker do
  @moduledoc """
  Periodically fetches GitHub star counts for public ecosystem packages and
  serves them from in-memory cache.

  This tracker is intentionally failure-tolerant:

  - fetch errors never crash the process
  - previously cached values are preserved when refreshes fail
  - callers always get a fast, non-blocking read path
  """

  use GenServer

  require Logger

  alias AgentJido.Ecosystem

  @default_refresh_interval_ms :timer.hours(1)
  @default_request_timeout_ms 10_000
  @default_min_request_interval_ms 200
  @default_rate_limit_cooldown_ms :timer.minutes(15)
  @default_user_agent "AgentJido-GithubStarsTracker"

  @typedoc "Cached star payload for one package."
  @type star_entry :: %{stars: non_neg_integer(), updated_at: DateTime.t()}

  @typedoc "Cached stars indexed by ecosystem package id."
  @type stars_map :: %{optional(String.t()) => star_entry()}

  @typedoc "Normalized GitHub repository metadata for one package."
  @type repo_ref :: %{
          owner: String.t(),
          repo: String.t(),
          github_url: String.t(),
          cache_timeout_ms: pos_integer() | :infinity
        }

  defmodule Fetcher do
    @moduledoc """
    Behaviour for fetching GitHub star counts.
    """

    @callback fetch_repo_stars(owner :: String.t(), repo :: String.t(), opts :: keyword()) ::
                {:ok, non_neg_integer()} | {:error, term()}
  end

  defmodule DefaultFetcher do
    @moduledoc false
    @behaviour AgentJido.GithubStarsTracker.Fetcher

    @impl true
    def fetch_repo_stars(owner, repo, opts) when is_binary(owner) and is_binary(repo) do
      url = "https://api.github.com/repos/#{owner}/#{repo}"
      request_timeout_ms = Keyword.get(opts, :request_timeout_ms, 10_000)
      user_agent = Keyword.get(opts, :user_agent, "AgentJido-GithubStarsTracker")
      token = Keyword.get(opts, :token)

      headers =
        [
          {"Accept", "application/vnd.github+json"},
          {"User-Agent", user_agent}
        ]
        |> maybe_put_auth_header(token)

      request = Finch.build(:get, url, headers)

      case Finch.request(request, AgentJido.Finch, receive_timeout: request_timeout_ms) do
        {:ok, %Finch.Response{status: 200, body: body}} ->
          case Jason.decode(body) do
            {:ok, %{"stargazers_count" => stars}} when is_integer(stars) and stars >= 0 ->
              {:ok, stars}

            {:ok, _other} ->
              {:error, :invalid_response}

            {:error, reason} ->
              {:error, {:invalid_json, reason}}
          end

        {:ok, %Finch.Response{status: status, body: body}} ->
          {:error, {:http_error, status, body}}

        {:error, reason} ->
          {:error, reason}
      end
    end

    defp maybe_put_auth_header(headers, token) when is_binary(token) and token != "" do
      [{"Authorization", "Bearer #{token}"} | headers]
    end

    defp maybe_put_auth_header(headers, _token), do: headers
  end

  @doc """
  Starts the tracker process.

  Supported options:

  - `:name` process name (defaults to module name)
  - `:fetcher` fetcher module implementing `Fetcher`
  - `:request_timeout_ms` HTTP request timeout
  - `:refresh_interval_ms` periodic refresh cadence
  - `:min_request_interval_ms` minimum delay between GitHub API requests
  - `:rate_limit_cooldown_ms` cooldown when GitHub rate limits are detected
  - `:repo_cache_timeout_ms` package-id keyed cache timeout override map
  - `:use_auth_token` include Authorization header when `:github_token` is set (default: false)
  - `:github_token` optional token override
  - `:repos` optional pre-resolved package->repo map (primarily for tests)
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Returns cached stars indexed by package id.
  """
  @spec stars_map() :: stars_map()
  def stars_map do
    case Process.whereis(__MODULE__) do
      nil -> %{}
      _pid -> GenServer.call(__MODULE__, :stars_map)
    end
  end

  @doc """
  Returns cached stars for one package id.
  """
  @spec stars_for(String.t()) :: star_entry() | nil
  def stars_for(package_id) when is_binary(package_id) do
    case Process.whereis(__MODULE__) do
      nil -> nil
      _pid -> GenServer.call(__MODULE__, {:stars_for, package_id})
    end
  end

  @doc """
  Triggers an immediate refresh.
  """
  @spec refresh() :: :ok
  def refresh do
    case Process.whereis(__MODULE__) do
      nil -> :ok
      _pid -> GenServer.call(__MODULE__, :refresh)
    end
  end

  @doc """
  Formats a star count for compact UI display.

  Examples:

  - `999` => `"999"`
  - `1200` => `"1.2k"`
  - `1500000` => `"1.5M"`
  """
  @spec format_stars(non_neg_integer()) :: String.t()
  def format_stars(stars) when is_integer(stars) and stars >= 0 do
    cond do
      stars >= 1_000_000 ->
        compact(stars / 1_000_000, "M")

      stars >= 1_000 ->
        compact(stars / 1_000, "k")

      true ->
        Integer.to_string(stars)
    end
  end

  @impl true
  def init(opts) do
    repo_cache_timeout_ms =
      Keyword.get(opts, :repo_cache_timeout_ms, config(:repo_cache_timeout_ms, %{}))

    repos =
      Keyword.get_lazy(opts, :repos, fn ->
        build_repo_map(Ecosystem.public_packages(), repo_cache_timeout_ms)
      end)
      |> normalize_repo_timeout_overrides(repo_cache_timeout_ms)

    fetcher = Keyword.get(opts, :fetcher, config(:fetcher, DefaultFetcher))
    request_timeout_ms = Keyword.get(opts, :request_timeout_ms, config(:request_timeout_ms, @default_request_timeout_ms))
    refresh_interval_ms = Keyword.get(opts, :refresh_interval_ms, config(:refresh_interval_ms, @default_refresh_interval_ms))
    min_request_interval_ms = Keyword.get(opts, :min_request_interval_ms, config(:min_request_interval_ms, @default_min_request_interval_ms))
    rate_limit_cooldown_ms = Keyword.get(opts, :rate_limit_cooldown_ms, config(:rate_limit_cooldown_ms, @default_rate_limit_cooldown_ms))
    use_auth_token = Keyword.get(opts, :use_auth_token, config(:use_auth_token, false))
    github_token = normalize_token(Keyword.get(opts, :github_token, config(:github_token, nil)))

    state = %{
      repos: repos,
      stars_map: %{},
      last_refresh_at: nil,
      fetcher: fetcher,
      request_timeout_ms: request_timeout_ms,
      refresh_interval_ms: refresh_interval_ms,
      min_request_interval_ms: normalize_non_neg_integer(min_request_interval_ms, @default_min_request_interval_ms),
      rate_limit_cooldown_ms: normalize_positive_integer(rate_limit_cooldown_ms, @default_rate_limit_cooldown_ms),
      rate_limit_reset_monotonic_ms: nil,
      last_request_monotonic_ms: nil,
      github_token: github_token,
      use_auth_token: use_auth_token == true and is_binary(github_token)
    }

    send(self(), :refresh)
    schedule_refresh(refresh_interval_ms)

    {:ok, ensure_state_defaults(state)}
  end

  @impl true
  def handle_call(:stars_map, _from, state) do
    normalized_state = ensure_state_defaults(state)
    {:reply, active_stars_map(normalized_state), normalized_state}
  end

  @impl true
  def handle_call({:stars_for, package_id}, _from, state) do
    normalized_state = ensure_state_defaults(state)
    {:reply, active_star_for(normalized_state, package_id), normalized_state}
  end

  @impl true
  def handle_call(:refresh, _from, state) do
    new_state =
      state
      |> ensure_state_defaults()
      |> refresh_stars()

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_info(:refresh, state) do
    normalized_state = ensure_state_defaults(state)
    schedule_refresh(normalized_state.refresh_interval_ms)
    {:noreply, refresh_stars(normalized_state)}
  end

  defp config(key, default) do
    :agent_jido
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(key, default)
  end

  defp schedule_refresh(interval_ms) when is_integer(interval_ms) and interval_ms > 0 do
    Process.send_after(self(), :refresh, interval_ms)
  end

  defp refresh_stars(state) do
    now = DateTime.utc_now()
    now_monotonic_ms = System.monotonic_time(:millisecond)

    case state.rate_limit_reset_monotonic_ms do
      reset_ms when is_integer(reset_ms) and reset_ms > now_monotonic_ms ->
        remaining_ms = reset_ms - now_monotonic_ms

        Logger.warning("[GithubStarsTracker] refresh skipped cooldown_ms_remaining=#{remaining_ms}")

        %{state | last_refresh_at: now}

      _other ->
        {next_stars_map, success_count, failure_count, halted_for_rate_limit, next_state} =
          Enum.reduce_while(
            state.repos,
            {state.stars_map, 0, 0, false, state},
            fn {package_id, repo_ref}, {acc, success, failure, _halted, state_acc} ->
              {result, state_after_fetch} = fetch_repo_stars(state_acc, repo_ref)
              handle_refresh_result(result, package_id, repo_ref, now, acc, success, failure, state_after_fetch)
            end
          )

        Logger.info(
          "[GithubStarsTracker] refresh complete success=#{success_count} failure=#{failure_count} total=#{map_size(state.repos)} halted_for_rate_limit=#{halted_for_rate_limit}"
        )

        %{next_state | stars_map: next_stars_map, last_refresh_at: now}
    end
  end

  defp handle_refresh_error(package_id, repo_ref, reason, acc, success, failure, state_after_fetch) do
    Logger.warning("[GithubStarsTracker] fetch failed package=#{package_id} repo=#{repo_ref.owner}/#{repo_ref.repo} reason=#{inspect(reason)}")

    if rate_limited_reason?(reason) do
      cooldown_until =
        System.monotonic_time(:millisecond) +
          state_after_fetch.rate_limit_cooldown_ms

      state_with_cooldown = %{
        state_after_fetch
        | rate_limit_reset_monotonic_ms: cooldown_until
      }

      {:halt, {acc, success, failure + 1, true, state_with_cooldown}}
    else
      {:cont, {acc, success, failure + 1, false, state_after_fetch}}
    end
  end

  defp handle_refresh_result(
         {:ok, stars},
         package_id,
         _repo_ref,
         now,
         acc,
         success,
         failure,
         state_after_fetch
       )
       when is_integer(stars) and stars >= 0 do
    updated_entry = %{stars: stars, updated_at: now}
    {:cont, {Map.put(acc, package_id, updated_entry), success + 1, failure, false, state_after_fetch}}
  end

  defp handle_refresh_result(
         {:error, reason},
         package_id,
         repo_ref,
         _now,
         acc,
         success,
         failure,
         state_after_fetch
       ) do
    handle_refresh_error(
      package_id,
      repo_ref,
      reason,
      acc,
      success,
      failure,
      state_after_fetch
    )
  end

  defp build_repo_map(packages, repo_cache_timeout_ms) when is_list(packages) and is_map(repo_cache_timeout_ms) do
    Enum.reduce(packages, %{}, fn pkg, acc ->
      case package_repo_ref(pkg, Map.get(repo_cache_timeout_ms, pkg.id)) do
        {:ok, repo_ref} -> Map.put(acc, pkg.id, repo_ref)
        :error -> acc
      end
    end)
  end

  defp package_repo_ref(pkg, timeout_override) do
    owner = normalize_text(Map.get(pkg, :github_org))
    repo = normalize_text(Map.get(pkg, :github_repo))
    github_url = normalize_text(Map.get(pkg, :github_url))
    cache_timeout_ms = normalize_cache_timeout(timeout_override)

    cond do
      owner != "" and repo != "" ->
        {:ok,
         %{
           owner: owner,
           repo: repo,
           github_url: build_repo_url(owner, repo, github_url),
           cache_timeout_ms: cache_timeout_ms
         }}

      github_url != "" ->
        case parse_repo_from_url(github_url) do
          {:ok, parsed_owner, parsed_repo} ->
            {:ok, %{owner: parsed_owner, repo: parsed_repo, github_url: github_url, cache_timeout_ms: cache_timeout_ms}}

          :error ->
            :error
        end

      true ->
        :error
    end
  end

  defp parse_repo_from_url(url) when is_binary(url) do
    uri = URI.parse(url)
    host = normalize_text(uri.host || "")

    path_segments =
      uri.path
      |> normalize_text()
      |> String.trim_leading("/")
      |> String.split("/", trim: true)

    case {host, path_segments} do
      {host_name, [owner, repo | _rest]} when host_name in ["github.com", "www.github.com"] ->
        owner = normalize_text(owner)
        repo = normalize_text(repo)

        if owner != "" and repo != "" do
          {:ok, owner, repo}
        else
          :error
        end

      _other ->
        :error
    end
  end

  defp parse_repo_from_url(_), do: :error

  defp build_repo_url(owner, repo, ""), do: "https://github.com/#{owner}/#{repo}"
  defp build_repo_url(_owner, _repo, github_url), do: github_url

  defp normalize_repo_timeout_overrides(repos, repo_cache_timeout_ms) when is_map(repos) and is_map(repo_cache_timeout_ms) do
    Enum.into(repos, %{}, fn {package_id, repo_ref} ->
      effective_timeout =
        repo_ref
        |> Map.get(:cache_timeout_ms, Map.get(repo_cache_timeout_ms, package_id))
        |> normalize_cache_timeout()

      {package_id, Map.put(repo_ref, :cache_timeout_ms, effective_timeout)}
    end)
  end

  defp normalize_cache_timeout(timeout_ms) when is_integer(timeout_ms) and timeout_ms > 0, do: timeout_ms
  defp normalize_cache_timeout(:infinity), do: :infinity
  defp normalize_cache_timeout(_), do: :infinity

  defp active_stars_map(state) do
    now = DateTime.utc_now()

    Enum.reduce(state.stars_map, %{}, fn {package_id, entry}, acc ->
      if stale_entry?(state, package_id, entry, now) do
        acc
      else
        Map.put(acc, package_id, entry)
      end
    end)
  end

  defp active_star_for(state, package_id) when is_binary(package_id) do
    now = DateTime.utc_now()

    case Map.get(state.stars_map, package_id) do
      nil ->
        nil

      entry ->
        if stale_entry?(state, package_id, entry, now), do: nil, else: entry
    end
  end

  defp stale_entry?(state, package_id, entry, now) do
    case timeout_for_repo(state, package_id) do
      :infinity ->
        false

      timeout_ms when is_integer(timeout_ms) and timeout_ms > 0 ->
        DateTime.diff(now, entry.updated_at, :millisecond) > timeout_ms
    end
  end

  defp timeout_for_repo(state, package_id) do
    state.repos
    |> Map.get(package_id, %{})
    |> Map.get(:cache_timeout_ms, :infinity)
    |> normalize_cache_timeout()
  end

  defp fetch_repo_stars(state, repo_ref) do
    state_with_slot = apply_request_rate_limit(state)
    token = if state_with_slot.use_auth_token, do: state_with_slot.github_token, else: nil

    case fetch_once(state_with_slot, repo_ref, token) do
      {:ok, stars} ->
        {{:ok, stars}, state_with_slot}

      {:error, reason} ->
        maybe_retry_without_token(state_with_slot, repo_ref, reason, token)
    end
  end

  defp maybe_retry_without_token(state, _repo_ref, reason, nil), do: {{:error, reason}, state}

  defp maybe_retry_without_token(state, repo_ref, reason, token) when is_binary(token) do
    if bad_credentials_reason?(reason) do
      Logger.warning("[GithubStarsTracker] github_token rejected (401); falling back to anonymous GitHub requests")

      state_without_token = %{state | use_auth_token: false}

      case fetch_once(state_without_token, repo_ref, nil) do
        {:ok, stars} -> {{:ok, stars}, state_without_token}
        {:error, retry_reason} -> {{:error, retry_reason}, state_without_token}
      end
    else
      {{:error, reason}, state}
    end
  end

  defp fetch_once(state, repo_ref, token) do
    fetch_opts = [
      request_timeout_ms: state.request_timeout_ms,
      token: token,
      user_agent: @default_user_agent
    ]

    state.fetcher.fetch_repo_stars(repo_ref.owner, repo_ref.repo, fetch_opts)
  end

  # Running trackers can hold old state maps after hot code reloads.
  # Populate and sanitize newly introduced keys before processing callbacks.
  defp ensure_state_defaults(state) when is_map(state) do
    github_token = normalize_token(Map.get(state, :github_token))
    use_auth_token? = Map.get(state, :use_auth_token, false) == true and is_binary(github_token)

    state
    |> Map.put_new(:repos, %{})
    |> Map.put_new(:stars_map, %{})
    |> Map.put_new(:last_refresh_at, nil)
    |> Map.put_new(:fetcher, DefaultFetcher)
    |> Map.update(:request_timeout_ms, @default_request_timeout_ms, &normalize_positive_integer(&1, @default_request_timeout_ms))
    |> Map.update(:refresh_interval_ms, @default_refresh_interval_ms, &normalize_positive_integer(&1, @default_refresh_interval_ms))
    |> Map.update(:min_request_interval_ms, @default_min_request_interval_ms, &normalize_non_neg_integer(&1, @default_min_request_interval_ms))
    |> Map.update(:rate_limit_cooldown_ms, @default_rate_limit_cooldown_ms, &normalize_positive_integer(&1, @default_rate_limit_cooldown_ms))
    |> Map.update(:rate_limit_reset_monotonic_ms, nil, &normalize_optional_integer/1)
    |> Map.update(:last_request_monotonic_ms, nil, &normalize_optional_integer/1)
    |> Map.put(:github_token, github_token)
    |> Map.put(:use_auth_token, use_auth_token?)
  end

  defp apply_request_rate_limit(state) do
    min_interval_ms = state.min_request_interval_ms

    if min_interval_ms <= 0 do
      %{state | last_request_monotonic_ms: System.monotonic_time(:millisecond)}
    else
      now = System.monotonic_time(:millisecond)
      previous = state.last_request_monotonic_ms

      wait_ms =
        case previous do
          nil -> 0
          last when is_integer(last) -> max(min_interval_ms - (now - last), 0)
        end

      if wait_ms > 0 do
        Process.sleep(wait_ms)
      end

      %{state | last_request_monotonic_ms: System.monotonic_time(:millisecond)}
    end
  end

  defp rate_limited_reason?(:rate_limited), do: true
  defp rate_limited_reason?({:http_error, 429, _body}), do: true

  defp rate_limited_reason?({:http_error, 403, body}) when is_binary(body) do
    normalized = String.downcase(body)
    String.contains?(normalized, "rate limit")
  end

  defp rate_limited_reason?(_reason), do: false

  defp bad_credentials_reason?({:http_error, 401, _body}), do: true
  defp bad_credentials_reason?(_reason), do: false

  defp normalize_token(token) when is_binary(token) do
    trimmed = String.trim(token)
    if trimmed == "", do: nil, else: trimmed
  end

  defp normalize_token(_), do: nil

  defp normalize_non_neg_integer(value, _default) when is_integer(value) and value >= 0, do: value
  defp normalize_non_neg_integer(_value, default), do: default

  defp normalize_optional_integer(value) when is_integer(value), do: value
  defp normalize_optional_integer(_value), do: nil

  defp normalize_positive_integer(value, _default) when is_integer(value) and value > 0, do: value
  defp normalize_positive_integer(_value, default), do: default

  defp normalize_text(nil), do: ""

  defp normalize_text(value) when is_binary(value) do
    value
    |> String.trim()
    |> String.replace(~r/\s+/, " ")
  end

  defp normalize_text(value), do: value |> to_string() |> normalize_text()

  defp compact(value, suffix) do
    rounded = Float.round(value, 1)

    number =
      if rounded == trunc(rounded) do
        rounded
        |> trunc()
        |> Integer.to_string()
      else
        :erlang.float_to_binary(rounded, decimals: 1)
      end

    number <> suffix
  end
end
