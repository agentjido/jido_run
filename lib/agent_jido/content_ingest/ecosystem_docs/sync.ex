defmodule AgentJido.ContentIngest.EcosystemDocs.Sync do
  @moduledoc """
  Synchronously crawls published HexDocs pages and reconciles a managed Arcana corpus.
  """

  import Ecto.Query

  alias AgentJido.ContentIngest.EcosystemDocs.{Extractor, HexDocsClient, ManifestParser, Resolver}
  alias AgentJido.ContentIngest.Source
  alias AgentJido.Ecosystem
  alias AgentJido.Ecosystem.Package
  alias AgentJido.Repo
  alias Arcana.{Collection, Document}

  @collection "site_ecosystem_docs"
  @collection_description "HexDocs package documentation for the public Jido ecosystem"
  @managed_by "agent_jido.content_ingest.ecosystem_docs/v1"
  @default_page_concurrency 4

  @typedoc """
  Review item created when an upstream README changes materially.

  Surfaced on the sync summary as `readme_drift` (jido-e09-t32): a content-hash
  change on a previously-ingested README page is a reviewable signal that the
  package's README drifted from the version backing the corpus.
  """
  @type readme_drift_item :: %{
          package_id: String.t(),
          package_name: String.t(),
          readme_source_id: String.t(),
          page_title: String.t() | nil,
          previous_content_hash: String.t(),
          current_content_hash: String.t(),
          readme_url: String.t() | nil,
          detected_at: String.t()
        }

  @typedoc """
  Assigned review task created when a priority package's upstream README
  changes materially (jido-e12-t18).

  A `readme_drift_item` (jido-e09-t32) on a priority package — core (tier 1) or
  official (tier 2), the set whose README defines a role the public site must
  mirror — is promoted to an assigned review task attributed to the package
  owner. The task asks the owner to re-align the site's package record (its
  documented role/boundaries) with the upstream README. Surfaced on the sync
  summary as `package_role_review`.
  """
  @type package_role_review_task :: %{
          package_id: String.t(),
          package_name: String.t(),
          owner: String.t(),
          category: atom() | nil,
          readme_source_id: String.t(),
          readme_url: String.t() | nil,
          previous_content_hash: String.t(),
          current_content_hash: String.t(),
          detected_at: String.t()
        }

  @type summary :: %{
          mode: :apply | :dry_run,
          dry_run: boolean(),
          total_packages: non_neg_integer(),
          eligible_packages: non_neg_integer(),
          skipped_unpublished_count: non_neg_integer(),
          total_sources: non_neg_integer(),
          inserted: non_neg_integer(),
          updated: non_neg_integer(),
          skipped: non_neg_integer(),
          deleted: non_neg_integer(),
          readme_drift: [readme_drift_item()],
          readme_drift_count: non_neg_integer(),
          package_role_review: [package_role_review_task()],
          package_role_review_count: non_neg_integer(),
          failed: [map()],
          failed_count: non_neg_integer(),
          started_at: DateTime.t(),
          finished_at: DateTime.t() | nil
        }

  @spec collection() :: String.t()
  def collection, do: @collection

  @spec managed_by() :: String.t()
  def managed_by, do: @managed_by

  @spec sync(keyword()) :: summary()
  def sync(opts \\ []) do
    packages = Resolver.public_packages(opts)
    sync_packages(packages, opts)
  end

  @spec sync_package(String.t(), keyword()) :: summary()
  def sync_package(package_id, opts \\ []) when is_binary(package_id) do
    opts
    |> Keyword.put(:package_id, package_id)
    |> sync()
  end

  @spec snapshot(keyword()) :: map()
  def snapshot(opts \\ []) do
    repo = Keyword.get(opts, :repo, Repo)
    rows = fetch_existing_documents(repo)

    packages =
      rows
      |> Enum.group_by(&metadata_value(&1.metadata, "package_id"))
      |> Enum.reject(fn {package_id, _docs} -> is_nil(package_id) end)
      |> Enum.map(fn {package_id, docs} ->
        versions = docs |> Enum.map(&metadata_value(&1.metadata, "package_version")) |> Enum.reject(&is_nil/1) |> Enum.uniq()

        last_crawled_at =
          docs
          |> Enum.map(&metadata_value(&1.metadata, "crawled_at"))
          |> Enum.map(&parse_datetime/1)
          |> Enum.reject(&is_nil/1)
          |> Enum.max(DateTime, fn -> nil end)

        %{
          package_id: package_id,
          package_version: List.first(versions),
          document_count: length(docs),
          last_crawled_at: last_crawled_at
        }
      end)
      |> Enum.sort_by(& &1.package_id)

    %{
      collection: @collection,
      total_documents: length(rows),
      package_count: length(packages),
      latest_crawled_at:
        packages
        |> Enum.map(& &1.last_crawled_at)
        |> Enum.reject(&is_nil/1)
        |> Enum.max(DateTime, fn -> nil end),
      packages: packages
    }
  end

  defp sync_packages(packages, opts) do
    repo = Keyword.get(opts, :repo, Repo)
    dry_run = Keyword.get(opts, :dry_run, false)
    page_concurrency = Keyword.get(opts, :page_concurrency, config(:page_concurrency, @default_page_concurrency))
    existing_by_package = fetch_existing_documents(repo) |> Enum.group_by(&metadata_value(&1.metadata, "package_id"))

    packages
    |> Enum.reduce(base_summary(packages, dry_run), fn package, acc ->
      package_existing_docs = Map.get(existing_by_package, package.id, [])

      case sync_one_package(package, package_existing_docs, repo, Keyword.put(opts, :page_concurrency, page_concurrency)) do
        {:ok, package_summary} ->
          merge_package_summary(acc, package_summary)

        {:error, reason} ->
          add_failure(acc, package.id, reason)
      end
    end)
    |> finalize_summary()
  end

  defp sync_one_package(package, existing_docs, repo, opts) do
    with {:ok, {resolution, resolved_package}} <- resolve_package(package, opts) do
      sync_resolved_package(resolution, resolved_package, existing_docs, repo, opts)
    end
  end

  defp sync_resolved_package(:eligible, resolved_package, existing_docs, repo, opts) do
    with {:ok, sources} <- build_sources(resolved_package, opts),
         {:ok, package_summary} <- reconcile_package(repo, resolved_package.package_id, sources, existing_docs, opts) do
      {:ok, eligible_package_summary(resolved_package, sources, package_summary)}
    end
  end

  defp sync_resolved_package(:skipped_unpublished, resolved_package, existing_docs, repo, opts) do
    deleted = delete_package_documents(repo, existing_docs, Keyword.get(opts, :dry_run, false))

    {:ok,
     %{
       package_id: resolved_package.package_id,
       eligible_packages: 0,
       skipped_unpublished_count: 1,
       total_sources: 0,
       inserted: 0,
       updated: 0,
       skipped: 0,
       deleted: deleted
     }}
  end

  defp eligible_package_summary(resolved_package, sources, package_summary) do
    %{
      package_id: resolved_package.package_id,
      eligible_packages: 1,
      skipped_unpublished_count: 0,
      total_sources: length(sources),
      inserted: package_summary.inserted,
      updated: package_summary.updated,
      skipped: package_summary.skipped,
      deleted: package_summary.deleted,
      readme_drift: Map.get(package_summary, :readme_drift, []),
      package_role_review: Map.get(package_summary, :package_role_review, [])
    }
  end

  defp resolve_package(package, opts) do
    case Resolver.resolve_package(package, opts) do
      {:ok, {:eligible, resolved_package}} ->
        {:ok, {:eligible, resolved_package}}

      {:ok, {:skipped_unpublished, resolved_package}} ->
        {:ok, {:skipped_unpublished, resolved_package}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_sources(resolved_package, opts) do
    client = Keyword.get(opts, :client, HexDocsClient)
    extractor = Keyword.get(opts, :extractor, Extractor)
    manifest_parser = Keyword.get(opts, :manifest_parser, ManifestParser)
    page_concurrency = Keyword.get(opts, :page_concurrency, config(:page_concurrency, @default_page_concurrency))

    with {:ok, docs_root_response} <- client.fetch(resolved_package.docs_html_url, opts),
         {:ok, landing_url} <- resolve_landing_url(docs_root_response, manifest_parser),
         {:ok, landing_response} <- client.fetch(landing_url, opts),
         {:ok, sidebar_asset_url} <-
           resolve_sidebar_asset_url(landing_response, resolved_package.docs_html_url, client, manifest_parser, opts),
         {:ok, manifest_response} <- client.fetch(sidebar_asset_url, opts),
         {:ok, manifest} <- manifest_parser.parse_sidebar_items(manifest_response.body) do
      pages = manifest_parser.page_entries(manifest, resolved_package.docs_html_url)
      cached_pages = %{landing_url => landing_response}

      pages
      |> Task.async_stream(
        fn page ->
          crawl_page(page, resolved_package, cached_pages, client, extractor, opts)
        end,
        max_concurrency: page_concurrency,
        ordered: true,
        timeout: Keyword.get(opts, :request_timeout_ms, config(:request_timeout_ms, 15_000)) + 5_000
      )
      |> Enum.reduce_while({:ok, []}, fn
        {:ok, {:ok, source}}, {:ok, acc} -> {:cont, {:ok, [source | acc]}}
        {:ok, {:error, reason}}, _acc -> {:halt, {:error, reason}}
        {:exit, reason}, _acc -> {:halt, {:error, {:page_task_failed, reason}}}
      end)
      |> case do
        {:ok, sources} -> {:ok, Enum.reverse(sources)}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp crawl_page(page, resolved_package, cached_pages, client, extractor, opts) do
    with {:ok, response} <- fetch_page(page.crawl_url, cached_pages, client, opts),
         {:ok, extracted} <- extractor.extract(response.body, title: page.page_title) do
      outbound_url =
        response.headers
        |> extractor.canonical_url(default_outbound_url(resolved_package.package_name, page.page_path))
        |> normalize_url(default_outbound_url(resolved_package.package_name, page.page_path))

      crawl_url = normalize_url(page.crawl_url, page.crawl_url)
      hexdocs_url = normalize_url(resolved_package.hexdocs_url, "https://hexdocs.pm/#{resolved_package.package_name}")
      page_title = extracted.title || page.page_title
      text = searchable_text(resolved_package, page.page_kind, page_title, extracted.text)
      content_hash = content_hash(text)

      {:ok,
       %Source{
         source_id: "ecosystem_docs:#{resolved_package.package_id}:#{page.page_kind}:#{page.page_id}",
         collection: @collection,
         collection_description: @collection_description,
         text: text,
         metadata: %{
           "managed_by" => @managed_by,
           "source_type" => "ecosystem_docs",
           "title" => page_title,
           "description" => snippet(text),
           "package_id" => resolved_package.package_id,
           "package_name" => resolved_package.package_name,
           "package_title" => resolved_package.package_title,
           "package_version" => resolved_package.package_version,
           "page_kind" => Atom.to_string(page.page_kind),
           "page_id" => page.page_id,
           "page_title" => page_title,
           "page_path" => page.page_path,
           "crawl_url" => crawl_url,
           "outbound_url" => outbound_url,
           "package_url" => resolved_package.package_url,
           "hexdocs_url" => hexdocs_url,
           "github_url" => resolved_package.github_url,
           "content_hash" => content_hash,
           "crawled_at" => DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()
         }
       }}
    end
  end

  defp resolve_landing_url(response, manifest_parser) do
    case manifest_parser.follow_meta_refresh(response.body, response.url) do
      nil -> {:ok, response.url}
      url -> {:ok, url}
    end
  end

  defp resolve_sidebar_asset_url(landing_response, docs_root_url, client, manifest_parser, opts) do
    case manifest_parser.sidebar_asset_url(landing_response.body, landing_response.url) do
      nil ->
        search_url = manifest_parser.search_url(docs_root_url)

        with {:ok, search_response} <- client.fetch(search_url, opts),
             sidebar_asset when is_binary(sidebar_asset) <- manifest_parser.sidebar_asset_url(search_response.body, search_url) do
          {:ok, sidebar_asset}
        else
          nil -> {:error, :missing_sidebar_manifest}
          {:error, reason} -> {:error, reason}
        end

      sidebar_asset_url ->
        {:ok, sidebar_asset_url}
    end
  end

  defp fetch_page(url, cached_pages, client, opts) do
    case Map.fetch(cached_pages, url) do
      {:ok, response} -> {:ok, response}
      :error -> client.fetch(url, opts)
    end
  end

  defp reconcile_package(repo, _package_id, sources, existing_docs, opts) do
    dry_run = Keyword.get(opts, :dry_run, false)
    detected_at = DateTime.utc_now() |> DateTime.truncate(:second)
    existing_by_source = Enum.group_by(existing_docs, & &1.source_id)
    source_ids = MapSet.new(Enum.map(sources, & &1.source_id))

    summary =
      Enum.reduce_while(sources, {:ok, %{inserted: 0, updated: 0, skipped: 0, deleted: 0}}, fn source, {:ok, acc} ->
        docs = Map.get(existing_by_source, source.source_id, [])

        case sync_source(repo, source, docs, dry_run, acc) do
          {:ok, updated_acc} -> {:cont, {:ok, updated_acc}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)

    with {:ok, summary} <- summary do
      stale_docs =
        existing_docs
        |> Enum.reject(&MapSet.member?(source_ids, &1.source_id))

      stale_deleted = delete_package_documents(repo, stale_docs, dry_run)

      readme_drift = detect_readme_drift(sources, existing_docs, detected_at)
      package_role_review = detect_package_role_review(readme_drift)

      {:ok,
       summary
       |> Map.update!(:deleted, &(&1 + stale_deleted))
       |> Map.put(:readme_drift, readme_drift)
       |> Map.put(:package_role_review, package_role_review)}
    end
  end

  # jido-e09-t32: a material upstream README change creates a review item.
  # Drift is a content-hash change on a README page that already had an
  # ingested version. New READMEs (no prior version) and unchanged READMEs
  # produce no review item.
  defp detect_readme_drift(sources, existing_docs, detected_at) do
    existing_by_source = Enum.group_by(existing_docs, & &1.source_id)

    sources
    |> Enum.filter(&readme_source?/1)
    |> Enum.flat_map(fn source ->
      current_hash = metadata_value(source.metadata, "content_hash")

      previous_hash =
        existing_by_source
        |> Map.get(source.source_id, [])
        |> Enum.map(&metadata_value(&1.metadata, "content_hash"))
        |> Enum.reject(&is_nil/1)
        |> List.first()

      if material_drift?(previous_hash, current_hash) do
        [build_readme_drift_item(source, previous_hash, current_hash, detected_at)]
      else
        []
      end
    end)
  end

  defp readme_source?(%Source{metadata: metadata}) do
    metadata_value(metadata, "page_kind") == "readme"
  end

  defp material_drift?(previous_hash, current_hash) do
    present?(previous_hash) and present?(current_hash) and previous_hash != current_hash
  end

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(_value), do: false

  defp build_readme_drift_item(source, previous_hash, current_hash, detected_at) do
    metadata = source.metadata || %{}

    %{
      package_id: metadata_value(metadata, "package_id"),
      package_name: metadata_value(metadata, "package_name"),
      readme_source_id: source.source_id,
      page_title: metadata_value(metadata, "page_title"),
      previous_content_hash: previous_hash,
      current_content_hash: current_hash,
      readme_url: metadata_value(metadata, "outbound_url"),
      detected_at: DateTime.to_iso8601(detected_at)
    }
  end

  # jido-e12-t18: a material upstream README change on a priority package is
  # promoted from an informational review item (jido-e09-t32) to an assigned
  # review task attributed to the package owner. For priority packages — core
  # (tier 1) and official (tier 2), the set whose README defines the role the
  # public site must mirror (E09 exit criterion) — a material change creates
  # owned, actionable work, not just a transient signal. Community (tier 3)
  # packages keep the readme_drift item only.
  defp detect_package_role_review(readme_drift_items) when is_list(readme_drift_items) do
    readme_drift_items
    |> Enum.filter(&priority_drift?/1)
    |> Enum.map(&build_package_role_review_task/1)
  end

  defp priority_drift?(%{package_id: package_id}) when is_binary(package_id) do
    Ecosystem.priority_package?(package_id)
  end

  defp priority_drift?(_item), do: false

  defp build_package_role_review_task(item) do
    package = Ecosystem.get_package(item.package_id)

    %{
      package_id: item.package_id,
      package_name: item.package_name,
      owner: package_owner(package),
      category: package_category(package),
      readme_source_id: item.readme_source_id,
      readme_url: item.readme_url,
      previous_content_hash: item.previous_content_hash,
      current_content_hash: item.current_content_hash,
      detected_at: item.detected_at
    }
  end

  defp package_owner(%Package{tech_lead: tech_lead}) when is_binary(tech_lead) do
    if String.trim(tech_lead) == "", do: "", else: tech_lead
  end

  defp package_owner(_package), do: ""

  defp package_category(%Package{category: category}) when is_atom(category), do: category
  defp package_category(_package), do: nil

  defp sync_source(repo, source, docs, dry_run, summary) do
    target_hash = metadata_value(source.metadata, "content_hash")

    {matching_docs, non_matching_docs} =
      Enum.split_with(docs, fn doc ->
        metadata_value(doc.metadata, "content_hash") == target_hash
      end)

    cond do
      docs == [] ->
        case maybe_ingest_source(repo, source, dry_run) do
          :ok -> {:ok, Map.update!(summary, :inserted, &(&1 + 1))}
          {:error, reason} -> {:error, reason}
        end

      matching_docs != [] ->
        keep_doc = hd(matching_docs)
        duplicate_ids = Enum.reject(docs, &(&1.id == keep_doc.id)) |> Enum.map(& &1.id)
        maybe_delete_documents(repo, duplicate_ids, dry_run)

        {:ok,
         summary
         |> Map.update!(:skipped, &(&1 + 1))
         |> Map.update!(:deleted, &(&1 + length(duplicate_ids)))}

      non_matching_docs != [] ->
        case maybe_ingest_source(repo, source, dry_run) do
          :ok ->
            maybe_delete_documents(repo, Enum.map(docs, & &1.id), dry_run)

            {:ok,
             summary
             |> Map.update!(:updated, &(&1 + 1))
             |> Map.update!(:deleted, &(&1 + length(docs)))}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp maybe_ingest_source(_repo, _source, true), do: :ok

  defp maybe_ingest_source(repo, %Source{} = source, false) do
    case Arcana.ingest(source.text,
           repo: repo,
           source_id: source.source_id,
           metadata: source.metadata,
           collection: %{name: source.collection, description: source.collection_description},
           graph: false
         ) do
      {:ok, _document} -> :ok
      {:error, reason} -> {:error, {:arcana_ingest_failed, source.source_id, reason}}
    end
  end

  defp delete_package_documents(repo, docs, dry_run) when is_list(docs) do
    ids = Enum.map(docs, & &1.id)
    maybe_delete_documents(repo, ids, dry_run)
    length(ids)
  end

  defp delete_package_documents(_repo, _docs, _dry_run), do: 0

  defp maybe_delete_documents(_repo, [], _dry_run), do: :ok
  defp maybe_delete_documents(_repo, _ids, true), do: :ok

  defp maybe_delete_documents(repo, ids, false) do
    from(d in Document, where: d.id in ^ids)
    |> repo.delete_all()

    :ok
  end

  defp fetch_existing_documents(repo) do
    from(d in Document,
      join: c in Collection,
      on: c.id == d.collection_id,
      where: c.name == ^@collection,
      where: not is_nil(d.source_id),
      where: fragment("?->>'managed_by' = ?", d.metadata, ^@managed_by),
      order_by: [desc: d.inserted_at],
      select: %{
        id: d.id,
        source_id: d.source_id,
        metadata: d.metadata,
        inserted_at: d.inserted_at
      }
    )
    |> repo.all()
  end

  defp base_summary(packages, dry_run) do
    %{
      mode: if(dry_run, do: :dry_run, else: :apply),
      dry_run: dry_run,
      total_packages: length(packages),
      eligible_packages: 0,
      skipped_unpublished_count: 0,
      total_sources: 0,
      inserted: 0,
      updated: 0,
      skipped: 0,
      deleted: 0,
      readme_drift: [],
      readme_drift_count: 0,
      package_role_review: [],
      package_role_review_count: 0,
      failed: [],
      failed_count: 0,
      started_at: DateTime.utc_now() |> DateTime.truncate(:second),
      finished_at: nil
    }
  end

  defp merge_package_summary(summary, package_summary) do
    summary
    |> Map.update!(:eligible_packages, &(&1 + Map.get(package_summary, :eligible_packages, 0)))
    |> Map.update!(:skipped_unpublished_count, &(&1 + Map.get(package_summary, :skipped_unpublished_count, 0)))
    |> Map.update!(:total_sources, &(&1 + Map.get(package_summary, :total_sources, 0)))
    |> Map.update!(:inserted, &(&1 + Map.get(package_summary, :inserted, 0)))
    |> Map.update!(:updated, &(&1 + Map.get(package_summary, :updated, 0)))
    |> Map.update!(:skipped, &(&1 + Map.get(package_summary, :skipped, 0)))
    |> Map.update!(:deleted, &(&1 + Map.get(package_summary, :deleted, 0)))
    |> Map.update!(:readme_drift, &(&1 ++ Map.get(package_summary, :readme_drift, [])))
    |> Map.update!(:package_role_review, &(&1 ++ Map.get(package_summary, :package_role_review, [])))
  end

  defp add_failure(summary, package_id, reason) do
    Map.update!(summary, :failed, &[%{package_id: package_id, reason: inspect(reason)} | &1])
  end

  defp finalize_summary(summary) do
    drift = Map.get(summary, :readme_drift, [])
    package_role_review = Map.get(summary, :package_role_review, [])

    %{
      summary
      | failed: Enum.reverse(summary.failed),
        failed_count: length(summary.failed),
        readme_drift: drift,
        readme_drift_count: length(drift),
        package_role_review: package_role_review,
        package_role_review_count: length(package_role_review),
        finished_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }
  end

  defp searchable_text(resolved_package, page_kind, page_title, page_text) do
    [
      resolved_package.package_title,
      resolved_package.package_name,
      "Version #{resolved_package.package_version}",
      page_kind_label(page_kind),
      page_title,
      page_text
    ]
    |> Enum.filter(&is_binary/1)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n\n")
  end

  defp page_kind_label(:module), do: "Module"
  defp page_kind_label(:guide), do: "Guide"
  defp page_kind_label(:readme), do: "README"
  defp page_kind_label(:task), do: "Task"
  defp page_kind_label(other) when is_atom(other), do: other |> Atom.to_string() |> String.capitalize()
  defp page_kind_label(_other), do: "Page"

  defp default_outbound_url(package_name, page_path), do: "https://hexdocs.pm/#{package_name}/#{page_path}"

  defp normalize_url(url, fallback) when is_binary(url) do
    case String.trim(url) do
      "" -> fallback
      value -> value
    end
  end

  defp normalize_url(_url, fallback), do: fallback

  defp snippet(text) when is_binary(text) do
    text
    |> String.replace(~r/\s+/u, " ")
    |> String.trim()
    |> String.slice(0, 280)
  end

  defp content_hash(text) do
    :crypto.hash(:sha256, :erlang.term_to_binary(text))
    |> Base.encode16(case: :lower)
  end

  defp metadata_value(metadata, key) when is_map(metadata) and is_binary(key), do: Map.get(metadata, key)
  defp metadata_value(_metadata, _key), do: nil

  defp parse_datetime(nil), do: nil

  defp parse_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> datetime
      _other -> nil
    end
  end

  defp parse_datetime(_value), do: nil

  defp config(key, default) do
    case Application.get_env(:agent_jido, AgentJido.ContentIngest.EcosystemDocs.Crawler, []) do
      config when is_list(config) -> Keyword.get(config, key, default)
      config when is_map(config) -> Map.get(config, key, default)
      _other -> default
    end
  end
end
