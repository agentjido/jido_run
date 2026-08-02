defmodule Mix.Tasks.Site.LinkAudit do
  @moduledoc """
  Audit internal and external links for public site content.

  ## Usage

      mix site.link_audit [options]

  ## Options

      --include-heex         Include static links from `lib/agent_jido_web/**/*.heex|.ex`
      --check-external       Check external markdown links (slower)
      --allow-prefix PREFIX  Ignore unmatched internal links with this prefix (repeatable)
      --max-unmatched COUNT  Fail above this count (default: 4)
      --report PATH          Write report to PATH (default: tmp/link_audit_report.md)

  ## Examples

      mix site.link_audit
      mix site.link_audit --include-heex
      mix site.link_audit --include-heex --check-external
      mix site.link_audit --allow-prefix /draft-preview
      mix site.link_audit --max-unmatched 0
  """
  use Mix.Task

  alias AgentJido.Release.LinkAudit

  @shortdoc "Audit internal and external links for the public site"
  @default_max_unmatched 4

  @switches [
    include_heex: :boolean,
    check_external: :boolean,
    allow_prefix: :keep,
    max_unmatched: :integer,
    report: :string
  ]

  @impl Mix.Task
  @spec run([String.t()]) :: :ok
  def run(args) do
    Mix.Task.run("compile")

    {opts, _argv, invalid} = OptionParser.parse(args, strict: @switches)

    if invalid != [] do
      Mix.raise("Invalid options: #{inspect(invalid)}")
    end

    audit_opts = [
      include_heex: Keyword.get(opts, :include_heex, false),
      check_external: Keyword.get(opts, :check_external, false),
      allow_prefixes: Keyword.get_values(opts, :allow_prefix),
      max_unmatched: Keyword.get(opts, :max_unmatched, @default_max_unmatched),
      report_path: Keyword.get(opts, :report, "tmp/link_audit_report.md")
    ]

    case LinkAudit.run(audit_opts) do
      {:ok, report} ->
        print_summary(report)
        :ok

      {:error, report} ->
        print_summary(report)
        Mix.raise("Link audit failed. See report at #{report.report_path}")
    end
  end

  defp print_summary(report) do
    Mix.shell().info("Route patterns checked: #{report.route_count}")
    Mix.shell().info("Internal links checked: #{report.internal_count}")
    Mix.shell().info("Unmatched internal links: #{length(report.unmatched_internal)}")
    Mix.shell().info("Maximum allowed unmatched links: #{report.max_unmatched}")

    if report.external_count > 0 do
      Mix.shell().info("External links checked (unique URLs): #{report.external_count}")
      Mix.shell().info("External warnings: #{length(report.external_warnings)}")
      Mix.shell().info("External failures: #{length(report.external_failures)}")
    end

    Mix.shell().info("Report written: #{report.report_path}")
  end
end
