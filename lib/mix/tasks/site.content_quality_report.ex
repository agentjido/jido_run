defmodule Mix.Tasks.Site.ContentQualityReport do
  @moduledoc """
  Generate the monthly content-quality dashboard.

  Aggregates the five content-quality signals the monthly full sweep reviews —
  broken links, stale pages, version drift, failed Livebooks, and no-result
  search queries — into one report so they are visible together. Each signal is
  informational; the per-signal release gates (`site.link_audit`,
  `site.orphan_page_report`, the Livebook coverage test) remain the blocking
  truth. See `AgentJido.Release.ContentQualityReport` for signal sources.

  ## Usage

      mix site.content_quality_report [options]

  ## Options

      --report PATH        Write report to PATH (default: tmp/content_quality_report.md)
      --window-days N      No-result query lookback window in days (default: 30)
      --no-results-limit N Max no-result search phrases to list (default: 25)

  ## Examples

      mix site.content_quality_report
      mix site.content_quality_report --window-days 90 --report tmp/july_dashboard.md

  ## Exit code

  Always exits 0 — the dashboard is informational. A section whose data source
  is unavailable (for example, no database for no-result queries) renders as
  `unavailable` instead of failing the run.
  """

  use Mix.Task

  alias AgentJido.Release.ContentQualityReport

  @shortdoc "Generate the monthly content-quality dashboard"

  @switches [
    report: :string,
    window_days: :integer,
    no_results_limit: :integer
  ]

  @impl Mix.Task
  @spec run([String.t()]) :: :ok
  def run(args) do
    # app.start (not just compile) so the no-result-queries signal can reach the
    # analytics database; the other four signals are filesystem/compile-time and
    # work regardless.
    Mix.Task.run("app.start")

    {opts, _argv, invalid} = OptionParser.parse(args, strict: @switches)

    if invalid != [] do
      Mix.raise("Invalid options: #{inspect(invalid)}")
    end

    report_opts =
      [
        report_path: Keyword.get(opts, :report, "tmp/content_quality_report.md"),
        window_days: Keyword.get(opts, :window_days),
        no_results_limit: Keyword.get(opts, :no_results_limit)
      ]
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)

    {:ok, report} = ContentQualityReport.run(report_opts)

    print_summary(report)
    :ok
  end

  defp print_summary(report) do
    Mix.shell().info("Broken internal links: #{length(report.broken_links.unmatched_internal)}")
    Mix.shell().info("Stale pages/examples: #{length(report.stale_pages)}")
    Mix.shell().info("Version-drift findings: #{length(report.version_drift)}")
    Mix.shell().info("Failed Livebooks (no coverage test): #{length(report.failed_livebooks)}")

    Mix.shell().info(
      "No-result search phrases: #{no_result_count(report.no_result_queries)}" <>
        if(report.no_result_queries.available, do: "", else: " (unavailable)")
    )

    Mix.shell().info("Report written: #{report.report_path}")
  end

  defp no_result_count(%{available: false}), do: "unavailable"
  defp no_result_count(%{rows: rows}), do: length(rows)
end
