defmodule Mix.Tasks.Content.Ingest.EcosystemDocs do
  @moduledoc """
  Ingest published HexDocs package pages for public ecosystem packages.

  Examples:

      mix content.ingest.ecosystem_docs
      mix content.ingest.ecosystem_docs --dry-run
      mix content.ingest.ecosystem_docs --package jido
  """

  use Mix.Task

  alias AgentJido.ContentIngest.EcosystemDocs

  @shortdoc "Ingest published HexDocs pages into Arcana"
  @switches [dry_run: :boolean, package: :string]

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _argv, _invalid} = OptionParser.parse(args, strict: @switches)

    sync_opts =
      [repo: AgentJido.Repo, dry_run: Keyword.get(opts, :dry_run, false)]
      |> maybe_put_package(opts[:package])

    summary =
      case opts[:package] do
        package_id when is_binary(package_id) and package_id != "" ->
          EcosystemDocs.sync_package_now(package_id, sync_opts)

        _other ->
          EcosystemDocs.sync_now(sync_opts)
      end

    print_summary(summary)

    if summary.failed_count > 0 do
      Mix.raise("HexDocs ingestion completed with #{summary.failed_count} failure(s)")
    end
  end

  defp print_summary(summary) do
    Mix.shell().info("Arcana HexDocs ingestion summary")
    Mix.shell().info("mode: #{summary.mode}")
    Mix.shell().info("packages: #{summary.total_packages}")
    Mix.shell().info("eligible_packages: #{summary.eligible_packages}")
    Mix.shell().info("skipped_unpublished: #{summary.skipped_unpublished_count}")
    Mix.shell().info("pages: #{summary.total_sources}")
    Mix.shell().info("inserted: #{summary.inserted}")
    Mix.shell().info("updated: #{summary.updated}")
    Mix.shell().info("skipped: #{summary.skipped}")
    Mix.shell().info("deleted: #{summary.deleted}")
    Mix.shell().info("failed: #{summary.failed_count}")
    Mix.shell().info("readme_drift: #{summary.readme_drift_count}")
    Mix.shell().info("package_role_review: #{summary.package_role_review_count}")

    Enum.each(summary.failed, fn failure ->
      Mix.shell().error("  - #{failure.package_id}: #{failure.reason}")
    end)

    # jido-e09-t32: each material upstream README change is a review item.
    Enum.each(summary.readme_drift, fn item ->
      Mix.shell().info(
        "  README review: #{item.package_name} (#{item.readme_source_id}) drifted; " <>
          "review at #{item.readme_url}"
      )
    end)

    # jido-e12-t18: each material package-role change on a priority package is
    # an assigned review task attributed to its owner.
    Enum.each(summary.package_role_review, fn task ->
      Mix.shell().info(
        "  Package-role review: #{task.package_name} (#{task.category}) " <>
          "assigned to #{task.owner}; re-align role with #{task.readme_url}"
      )
    end)
  end

  defp maybe_put_package(opts, package_id) when is_binary(package_id) and package_id != "",
    do: Keyword.put(opts, :package_id, package_id)

  defp maybe_put_package(opts, _package_id), do: opts
end
