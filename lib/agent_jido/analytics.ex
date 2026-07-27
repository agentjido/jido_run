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
          ingestion: map(),
          home_conversion: [map()],
          first_livebook_open: [map()],
          first_core_agent_success: [map()],
          first_llm_request: [map()],
          example_filter: [map()],
          example_engagement: [map()],
          example_simulated_run: [map()],
          long_running_path_entry: [map()],
          control_proof_evaluation: [map()],
          controlled_agent_completion: [map()],
          ecosystem_stack_selection: [map()],
          docs_search_no_results: [map()],
          docs_search_reformulations: [map()]
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
      no_results_limit = Keyword.get(opts, :no_results_limit, @default_limit)
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
        ingestion: ingestion_snapshot(days),
        home_conversion: home_conversion_breakdown(days),
        first_livebook_open: first_livebook_open_breakdown(days),
        first_core_agent_success: first_core_agent_success_breakdown(days),
        first_llm_request: first_llm_request_breakdown(days),
        example_filter: example_filter_breakdown(days),
        example_engagement: example_engagement_breakdown(days),
        example_simulated_run: example_simulated_run_breakdown(days),
        long_running_path_entry: long_running_path_entry_breakdown(days),
        control_proof_evaluation: control_proof_evaluation_breakdown(days),
        controlled_agent_completion: controlled_agent_completion_breakdown(days),
        ecosystem_stack_selection: ecosystem_stack_selection_breakdown(days),
        docs_search_no_results: docs_search_no_results_breakdown(days, no_results_limit),
        docs_search_reformulations: docs_search_reformulations_breakdown(days, reform_limit)
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

  # First Livebook open — where activation starts (jido-e12-t22). A visitor's
  # first-ever `livebook_run_clicked` is the moment they first open a Livebook,
  # so we take, per visitor, their earliest Livebook engagement and then group
  # the activations that fell inside the window by the surface they started on
  # (the docs "Run in Livebook" CTA vs. an example-page companion notebook).
  # `DISTINCT ON (visitor_id)` keeps one row per visitor — the earliest, because
  # inserted_at is ordered ascending within each visitor group — so repeat
  # opens by the same visitor never re-count as a new activation.
  defp first_livebook_open_breakdown(days) do
    since = since_naive(days)

    first_open_per_visitor =
      from(e in AnalyticsEvent,
        where: e.event == "livebook_run_clicked" and not is_nil(e.source),
        order_by: [asc: e.visitor_id, asc: e.inserted_at],
        distinct: e.visitor_id,
        select: %{
          visitor_id: e.visitor_id,
          opened_at: e.inserted_at,
          source: e.source
        }
      )

    from(o in subquery(first_open_per_visitor),
      where: o.opened_at >= ^since,
      group_by: o.source,
      select: %{
        source: o.source,
        activations: count(o.visitor_id)
      },
      order_by: [desc: count(o.visitor_id), asc: o.source]
    )
    |> Repo.all()
  end

  # First core Agent success (jido-e12-t23). A visitor's first-ever
  # `agent_run_succeeded` is the moment they first completed a real core Agent
  # operation (a Jido.Agent.cmd/2 returned in an interactive demo), so success
  # does not depend only on page views. `DISTINCT ON (visitor_id)` keeps one row
  # per visitor — the earliest success, because inserted_at is ordered ascending
  # within each visitor group — so repeat successes by the same visitor never
  # re-count. We then group the in-window first successes by the example
  # (section_id) the visitor succeeded on, so the team sees which core Agent a
  # visitor first ran to completion.
  defp first_core_agent_success_breakdown(days) do
    since = since_naive(days)

    first_success_per_visitor =
      from(e in AnalyticsEvent,
        where:
          e.event == "agent_run_succeeded" and
            not is_nil(e.section_id),
        order_by: [asc: e.visitor_id, asc: e.inserted_at],
        distinct: e.visitor_id,
        select: %{
          visitor_id: e.visitor_id,
          succeeded_at: e.inserted_at,
          section_id: e.section_id
        }
      )

    from(s in subquery(first_success_per_visitor),
      where: s.succeeded_at >= ^since,
      group_by: s.section_id,
      select: %{
        section_id: s.section_id,
        successes: count(s.visitor_id)
      },
      order_by: [desc: count(s.visitor_id), asc: s.section_id]
    )
    |> Repo.all()
  end

  # First LLM request outcome (jido-e12-t24). The content assistant is where a
  # visitor makes their first LLM request. A visitor's first-ever
  # `llm_request_outcome` is the moment that request resolved, so outcome does
  # not depend only on page views. `DISTINCT ON (visitor_id)` keeps one row per
  # visitor — the earliest outcome, because inserted_at is ordered ascending
  # within each visitor group — so repeat requests by the same visitor never
  # re-count. We then group the in-window first outcomes by their categorized
  # `reason` (carried in metadata), so the team sees where first LLM requests
  # succeed and — critically — where provider setup problems
  # (`provider_unconfigured`/`provider_quota`/`verification_required`) block
  # them, distinct from a generic error.
  defp first_llm_request_breakdown(days) do
    since = since_naive(days)

    first_outcome_per_visitor =
      from(e in AnalyticsEvent,
        where:
          e.event == "llm_request_outcome" and
            not is_nil(e.visitor_id),
        order_by: [asc: e.visitor_id, asc: e.inserted_at],
        distinct: e.visitor_id,
        select: %{
          visitor_id: e.visitor_id,
          occurred_at: e.inserted_at,
          reason: fragment("COALESCE(?->>'reason', 'unknown')", e.metadata)
        }
      )

    from(o in subquery(first_outcome_per_visitor),
      where: o.occurred_at >= ^since,
      group_by: o.reason,
      select: %{
        reason: o.reason,
        requests: count(o.visitor_id)
      },
      order_by: [desc: count(o.visitor_id), asc: o.reason]
    )
    |> Repo.all()
  end

  # Home -> onboarding conversion (jido-e12-t21). Groups `cta_clicked` events
  # fired from the home page (`source: "home"`) by their `section_id` so the
  # team can see each CTA path — the hero CTA and every section CTA — instead
  # of only page traffic. Each instrumented home CTA carries a distinct
  # section_id (hero, start-with-one-agent, quick-start, agent-model,
  # build-first-agent); rows are ordered by clicks so the strongest path leads.
  defp home_conversion_breakdown(days) do
    since = since_naive(days)

    from(e in AnalyticsEvent,
      where:
        e.inserted_at >= ^since and
          e.event == "cta_clicked" and
          e.source == "home" and
          not is_nil(e.section_id),
      group_by: e.section_id,
      select: %{
        section_id: e.section_id,
        clicks: count(e.id)
      },
      order_by: [desc: count(e.id), asc: e.section_id]
    )
    |> Repo.all()
  end

  # Example catalog filter use (jido-e12-t25). The use-case filter
  # (`/examples?use_case=<slug>`) is the catalog's only filter/search
  # mechanism, so a visitor applying one is where example discovery starts —
  # not only page traffic. A visitor's first-ever `example_filter_used` is the
  # use-case they first scoped the catalog to, so `DISTINCT ON (visitor_id)`
  # keeps one row per visitor — the earliest, because inserted_at is ordered
  # ascending within each visitor group — so repeat filter views by the same
  # visitor never re-count. We then group the in-window first filters by use
  # case (section_id), so the team sees which use-case filters visitors reach
  # the catalog through.
  defp example_filter_breakdown(days) do
    since = since_naive(days)

    first_filter_per_visitor =
      from(e in AnalyticsEvent,
        where:
          e.event == "example_filter_used" and
            not is_nil(e.section_id),
        order_by: [asc: e.visitor_id, asc: e.inserted_at],
        distinct: e.visitor_id,
        select: %{
          visitor_id: e.visitor_id,
          applied_at: e.inserted_at,
          use_case: e.section_id
        }
      )

    from(f in subquery(first_filter_per_visitor),
      where: f.applied_at >= ^since,
      group_by: f.use_case,
      select: %{
        use_case: f.use_case,
        visitors: count(f.visitor_id)
      },
      order_by: [desc: count(f.visitor_id), asc: f.use_case]
    )
    |> Repo.all()
  end

  # Movement from an example to its source code or local run (jido-e12-t26).
  # The example show page's "Source Code" tab (the production implementation)
  # and "Interactive Demo" tab (run the agent locally) are the proof surfaces a
  # visitor can move into beyond reading the explanation — so a visitor opening
  # either is where proof engagement starts, not only an example page view. The
  # event carries the target surface (`source` or `demo`) as section_id. A
  # visitor can engage with both surfaces, so `DISTINCT ON (visitor_id,
  # section_id)` keeps the earliest row per visitor per target — repeat opens of
  # the same surface by the same visitor never re-count, while a visitor who
  # reaches both source and demo counts once in each. We then group the
  # in-window first engagements by target (section_id), so the team sees how many
  # visitors moved from examples to source and to a local run.
  defp example_engagement_breakdown(days) do
    since = since_naive(days)

    first_engagement_per_visitor_target =
      from(e in AnalyticsEvent,
        where:
          e.event == "example_tab_viewed" and
            not is_nil(e.section_id),
        order_by: [asc: e.visitor_id, asc: e.section_id, asc: e.inserted_at],
        distinct: [e.visitor_id, e.section_id],
        select: %{
          visitor_id: e.visitor_id,
          engaged_at: e.inserted_at,
          target: e.section_id
        }
      )

    from(eng in subquery(first_engagement_per_visitor_target),
      where: eng.engaged_at >= ^since,
      group_by: eng.target,
      select: %{
        target: eng.target,
        visitors: count(eng.visitor_id)
      },
      order_by: [desc: count(eng.visitor_id), asc: eng.target]
    )
    |> Repo.all()
  end

  # Completion of a simulated (deterministic) example run (jido-e08-t34). AI and
  # browser examples that ship as fixture replays — not live model calls — use the
  # shared `SimulatedShowcaseLive` demo, whose "Run simulated flow" button is the
  # example-completion surface a visitor moves into beyond reading the
  # explanation. Each click that starts a genuine run fires one
  # `example_simulated_run` event carrying the example slug in metadata. A visitor
  # can run the same example more than once, so `DISTINCT ON (visitor_id, example)`
  # keeps the earliest run per visitor per example — repeat runs of the same
  # example by the same visitor never re-count, while a visitor who runs two
  # simulated examples counts once in each. We then group the in-window first runs
  # by example slug, so the team sees how many visitors actually ran each
  # simulated example.
  defp example_simulated_run_breakdown(days) do
    since = since_naive(days)

    first_run_per_visitor_example =
      from(e in AnalyticsEvent,
        where: e.event == "example_simulated_run",
        order_by: [
          asc: e.visitor_id,
          asc: fragment("(?->>'example')", e.metadata),
          asc: e.inserted_at
        ],
        distinct: [e.visitor_id, fragment("(?->>'example')", e.metadata)],
        select: %{
          visitor_id: e.visitor_id,
          ran_at: e.inserted_at,
          example: fragment("(?->>'example')", e.metadata)
        }
      )

    from(run in subquery(first_run_per_visitor_example),
      where: run.ran_at >= ^since,
      group_by: run.example,
      select: %{
        example: run.example,
        visitors: count(run.visitor_id)
      },
      order_by: [desc: count(run.visitor_id), asc: run.example]
    )
    |> Repo.all()
  end

  # Movement from onboarding into the Operate / long-running path (jido-e12-t27).
  # The operations hub and its runbooks are the "long-running agent path" — where
  # a visitor moves from onboarding (building a first agent) toward running it in
  # production. A visitor's first-ever `long_running_path_entered` is the moment
  # they first step onto that path, so conversion into Operate does not depend
  # only on page traffic. `DISTINCT ON (visitor_id)` keeps one row per visitor —
  # the earliest entry, because inserted_at is ordered ascending within each
  # visitor group — so repeat operations-page views by the same visitor never
  # re-count as a new conversion. We then group the in-window first entries by
  # the operations page the visitor first reached (section_id), so the team sees
  # which surface of the long-running path visitors move into from onboarding.
  defp long_running_path_entry_breakdown(days) do
    since = since_naive(days)

    first_entry_per_visitor =
      from(e in AnalyticsEvent,
        where:
          e.event == "long_running_path_entered" and
            not is_nil(e.section_id),
        order_by: [asc: e.visitor_id, asc: e.inserted_at],
        distinct: e.visitor_id,
        select: %{
          visitor_id: e.visitor_id,
          entered_at: e.inserted_at,
          section_id: e.section_id
        }
      )

    from(entry in subquery(first_entry_per_visitor),
      where: entry.entered_at >= ^since,
      group_by: entry.section_id,
      select: %{
        section_id: entry.section_id,
        visitors: count(entry.visitor_id)
      },
      order_by: [desc: count(entry.visitor_id), asc: entry.section_id]
    )
    |> Repo.all()
  end

  # Movement from the home control message to proof (jido-e12-t46). The home
  # operational-control section states four control claims, then routes each to
  # the surface where a visitor can see it (supervision, typed Actions, causal
  # Signals, the durable Journal, the integrated controlled-Agent example, and
  # the rest). A visitor following one of those proof links is where evaluation
  # of a control claim starts — not only a page view of the home section. The
  # event carries the control claim (the proof link's slug) as section_id. A
  # visitor can start evaluating more than one claim, so `DISTINCT ON (visitor_id,
  # section_id)` keeps the earliest evaluation per visitor per claim — repeat
  # follows of the same claim by the same visitor never re-count, while a visitor
  # who evaluates two claims counts once in each. We then group the in-window
  # first evaluations by claim (section_id), so the team can see which control
  # claims visitors start evaluating from the home control message.
  defp control_proof_evaluation_breakdown(days) do
    since = since_naive(days)

    first_evaluation_per_visitor_claim =
      from(e in AnalyticsEvent,
        where:
          e.event == "control_proof_viewed" and
            not is_nil(e.section_id),
        order_by: [asc: e.visitor_id, asc: e.section_id, asc: e.inserted_at],
        distinct: [e.visitor_id, e.section_id],
        select: %{
          visitor_id: e.visitor_id,
          evaluated_at: e.inserted_at,
          claim: e.section_id
        }
      )

    from(ev in subquery(first_evaluation_per_visitor_claim),
      where: ev.evaluated_at >= ^since,
      group_by: ev.claim,
      select: %{
        claim: ev.claim,
        visitors: count(ev.visitor_id)
      },
      order_by: [desc: count(ev.visitor_id), asc: ev.claim]
    )
    |> Repo.all()
  end

  # Completion of the integrated controlled-Agent example (jido-e12-t47). The
  # example is the home operational-control section's capstone proof — one
  # supervised run that answers every control question — so the team measures
  # how far visitors get through it, not only that the page was viewed. Five
  # steps mark that progress: starting the demo's local runtime (`start`),
  # running the allowed path (`allowed_path`), running the denied path
  # (`denied_path`), opening the example's source code (`source_open`), and
  # opening the local run — the interactive demo tab (`local_run`). Each step
  # fires a single `controlled_agent_engagement` event carrying the step as
  # section_id. A visitor can reach several steps, so `DISTINCT ON (visitor_id,
  # section_id)` keeps the earliest row per visitor per step — repeat runs of the
  # same step by the same visitor never re-count, while a visitor who reaches
  # both paths counts once in each. We then group the in-window first completions
  # by step (section_id), so the team sees how many visitors reached each stage
  # of the controlled-Agent example.
  defp controlled_agent_completion_breakdown(days) do
    since = since_naive(days)

    first_completion_per_visitor_step =
      from(e in AnalyticsEvent,
        where:
          e.event == "controlled_agent_engagement" and
            not is_nil(e.section_id),
        order_by: [asc: e.visitor_id, asc: e.section_id, asc: e.inserted_at],
        distinct: [e.visitor_id, e.section_id],
        select: %{
          visitor_id: e.visitor_id,
          completed_at: e.inserted_at,
          step: e.section_id
        }
      )

    from(c in subquery(first_completion_per_visitor_step),
      where: c.completed_at >= ^since,
      group_by: c.step,
      select: %{
        step: c.step,
        visitors: count(c.visitor_id)
      },
      order_by: [desc: count(c.visitor_id), asc: c.step]
    )
    |> Repo.all()
  end

  # Ecosystem stack selection (jido-e12-t28). The ecosystem hub offers two
  # starting points, and the team needs to compare them — not only page traffic:
  # the three recommended starting stacks (Core, AI, Operate), which render
  # first and expanded, and the full package catalog, which stays collapsed
  # behind the dependency-map disclosure until a visitor reaches for it. A
  # visitor "selects" a recommended stack by following one of its package links
  # (the event carries the stack key — core/ai/operate — as section_id), and
  # "browses the full catalog" by expanding the dependency map (the event
  # carries `full_catalog` as section_id). `DISTINCT ON (visitor_id,
  # section_id)` keeps the earliest selection per visitor per path — repeat
  # follows of the same stack or repeat expands by the same visitor never
  # re-count, while a visitor who reaches two stacks counts once in each. We
  # then group the in-window first selections by path (section_id), so the team
  # can compare recommended-stack visitors against full-catalog-browsing
  # visitors.
  defp ecosystem_stack_selection_breakdown(days) do
    since = since_naive(days)

    first_selection_per_visitor_path =
      from(e in AnalyticsEvent,
        where:
          e.event == "ecosystem_stack_selected" and
            not is_nil(e.section_id),
        order_by: [asc: e.visitor_id, asc: e.section_id, asc: e.inserted_at],
        distinct: [e.visitor_id, e.section_id],
        select: %{
          visitor_id: e.visitor_id,
          selected_at: e.inserted_at,
          selection: e.section_id
        }
      )

    from(s in subquery(first_selection_per_visitor_path),
      where: s.selected_at >= ^since,
      group_by: s.selection,
      select: %{
        selection: s.selection,
        visitors: count(s.visitor_id)
      },
      order_by: [desc: count(s.visitor_id), asc: s.selection]
    )
    |> Repo.all()
  end

  # Docs search no-results (jido-e12-t29). The docs site's search surface is the
  # content assistant — a query that resolves to `no_results` is a content gap:
  # a visitor searched for something the docs do not answer. The existing
  # content_gap_report folds no-result, error, and challenge queries into one
  # demand/failure score, so the team could not read the actual zero-hit
  # phrases. This breakdown surfaces the redacted user language of no-result
  # searches directly — ranked by how many distinct visitors hit each phrase —
  # so a content gap is backed by the visitor's own words. `DISTINCT ON
  # (query_hash, visitor_id)` keeps the earliest no-result per visitor per
  # phrase: repeat no-result searches of the same phrase by the same visitor
  # never re-count the visitor, while two visitors hitting the same phrase both
  # count. The query text (redacted) and query_hash group a phrase together.
  defp docs_search_no_results_breakdown(days, limit) do
    since = since_naive(days)

    first_no_result_per_visitor_phrase =
      from(q in QueryLog,
        where:
          q.inserted_at >= ^since and
            q.status == "no_results" and
            not is_nil(q.query_hash) and
            q.query_hash != "" and
            not is_nil(q.visitor_id),
        order_by: [asc: q.query_hash, asc: q.visitor_id, asc: q.inserted_at],
        distinct: [q.query_hash, q.visitor_id],
        select: %{
          query_hash: q.query_hash,
          query: q.query,
          visitor_id: q.visitor_id
        }
      )

    from(n in subquery(first_no_result_per_visitor_phrase),
      group_by: [n.query_hash, n.query],
      select: %{
        query: n.query,
        query_hash: n.query_hash,
        visitors: count(n.visitor_id)
      },
      order_by: [desc: count(n.visitor_id), asc: n.query],
      limit: ^limit
    )
    |> Repo.all()
  end

  # Docs search reformulation transitions (jido-e12-t29). When a visitor
  # searches the docs (content assistant), finds nothing, and rephrases, the
  # *earlier* query is the content gap — the need the docs did not meet — and
  # the *later* query shows how the visitor worked around it. The existing
  # reformulation_leaderboard counts only the destination (later) query, so it
  # could not show the gap a reformulation started from. This breakdown
  # surfaces the from -> to transition in redacted user language, ranked by how
  # often each transition happened, so a content gap is backed by the visitor's
  # phrasing and the rephrase they reached for. A transition is a consecutive
  # pair of queries from the same visitor/session within the reformulation
  # window with different query hashes (same threshold as
  # reformulation_leaderboard). Counting every transition — not deduping per
  # visitor — mirrors reformulation_leaderboard, so a visitor who rephrases the
  # same gap more than once is counted each time.
  defp docs_search_reformulations_breakdown(days, limit) do
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
      |> Enum.reduce(counts, fn [previous, current], acc ->
        if reformulation_transition?(previous, current) do
          Map.update(acc, {previous.query, current.query}, 1, &(&1 + 1))
        else
          acc
        end
      end)
    end)
    |> Enum.map(fn {{from_query, to_query}, count} ->
      %{from_query: from_query, to_query: to_query, count: count}
    end)
    |> Enum.sort_by(fn row -> {-row.count, row.from_query || "", row.to_query || ""} end)
    |> Enum.take(limit)
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
      ingestion: empty_ingestion_snapshot(),
      home_conversion: [],
      first_livebook_open: [],
      first_core_agent_success: [],
      first_llm_request: [],
      example_filter: [],
      example_engagement: [],
      example_simulated_run: [],
      long_running_path_entry: [],
      control_proof_evaluation: [],
      controlled_agent_completion: [],
      ecosystem_stack_selection: [],
      docs_search_no_results: [],
      docs_search_reformulations: []
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
      ingestion: empty_ingestion_snapshot(),
      home_conversion: [],
      first_livebook_open: [],
      first_core_agent_success: [],
      first_llm_request: [],
      example_filter: [],
      example_engagement: [],
      example_simulated_run: [],
      long_running_path_entry: [],
      control_proof_evaluation: [],
      controlled_agent_completion: [],
      ecosystem_stack_selection: [],
      docs_search_no_results: [],
      docs_search_reformulations: []
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
