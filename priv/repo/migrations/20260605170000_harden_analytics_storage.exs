defmodule AgentJido.Repo.Migrations.HardenAnalyticsStorage do
  use Ecto.Migration

  def change do
    create(index(:analytics_ingestion_runs, [:started_at], name: :air_started_at_idx))

    create(
      index(:query_logs, [:inserted_at, :query_hash],
        name: :ql_inserted_hash_idx,
        where: "query_hash IS NOT NULL"
      )
    )

    create(
      index(:analytics_events, [:path, :visitor_id, :inserted_at],
        name: :ae_feedback_path_visitor_idx,
        where: "event = 'feedback_submitted' AND visitor_id IS NOT NULL"
      )
    )

    create(
      index(:analytics_events, [:path, :session_id, :inserted_at],
        name: :ae_feedback_path_session_idx,
        where: "event = 'feedback_submitted' AND session_id IS NOT NULL"
      )
    )

    create(index(:analytics_plausible_dimension_daily, [:dimension, :day, :value_key], name: :apdd_dimension_day_value_idx))

    create(
      index(:analytics_search_console_daily, [:dimension_set, :day, :query],
        name: :ascd_dimension_day_query_idx,
        where: "query IS NOT NULL"
      )
    )

    create(
      index(:analytics_search_console_daily, [:dimension_set, :day, :page],
        name: :ascd_dimension_day_page_idx,
        where: "page IS NOT NULL"
      )
    )

    create(index(:analytics_github_referrer_snapshots, [:snapshot_date, :rank], name: :agrs_snapshot_rank_idx))

    create(index(:analytics_github_path_snapshots, [:snapshot_date, :rank], name: :agps_snapshot_rank_idx))

    create(index(:analytics_hex_package_daily, [:day, :downloads_recent], name: :ahpd_day_recent_idx))

    create(constraint(:query_logs, :query_logs_results_latency_nonneg, check: "results_count >= 0 AND (latency_ms IS NULL OR latency_ms >= 0)"))

    create(constraint(:analytics_events, :analytics_events_rank_positive, check: "rank IS NULL OR rank > 0"))

    create(constraint(:analytics_ingestion_runs, :air_status_valid, check: "status IN ('running', 'completed', 'failed')"))

    create(constraint(:analytics_ingestion_runs, :air_rows_nonnegative, check: "rows_count >= 0"))

    create(constraint(:analytics_ingestion_runs, :air_dates_ordered, check: "date_from IS NULL OR date_to IS NULL OR date_from <= date_to"))

    create(
      constraint(:analytics_github_repo_daily, :agrd_metrics_nonnegative,
        check: "views_count >= 0 AND views_uniques >= 0 AND clones_count >= 0 AND clones_uniques >= 0"
      )
    )

    create(constraint(:analytics_github_referrer_snapshots, :agrs_metrics_nonnegative, check: "rank > 0 AND count >= 0 AND uniques >= 0"))

    create(constraint(:analytics_github_path_snapshots, :agps_metrics_nonnegative, check: "rank > 0 AND count >= 0 AND uniques >= 0"))

    create(
      constraint(:analytics_plausible_site_daily, :apsd_metrics_valid,
        check:
          "visitors >= 0 AND visits >= 0 AND pageviews >= 0 AND events >= 0 AND " <>
            "(bounce_rate IS NULL OR (bounce_rate >= 0 AND bounce_rate <= 100)) AND " <>
            "(visit_duration IS NULL OR visit_duration >= 0)"
      )
    )

    create(
      constraint(:analytics_plausible_dimension_daily, :apdd_metrics_valid,
        check:
          "visitors >= 0 AND visits >= 0 AND pageviews >= 0 AND events >= 0 AND " <>
            "(bounce_rate IS NULL OR (bounce_rate >= 0 AND bounce_rate <= 100)) AND " <>
            "(visit_duration IS NULL OR visit_duration >= 0)"
      )
    )

    create(
      constraint(:analytics_search_console_daily, :ascd_metrics_valid,
        check:
          "clicks >= 0 AND impressions >= 0 AND " <>
            "(ctr IS NULL OR (ctr >= 0 AND ctr <= 1)) AND " <>
            "(position IS NULL OR position >= 0)"
      )
    )

    create(
      constraint(:analytics_hex_package_daily, :ahpd_metrics_nonnegative,
        check: "downloads_day >= 0 AND downloads_week >= 0 AND downloads_recent >= 0 AND downloads_all >= 0"
      )
    )

    create(constraint(:analytics_hex_release_daily, :ahrd_metrics_nonnegative, check: "downloads_total >= 0"))
  end
end
