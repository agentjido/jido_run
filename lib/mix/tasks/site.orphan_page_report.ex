defmodule Mix.Tasks.Site.OrphanPageReport do
  @moduledoc """
  Report orphan public content pages that have no inbound navigation or
  related-content link.

  ## Usage

      mix site.orphan_page_report [options]

  ## Options

      --report PATH   Write report to PATH (default: tmp/orphan_page_report.md)

  ## Examples

      mix site.orphan_page_report
      mix site.orphan_page_report --report tmp/orphans.md

  ## Exit code

  Exits non-zero when one or more published pages have no inbound navigation
  or related-content link, so this task can gate CI and release checks.
  """
  use Mix.Task

  alias AgentJido.Release.OrphanPageReport

  @shortdoc "Report orphan public content pages with no inbound link"

  @switches [report: :string]

  @impl Mix.Task
  @spec run([String.t()]) :: :ok
  def run(args) do
    Mix.Task.run("compile")

    {opts, _argv, invalid} = OptionParser.parse(args, strict: @switches)

    if invalid != [] do
      Mix.raise("Invalid options: #{inspect(invalid)}")
    end

    audit_opts = [report_path: Keyword.get(opts, :report, "tmp/orphan_page_report.md")]

    case OrphanPageReport.run(audit_opts) do
      {:ok, report} ->
        print_summary(report)
        :ok

      {:error, report} ->
        print_summary(report)
        Mix.raise("Orphan-page report failed. See report at #{report.report_path}")
    end
  end

  defp print_summary(report) do
    Mix.shell().info("Public content pages checked: #{report.public_page_count}")
    Mix.shell().info("Pages in navigation menu: #{report.in_menu_count}")
    Mix.shell().info("Pages with an inbound related-content link: #{report.linked_count}")
    Mix.shell().info("Orphan pages: #{length(report.orphans)}")
    Mix.shell().info("Report written: #{report.report_path}")
  end
end
