defmodule AgentJido.Analytics do
  @moduledoc """
  First-party analytics context for event ingestion and admin reporting.
  """
  import Ecto.Query, warn: false

  alias AgentJido.Analytics.AnalyticsEvent
  alias AgentJido.Analytics.Ingestion
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
  alias AgentJido.Analytics.RateLimiter
  alias AgentJido.Analytics.Redactor
  alias AgentJido.QueryLogs.QueryLog
  alias AgentJido.Repo

  @default_days 7
  @default_limit 10
  @default_ecosystem_limit 8
  @default_feedback_limit 30
  @default_search_message_limit 30
  @failure_statuses ["no_results", "error", "challenge"]
  @feedback_surfaces ["content_assistant", "docs_page"]

  @type dashboard_snapshot :: %{
          days: pos_integer(),
          since: NaiveDateTime.t(),
          unavailable?: boolean(),
          authorized?: boolean(),
          summary: map(),
          top_demand_topics: [map()],
          content_gaps: [map()],
          reformulations: [map()],
          feedback_breakdown: [map()],
          recent_feedback: [map()],
          recent_negative_feedback: [AnalyticsEvent.t()],
          local_search: map(),
          ingestion: map()
        }

  @doc """
  Accepted first-party analytics event names.
  """
  @spec event_values() :: [String.t()]
  def event_values, do: AnalyticsEvent.event_values()

  @doc """
  Accepted feedback surfaces.
  """
  @spec feedback_surfaces() :: [String.t()]
  def feedback_surfaces, do: @feedback_surfaces

  @doc """
  Inserts a single analytics event.
  """
  @spec track_event(term(), map() | keyword()) :: {:ok, AnalyticsEvent.t() | :excluded_admin} | {:error, term()}
  def track_event(current_scope, attrs) do
    if admin_scope?(current_scope) do
      {:ok, :excluded_admin}
    else
      attrs =
        attrs
        |> normalize_attrs()
        |> enrich_event_attrs(current_scope)

      changeset = AnalyticsEvent.changeset(%AnalyticsEvent{}, attrs)

      case ensure_rate_limit(attrs) do
        :ok -> Repo.insert(changeset)
        {:error, _reason} = error -> error
      end
    end
  end

  @doc """
  Best-effort event tracking helper that never raises.
  """
  @spec track_event_safe(term(), map() | keyword()) :: :ok
  def track_event_safe(current_scope, attrs) do
    _ = track_event(current_scope, attrs)
    :ok
  rescue
    _ -> :ok
  catch
    _, _ -> :ok
  end

  @doc """
  Specialized feedback ingestion helper.
  """
  @spec track_feedback_safe(term(), map() | keyword()) :: :ok
  def track_feedback_safe(current_scope, attrs) do
    attrs =
      attrs
      |> normalize_attrs()
      |> Map.put_new("event", "feedback_submitted")

    track_event_safe(current_scope, attrs)
  end

  @doc """
  Returns an admin analytics snapshot for dashboards.
  """
  @spec dashboard_snapshot(term(), pos_integer(), keyword()) :: dashboard_snapshot()
  def dashboard_snapshot(current_scope, days \\ @default_days, opts \\ [])
      when is_integer(days) and days > 0 do
    if admin_scope?(current_scope) do
      top_limit = Keyword.get(opts, :top_limit, @default_limit)
      gap_limit = Keyword.get(opts, :gap_limit, @default_limit)
      reform_limit = Keyword.get(opts, :reform_limit, @default_limit)
      feedback_limit = Keyword.get(opts, :feedback_limit, @default_feedback_limit)
      search_message_limit = Keyword.get(opts, :search_message_limit, @default_search_message_limit)
      since = since_naive(days)

      %{
        days: days,
        since: since,
        unavailable?: false,
        authorized?: true,
        summary: summary(days),
        top_demand_topics: top_demand_topics(days, top_limit),
        content_gaps: content_gap_report(current_scope, days, limit: gap_limit),
        reformulations: reformulation_leaderboard(days, reform_limit),
        feedback_breakdown: feedback_breakdown(days, feedback_limit),
        recent_feedback: recent_feedback(days, feedback_limit),
        recent_negative_feedback: recent_negative_feedback(days, feedback_limit),
        local_search: local_search_snapshot(days, search_message_limit),
        ingestion: ingestion_snapshot(days)
      }
    else
      unauthorized_snapshot(days)
    end
  rescue
    _ -> unavailable_snapshot(days)
  catch
    _, _ -> unavailable_snapshot(days)
  end

  @doc """
  Returns local first-party search activity from the query log and analytics-event tables.
  """
  @spec search_activity_snapshot(term(), pos_integer(), keyword()) :: map()
  def search_activity_snapshot(current_scope, days \\ @default_days, opts \\ [])
      when is_integer(days) and days > 0 do
    if admin_scope?(current_scope) do
      limit = Keyword.get(opts, :limit, @default_search_message_limit)
      local_search_snapshot(days, limit)
    else
      empty_local_search()
    end
  rescue
    _ -> empty_local_search()
  catch
    _, _ -> empty_local_search()
  end

  @doc """
  Returns external analytics collector health and coverage for admin reporting.
  """
  @spec external_collection_snapshot(term(), pos_integer()) :: map()
  def external_collection_snapshot(current_scope, days \\ @default_days)
      when is_integer(days) and days > 0 do
    if admin_scope?(current_scope), do: ingestion_snapshot(days), else: empty_ingestion_snapshot()
  rescue
    _ -> empty_ingestion_snapshot()
  catch
    _, _ -> empty_ingestion_snapshot()
  end

  @doc """
  Returns external ecosystem demand, adoption, and opportunity signals for admin reporting.
  """
  @spec ecosystem_snapshot(term(), pos_integer(), keyword()) :: map()
  def ecosystem_snapshot(current_scope, days \\ 30, opts \\ []) when is_integer(days) and days > 0 do
    if admin_scope?(current_scope) do
      limit = Keyword.get(opts, :limit, @default_ecosystem_limit)
      since_date = since_date(days)

      %{
        days: days,
        since_date: since_date,
        unavailable?: false,
        authorized?: true,
        totals: ecosystem_totals(since_date),
        collection: ingestion_snapshot(days),
        acquisition_sources: plausible_source_rows(since_date, limit),
        site_pages: plausible_page_rows(since_date, limit),
        search_queries: search_console_query_rows(since_date, limit),
        search_pages: search_console_page_rows(since_date, limit),
        repo_interest: github_repo_interest_rows(since_date, limit),
        github_paths: github_path_rows(limit),
        github_referrers: github_referrer_rows(limit),
        package_adoption: hex_package_rows(limit),
        release_adoption: hex_release_rows(limit),
        content_gaps: content_gap_report(current_scope, days, limit: limit)
      }
    else
      empty_ecosystem_snapshot(days, authorized?: false)
    end
  rescue
    _ -> empty_ecosystem_snapshot(days, unavailable?: true)
  catch
    _, _ -> empty_ecosystem_snapshot(days, unavailable?: true)
  end

  @doc """
  Returns high-demand/low-success topics for a lookback window.
  """
  @spec content_gap_report(term(), pos_integer(), keyword()) :: [map()]
  def content_gap_report(current_scope, days \\ @default_days, opts \\ [])
      when is_integer(days) and days > 0 do
    if admin_scope?(current_scope) do
      limit = Keyword.get(opts, :limit, @default_limit)
      since = since_naive(days)

      from(q in QueryLog,
        where: q.inserted_at >= ^since and not is_nil(q.query_hash),
        group_by: [q.query, q.query_hash],
        select: %{
          query: q.query,
          query_hash: q.query_hash,
          demand_count: count(q.id),
          success_count: filter(count(q.id), q.status == "success"),
          failure_count: filter(count(q.id), q.status in ^@failure_statuses)
        }
      )
      |> Repo.all()
      |> Enum.map(&gap_row/1)
      |> Enum.sort_by(fn row -> {-row.gap_score, -row.demand_count, row.query || ""} end)
      |> Enum.take(limit)
    else
      []
    end
  rescue
    _ -> []
  catch
    _, _ -> []
  end

  @doc """
  Rows for CSV export of content gap analysis.
  """
  @spec content_gap_rows_for_export(term(), pos_integer(), pos_integer()) :: [map()]
  def content_gap_rows_for_export(current_scope, days \\ @default_days, limit \\ 250)
      when is_integer(days) and days > 0 and is_integer(limit) and limit > 0 do
    content_gap_report(current_scope, days, limit: limit)
  end

  @doc """
  Rows for CSV export of feedback activity.
  """
  @spec feedback_rows_for_export(term(), pos_integer(), pos_integer()) :: [map()]
  def feedback_rows_for_export(current_scope, days \\ @default_days, limit \\ 500)
      when is_integer(days) and days > 0 and is_integer(limit) and limit > 0 do
    if admin_scope?(current_scope) do
      recent_feedback(days, limit)
    else
      []
    end
  rescue
    _ -> []
  catch
    _, _ -> []
  end

  @doc """
  Returns the latest feedback event for a visitor/session on a specific path.

  This is used to prevent duplicate "helpful/not helpful" submissions when the
  same visitor revisits a page.
  """
  @spec latest_feedback_for_identity(String.t() | nil, String.t() | nil, String.t() | nil, keyword()) ::
          %{feedback_value: String.t() | nil, feedback_note: String.t() | nil} | nil
  def latest_feedback_for_identity(visitor_id, session_id, path, opts \\ [])

  def latest_feedback_for_identity(visitor_id, session_id, path, opts) when is_binary(path) do
    case feedback_identity_filter(visitor_id, session_id) do
      {:ok, identity_filter} ->
        surface = opts |> Keyword.get(:surface) |> normalize_feedback_surface_filter()

        query =
          from(e in AnalyticsEvent,
            where: e.event == "feedback_submitted" and e.path == ^path and ^identity_filter,
            order_by: [desc: e.inserted_at, desc: e.id],
            limit: 1,
            select: %{feedback_value: e.feedback_value, feedback_note: e.feedback_note}
          )

        query =
          if is_binary(surface) do
            from(e in query, where: fragment("?->>'surface' = ?", e.metadata, ^surface))
          else
            query
          end

        Repo.one(query)

      :error ->
        nil
    end
  rescue
    _ -> nil
  catch
    _, _ -> nil
  end

  def latest_feedback_for_identity(_visitor_id, _session_id, _path, _opts), do: nil

  defp summary(days) do
    since = since_naive(days)

    query_base = from(q in QueryLog, where: q.inserted_at >= ^since)
    event_base = from(e in AnalyticsEvent, where: e.inserted_at >= ^since)

    %{
      total_queries: Repo.aggregate(query_base, :count, :id),
      successful_queries: count_queries(query_base, status: "success"),
      failed_queries: count_queries(query_base, status_in: @failure_statuses),
      no_result_queries: count_queries(query_base, status: "no_results"),
      total_events: Repo.aggregate(event_base, :count, :id),
      total_feedback: count_feedback(event_base, nil),
      helpful_feedback: count_feedback(event_base, "helpful"),
      not_helpful_feedback: count_feedback(event_base, "not_helpful")
    }
  end

  defp top_demand_topics(days, limit) do
    since = since_naive(days)

    from(q in QueryLog,
      where: q.inserted_at >= ^since and not is_nil(q.query_hash),
      group_by: [q.query, q.query_hash],
      select: %{
        query: q.query,
        query_hash: q.query_hash,
        demand_count: count(q.id)
      },
      order_by: [desc: count(q.id), asc: q.query],
      limit: ^limit
    )
    |> Repo.all()
  end

  defp reformulation_leaderboard(days, limit) do
    since = since_naive(days)

    logs =
      from(q in QueryLog,
        where:
          q.inserted_at >= ^since and not is_nil(q.session_id) and not is_nil(q.query_hash) and
            q.query_hash != "",
        order_by: [asc: q.session_id, asc: q.source, asc: q.inserted_at, asc: q.id],
        select: %{
          session_id: q.session_id,
          source: q.source,
          query: q.query,
          query_hash: q.query_hash,
          inserted_at: q.inserted_at
        }
      )
      |> Repo.all()

    logs
    |> Enum.group_by(&{&1.session_id, &1.source})
    |> Enum.reduce(%{}, fn {_group_key, entries}, counts ->
      entries
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.reduce(counts, fn [previous, current], acc -> maybe_count_reformulation(acc, previous, current) end)
    end)
    |> Enum.map(fn {query, count} -> %{query: query, count: count} end)
    |> Enum.sort_by(fn row -> {-row.count, row.query || ""} end)
    |> Enum.take(limit)
  end

  defp maybe_count_reformulation(acc, previous, current) do
    if reformulation_transition?(previous, current) do
      Map.update(acc, current.query, 1, &(&1 + 1))
    else
      acc
    end
  end

  defp reformulation_transition?(previous, current) do
    NaiveDateTime.diff(current.inserted_at, previous.inserted_at, :second) <= 120 and
      previous.query_hash != current.query_hash
  end

  defp feedback_breakdown(days, limit) do
    since = since_naive(days)

    from(e in AnalyticsEvent,
      where: e.inserted_at >= ^since and e.event == "feedback_submitted",
      group_by: [fragment("COALESCE((?->>'surface'), ?)", e.metadata, e.source), e.feedback_value],
      select: %{
        surface: fragment("COALESCE((?->>'surface'), ?)", e.metadata, e.source),
        feedback_value: e.feedback_value,
        count: count(e.id)
      },
      order_by: [desc: count(e.id)],
      limit: ^limit
    )
    |> Repo.all()
  end

  defp recent_negative_feedback(days, limit) do
    since = since_naive(days)

    from(e in AnalyticsEvent,
      where:
        e.inserted_at >= ^since and e.event == "feedback_submitted" and
          e.feedback_value == "not_helpful",
      order_by: [desc: e.inserted_at],
      limit: ^limit
    )
    |> Repo.all()
  end

  defp recent_feedback(days, limit) do
    since = since_naive(days)

    from(e in AnalyticsEvent,
      where: e.inserted_at >= ^since and e.event == "feedback_submitted",
      order_by: [desc: e.inserted_at],
      limit: ^limit
    )
    |> Repo.all()
    |> Enum.map(fn event ->
      %{
        inserted_at: event.inserted_at,
        path: event.path,
        source: event.source,
        channel: event.channel,
        feedback_value: event.feedback_value,
        feedback_note: event.feedback_note,
        surface: surface_for(event),
        query_log_id: event.query_log_id
      }
    end)
  end

  defp local_search_snapshot(days, limit) do
    limit = normalize_limit(limit, @default_search_message_limit)
    since = since_naive(days)
    query_base = from(q in QueryLog, where: q.inserted_at >= ^since)

    %{
      summary: %{
        total_messages: Repo.aggregate(query_base, :count, :id),
        submitted_messages: count_queries(query_base, status: "submitted"),
        successful_messages: count_queries(query_base, status: "success"),
        no_result_messages: count_queries(query_base, status: "no_results"),
        failed_messages: count_queries(query_base, status_in: ["error", "challenge"])
      },
      outcome_breakdown: search_outcome_breakdown(days),
      channel_breakdown: search_channel_breakdown(days),
      recent_messages: recent_search_messages(days, limit)
    }
  end

  defp search_outcome_breakdown(days) do
    since = since_naive(days)

    from(q in QueryLog,
      where: q.inserted_at >= ^since,
      group_by: q.status,
      select: %{status: q.status, count: count(q.id)},
      order_by: [desc: count(q.id), asc: q.status]
    )
    |> Repo.all()
  end

  defp search_channel_breakdown(days) do
    since = since_naive(days)

    from(q in QueryLog,
      where: q.inserted_at >= ^since,
      group_by: q.channel,
      select: %{
        channel: q.channel,
        total_count: count(q.id),
        success_count: filter(count(q.id), q.status == "success"),
        no_result_count: filter(count(q.id), q.status == "no_results"),
        failure_count: filter(count(q.id), q.status in ["error", "challenge"])
      },
      order_by: [desc: count(q.id), asc: q.channel]
    )
    |> Repo.all()
  end

  defp recent_search_messages(days, limit) do
    since = since_naive(days)

    from(q in QueryLog,
      where: q.inserted_at >= ^since,
      order_by: [desc: q.inserted_at, desc: q.id],
      limit: ^limit,
      select: %{
        id: q.id,
        query: q.query,
        source: q.source,
        channel: q.channel,
        status: q.status,
        path: q.path,
        results_count: q.results_count,
        latency_ms: q.latency_ms,
        inserted_at: q.inserted_at
      }
    )
    |> Repo.all()
  end

  defp ingestion_snapshot(days) do
    since_date = since_date(days)

    sources = [
      source_snapshot(
        "github_traffic",
        "GitHub traffic",
        Ingestion.github_auth_configured?(),
        active_tracked_repository_count(),
        GitHubRepoDaily,
        since_date
      ),
      source_snapshot(
        "plausible",
        "Plausible",
        Ingestion.plausible_configured?(),
        configured_site_count(:plausible_site_id),
        PlausibleSiteDaily,
        since_date
      ),
      source_snapshot(
        "search_console",
        "Search Console",
        Ingestion.search_console_configured?(),
        configured_site_count(:search_console_site_url),
        SearchConsoleDaily,
        since_date
      ),
      source_snapshot("hex", "Hex", true, active_tracked_hex_package_count(), HexPackageDaily, since_date)
    ]

    %{
      sources: sources,
      recent_runs: recent_ingestion_runs(20)
    }
  end

  defp source_snapshot(source, label, configured?, tracked_count, schema, since_date) do
    %{
      source: source,
      label: label,
      configured?: configured?,
      tracked_count: tracked_count,
      latest_day: latest_collection_day(schema),
      rows_count: collection_rows_since(schema, since_date),
      latest_run: latest_ingestion_run(source)
    }
  end

  defp latest_ingestion_run(source) do
    IngestionRun
    |> where([run], run.source == ^source)
    |> order_by([run], desc: run.started_at, desc: run.id)
    |> limit(1)
    |> Repo.one()
    |> run_summary()
  end

  defp recent_ingestion_runs(limit) do
    IngestionRun
    |> order_by([run], desc: run.started_at, desc: run.id)
    |> limit(^limit)
    |> Repo.all()
    |> Enum.map(&run_summary/1)
  end

  defp run_summary(nil), do: nil

  defp run_summary(%IngestionRun{} = run) do
    %{
      source: run.source,
      status: run.status,
      started_at: run.started_at,
      finished_at: run.finished_at,
      date_from: run.date_from,
      date_to: run.date_to,
      rows_count: run.rows_count,
      error: run.error
    }
  end

  defp latest_collection_day(schema) do
    from(row in schema, select: max(row.day))
    |> Repo.one()
  end

  defp collection_rows_since(schema, since_date) do
    from(row in schema, where: row.day >= ^since_date)
    |> Repo.aggregate(:count, :id)
  end

  defp active_tracked_repository_count do
    TrackedRepository
    |> where([repository], repository.active == true and repository.provider == "github")
    |> Repo.aggregate(:count, :id)
  end

  defp active_tracked_hex_package_count do
    TrackedHexPackage
    |> where([package], package.active == true)
    |> Repo.aggregate(:count, :id)
  end

  defp ecosystem_totals(since_date) do
    %{
      github: github_totals(since_date),
      plausible: plausible_totals(since_date),
      search_console: search_console_totals(since_date),
      hex: hex_totals()
    }
  end

  defp github_totals(since_date) do
    from(row in GitHubRepoDaily,
      where: row.day >= ^since_date,
      select: %{
        views_count: sum(row.views_count),
        views_uniques: sum(row.views_uniques),
        clones_count: sum(row.clones_count),
        clones_uniques: sum(row.clones_uniques)
      }
    )
    |> Repo.one()
    |> normalize_count_map([:views_count, :views_uniques, :clones_count, :clones_uniques])
  end

  defp plausible_totals(since_date) do
    from(row in PlausibleSiteDaily,
      where: row.day >= ^since_date,
      select: %{
        visitors: sum(row.visitors),
        visits: sum(row.visits),
        pageviews: sum(row.pageviews),
        events: sum(row.events),
        bounce_rate: avg(row.bounce_rate),
        visit_duration: avg(row.visit_duration)
      }
    )
    |> Repo.one()
    |> normalize_count_map([:visitors, :visits, :pageviews, :events])
  end

  defp search_console_totals(since_date) do
    totals =
      from(row in SearchConsoleDaily,
        where: row.day >= ^since_date and row.dimension_set == "date",
        select: %{
          clicks: sum(row.clicks),
          impressions: sum(row.impressions),
          position: avg(row.position)
        }
      )
      |> Repo.one()
      |> normalize_count_map([:clicks, :impressions])

    Map.put(totals, :ctr, safe_rate(totals.clicks, totals.impressions))
  end

  defp hex_totals do
    case latest_hex_package_day() do
      nil ->
        %{day: nil, packages_count: 0, downloads_day: 0, downloads_week: 0, downloads_recent: 0, downloads_all: 0}

      latest_day ->
        totals =
          from(row in HexPackageDaily,
            where: row.day == ^latest_day,
            select: %{
              packages_count: count(row.id),
              downloads_day: sum(row.downloads_day),
              downloads_week: sum(row.downloads_week),
              downloads_recent: sum(row.downloads_recent),
              downloads_all: sum(row.downloads_all)
            }
          )
          |> Repo.one()
          |> normalize_count_map([:packages_count, :downloads_day, :downloads_week, :downloads_recent, :downloads_all])

        Map.put(totals, :day, latest_day)
    end
  end

  defp plausible_source_rows(since_date, limit) do
    plausible_dimension_rows("visit:source", since_date, limit, :visitors, :visits)
  end

  defp plausible_page_rows(since_date, limit) do
    plausible_dimension_rows("event:page", since_date, limit, :visitors, :pageviews)
  end

  defp plausible_dimension_rows(dimension, since_date, limit, primary_metric, secondary_metric) do
    from(row in PlausibleDimensionDaily,
      where: row.day >= ^since_date and row.dimension == ^dimension,
      group_by: row.value,
      order_by: [desc: sum(field(row, ^primary_metric)), desc: sum(field(row, ^secondary_metric))],
      limit: ^limit,
      select: %{
        value: row.value,
        visitors: sum(row.visitors),
        visits: sum(row.visits),
        pageviews: sum(row.pageviews),
        events: sum(row.events),
        bounce_rate: avg(row.bounce_rate),
        visit_duration: avg(row.visit_duration)
      }
    )
    |> Repo.all()
    |> Enum.map(&normalize_count_map(&1, [:visitors, :visits, :pageviews, :events]))
  end

  defp search_console_query_rows(since_date, limit) do
    search_console_grouped_rows(:query, "date+query", since_date, limit)
  end

  defp search_console_page_rows(since_date, limit) do
    search_console_grouped_rows(:page, "date+page", since_date, limit)
  end

  defp search_console_grouped_rows(field, dimension_set, since_date, limit) do
    from(row in SearchConsoleDaily,
      where: row.day >= ^since_date and row.dimension_set == ^dimension_set and not is_nil(field(row, ^field)),
      group_by: field(row, ^field),
      order_by: [desc: sum(row.clicks), desc: sum(row.impressions)],
      limit: ^limit,
      select: %{
        value: field(row, ^field),
        clicks: sum(row.clicks),
        impressions: sum(row.impressions),
        position: avg(row.position)
      }
    )
    |> Repo.all()
    |> Enum.map(&put_ctr/1)
  end

  defp github_repo_interest_rows(since_date, limit) do
    from(row in GitHubRepoDaily,
      join: repository in assoc(row, :tracked_repository),
      where: row.day >= ^since_date,
      group_by: repository.full_name,
      order_by: [desc: sum(row.views_count), desc: sum(row.clones_count)],
      limit: ^limit,
      select: %{
        repository: repository.full_name,
        views_count: sum(row.views_count),
        views_uniques: sum(row.views_uniques),
        clones_count: sum(row.clones_count),
        clones_uniques: sum(row.clones_uniques)
      }
    )
    |> Repo.all()
    |> Enum.map(&normalize_count_map(&1, [:views_count, :views_uniques, :clones_count, :clones_uniques]))
  end

  defp github_path_rows(limit) do
    case latest_snapshot_day(GitHubPathSnapshot) do
      nil ->
        []

      latest_day ->
        from(row in GitHubPathSnapshot,
          join: repository in assoc(row, :tracked_repository),
          where: row.snapshot_date == ^latest_day,
          order_by: [desc: row.count, asc: row.rank],
          limit: ^limit,
          select: %{
            repository: repository.full_name,
            path: row.path,
            title: row.title,
            count: row.count,
            uniques: row.uniques,
            snapshot_date: row.snapshot_date
          }
        )
        |> Repo.all()
    end
  end

  defp github_referrer_rows(limit) do
    case latest_snapshot_day(GitHubReferrerSnapshot) do
      nil ->
        []

      latest_day ->
        from(row in GitHubReferrerSnapshot,
          join: repository in assoc(row, :tracked_repository),
          where: row.snapshot_date == ^latest_day,
          order_by: [desc: row.count, asc: row.rank],
          limit: ^limit,
          select: %{
            repository: repository.full_name,
            referrer: row.referrer,
            count: row.count,
            uniques: row.uniques,
            snapshot_date: row.snapshot_date
          }
        )
        |> Repo.all()
    end
  end

  defp hex_package_rows(limit) do
    case latest_hex_package_day() do
      nil ->
        []

      latest_day ->
        from(row in HexPackageDaily,
          where: row.day == ^latest_day,
          order_by: [desc: row.downloads_recent, desc: row.downloads_week, desc: row.downloads_all],
          limit: ^limit,
          select: %{
            package_name: row.package_name,
            latest_version: row.latest_version,
            downloads_day: row.downloads_day,
            downloads_week: row.downloads_week,
            downloads_recent: row.downloads_recent,
            downloads_all: row.downloads_all,
            day: row.day
          }
        )
        |> Repo.all()
    end
  end

  defp hex_release_rows(limit) do
    case latest_release_day() do
      nil ->
        []

      latest_day ->
        from(row in HexReleaseDaily,
          where: row.day == ^latest_day,
          order_by: [desc: row.downloads_total],
          limit: ^limit,
          select: %{
            package_name: row.package_name,
            version: row.version,
            downloads_total: row.downloads_total,
            release_inserted_at: row.release_inserted_at,
            has_docs: row.has_docs,
            day: row.day
          }
        )
        |> Repo.all()
    end
  end

  defp latest_hex_package_day do
    from(row in HexPackageDaily, select: max(row.day))
    |> Repo.one()
  end

  defp latest_release_day do
    from(row in HexReleaseDaily, select: max(row.day))
    |> Repo.one()
  end

  defp latest_snapshot_day(schema) do
    from(row in schema, select: max(row.snapshot_date))
    |> Repo.one()
  end

  defp normalize_count_map(nil, keys), do: normalize_count_map(%{}, keys)

  defp normalize_count_map(map, keys) when is_map(map) do
    Enum.reduce(keys, map, fn key, acc ->
      Map.update(acc, key, 0, &number_or_zero/1)
    end)
  end

  defp put_ctr(row) do
    row
    |> normalize_count_map([:clicks, :impressions])
    |> Map.put(:ctr, safe_rate(row.clicks, row.impressions))
  end

  defp number_or_zero(nil), do: 0
  defp number_or_zero(value) when is_number(value), do: value
  defp number_or_zero(_value), do: 0

  defp safe_rate(_numerator, denominator) when denominator in [nil, 0], do: 0.0
  defp safe_rate(numerator, denominator) when is_number(numerator) and is_number(denominator), do: numerator / denominator
  defp safe_rate(_numerator, _denominator), do: 0.0

  defp configured_site_count(key) do
    if Ingestion.config(key) |> present?(), do: 1, else: 0
  end

  defp count_queries(base_query, [{:status, status}]) do
    base_query
    |> where([q], q.status == ^status)
    |> Repo.aggregate(:count, :id)
  end

  defp count_queries(base_query, [{:status_in, statuses}]) when is_list(statuses) do
    base_query
    |> where([q], q.status in ^statuses)
    |> Repo.aggregate(:count, :id)
  end

  defp count_feedback(base_query, nil) do
    base_query
    |> where([e], e.event == "feedback_submitted")
    |> Repo.aggregate(:count, :id)
  end

  defp count_feedback(base_query, feedback_value) do
    base_query
    |> where([e], e.event == "feedback_submitted" and e.feedback_value == ^feedback_value)
    |> Repo.aggregate(:count, :id)
  end

  defp feedback_identity_filter(visitor_id, session_id) do
    normalized_visitor_id = normalize_feedback_identity(visitor_id)
    normalized_session_id = normalize_feedback_identity(session_id)

    cond do
      is_binary(normalized_visitor_id) and is_binary(normalized_session_id) ->
        {:ok, dynamic([e], e.visitor_id == ^normalized_visitor_id or e.session_id == ^normalized_session_id)}

      is_binary(normalized_visitor_id) ->
        {:ok, dynamic([e], e.visitor_id == ^normalized_visitor_id)}

      is_binary(normalized_session_id) ->
        {:ok, dynamic([e], e.session_id == ^normalized_session_id)}

      true ->
        :error
    end
  end

  defp normalize_feedback_identity(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      identity -> identity
    end
  end

  defp normalize_feedback_identity(_value), do: nil

  defp normalize_feedback_surface_filter(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      surface -> surface
    end
  end

  defp normalize_feedback_surface_filter(_value), do: nil

  defp gap_row(%{demand_count: demand_count, success_count: success_count, failure_count: failure_count} = row) do
    failure_rate = if demand_count > 0, do: failure_count / demand_count, else: 0.0

    row
    |> Map.put(:failure_rate, Float.round(failure_rate, 4))
    |> Map.put(:gap_score, Float.round(demand_count * failure_rate, 4))
    |> Map.put(:success_count, success_count || 0)
    |> Map.put(:failure_count, failure_count || 0)
  end

  defp ensure_rate_limit(attrs) do
    event = Map.get(attrs, "event") || "unknown"
    visitor_id = Map.get(attrs, "visitor_id") || "anonymous"

    if RateLimiter.allow?(visitor_id, event) do
      :ok
    else
      {:error, :rate_limited}
    end
  end

  defp enrich_event_attrs(attrs, current_scope) do
    metadata =
      attrs
      |> fetch_value("metadata")
      |> normalize_metadata()

    feedback_note =
      attrs
      |> fetch_value("feedback_note")
      |> case do
        nil -> Map.get(metadata, "feedback_note")
        value -> value
      end
      |> Redactor.redact_text()
      |> maybe_blank_to_nil()

    %{
      "event" => attrs |> fetch_value("event") |> normalize_string(),
      "source" => attrs |> fetch_value("source") |> normalize_string(default: "site"),
      "channel" => attrs |> fetch_value("channel") |> normalize_string(default: "web"),
      "path" => attrs |> fetch_value("path") |> normalize_path(),
      "section_id" => attrs |> fetch_value("section_id") |> normalize_string(),
      "target_url" => attrs |> fetch_value("target_url") |> normalize_string(),
      "rank" => attrs |> fetch_value("rank") |> normalize_rank(),
      "feedback_value" => attrs |> fetch_value("feedback_value") |> normalize_feedback_value(),
      "feedback_note" => feedback_note,
      "query_log_id" => attrs |> fetch_value("query_log_id") |> normalize_uuid(),
      "visitor_id" => attrs |> fetch_value("visitor_id") |> normalize_identity(default: "anonymous"),
      "session_id" => attrs |> fetch_value("session_id") |> normalize_identity(default: "anonymous"),
      "user_id" => current_user_id(current_scope),
      "metadata" => metadata
    }
  end

  defp normalize_metadata(metadata) when is_map(metadata) do
    metadata
    |> stringify_keys()
    |> Map.drop(["visitor_id", "session_id", "user_id", "path"])
    |> maybe_redact_metadata_text()
  end

  defp normalize_metadata(_metadata), do: %{}

  defp maybe_redact_metadata_text(metadata) do
    Enum.reduce(metadata, %{}, fn {key, value}, acc ->
      sanitized =
        case {key, value} do
          {"query", query} -> Redactor.redact_query(query)
          {"feedback_note", note} -> Redactor.redact_text(note)
          {_, v} -> v
        end

      Map.put(acc, key, sanitized)
    end)
  end

  defp normalize_string(value, opts \\ []) do
    default = Keyword.get(opts, :default)

    value
    |> case do
      nil -> default
      atom when is_atom(atom) -> Atom.to_string(atom)
      number when is_number(number) -> to_string(number)
      binary when is_binary(binary) -> binary
      _other -> default
    end
    |> maybe_trim(default)
  end

  defp maybe_trim(nil, _default), do: nil

  defp maybe_trim(value, default) when is_binary(value) do
    case String.trim(value) do
      "" -> default
      trimmed -> trimmed
    end
  end

  defp maybe_trim(_value, default), do: default

  defp normalize_path(value) do
    normalized = normalize_string(value, default: "/")

    if String.starts_with?(normalized, "/") do
      normalized
    else
      "/"
    end
  end

  defp normalize_rank(value) when is_integer(value) and value > 0, do: value

  defp normalize_rank(value) when is_binary(value) do
    case Integer.parse(value) do
      {rank, ""} when rank > 0 -> rank
      _ -> nil
    end
  end

  defp normalize_rank(_value), do: nil

  defp normalize_feedback_value(value) do
    normalized = normalize_string(value)

    if normalized in AnalyticsEvent.feedback_values(), do: normalized, else: nil
  end

  defp normalize_identity(value, opts) do
    default = Keyword.fetch!(opts, :default)

    value
    |> normalize_string(default: default)
    |> case do
      nil -> default
      "" -> default
      identity -> identity
    end
  end

  defp normalize_uuid(value) do
    case normalize_string(value) do
      nil -> nil
      uuid when is_binary(uuid) and byte_size(uuid) == 36 -> uuid
      _other -> nil
    end
  end

  defp maybe_blank_to_nil(nil), do: nil

  defp maybe_blank_to_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp maybe_blank_to_nil(_value), do: nil

  defp current_user_id(%{user: %{id: user_id}}) when is_binary(user_id), do: user_id
  defp current_user_id(%{assigns: %{current_scope: %{user: %{id: user_id}}}}) when is_binary(user_id), do: user_id
  defp current_user_id(_scope), do: nil

  defp admin_scope?(%{user: %{is_admin: true}}), do: true
  defp admin_scope?(%{assigns: %{current_scope: %{user: %{is_admin: true}}}}), do: true
  defp admin_scope?(_), do: false

  defp normalize_attrs(attrs) when is_map(attrs), do: attrs
  defp normalize_attrs(attrs) when is_list(attrs), do: Map.new(attrs)
  defp normalize_attrs(_attrs), do: %{}

  defp fetch_value(map, key) when is_map(map) and is_binary(key) do
    Map.get(map, key) || Map.get(map, String.to_atom(key))
  rescue
    ArgumentError -> Map.get(map, key)
  end

  defp stringify_keys(map) when is_map(map) do
    Enum.reduce(map, %{}, fn {key, value}, acc ->
      string_key =
        case key do
          atom when is_atom(atom) -> Atom.to_string(atom)
          binary when is_binary(binary) -> binary
          other -> to_string(other)
        end

      Map.put(acc, string_key, value)
    end)
  end

  defp surface_for(%AnalyticsEvent{metadata: metadata, source: source}) when is_map(metadata) do
    Map.get(metadata, "surface") || Map.get(metadata, :surface) || source
  end

  defp surface_for(%AnalyticsEvent{source: source}), do: source

  defp since_naive(days) do
    NaiveDateTime.utc_now()
    |> NaiveDateTime.add(-days * 86_400, :second)
  end

  defp since_date(days) do
    Date.utc_today()
    |> Date.add(-days + 1)
  end

  defp unauthorized_snapshot(days) do
    %{
      days: days,
      since: since_naive(days),
      unavailable?: false,
      authorized?: false,
      summary: empty_summary(),
      top_demand_topics: [],
      content_gaps: [],
      reformulations: [],
      feedback_breakdown: [],
      recent_feedback: [],
      recent_negative_feedback: [],
      local_search: empty_local_search(),
      ingestion: empty_ingestion_snapshot()
    }
  end

  defp unavailable_snapshot(days) do
    %{
      days: days,
      since: since_naive(days),
      unavailable?: true,
      authorized?: true,
      summary: empty_summary(),
      top_demand_topics: [],
      content_gaps: [],
      reformulations: [],
      feedback_breakdown: [],
      recent_feedback: [],
      recent_negative_feedback: [],
      local_search: empty_local_search(),
      ingestion: empty_ingestion_snapshot()
    }
  end

  defp empty_summary do
    %{
      total_queries: 0,
      successful_queries: 0,
      failed_queries: 0,
      no_result_queries: 0,
      total_events: 0,
      total_feedback: 0,
      helpful_feedback: 0,
      not_helpful_feedback: 0
    }
  end

  defp empty_local_search do
    %{
      summary: %{
        total_messages: 0,
        submitted_messages: 0,
        successful_messages: 0,
        no_result_messages: 0,
        failed_messages: 0
      },
      outcome_breakdown: [],
      channel_breakdown: [],
      recent_messages: []
    }
  end

  defp empty_ingestion_snapshot do
    %{
      sources: [],
      recent_runs: []
    }
  end

  defp empty_ecosystem_snapshot(days, opts) do
    %{
      days: days,
      since_date: since_date(days),
      unavailable?: Keyword.get(opts, :unavailable?, false),
      authorized?: Keyword.get(opts, :authorized?, true),
      totals: %{
        github: %{views_count: 0, views_uniques: 0, clones_count: 0, clones_uniques: 0},
        plausible: %{visitors: 0, visits: 0, pageviews: 0, events: 0, bounce_rate: nil, visit_duration: nil},
        search_console: %{clicks: 0, impressions: 0, ctr: 0.0, position: nil},
        hex: %{day: nil, packages_count: 0, downloads_day: 0, downloads_week: 0, downloads_recent: 0, downloads_all: 0}
      },
      collection: empty_ingestion_snapshot(),
      acquisition_sources: [],
      site_pages: [],
      search_queries: [],
      search_pages: [],
      repo_interest: [],
      github_paths: [],
      github_referrers: [],
      package_adoption: [],
      release_adoption: [],
      content_gaps: []
    }
  end

  defp normalize_limit(value, _default) when is_integer(value) and value > 0, do: value
  defp normalize_limit(_value, default), do: default

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(_value), do: false
end
