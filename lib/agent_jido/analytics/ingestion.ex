defmodule AgentJido.Analytics.Ingestion do
  @moduledoc """
  External analytics ingestion for repo, website, and search visibility data.

  This context keeps credentials in runtime configuration and stores only the
  tracked sources, ingestion audit rows, and normalized metric snapshots.
  """
  import Ecto.Query, warn: false

  alias AgentJido.Analytics.Ingestion.GitHubAppAuth
  alias AgentJido.Analytics.Ingestion.GitHubPathSnapshot
  alias AgentJido.Analytics.Ingestion.GitHubReferrerSnapshot
  alias AgentJido.Analytics.Ingestion.GitHubRepoDaily
  alias AgentJido.Analytics.Ingestion.HexPackageDaily
  alias AgentJido.Analytics.Ingestion.HexReleaseDaily
  alias AgentJido.Analytics.Ingestion.IngestionRun
  alias AgentJido.Analytics.Ingestion.PlausibleDimensionDaily
  alias AgentJido.Analytics.Ingestion.PlausibleSiteDaily
  alias AgentJido.Analytics.Ingestion.SearchConsoleDaily
  alias AgentJido.Analytics.Ingestion.TrackedHexPackage
  alias AgentJido.Analytics.Ingestion.TrackedRepository
  alias AgentJido.Analytics.Ingestion.Workers.DispatcherWorker
  alias AgentJido.Analytics.Ingestion.Workers.GitHubTrafficWorker
  alias AgentJido.Analytics.Ingestion.Workers.HexWorker
  alias AgentJido.Analytics.Ingestion.Workers.PlausibleWorker
  alias AgentJido.Analytics.Ingestion.Workers.SearchConsoleWorker
  alias AgentJido.Ecosystem
  alias AgentJido.Repo

  @known_site_repositories [
    %{owner: "agentjido", name: "jido_run", label: "Jido Run", source: "site"},
    %{owner: "agentjido", name: "agentjido_xyz", label: "Jido docs", source: "site"}
  ]
  @excluded_github_traffic_repositories [
    {"www-zaq-ai", "jido_chat_mattermost"}
  ]
  @github_daily_replace [
    :views_count,
    :views_uniques,
    :clones_count,
    :clones_uniques,
    :metadata,
    :updated_at
  ]
  @plausible_site_replace [
    :visitors,
    :visits,
    :pageviews,
    :bounce_rate,
    :visit_duration,
    :events,
    :metadata,
    :updated_at
  ]
  @plausible_dimension_replace [
    :value,
    :visitors,
    :visits,
    :pageviews,
    :bounce_rate,
    :visit_duration,
    :events,
    :metadata,
    :updated_at
  ]
  @search_console_replace [
    :query,
    :page,
    :country,
    :device,
    :clicks,
    :impressions,
    :ctr,
    :position,
    :metadata,
    :updated_at
  ]
  @hex_package_replace [
    :package_name,
    :latest_version,
    :downloads_day,
    :downloads_week,
    :downloads_recent,
    :downloads_all,
    :metadata,
    :updated_at
  ]
  @hex_release_replace [
    :package_name,
    :downloads_total,
    :release_inserted_at,
    :has_docs,
    :metadata,
    :updated_at
  ]
  @incomplete_job_states [:available, :scheduled, :executing, :retryable, :suspended]

  @doc """
  Reads an ingestion configuration value.
  """
  @spec config(atom(), term()) :: term()
  def config(key, default \\ nil) when is_atom(key) do
    :agent_jido
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(key, default)
  end

  @doc """
  Returns true when GitHub traffic auth is configured by app credentials or PAT.
  """
  @spec github_auth_configured?(keyword()) :: boolean()
  def github_auth_configured?(opts \\ []) do
    GitHubAppAuth.configured?(opts) or present?(Keyword.get(opts, :github_token, config(:github_token)))
  end

  @doc """
  Returns true when Plausible has both a site id and API key configured.
  """
  @spec plausible_configured?() :: boolean()
  def plausible_configured? do
    present?(config(:plausible_site_id)) and present?(config(:plausible_api_key))
  end

  @doc """
  Returns true when Search Console has both a property URL and service-account credentials.
  """
  @spec search_console_configured?() :: boolean()
  def search_console_configured? do
    present?(config(:search_console_site_url)) and
      (present?(config(:search_console_credentials_json)) or present?(config(:search_console_credentials_json_path)))
  end

  @doc """
  Returns active repositories selected for Git traffic collection.
  """
  @spec list_active_tracked_repositories() :: [TrackedRepository.t()]
  def list_active_tracked_repositories do
    TrackedRepository
    |> where([r], r.active == true and r.provider == "github")
    |> order_by([r], asc: r.owner, asc: r.name)
    |> Repo.all()
  end

  @doc """
  Fetches a tracked repository by id.
  """
  @spec get_tracked_repository(Ecto.UUID.t()) :: TrackedRepository.t() | nil
  def get_tracked_repository(id) when is_binary(id), do: Repo.get(TrackedRepository, id)
  def get_tracked_repository(_id), do: nil

  @doc """
  Returns active Hex packages selected for download tracking.
  """
  @spec list_active_tracked_hex_packages() :: [TrackedHexPackage.t()]
  def list_active_tracked_hex_packages do
    TrackedHexPackage
    |> where([p], p.active == true)
    |> order_by([p], asc: p.package_name)
    |> Repo.all()
  end

  @doc """
  Inserts or updates a tracked repository.
  """
  @spec upsert_tracked_repository(map()) :: {:ok, TrackedRepository.t()} | {:error, Ecto.Changeset.t()}
  def upsert_tracked_repository(attrs) when is_map(attrs) do
    attrs =
      attrs
      |> Map.new(fn {key, value} -> {normalize_key(key), value} end)
      |> Map.put_new(:provider, "github")
      |> Map.put_new_lazy(:url, fn -> repo_url(attrs) end)

    changeset = TrackedRepository.changeset(%TrackedRepository{}, attrs)

    case Repo.insert(changeset,
           on_conflict: {:replace, [:full_name, :url, :label, :source, :active, :metadata, :updated_at]},
           conflict_target: [:provider, :owner, :name]
         ) do
      {:ok, repository} ->
        {:ok,
         Repo.get_by!(TrackedRepository,
           provider: repository.provider,
           owner: repository.owner,
           name: repository.name
         )}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Inserts or updates a tracked Hex package.
  """
  @spec upsert_tracked_hex_package(map()) :: {:ok, TrackedHexPackage.t()} | {:error, Ecto.Changeset.t()}
  def upsert_tracked_hex_package(attrs) when is_map(attrs) do
    attrs =
      attrs
      |> Map.new(fn {key, value} -> {normalize_key(key), value} end)
      |> Map.put_new_lazy(:url, fn -> hex_package_url(attrs) end)

    changeset = TrackedHexPackage.changeset(%TrackedHexPackage{}, attrs)

    case Repo.insert(changeset,
           on_conflict: {:replace, [:display_name, :url, :source, :active, :metadata, :updated_at]},
           conflict_target: [:package_name]
         ) do
      {:ok, package} ->
        {:ok, Repo.get_by!(TrackedHexPackage, package_name: package.package_name)}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Seeds the tracked repository table from the public ecosystem registry.
  """
  @spec sync_repositories_from_ecosystem() :: %{inserted_or_updated: non_neg_integer(), errors: [term()]}
  def sync_repositories_from_ecosystem do
    default_tracked_repositories()
    |> Enum.reduce(%{inserted_or_updated: 0, errors: []}, fn attrs, acc ->
      case upsert_tracked_repository(attrs) do
        {:ok, _repo} ->
          %{acc | inserted_or_updated: acc.inserted_or_updated + 1}

        {:error, changeset} ->
          %{acc | errors: [changeset | acc.errors]}
      end
    end)
    |> Map.update!(:errors, &Enum.reverse/1)
  end

  @doc """
  Seeds the tracked Hex package table from the public ecosystem registry.
  """
  @spec sync_hex_packages_from_ecosystem() :: %{inserted_or_updated: non_neg_integer(), errors: [term()]}
  def sync_hex_packages_from_ecosystem do
    default_tracked_hex_packages()
    |> Enum.reduce(%{inserted_or_updated: 0, errors: []}, fn attrs, acc ->
      case upsert_tracked_hex_package(attrs) do
        {:ok, _package} ->
          %{acc | inserted_or_updated: acc.inserted_or_updated + 1}

        {:error, changeset} ->
          %{acc | errors: [changeset | acc.errors]}
      end
    end)
    |> Map.update!(:errors, &Enum.reverse/1)
  end

  @doc """
  Returns the default GitHub repositories worth tracking for Jido.
  """
  @spec default_tracked_repositories() :: [map()]
  def default_tracked_repositories do
    ecosystem_repositories =
      for package <- Ecosystem.public_packages(),
          owner = normalize_text(Map.get(package, :github_org)),
          name = normalize_text(Map.get(package, :github_repo)),
          present?(owner) and present?(name) do
        {active?, traffic_metadata} = github_traffic_tracking_defaults(owner, name)

        %{
          owner: owner,
          name: name,
          label: Map.get(package, :title) || Map.get(package, :name) || name,
          source: "ecosystem",
          active: active?,
          metadata: Map.put(traffic_metadata, "package_id", Map.get(package, :id))
        }
      end

    (@known_site_repositories ++ ecosystem_repositories)
    |> Enum.uniq_by(fn repo -> {repo.owner, repo.name} end)
  end

  @doc """
  Returns the default Hex packages worth tracking for Jido.
  """
  @spec default_tracked_hex_packages() :: [map()]
  def default_tracked_hex_packages do
    Ecosystem.public_packages()
    |> Enum.map(fn package ->
      name = normalize_text(Map.get(package, :name) || Map.get(package, :id))

      if present?(name) do
        %{
          package_name: name,
          display_name: Map.get(package, :title) || name,
          source: "ecosystem",
          metadata: %{"package_id" => Map.get(package, :id)}
        }
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq_by(& &1.package_name)
  end

  @doc """
  Enqueues the dispatcher that fans out source-specific ingestion jobs.
  """
  @spec enqueue_dispatch(keyword()) :: {:ok, Oban.Job.t()} | {:error, Ecto.Changeset.t()}
  def enqueue_dispatch(opts \\ []) do
    args = date_window_args(opts)

    args
    |> DispatcherWorker.new(unique: [period: 300, states: @incomplete_job_states, fields: [:worker, :args]])
    |> Oban.insert()
  end

  @doc """
  Enqueues one GitHub traffic job for a tracked repository.
  """
  @spec enqueue_github_traffic(TrackedRepository.t(), keyword()) :: {:ok, Oban.Job.t()} | {:error, Ecto.Changeset.t()}
  def enqueue_github_traffic(%TrackedRepository{id: id}, opts \\ []) do
    %{"tracked_repository_id" => id}
    |> Map.merge(date_window_args(opts))
    |> GitHubTrafficWorker.new(unique: [period: 3600, states: @incomplete_job_states, fields: [:worker, :args]])
    |> Oban.insert()
  end

  @doc """
  Enqueues a Plausible collection job.
  """
  @spec enqueue_plausible(keyword()) :: {:ok, Oban.Job.t()} | {:error, Ecto.Changeset.t()}
  def enqueue_plausible(opts \\ []) do
    opts
    |> date_window_args()
    |> PlausibleWorker.new(unique: [period: 3600, states: @incomplete_job_states, fields: [:worker, :args]])
    |> Oban.insert()
  end

  @doc """
  Enqueues a Google Search Console collection job.
  """
  @spec enqueue_search_console(keyword()) :: {:ok, Oban.Job.t()} | {:error, Ecto.Changeset.t()}
  def enqueue_search_console(opts \\ []) do
    opts
    |> date_window_args()
    |> SearchConsoleWorker.new(unique: [period: 82_800, states: @incomplete_job_states, fields: [:worker, :args]])
    |> Oban.insert()
  end

  @doc """
  Enqueues a Hex package download snapshot collection job.
  """
  @spec enqueue_hex(keyword()) :: {:ok, Oban.Job.t()} | {:error, Ecto.Changeset.t()}
  def enqueue_hex(opts \\ []) do
    opts
    |> date_window_args()
    |> HexWorker.new(unique: [period: 82_800, states: @incomplete_job_states, fields: [:worker, :args]])
    |> Oban.insert()
  end

  @doc """
  Creates a started ingestion run audit row.
  """
  @spec start_run(String.t(), keyword()) :: IngestionRun.t()
  def start_run(source, opts \\ []) when is_binary(source) do
    Repo.insert!(%IngestionRun{
      source: source,
      status: "running",
      started_at: now(),
      date_from: Keyword.get(opts, :date_from),
      date_to: Keyword.get(opts, :date_to),
      tracked_repository_id: Keyword.get(opts, :tracked_repository_id),
      metadata: Keyword.get(opts, :metadata, %{})
    })
  end

  @doc """
  Marks an ingestion run as completed.
  """
  @spec complete_run(IngestionRun.t(), non_neg_integer(), map()) :: IngestionRun.t()
  def complete_run(%IngestionRun{} = run, rows_count, metadata \\ %{}) when is_integer(rows_count) do
    update_run!(run, %{status: "completed", rows_count: max(rows_count, 0), metadata: metadata})
  end

  @doc """
  Marks an ingestion run as failed.
  """
  @spec fail_run(IngestionRun.t(), term(), map()) :: IngestionRun.t()
  def fail_run(%IngestionRun{} = run, reason, metadata \\ %{}) do
    update_run!(run, %{status: "failed", error: inspect(sanitize_error(reason)), metadata: metadata})
  end

  @doc """
  Upserts normalized GitHub traffic results for one repository.
  """
  @spec upsert_github_traffic(TrackedRepository.t(), map()) :: non_neg_integer()
  def upsert_github_traffic(%TrackedRepository{} = repository, result) when is_map(result) do
    daily_count = upsert_github_daily(repository, Map.get(result, :daily, []))
    snapshot_date = result |> Map.get(:snapshot_date, Date.utc_today()) |> normalize_date!()
    referrer_count = replace_github_referrers(repository, snapshot_date, Map.get(result, :referrers, []))
    path_count = replace_github_paths(repository, snapshot_date, Map.get(result, :paths, []))

    daily_count + referrer_count + path_count
  end

  @doc """
  Upserts daily Plausible aggregate rows.
  """
  @spec upsert_plausible_site_daily(String.t(), [map()]) :: non_neg_integer()
  def upsert_plausible_site_daily(site_id, rows) when is_binary(site_id) and is_list(rows) do
    now = now()

    entries = rows |> Enum.map(&plausible_site_entry(&1, site_id, now)) |> Enum.reject(&is_nil/1)

    insert_all(PlausibleSiteDaily, entries,
      on_conflict: {:replace, @plausible_site_replace},
      conflict_target: [:site_id, :day]
    )
  end

  @doc """
  Upserts daily Plausible rows grouped by a single dimension.
  """
  @spec upsert_plausible_dimension_daily(String.t(), [map()]) :: non_neg_integer()
  def upsert_plausible_dimension_daily(site_id, rows) when is_binary(site_id) and is_list(rows) do
    now = now()

    entries = rows |> Enum.map(&plausible_dimension_entry(&1, site_id, now)) |> Enum.reject(&is_nil/1)

    insert_all(PlausibleDimensionDaily, entries,
      on_conflict: {:replace, @plausible_dimension_replace},
      conflict_target: [:site_id, :day, :dimension, :value_key]
    )
  end

  @doc """
  Upserts bounded Google Search Console rows.
  """
  @spec upsert_search_console_daily(String.t(), [map()]) :: non_neg_integer()
  def upsert_search_console_daily(site_url, rows) when is_binary(site_url) and is_list(rows) do
    now = now()

    entries = rows |> Enum.map(&search_console_entry(&1, site_url, now)) |> Enum.reject(&is_nil/1)

    insert_all(SearchConsoleDaily, entries,
      on_conflict: {:replace, @search_console_replace},
      conflict_target: [:site_url, :day, :dimension_set, :dimension_key, :search_type]
    )
  end

  @doc """
  Upserts public Hex package and release counter snapshots.
  """
  @spec upsert_hex_package_stats(TrackedHexPackage.t(), map()) :: non_neg_integer()
  def upsert_hex_package_stats(%TrackedHexPackage{} = package, result) when is_map(result) do
    package_count = upsert_hex_package_daily(package, Map.get(result, :package, %{}))
    release_count = upsert_hex_release_daily(package, Map.get(result, :releases, []))

    package_count + release_count
  end

  defp upsert_github_daily(repository, rows) do
    now = now()

    entries =
      for row <- rows,
          day = normalize_date(row[:day] || row["day"]) do
        %{
          id: Ecto.UUID.generate(),
          tracked_repository_id: repository.id,
          day: day,
          views_count: integer(row[:views_count] || row["views_count"]),
          views_uniques: integer(row[:views_uniques] || row["views_uniques"]),
          clones_count: integer(row[:clones_count] || row["clones_count"]),
          clones_uniques: integer(row[:clones_uniques] || row["clones_uniques"]),
          metadata: map_value(row[:metadata] || row["metadata"]),
          inserted_at: now,
          updated_at: now
        }
      end

    insert_all(GitHubRepoDaily, entries,
      on_conflict: {:replace, @github_daily_replace},
      conflict_target: [:tracked_repository_id, :day]
    )
  end

  defp upsert_hex_package_daily(package, row) when is_map(row) do
    now = now()

    case hex_package_entry(row, package, now) do
      nil ->
        0

      entry ->
        insert_all(HexPackageDaily, [entry],
          on_conflict: {:replace, @hex_package_replace},
          conflict_target: [:tracked_hex_package_id, :day]
        )
    end
  end

  defp upsert_hex_release_daily(package, rows) when is_list(rows) do
    now = now()

    entries = rows |> Enum.map(&hex_release_entry(&1, package, now)) |> Enum.reject(&is_nil/1)

    insert_all(HexReleaseDaily, entries,
      on_conflict: {:replace, @hex_release_replace},
      conflict_target: [:tracked_hex_package_id, :version, :day]
    )
  end

  defp replace_github_referrers(repository, snapshot_date, rows) do
    now = now()

    entries =
      rows
      |> Enum.with_index(1)
      |> Enum.map(fn {row, rank} -> github_referrer_entry(row, rank, repository.id, snapshot_date, now) end)
      |> Enum.reject(&is_nil/1)

    Repo.transaction(fn ->
      from(row in GitHubReferrerSnapshot,
        where: row.tracked_repository_id == ^repository.id and row.snapshot_date == ^snapshot_date
      )
      |> Repo.delete_all()

      insert_all(GitHubReferrerSnapshot, entries)
    end)
    |> elem(1)
  end

  defp replace_github_paths(repository, snapshot_date, rows) do
    now = now()

    entries =
      rows
      |> Enum.with_index(1)
      |> Enum.map(fn {row, rank} -> github_path_entry(row, rank, repository.id, snapshot_date, now) end)
      |> Enum.reject(&is_nil/1)

    Repo.transaction(fn ->
      from(row in GitHubPathSnapshot,
        where: row.tracked_repository_id == ^repository.id and row.snapshot_date == ^snapshot_date
      )
      |> Repo.delete_all()

      insert_all(GitHubPathSnapshot, entries)
    end)
    |> elem(1)
  end

  defp hex_package_entry(row, package, now) do
    case normalize_date(field(row, :day)) do
      %Date{} = day ->
        %{
          id: Ecto.UUID.generate(),
          tracked_hex_package_id: package.id,
          package_name: normalize_text(field(row, :package_name)) || package.package_name,
          day: day,
          latest_version: normalize_text(field(row, :latest_version)),
          downloads_day: integer(field(row, :downloads_day)),
          downloads_week: integer(field(row, :downloads_week)),
          downloads_recent: integer(field(row, :downloads_recent)),
          downloads_all: integer(field(row, :downloads_all)),
          metadata: map_value(field(row, :metadata)),
          inserted_at: now,
          updated_at: now
        }

      _value ->
        nil
    end
  end

  defp hex_release_entry(row, package, now) do
    with %Date{} = day <- normalize_date(field(row, :day)),
         version when is_binary(version) <- normalize_text(field(row, :version)) do
      %{
        id: Ecto.UUID.generate(),
        tracked_hex_package_id: package.id,
        package_name: normalize_text(field(row, :package_name)) || package.package_name,
        version: version,
        day: day,
        downloads_total: integer(field(row, :downloads_total)),
        release_inserted_at: normalize_datetime(field(row, :release_inserted_at)),
        has_docs: boolean_or_nil(field(row, :has_docs)),
        metadata: map_value(field(row, :metadata)),
        inserted_at: now,
        updated_at: now
      }
    else
      _value -> nil
    end
  end

  defp plausible_site_entry(row, site_id, now) do
    case normalize_date(field(row, :day)) do
      %Date{} = day ->
        %{}
        |> Map.merge(entry_identity(site_id: site_id, day: day))
        |> Map.merge(plausible_metrics(row))
        |> Map.merge(row_metadata(row))
        |> Map.merge(timestamps(now))

      _value ->
        nil
    end
  end

  defp plausible_dimension_entry(row, site_id, now) do
    case dimension_parts(row) do
      {day, dimension, value} ->
        %{}
        |> Map.merge(entry_identity(site_id: site_id, day: day))
        |> Map.merge(%{dimension: dimension, value: value, value_key: hash(value)})
        |> Map.merge(plausible_metrics(row))
        |> Map.merge(row_metadata(row))
        |> Map.merge(timestamps(now))

      nil ->
        nil
    end
  end

  defp search_console_entry(row, site_url, now) do
    case search_console_parts(row) do
      {day, dimension_set, dimension_key} ->
        %{}
        |> Map.merge(entry_identity(site_url: site_url, day: day))
        |> Map.merge(%{dimension_set: dimension_set, dimension_key: dimension_key})
        |> Map.merge(search_console_dimensions(row))
        |> Map.merge(search_console_metrics(row))
        |> Map.merge(row_metadata(row))
        |> Map.merge(timestamps(now))

      nil ->
        nil
    end
  end

  defp github_referrer_entry(row, rank, repository_id, snapshot_date, now) do
    case normalize_text(field(row, :referrer)) do
      nil ->
        nil

      referrer ->
        %{
          id: Ecto.UUID.generate(),
          tracked_repository_id: repository_id,
          snapshot_date: snapshot_date,
          rank: integer(field(row, :rank) || rank),
          referrer: referrer,
          count: integer(field(row, :count)),
          uniques: integer(field(row, :uniques)),
          metadata: map_value(field(row, :metadata)),
          inserted_at: now
        }
    end
  end

  defp github_path_entry(row, rank, repository_id, snapshot_date, now) do
    case normalize_text(field(row, :path)) do
      nil ->
        nil

      path ->
        %{
          id: Ecto.UUID.generate(),
          tracked_repository_id: repository_id,
          snapshot_date: snapshot_date,
          rank: integer(field(row, :rank) || rank),
          path: path,
          path_key: hash(path),
          title: normalize_text(field(row, :title)),
          count: integer(field(row, :count)),
          uniques: integer(field(row, :uniques)),
          metadata: map_value(field(row, :metadata)),
          inserted_at: now
        }
    end
  end

  defp dimension_parts(row) do
    day = normalize_date(field(row, :day))
    dimension = normalize_text(field(row, :dimension))
    value = normalize_text(field(row, :value))

    if day && present?(dimension) && present?(value), do: {day, dimension, value}
  end

  defp search_console_parts(row) do
    day = normalize_date(field(row, :day))
    dimension_set = normalize_text(field(row, :dimension_set))
    dimension_key = normalize_text(field(row, :dimension_key))

    if day && present?(dimension_set) && present?(dimension_key), do: {day, dimension_set, dimension_key}
  end

  defp plausible_metrics(row) do
    %{
      visitors: integer(field(row, :visitors)),
      visits: integer(field(row, :visits)),
      pageviews: integer(field(row, :pageviews)),
      bounce_rate: float(field(row, :bounce_rate)),
      visit_duration: integer_or_nil(field(row, :visit_duration)),
      events: integer(field(row, :events))
    }
  end

  defp search_console_dimensions(row) do
    %{
      search_type: normalize_text(field(row, :search_type)) || "web",
      query: normalize_text(field(row, :query)),
      page: normalize_text(field(row, :page)),
      country: normalize_text(field(row, :country)),
      device: normalize_text(field(row, :device))
    }
  end

  defp search_console_metrics(row) do
    %{
      clicks: integer(field(row, :clicks)),
      impressions: integer(field(row, :impressions)),
      ctr: float(field(row, :ctr)),
      position: float(field(row, :position))
    }
  end

  defp row_metadata(row), do: %{metadata: map_value(field(row, :metadata))}
  defp entry_identity(attrs), do: Map.put(Enum.into(attrs, %{}), :id, Ecto.UUID.generate())
  defp timestamps(now), do: %{inserted_at: now, updated_at: now}

  defp update_run!(run, attrs) do
    run
    |> Ecto.Changeset.change(Map.put(attrs, :finished_at, now()))
    |> Repo.update!()
  end

  defp insert_all(schema, entries, opts \\ [])

  defp insert_all(_schema, [], _opts), do: 0

  defp insert_all(schema, entries, opts) when is_list(entries) do
    {count, _rows} = Repo.insert_all(schema, entries, opts)
    count
  end

  defp date_window_args(opts) do
    lookback_days = opts |> Keyword.get(:lookback_days, 7) |> integer() |> max(1)
    today = Date.utc_today()
    date_to = Keyword.get(opts, :date_to, Date.add(today, -1))
    date_from = Keyword.get(opts, :date_from, Date.add(date_to, -lookback_days + 1))

    %{
      "date_from" => Date.to_iso8601(date_from),
      "date_to" => Date.to_iso8601(date_to)
    }
  end

  defp repo_url(attrs) do
    owner = attrs[:owner] || attrs["owner"]
    name = attrs[:name] || attrs["name"]

    if present?(owner) and present?(name), do: "https://github.com/#{owner}/#{name}"
  end

  defp hex_package_url(attrs) do
    package_name = attrs[:package_name] || attrs["package_name"]

    if present?(package_name), do: "https://hex.pm/packages/#{package_name}"
  end

  defp normalize_key(key) when is_atom(key), do: key
  defp normalize_key(key) when is_binary(key), do: String.to_existing_atom(key)

  defp field(row, key) when is_map(row) and is_atom(key), do: Map.get(row, key) || Map.get(row, Atom.to_string(key))

  defp normalize_text(value) when is_binary(value) do
    value
    |> String.replace(<<0>>, "")
    |> String.trim()
    |> case do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp normalize_text(value) when is_atom(value), do: value |> Atom.to_string() |> normalize_text()
  defp normalize_text(value) when is_number(value), do: value |> to_string() |> normalize_text()
  defp normalize_text(_value), do: nil

  defp github_traffic_accessible_by_default?(owner) when is_binary(owner) do
    String.downcase(owner) == "agentjido"
  end

  defp github_traffic_accessible_by_default?(_owner), do: false

  defp github_traffic_tracking_defaults(owner, name) do
    cond do
      excluded_github_traffic_repository?(owner, name) ->
        {false,
         %{
           "traffic_access" => "excluded",
           "traffic_exclusion_reason" => "github_app_not_installed"
         }}

      github_traffic_accessible_by_default?(owner) ->
        {true, %{"traffic_access" => "github_app_installation"}}

      true ->
        {false, %{"traffic_access" => "external_owner"}}
    end
  end

  defp excluded_github_traffic_repository?(owner, name) when is_binary(owner) and is_binary(name) do
    normalized_repository = {String.downcase(owner), String.downcase(name)}

    Enum.any?(@excluded_github_traffic_repositories, fn {excluded_owner, excluded_name} ->
      normalized_repository == {String.downcase(excluded_owner), String.downcase(excluded_name)}
    end)
  end

  defp excluded_github_traffic_repository?(_owner, _name), do: false

  defp normalize_date!(value) do
    normalize_date(value) || raise ArgumentError, "invalid date: #{inspect(value)}"
  end

  defp normalize_date(%Date{} = date), do: date
  defp normalize_date(%DateTime{} = date_time), do: DateTime.to_date(date_time)
  defp normalize_date(%NaiveDateTime{} = date_time), do: NaiveDateTime.to_date(date_time)

  defp normalize_date(value) when is_binary(value) do
    value
    |> String.slice(0, 10)
    |> Date.from_iso8601()
    |> case do
      {:ok, date} -> date
      {:error, _reason} -> nil
    end
  end

  defp normalize_date(_value), do: nil

  defp normalize_datetime(%DateTime{} = date_time), do: DateTime.truncate(date_time, :microsecond)
  defp normalize_datetime(%NaiveDateTime{} = date_time), do: DateTime.from_naive!(date_time, "Etc/UTC")

  defp normalize_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, date_time, _offset} -> DateTime.truncate(date_time, :microsecond)
      {:error, _reason} -> nil
    end
  end

  defp normalize_datetime(_value), do: nil

  defp integer(value) when is_integer(value), do: value
  defp integer(value) when is_float(value), do: trunc(value)

  defp integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _rest} -> int
      :error -> 0
    end
  end

  defp integer(_value), do: 0

  defp integer_or_nil(nil), do: nil
  defp integer_or_nil(value), do: integer(value)

  defp float(nil), do: nil
  defp float(value) when is_float(value), do: value
  defp float(value) when is_integer(value), do: value / 1

  defp float(value) when is_binary(value) do
    case Float.parse(value) do
      {float, _rest} -> float
      :error -> nil
    end
  end

  defp float(_value), do: nil

  defp boolean_or_nil(value) when is_boolean(value), do: value
  defp boolean_or_nil(_value), do: nil

  defp map_value(value) when is_map(value), do: sanitize_metadata(value)
  defp map_value(_value), do: %{}

  defp sanitize_metadata(value) when is_map(value) do
    Map.new(value, fn {key, value} -> {sanitize_metadata(key), sanitize_metadata(value)} end)
  end

  defp sanitize_metadata(value) when is_list(value), do: Enum.map(value, &sanitize_metadata/1)
  defp sanitize_metadata(value) when is_binary(value), do: String.replace(value, <<0>>, "")
  defp sanitize_metadata(value), do: value

  defp hash(value) when is_binary(value) do
    :sha256
    |> :crypto.hash(value)
    |> Base.encode16(case: :lower)
  end

  defp sanitize_error({:github_forbidden, _body}), do: :github_forbidden
  defp sanitize_error({:github_not_found, _body}), do: :github_not_found
  defp sanitize_error({:github_rate_limited, _body}), do: :github_rate_limited
  defp sanitize_error({:github_http_error, status, _body}), do: {:github_http_error, status}
  defp sanitize_error({:github_app_unauthorized, _body}), do: :github_app_unauthorized
  defp sanitize_error({:github_app_forbidden, _body}), do: :github_app_forbidden
  defp sanitize_error({:github_app_installation_not_found, _body}), do: :github_app_installation_not_found
  defp sanitize_error({:github_app_http_error, status, _body}), do: {:github_app_http_error, status}
  defp sanitize_error({:hex_package_not_found, package_name}), do: {:hex_package_not_found, package_name}
  defp sanitize_error({:hex_not_found, _body}), do: :hex_not_found
  defp sanitize_error({:hex_rate_limited, _body}), do: :hex_rate_limited
  defp sanitize_error({:hex_http_error, status, _body}), do: {:hex_http_error, status}
  defp sanitize_error({:plausible_unauthorized, _body}), do: :plausible_unauthorized
  defp sanitize_error({:plausible_rate_limited, _body}), do: :plausible_rate_limited
  defp sanitize_error({:plausible_http_error, status, _body}), do: {:plausible_http_error, status}
  defp sanitize_error({:search_console_unauthorized, _body}), do: :search_console_unauthorized
  defp sanitize_error({:search_console_forbidden, _body}), do: :search_console_forbidden
  defp sanitize_error({:search_console_rate_limited, _body}), do: :search_console_rate_limited
  defp sanitize_error({:search_console_http_error, status, _body}), do: {:search_console_http_error, status}
  defp sanitize_error(reason), do: reason

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:microsecond)
  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(_value), do: false
end
