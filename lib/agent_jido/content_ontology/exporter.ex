defmodule AgentJido.ContentOntology.Exporter do
  @moduledoc """
  Exports a Turtle graph for the AgentJido content ontology.

  The export focuses on markdown-backed first-party content:
  - `priv/pages/**`
  - `priv/blog/**`
  - `priv/ecosystem/**`
  - `priv/examples/**`
  - optional `priv/content_plan/**`

  It materializes:
  - web documents and source documents
  - categories and tags
  - source/provenance relations
  - version nodes and current-version links
  - hyperlink and related/prerequisite relations
  - content-plan to generated-page lineage
  """

  alias AgentJido.Blog
  alias AgentJido.ContentPlan
  alias AgentJido.Ecosystem
  alias AgentJido.Examples
  alias AgentJido.Pages
  alias AgentJido.Pages.Page

  @repo_base "https://github.com/agentjido/agentjido_xyz/blob/main/"
  @default_internal_hosts ["localhost", "127.0.0.1"]

  @type export_result :: %{
          path: String.t(),
          generated_at: DateTime.t(),
          web_documents: non_neg_integer(),
          source_documents: non_neg_integer(),
          content_plan_entries: non_neg_integer(),
          tags: non_neg_integer(),
          versions: non_neg_integer(),
          triples: non_neg_integer()
        }

  @type option ::
          {:output, String.t()}
          | {:include_content_plan, boolean()}
          | {:include_non_routable, boolean()}
          | {:git_commit_hash, String.t() | nil}

  @doc """
  Export ontology data graph and write Turtle output.

  ## Options

    * `:output` - Output path (default: `tmp/agentjido-content-graph.ttl`)
    * `:include_content_plan` - Include `priv/content_plan` entries (default: `true`)
    * `:include_non_routable` - Include known non-routable pages like training (default: `false`)
    * `:git_commit_hash` - Override commit hash for version nodes
  """
  @spec export([option()]) :: {:ok, export_result()} | {:error, String.t()}
  def export(opts \\ []) do
    output_path = Keyword.get(opts, :output, "tmp/agentjido-content-graph.ttl")
    include_content_plan = Keyword.get(opts, :include_content_plan, true)
    include_non_routable = Keyword.get(opts, :include_non_routable, false)
    git_commit_hash = Keyword.get(opts, :git_commit_hash, current_git_commit())
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    web_docs =
      collect_web_documents(include_non_routable)
      |> Enum.sort_by(&{&1.kind, &1.route, &1.id})

    plan_entries =
      if include_content_plan do
        collect_content_plan_entries()
      else
        []
      end

    web_by_route = Map.new(web_docs, &{normalize_route(&1.route), &1})
    web_by_id = Map.new(web_docs, &{normalize_identifier(&1.id), &1})

    plan_by_id =
      plan_entries
      |> Enum.map(fn entry -> {normalize_identifier(entry.id), entry} end)
      |> Map.new()

    plan_by_route =
      plan_entries
      |> Enum.reduce(%{}, fn entry, acc ->
        route = normalize_route(entry.destination_route)

        if route do
          Map.update(acc, route, [entry], &[entry | &1])
        else
          acc
        end
      end)

    tag_labels =
      (Enum.flat_map(web_docs, & &1.tags) ++ Enum.flat_map(plan_entries, & &1.tags))
      |> Enum.uniq()
      |> Enum.sort()

    source_docs =
      collect_source_documents(web_docs, plan_entries)
      |> Enum.sort_by(& &1.id)

    web_doc_uri_by_id = Map.new(web_docs, &{&1.id, doc_qname(&1)})
    web_doc_by_qname = Map.new(web_docs, &{Map.fetch!(web_doc_uri_by_id, &1.id), &1})
    source_uri_by_path = Map.new(source_docs, &{&1.path, source_qname(&1)})
    plan_uri_by_id = Map.new(plan_entries, &{&1.id, plan_qname(&1)})

    triples =
      MapSet.new()
      |> add_export_dataset_node(now)
      |> add_tag_nodes(tag_labels)
      |> add_source_nodes(source_docs)
      |> add_web_nodes(web_docs, web_doc_uri_by_id)
      |> add_content_plan_nodes(plan_entries)
      |> add_source_lineage(web_docs, source_uri_by_path, plan_by_route, plan_uri_by_id, web_doc_uri_by_id)
      |> add_web_links(web_docs, web_by_route, web_doc_uri_by_id)
      |> add_web_relations(web_docs, web_by_id, plan_by_id, web_doc_uri_by_id, plan_uri_by_id)
      |> add_content_plan_relations(plan_entries, plan_by_id, web_by_route, plan_uri_by_id, web_doc_uri_by_id)
      |> add_web_library_version_references(
        web_docs,
        web_by_id,
        web_doc_uri_by_id,
        web_doc_by_qname,
        source_uri_by_path
      )
      |> add_content_plan_library_version_references(
        plan_entries,
        web_by_route,
        web_doc_uri_by_id,
        web_doc_by_qname,
        plan_uri_by_id
      )
      |> add_tags_for_resources(
        web_docs,
        plan_entries,
        tag_labels,
        web_doc_uri_by_id,
        plan_uri_by_id,
        source_uri_by_path
      )
      |> add_versions_for_web_docs(web_docs, source_uri_by_path, web_doc_uri_by_id, git_commit_hash, now)

    body =
      triples
      |> MapSet.to_list()
      |> Enum.sort_by(&triple_sort_key/1)
      |> Enum.map(&render_triple/1)
      |> IO.iodata_to_binary()

    output =
      """
      @prefix ajc: <#{ontology_prefix_iri()}> .
      @prefix ajr: <#{resource_prefix_iri()}> .
      @prefix dcterms: <http://purl.org/dc/terms/> .
      @prefix owl: <http://www.w3.org/2002/07/owl#> .
      @prefix pav: <http://purl.org/pav/> .
      @prefix prov: <http://www.w3.org/ns/prov#> .
      @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
      @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
      @prefix skos: <http://www.w3.org/2004/02/skos/core#> .
      @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

      <> a owl:Ontology ;
        owl:imports <#{ontology_import_iri()}> ;
        dcterms:title "AgentJido content graph export" ;
        dcterms:created "#{DateTime.to_iso8601(now)}"^^xsd:dateTime .

      #{body}
      """

    with :ok <- File.mkdir_p(Path.dirname(output_path)),
         :ok <- File.write(output_path, output) do
      {:ok,
       %{
         path: output_path,
         generated_at: now,
         web_documents: length(web_docs),
         source_documents: length(source_docs),
         content_plan_entries: length(plan_entries),
         tags: length(tag_labels),
         versions: length(web_docs),
         triples: MapSet.size(triples)
       }}
    else
      {:error, reason} ->
        {:error, "failed writing ontology export to #{output_path}: #{inspect(reason)}"}
    end
  end

  defp collect_web_documents(include_non_routable) do
    pages =
      Pages.all_pages()
      |> Enum.reject(fn page -> not include_non_routable and page.category == :training end)
      |> Enum.map(fn page ->
        freshness = map_value(page, :freshness, %{})
        validation = map_value(page, :validation, %{})

        %{
          kind: :page,
          id: "page:" <> page.id,
          slug: page.id,
          title: page.title,
          description: normalize_optional(page.description),
          route: Pages.route_for(page),
          category: page.category,
          collection: collection_from_path(page.source_path),
          source_path: normalize_path(page.source_path),
          source_format: if(page.is_livebook, do: "livemd", else: "md"),
          tags: normalize_tags(page.tags),
          draft: Map.get(page, :draft, false),
          in_menu: Map.get(page, :in_menu, true),
          order: Map.get(page, :order, 9999),
          word_count: Map.get(page, :word_count),
          reading_time_minutes: Map.get(page, :reading_time_minutes),
          github_url: normalize_optional(page.github_url),
          livebook_url: normalize_optional(Page.livebook_url(page, AgentJidoWeb.Endpoint.url())),
          legacy_routes: List.wrap(Map.get(page, :legacy_paths, [])),
          doc_type: map_value(page, :doc_type),
          audience: map_value(page, :audience),
          journey_stage: map_value(page, :journey_stage),
          content_intent: map_value(page, :content_intent),
          capability_theme: map_value(page, :capability_theme),
          evidence_surface: map_value(page, :evidence_surface),
          difficulty: map_value(page, :difficulty),
          track: map_value(page, :track),
          prerequisites: normalize_ref_list(Map.get(page, :prerequisites, [])),
          related_docs: normalize_ref_list(Map.get(page, :related_docs, [])),
          related_posts: normalize_ref_list(Map.get(page, :related_posts, [])),
          ecosystem_packages: normalize_ref_list(map_value(validation, :ecosystem_packages, [])),
          min_package_versions: validation_package_versions(validation),
          body_html: normalize_optional(page.body),
          content_hash: normalize_optional(map_value(freshness, :content_hash)),
          version_label: normalize_optional(map_value(freshness, :last_refreshed_at))
        }
      end)

    blog_posts =
      Blog.all_posts()
      |> Enum.map(fn post ->
        freshness = map_value(post, :freshness, %{})
        validation = map_value(post, :validation, %{})

        %{
          kind: :blog,
          id: "blog:" <> post.id,
          slug: post.id,
          title: post.title,
          description: normalize_optional(post.description),
          route: "/blog/#{post.id}",
          category: :blog,
          collection: collection_from_path(post.source_path),
          source_path: normalize_path(post.source_path),
          source_format: if(post.is_livebook, do: "livemd", else: "md"),
          tags: normalize_tags(post.tags),
          draft: false,
          in_menu: true,
          order: 0,
          word_count: Map.get(post, :word_count),
          reading_time_minutes: Map.get(post, :reading_time_minutes),
          github_url: github_url_for(post.source_path),
          livebook_url: nil,
          legacy_routes: [],
          doc_type: Map.get(post, :post_type),
          audience: Map.get(post, :audience),
          journey_stage: Map.get(post, :journey_stage),
          content_intent: Map.get(post, :content_intent),
          capability_theme: Map.get(post, :capability_theme),
          evidence_surface: Map.get(post, :evidence_surface),
          difficulty: nil,
          track: nil,
          prerequisites: [],
          related_docs: normalize_ref_list(Map.get(post, :related_docs, [])),
          related_posts: normalize_ref_list(Map.get(post, :related_posts, [])),
          ecosystem_packages: normalize_ref_list(map_value(validation, :ecosystem_packages, [])),
          min_package_versions: validation_package_versions(validation),
          body_html: normalize_optional(post.body),
          content_hash: normalize_optional(map_value(freshness, :content_hash)),
          version_label: Date.to_iso8601(post.date),
          author_name: normalize_optional(Map.get(post, :author)),
          published_on: post.date
        }
      end)

    ecosystem_packages =
      Ecosystem.public_packages()
      |> Enum.map(fn pkg ->
        hash = sha256_hex([pkg.id, pkg.version, pkg.path, pkg.body])

        %{
          kind: :ecosystem,
          id: "ecosystem:" <> pkg.id,
          slug: pkg.id,
          title: pkg.title || pkg.name || pkg.id,
          description: normalize_optional(pkg.description || pkg.tagline),
          route: "/ecosystem/#{pkg.id}",
          category: :ecosystem,
          collection: collection_from_path(pkg.path),
          source_path: normalize_path(pkg.path),
          source_format: "md",
          tags: normalize_tags(pkg.tags),
          draft: false,
          in_menu: true,
          order: Map.get(pkg, :tier, 0),
          word_count: nil,
          reading_time_minutes: nil,
          github_url: normalize_optional(pkg.github_url || github_url_for(pkg.path)),
          livebook_url: nil,
          legacy_routes: [],
          doc_type: nil,
          audience: nil,
          journey_stage: nil,
          content_intent: nil,
          capability_theme: nil,
          evidence_surface: nil,
          difficulty: nil,
          track: nil,
          prerequisites: [],
          related_docs: [],
          related_posts: [],
          ecosystem_packages: normalize_ref_list(Map.get(pkg, :ecosystem_deps, [])),
          min_package_versions: %{},
          body_html: normalize_optional(pkg.body),
          content_hash: "sha256:" <> hash,
          version_label: normalize_optional(pkg.version)
        }
      end)

    examples =
      Examples.all_examples()
      |> Enum.map(fn ex ->
        hash = sha256_hex([ex.slug, ex.path, ex.body])

        %{
          kind: :example,
          id: "example:" <> ex.slug,
          slug: ex.slug,
          title: ex.title,
          description: normalize_optional(ex.description),
          route: "/examples/#{ex.slug}",
          category: :examples,
          collection: collection_from_path(ex.source_path),
          source_path: normalize_path(ex.source_path),
          source_format: "md",
          tags: normalize_tags(ex.tags),
          draft: ex.status == :draft,
          in_menu: true,
          order: Map.get(ex, :sort_order, 0),
          word_count: nil,
          reading_time_minutes: nil,
          github_url: github_url_for(ex.source_path),
          livebook_url: nil,
          legacy_routes: [],
          doc_type: nil,
          audience: nil,
          journey_stage: Map.get(ex, :journey_stage),
          content_intent: Map.get(ex, :content_intent),
          capability_theme: Map.get(ex, :capability_theme),
          evidence_surface: Map.get(ex, :evidence_surface),
          difficulty: Map.get(ex, :difficulty),
          track: nil,
          prerequisites: [],
          related_docs: [],
          related_posts: [],
          ecosystem_packages: [],
          min_package_versions: %{},
          body_html: normalize_optional(ex.body),
          content_hash: "sha256:" <> hash,
          version_label: nil
        }
      end)

    pages ++ blog_posts ++ ecosystem_packages ++ examples
  end

  defp collect_content_plan_entries do
    ContentPlan.all_entries()
    |> Enum.map(fn entry ->
      %{
        id: entry.id,
        slug: entry.slug,
        title: entry.title,
        source_path: normalize_path(entry.path),
        destination_route: normalize_route(Map.get(entry, :destination_route)),
        tags: normalize_tags(entry.tags),
        status: Map.get(entry, :status),
        priority: Map.get(entry, :priority),
        prerequisites: normalize_ref_list(Map.get(entry, :prerequisites, [])),
        related: normalize_ref_list(Map.get(entry, :related, [])),
        repos: normalize_ref_list(Map.get(entry, :repos, [])),
        ecosystem_packages: normalize_ref_list(Map.get(entry, :ecosystem_packages, [])),
        min_package_versions: normalize_package_version_requirements(Map.get(entry, :min_package_versions, []))
      }
    end)
  end

  defp collect_source_documents(web_docs, plan_entries) do
    from_web =
      Enum.map(web_docs, fn doc ->
        %{
          id: "source:" <> doc.source_path,
          title: doc.title,
          path: doc.source_path,
          format: doc.source_format,
          category: doc.category,
          collection: doc.collection,
          tags: doc.tags,
          github_url: doc.github_url || github_url_for(doc.source_path),
          class: source_class_for_path(doc.source_path)
        }
      end)

    from_plan =
      Enum.map(plan_entries, fn entry ->
        %{
          id: "source:" <> entry.source_path,
          title: entry.title,
          path: entry.source_path,
          format: "md",
          category: :content_plan,
          collection: :collection_priv_content_plan,
          tags: entry.tags,
          github_url: github_url_for(entry.source_path),
          class: :ContentPlanEntry
        }
      end)

    (from_web ++ from_plan)
    |> Enum.uniq_by(& &1.path)
  end

  defp add_export_dataset_node(set, now) do
    dataset = "ajr:dataset_current_export"

    set
    |> add_obj(dataset, "a", "prov:Entity")
    |> add_lit(dataset, "dcterms:title", "AgentJido content graph dataset export")
    |> add_lit(dataset, "dcterms:created", DateTime.to_iso8601(now), "xsd:dateTime")
  end

  defp add_tag_nodes(set, labels) do
    Enum.reduce(labels, set, fn label, acc ->
      tag = tag_qname(label)

      acc
      |> add_obj(tag, "a", "ajc:Tag")
      |> add_lit(tag, "skos:prefLabel", label)
    end)
  end

  defp add_source_nodes(set, source_docs) do
    Enum.reduce(source_docs, set, fn source, acc ->
      source_qn = source_qname(source)

      acc
      |> add_obj(source_qn, "a", source_class_qname(source.class))
      |> add_obj(source_qn, "a", "ajc:SourceDocument")
      |> add_lit(source_qn, "ajc:documentId", source.id)
      |> add_lit(source_qn, "ajc:title", source.title)
      |> add_lit(source_qn, "ajc:sourcePath", source.path)
      |> add_lit(source_qn, "ajc:format", source.format)
      |> maybe_add_lit(source_qn, "ajc:githubUrl", source.github_url, "xsd:anyURI")
      |> add_obj(source_qn, "ajc:belongsToCategory", category_qname(source.category))
      |> add_obj(source_qn, "ajc:inCollection", collection_qname(source.collection))
    end)
  end

  defp add_web_nodes(set, web_docs, web_doc_uri_by_id) do
    Enum.reduce(web_docs, set, fn doc, acc ->
      doc_qn = Map.fetch!(web_doc_uri_by_id, doc.id)
      doc_class = web_doc_class_qname(doc)

      acc
      |> add_obj(doc_qn, "a", doc_class)
      |> add_obj(doc_qn, "a", "ajc:WebDocument")
      |> add_lit(doc_qn, "ajc:documentId", doc.id)
      |> add_lit(doc_qn, "ajc:title", doc.title)
      |> maybe_add_lit(doc_qn, "ajc:description", doc.description)
      |> maybe_add_lit(doc_qn, "ajc:slug", doc.slug)
      |> add_lit(doc_qn, "ajc:canonicalRoute", doc.route)
      |> add_obj(doc_qn, "ajc:belongsToCategory", category_qname(doc.category))
      |> add_obj(doc_qn, "ajc:inCollection", collection_qname(doc.collection))
      |> add_lit(doc_qn, "ajc:isDraft", to_string(doc.draft), "xsd:boolean")
      |> add_lit(doc_qn, "ajc:sortOrder", Integer.to_string(doc.order || 0), "xsd:integer")
      |> maybe_add_lit(doc_qn, "ajc:isInMenu", to_bool_string(doc.in_menu), "xsd:boolean")
      |> maybe_add_lit(doc_qn, "ajc:wordCount", integer_literal(doc.word_count), "xsd:integer")
      |> maybe_add_lit(doc_qn, "ajc:readingTimeMinutes", integer_literal(doc.reading_time_minutes), "xsd:integer")
      |> maybe_add_lit(doc_qn, "ajc:githubUrl", doc.github_url, "xsd:anyURI")
      |> maybe_add_lit(doc_qn, "ajc:livebookUrl", doc.livebook_url, "xsd:anyURI")
      |> maybe_add_doc_type(doc_qn, doc.doc_type)
      |> maybe_add_audience(doc_qn, doc.audience)
      |> maybe_add_journey_stage(doc_qn, doc.journey_stage)
      |> maybe_add_content_intent(doc_qn, doc.content_intent)
      |> maybe_add_capability_theme(doc_qn, doc.capability_theme)
      |> maybe_add_evidence_surface(doc_qn, doc.evidence_surface)
      |> maybe_add_difficulty(doc_qn, doc.difficulty)
      |> maybe_add_track(doc_qn, doc.track)
      |> maybe_add_author(doc_qn, doc)
      |> maybe_add_published_on(doc_qn, doc)
      |> add_legacy_routes(doc_qn, doc.legacy_routes)
    end)
  end

  defp add_content_plan_nodes(set, entries) do
    Enum.reduce(entries, set, fn entry, acc ->
      plan_qn = plan_qname(entry)

      acc
      |> add_obj(plan_qn, "a", "ajc:ContentPlanEntry")
      |> add_obj(plan_qn, "a", "ajc:SourceDocument")
      |> add_lit(plan_qn, "ajc:documentId", entry.id)
      |> add_lit(plan_qn, "ajc:title", entry.title)
      |> add_lit(plan_qn, "ajc:slug", entry.slug)
      |> add_lit(plan_qn, "ajc:sourcePath", entry.source_path)
      |> add_lit(plan_qn, "ajc:format", "md")
      |> maybe_add_lit(plan_qn, "ajc:destinationRoute", entry.destination_route)
      |> add_obj(plan_qn, "ajc:belongsToCategory", "ajc:category_content_plan")
      |> add_obj(plan_qn, "ajc:inCollection", "ajc:collection_priv_content_plan")
      |> maybe_add_status(plan_qn, entry.status)
      |> maybe_add_priority(plan_qn, entry.priority)
    end)
  end

  defp add_source_lineage(set, web_docs, source_uri_by_path, plan_by_route, plan_uri_by_id, web_doc_uri_by_id) do
    Enum.reduce(web_docs, set, fn doc, acc ->
      doc_qn = Map.fetch!(web_doc_uri_by_id, doc.id)
      source_qn = Map.get(source_uri_by_path, doc.source_path)

      acc = maybe_link_source_document(acc, doc_qn, source_qn)

      route = normalize_route(doc.route)
      entries = Map.get(plan_by_route, route, [])

      Enum.reduce(entries, acc, &link_plan_entry(&2, &1, plan_uri_by_id, doc_qn))
    end)
  end

  defp add_web_links(set, web_docs, web_by_route, web_doc_uri_by_id) do
    Enum.reduce(web_docs, set, fn doc, acc ->
      doc_qn = Map.fetch!(web_doc_uri_by_id, doc.id)

      links =
        doc.body_html
        |> extract_internal_routes()
        |> Enum.filter(&Map.has_key?(web_by_route, &1))
        |> Enum.uniq()

      Enum.reduce(links, acc, fn route, inner ->
        target = Map.fetch!(web_by_route, route)
        target_qn = Map.fetch!(web_doc_uri_by_id, target.id)
        add_obj(inner, doc_qn, "ajc:linksTo", target_qn)
      end)
    end)
  end

  defp add_web_relations(set, web_docs, web_by_id, plan_by_id, web_doc_uri_by_id, plan_uri_by_id) do
    Enum.reduce(web_docs, set, fn doc, acc ->
      doc_qn = Map.fetch!(web_doc_uri_by_id, doc.id)

      acc
      |> add_doc_ref_relations(doc_qn, doc.prerequisites, "ajc:hasPrerequisite", web_by_id, web_doc_uri_by_id, plan_by_id, plan_uri_by_id)
      |> add_doc_ref_relations(doc_qn, doc.related_docs, "ajc:relatedTo", web_by_id, web_doc_uri_by_id, plan_by_id, plan_uri_by_id)
      |> add_doc_ref_relations(doc_qn, doc.related_posts, "ajc:relatedTo", web_by_id, web_doc_uri_by_id, plan_by_id, plan_uri_by_id)
      |> add_package_relations(doc_qn, doc.ecosystem_packages, web_by_id, web_doc_uri_by_id)
      |> add_ecosystem_dependency_relations(doc, doc_qn, web_by_id, web_doc_uri_by_id)
    end)
  end

  defp add_content_plan_relations(set, entries, plan_by_id, web_by_route, plan_uri_by_id, web_doc_uri_by_id) do
    Enum.reduce(entries, set, fn entry, acc ->
      plan_qn = Map.fetch!(plan_uri_by_id, entry.id)
      package_refs = entry.ecosystem_packages ++ Map.keys(entry.min_package_versions) ++ entry.repos

      acc
      |> add_plan_ref_relations(plan_qn, entry.prerequisites, "ajc:hasPrerequisite", plan_by_id, plan_uri_by_id)
      |> add_plan_ref_relations(plan_qn, entry.related, "ajc:relatedTo", plan_by_id, plan_uri_by_id)
      |> add_package_relations(plan_qn, package_refs, web_by_route, web_doc_uri_by_id, :route_or_slug)
      |> maybe_link_plan_to_target(entry, web_by_route, web_doc_uri_by_id)
    end)
  end

  defp add_web_library_version_references(
         set,
         web_docs,
         web_by_id,
         web_doc_uri_by_id,
         web_doc_by_qname,
         source_uri_by_path
       ) do
    Enum.reduce(web_docs, set, fn doc, acc ->
      doc_qn = Map.fetch!(web_doc_uri_by_id, doc.id)
      source_qn = Map.get(source_uri_by_path, doc.source_path)

      references = build_web_doc_library_ref_specs(doc)

      add_library_version_references(
        acc,
        doc_qn,
        source_qn,
        references,
        web_by_id,
        web_doc_uri_by_id,
        web_doc_by_qname,
        :id_only
      )
    end)
  end

  defp add_content_plan_library_version_references(
         set,
         plan_entries,
         web_by_route,
         web_doc_uri_by_id,
         web_doc_by_qname,
         plan_uri_by_id
       ) do
    Enum.reduce(plan_entries, set, fn entry, acc ->
      plan_qn = Map.fetch!(plan_uri_by_id, entry.id)
      references = build_content_plan_library_ref_specs(entry)

      add_library_version_references(
        acc,
        plan_qn,
        plan_qn,
        references,
        web_by_route,
        web_doc_uri_by_id,
        web_doc_by_qname,
        :route_or_slug
      )
    end)
  end

  defp build_web_doc_library_ref_specs(doc) do
    requirements = Map.get(doc, :min_package_versions, %{})

    (doc.ecosystem_packages ++ Map.keys(requirements))
    |> Enum.uniq()
    |> Enum.map(fn package_ref ->
      package_key = normalize_identifier(package_ref)
      constraint = Map.get(requirements, package_key)
      role = if constraint, do: "minimum_required_version", else: "ecosystem_reference"

      %{
        package_ref: package_ref,
        role: role,
        constraint: constraint
      }
    end)
  end

  defp build_content_plan_library_ref_specs(entry) do
    requirements = Map.get(entry, :min_package_versions, %{})

    constrained_refs =
      Enum.map(requirements, fn {package_ref, constraint} ->
        %{
          package_ref: package_ref,
          role: "minimum_required_version",
          constraint: constraint
        }
      end)

    ecosystem_refs =
      Enum.map(entry.ecosystem_packages, fn package_ref ->
        %{
          package_ref: package_ref,
          role: "ecosystem_reference",
          constraint: nil
        }
      end)

    repo_refs =
      Enum.map(entry.repos, fn package_ref ->
        %{
          package_ref: package_ref,
          role: "repository_reference",
          constraint: nil
        }
      end)

    (constrained_refs ++ ecosystem_refs ++ repo_refs)
    |> Enum.uniq_by(fn ref -> normalize_identifier(ref.package_ref) end)
  end

  defp add_library_version_references(
         set,
         source_qn,
         provenance_qn,
         references,
         web_index,
         web_doc_uri_by_id,
         web_doc_by_qname,
         mode
       ) do
    Enum.reduce(references, set, fn ref, acc ->
      case resolve_package_doc_and_qname(ref.package_ref, web_index, web_doc_uri_by_id, web_doc_by_qname, mode) do
        nil ->
          acc

        {target_doc, target_qn} ->
          role = normalize_optional(ref.role) || "ecosystem_reference"
          constraint = normalize_optional(ref.constraint)
          library_version = normalize_optional(Map.get(target_doc, :version_label))
          libref_qn = library_version_reference_qname(source_qn, target_doc.id, role, constraint)

          acc
          |> add_obj(source_qn, "ajc:referencesPackage", target_qn)
          |> add_obj(source_qn, "ajc:hasLibraryVersionReference", libref_qn)
          |> add_obj(libref_qn, "a", "ajc:LibraryVersionReference")
          |> add_obj(libref_qn, "a", "prov:Entity")
          |> add_obj(libref_qn, "ajc:isLibraryVersionReferenceFor", source_qn)
          |> add_obj(libref_qn, "ajc:forLibrary", target_qn)
          |> add_lit(libref_qn, "ajc:referenceRole", role)
          |> maybe_add_lit(libref_qn, "ajc:libraryVersion", library_version)
          |> maybe_add_lit(libref_qn, "ajc:libraryVersionConstraint", constraint)
          |> maybe_add_obj(libref_qn, "prov:wasDerivedFrom", provenance_qn)
      end
    end)
  end

  defp resolve_package_doc_and_qname(ref, web_index, web_doc_uri_by_id, web_doc_by_qname, mode) do
    target_qn =
      case mode do
        :id_only ->
          resolve_package_target_by_id(ref, web_doc_uri_by_id)

        :route_or_slug ->
          resolve_package_target_by_route_or_slug(ref, web_index, web_doc_uri_by_id)
      end

    case Map.get(web_doc_by_qname, target_qn) do
      %{kind: :ecosystem} = doc -> {doc, target_qn}
      _other -> nil
    end
  end

  defp add_tags_for_resources(set, web_docs, plan_entries, _tag_labels, web_doc_uri_by_id, plan_uri_by_id, source_uri_by_path) do
    set =
      Enum.reduce(web_docs, set, fn doc, acc ->
        doc_qn = Map.fetch!(web_doc_uri_by_id, doc.id)
        source_qn = Map.get(source_uri_by_path, doc.source_path)

        Enum.reduce(doc.tags, acc, &attach_doc_tag(&2, &1, doc_qn, source_qn))
      end)

    Enum.reduce(plan_entries, set, fn entry, acc ->
      plan_qn = Map.fetch!(plan_uri_by_id, entry.id)

      Enum.reduce(entry.tags, acc, fn tag, inner ->
        tag_qn = tag_qname(tag)

        inner
        |> add_obj(plan_qn, "ajc:hasTag", tag_qn)
        |> add_obj(tag_qn, "ajc:tagsResource", plan_qn)
      end)
    end)
  end

  defp add_versions_for_web_docs(set, web_docs, source_uri_by_path, web_doc_uri_by_id, git_commit_hash, now) do
    Enum.reduce(web_docs, set, fn doc, acc ->
      doc_qn = Map.fetch!(web_doc_uri_by_id, doc.id)
      source_qn = Map.get(source_uri_by_path, doc.source_path)
      hash = doc.content_hash || "sha256:" <> sha256_hex([doc.id, doc.source_path, doc.route, doc.title, doc.body_html || ""])
      hash_suffix = hash |> to_string() |> String.replace(~r/[^a-zA-Z0-9]/, "") |> String.slice(-12, 12)
      version_qn = "ajr:version_#{safe_local(doc.id)}_#{hash_suffix}"
      label = doc.version_label || DateTime.to_iso8601(now)

      acc
      |> add_obj(version_qn, "a", "ajc:DocumentVersion")
      |> add_lit(version_qn, "ajc:documentId", "version:#{doc.id}:#{hash_suffix}")
      |> add_lit(version_qn, "ajc:contentHash", hash)
      |> add_lit(version_qn, "ajc:versionLabel", label)
      |> maybe_add_lit(version_qn, "ajc:gitCommitHash", git_commit_hash)
      |> add_obj(version_qn, "ajc:isVersionOf", doc_qn)
      |> add_obj(doc_qn, "ajc:hasVersion", version_qn)
      |> add_obj(doc_qn, "ajc:hasCurrentVersion", version_qn)
      |> maybe_add_obj(version_qn, "prov:wasDerivedFrom", source_qn)
    end)
  end

  defp add_doc_ref_relations(set, source_qn, refs, predicate, web_by_id, web_doc_uri_by_id, plan_by_id, plan_uri_by_id) do
    Enum.reduce(refs, set, fn ref, acc ->
      case resolve_ref_target(ref, web_by_id, web_doc_uri_by_id, plan_by_id, plan_uri_by_id) do
        nil -> acc
        target_qn -> add_obj(acc, source_qn, predicate, target_qn)
      end
    end)
  end

  defp add_plan_ref_relations(set, source_qn, refs, predicate, plan_by_id, plan_uri_by_id) do
    Enum.reduce(refs, set, fn ref, acc ->
      normalized = normalize_identifier(ref)

      case Map.get(plan_by_id, normalized) do
        nil ->
          acc

        target ->
          target_qn = Map.fetch!(plan_uri_by_id, target.id)
          add_obj(acc, source_qn, predicate, target_qn)
      end
    end)
  end

  defp add_package_relations(set, source_qn, package_refs, web_index, web_doc_uri_by_id, mode \\ :id_only) do
    Enum.reduce(package_refs, set, fn ref, acc ->
      target_qn =
        case mode do
          :id_only ->
            resolve_package_target_by_id(ref, web_doc_uri_by_id)

          :route_or_slug ->
            resolve_package_target_by_route_or_slug(ref, web_index, web_doc_uri_by_id)
        end

      if target_qn do
        add_obj(acc, source_qn, "ajc:referencesPackage", target_qn)
      else
        acc
      end
    end)
  end

  defp add_ecosystem_dependency_relations(set, %{kind: :ecosystem} = doc, doc_qn, web_by_id, web_doc_uri_by_id) do
    Enum.reduce(doc.ecosystem_packages, set, fn dep_id, acc ->
      candidate = "ecosystem:" <> dep_id

      case Map.get(web_by_id, normalize_identifier(candidate)) do
        nil ->
          acc

        dep_doc ->
          dep_qn = Map.fetch!(web_doc_uri_by_id, dep_doc.id)
          add_obj(acc, doc_qn, "ajc:dependsOnPackage", dep_qn)
      end
    end)
  end

  defp add_ecosystem_dependency_relations(set, _doc, _doc_qn, _web_by_id, _web_doc_uri_by_id), do: set

  defp maybe_link_plan_to_target(set, entry, web_by_route, web_doc_uri_by_id) do
    case Map.get(web_by_route, normalize_route(entry.destination_route || "")) do
      nil ->
        set

      doc ->
        doc_qn = Map.fetch!(web_doc_uri_by_id, doc.id)
        plan_qn = plan_qname(entry)
        add_obj(set, plan_qn, "ajc:isSourceFor", doc_qn)
    end
  end

  defp maybe_promote_to_generated(set, doc_qn) do
    add_obj(set, doc_qn, "a", "ajc:GeneratedPage")
  end

  defp add_legacy_routes(set, _doc_qn, []), do: set

  defp add_legacy_routes(set, doc_qn, legacy_routes) do
    Enum.reduce(legacy_routes, set, fn route, acc ->
      maybe_add_lit(acc, doc_qn, "ajc:legacyRoute", normalize_route(route))
    end)
  end

  defp maybe_add_doc_type(set, _doc_qn, nil), do: set

  defp maybe_add_doc_type(set, doc_qn, value) do
    concept = concept_qname("doc_type", value, "ajc:DocumentType")
    set |> maybe_add_concept(concept, to_string(value), "ajc:DocumentType") |> add_obj(doc_qn, "ajc:hasDocumentType", concept)
  end

  defp maybe_add_audience(set, _doc_qn, nil), do: set

  defp maybe_add_audience(set, doc_qn, value) do
    concept = concept_qname("audience", value, "ajc:AudienceLevel")
    set |> maybe_add_concept(concept, to_string(value), "ajc:AudienceLevel") |> add_obj(doc_qn, "ajc:hasAudienceLevel", concept)
  end

  defp maybe_add_journey_stage(set, _doc_qn, nil), do: set

  defp maybe_add_journey_stage(set, doc_qn, value) do
    concept = concept_qname("journey_stage", value, "ajc:JourneyStage")
    set |> maybe_add_concept(concept, to_string(value), "ajc:JourneyStage") |> add_obj(doc_qn, "ajc:hasJourneyStage", concept)
  end

  defp maybe_add_content_intent(set, _doc_qn, nil), do: set

  defp maybe_add_content_intent(set, doc_qn, value) do
    concept = concept_qname("content_intent", value, "ajc:ContentIntent")
    set |> maybe_add_concept(concept, to_string(value), "ajc:ContentIntent") |> add_obj(doc_qn, "ajc:hasContentIntent", concept)
  end

  defp maybe_add_capability_theme(set, _doc_qn, nil), do: set

  defp maybe_add_capability_theme(set, doc_qn, value) do
    concept = concept_qname("capability_theme", value, "ajc:CapabilityTheme")

    set
    |> maybe_add_concept(concept, to_string(value), "ajc:CapabilityTheme")
    |> add_obj(doc_qn, "ajc:hasCapabilityTheme", concept)
  end

  defp maybe_add_evidence_surface(set, _doc_qn, nil), do: set

  defp maybe_add_evidence_surface(set, doc_qn, value) do
    concept = concept_qname("evidence_surface", value, "ajc:EvidenceSurface")

    set
    |> maybe_add_concept(concept, to_string(value), "ajc:EvidenceSurface")
    |> add_obj(doc_qn, "ajc:hasEvidenceSurface", concept)
  end

  defp maybe_add_difficulty(set, _doc_qn, nil), do: set

  defp maybe_add_difficulty(set, doc_qn, value) do
    concept = concept_qname("difficulty", value, "ajc:DifficultyLevel")
    set |> maybe_add_concept(concept, to_string(value), "ajc:DifficultyLevel") |> add_obj(doc_qn, "ajc:hasDifficultyLevel", concept)
  end

  defp maybe_add_track(set, _doc_qn, nil), do: set

  defp maybe_add_track(set, doc_qn, value) do
    concept = concept_qname("track", value, "ajc:TrainingTrack")
    set |> maybe_add_concept(concept, to_string(value), "ajc:TrainingTrack") |> add_obj(doc_qn, "ajc:hasTrainingTrack", concept)
  end

  defp maybe_add_status(set, _plan_qn, nil), do: set

  defp maybe_add_status(set, plan_qn, value) do
    concept = concept_qname("status", value, "ajc:WorkflowStatus")
    set |> maybe_add_concept(concept, to_string(value), "ajc:WorkflowStatus") |> add_obj(plan_qn, "ajc:hasWorkflowStatus", concept)
  end

  defp maybe_add_priority(set, _plan_qn, nil), do: set

  defp maybe_add_priority(set, plan_qn, value) do
    concept = concept_qname("priority", value, "ajc:PriorityLevel")
    set |> maybe_add_concept(concept, to_string(value), "ajc:PriorityLevel") |> add_obj(plan_qn, "ajc:hasPriorityLevel", concept)
  end

  defp maybe_add_author(set, doc_qn, %{kind: :blog, author_name: author}) when is_binary(author) and author != "" do
    add_lit(set, doc_qn, "ajc:authorName", author)
  end

  defp maybe_add_author(set, _doc_qn, _doc), do: set

  defp maybe_add_published_on(set, doc_qn, %{kind: :blog, published_on: %Date{} = date}) do
    add_lit(set, doc_qn, "ajc:publishedOn", Date.to_iso8601(date), "xsd:date")
  end

  defp maybe_add_published_on(set, _doc_qn, _doc), do: set

  defp resolve_ref_target(ref, web_by_id, web_doc_uri_by_id, plan_by_id, plan_uri_by_id) do
    normalized = normalize_identifier(ref)

    cond do
      Map.has_key?(web_by_id, normalized) ->
        web = Map.fetch!(web_by_id, normalized)
        Map.fetch!(web_doc_uri_by_id, web.id)

      Map.has_key?(plan_by_id, normalized) ->
        plan = Map.fetch!(plan_by_id, normalized)
        Map.fetch!(plan_uri_by_id, plan.id)

      true ->
        route = normalize_route(ref)

        case find_web_by_route(route, web_by_id) do
          nil -> nil
          web -> Map.fetch!(web_doc_uri_by_id, web.id)
        end
    end
  end

  defp resolve_package_target_by_id(ref, web_doc_uri_by_id) do
    normalized = normalize_identifier(ref)

    variants =
      [normalized, String.replace(normalized, "-", "_"), String.replace(normalized, "_", "-")]
      |> Enum.uniq()

    Enum.find_value(variants, fn variant ->
      Map.get(web_doc_uri_by_id, "ecosystem:" <> variant)
    end)
  end

  defp resolve_package_target_by_route_or_slug(ref, web_by_route, web_doc_uri_by_id) do
    normalized = normalize_identifier(ref)
    by_id = Map.get(web_doc_uri_by_id, "ecosystem:" <> normalized)

    if by_id do
      by_id
    else
      route_candidates =
        [normalize_route(ref), "/ecosystem/#{normalized}", "/ecosystem/#{String.replace(normalized, "-", "_")}"]
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq()

      Enum.find_value(route_candidates, &package_target_qname(&1, web_by_route, web_doc_uri_by_id))
    end
  end

  defp find_web_by_route(nil, _web_by_id), do: nil

  defp find_web_by_route(route, web_by_id) do
    Enum.find_value(web_by_id, fn {_key, web} ->
      if normalize_route(web.route) == route, do: web
    end)
  end

  defp library_version_reference_qname(source_qn, target_doc_id, role, constraint) do
    "ajr:libref_#{safe_local("#{source_qn}|#{target_doc_id}|#{role}|#{constraint || ""}")}"
  end

  defp source_qname(source), do: "ajr:source_#{safe_local(source.path)}"
  defp plan_qname(entry), do: "ajr:plan_#{safe_local(entry.id)}"
  defp doc_qname(doc), do: "ajr:doc_#{safe_local(doc.id)}"
  defp tag_qname(label), do: "ajr:tag_#{safe_local(label)}"

  defp source_class_qname(:ContentPlanEntry), do: "ajc:ContentPlanEntry"
  defp source_class_qname(:LivebookSourceDocument), do: "ajc:LivebookSourceDocument"
  defp source_class_qname(_), do: "ajc:MarkdownSourceDocument"

  defp web_doc_class_qname(%{kind: :blog}), do: "ajc:BlogPost"
  defp web_doc_class_qname(%{kind: :ecosystem}), do: "ajc:EcosystemPackagePage"
  defp web_doc_class_qname(%{kind: :example}), do: "ajc:ExamplePage"
  defp web_doc_class_qname(_), do: "ajc:RenderedPage"

  defp category_qname(:docs), do: "ajc:category_docs"
  defp category_qname(:blog), do: "ajc:category_blog"
  defp category_qname(:ecosystem), do: "ajc:category_ecosystem"
  defp category_qname(:examples), do: "ajc:category_examples"
  defp category_qname(:features), do: "ajc:category_features"
  defp category_qname(:build), do: "ajc:category_build"
  defp category_qname(:community), do: "ajc:category_community"
  defp category_qname(:training), do: "ajc:category_training"
  defp category_qname(:content_plan), do: "ajc:category_content_plan"
  defp category_qname(_), do: "ajc:category_docs"

  defp collection_qname(:collection_priv_pages), do: "ajc:collection_priv_pages"
  defp collection_qname(:collection_priv_blog), do: "ajc:collection_priv_blog"
  defp collection_qname(:collection_priv_ecosystem), do: "ajc:collection_priv_ecosystem"
  defp collection_qname(:collection_priv_examples), do: "ajc:collection_priv_examples"
  defp collection_qname(:collection_priv_content_plan), do: "ajc:collection_priv_content_plan"
  defp collection_qname(_), do: "ajc:collection_priv_pages"

  defp concept_qname(prefix, value, _class_qname) do
    "ajc:#{prefix}_#{safe_token(to_string(value))}"
  end

  defp maybe_link_source_document(acc, _doc_qn, nil), do: acc

  defp maybe_link_source_document(acc, doc_qn, source_qn) do
    acc
    |> add_obj(doc_qn, "ajc:hasSourceDocument", source_qn)
    |> add_obj(source_qn, "ajc:isSourceFor", doc_qn)
  end

  defp link_plan_entry(inner, entry, plan_uri_by_id, doc_qn) do
    case Map.get(plan_uri_by_id, entry.id) do
      nil ->
        inner

      plan_qn ->
        inner
        |> maybe_promote_to_generated(doc_qn)
        |> add_obj(doc_qn, "ajc:generatedFromPlanEntry", plan_qn)
        |> add_obj(plan_qn, "ajc:isSourceFor", doc_qn)
    end
  end

  defp attach_doc_tag(inner, tag, doc_qn, source_qn) do
    tag_qn = tag_qname(tag)

    inner
    |> add_obj(doc_qn, "ajc:hasTag", tag_qn)
    |> add_obj(tag_qn, "ajc:tagsResource", doc_qn)
    |> maybe_attach_source_tag(source_qn, tag_qn)
  end

  defp maybe_attach_source_tag(inner, nil, _tag_qn), do: inner

  defp maybe_attach_source_tag(inner, source_qn, tag_qn) do
    inner
    |> add_obj(source_qn, "ajc:hasTag", tag_qn)
    |> add_obj(tag_qn, "ajc:tagsResource", source_qn)
  end

  defp package_target_qname(route, web_by_route, web_doc_uri_by_id) do
    case Map.get(web_by_route, route) do
      nil -> nil
      doc -> Map.get(web_doc_uri_by_id, doc.id)
    end
  end

  defp maybe_add_concept(set, qname, label, class_qname) do
    set
    |> add_obj(qname, "a", class_qname)
    |> add_lit(qname, "skos:prefLabel", label)
  end

  defp source_class_for_path(path) do
    if String.ends_with?(path, ".livemd"), do: :LivebookSourceDocument, else: :MarkdownSourceDocument
  end

  defp collection_from_path(path) when is_binary(path) do
    normalized = normalize_path(path)

    cond do
      String.starts_with?(normalized, "priv/pages/") -> :collection_priv_pages
      String.starts_with?(normalized, "priv/blog/") -> :collection_priv_blog
      String.starts_with?(normalized, "priv/ecosystem/") -> :collection_priv_ecosystem
      String.starts_with?(normalized, "priv/examples/") -> :collection_priv_examples
      String.starts_with?(normalized, "priv/content_plan/") -> :collection_priv_content_plan
      true -> :collection_priv_pages
    end
  end

  defp normalize_tags(tags) do
    tags
    |> List.wrap()
    |> Enum.map(&to_string/1)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp normalize_ref_list(list) do
    list
    |> List.wrap()
    |> Enum.map(&to_string/1)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end

  defp validation_package_versions(validation) do
    validation
    |> map_value(:min_package_versions, [])
    |> normalize_package_version_requirements()
  end

  defp normalize_package_version_requirements(raw) do
    raw
    |> package_version_requirement_entries()
    |> Enum.reduce(%{}, fn entry, acc ->
      case normalize_package_version_requirement(entry) do
        nil ->
          acc

        {package_id, constraint} ->
          Map.put(acc, package_id, constraint)
      end
    end)
  end

  defp package_version_requirement_entries(raw) when is_list(raw), do: raw

  defp package_version_requirement_entries(raw) when is_map(raw) do
    if requirement_entry_map?(raw), do: [raw], else: Map.to_list(raw)
  end

  defp package_version_requirement_entries(_raw), do: []

  defp normalize_package_version_requirement({package_ref, constraint}) do
    normalize_package_version_requirement_pair(package_ref, constraint)
  end

  defp normalize_package_version_requirement(entry) when is_map(entry) do
    package_ref = requirement_package_ref(entry)
    constraint = requirement_constraint(entry)

    cond do
      package_ref ->
        normalize_package_version_requirement_pair(package_ref, constraint)

      map_size(entry) == 1 ->
        [{k, v}] = Map.to_list(entry)
        normalize_package_version_requirement_pair(k, v)

      true ->
        nil
    end
  end

  defp normalize_package_version_requirement(_entry), do: nil

  defp normalize_package_version_requirement_pair(package_ref, constraint) do
    package_id =
      case normalize_optional(package_ref) do
        nil -> nil
        value -> normalize_identifier(value)
      end

    if package_id in [nil, ""] do
      nil
    else
      {package_id, normalize_optional(constraint)}
    end
  end

  defp requirement_entry_map?(map) when is_map(map) do
    map
    |> Map.keys()
    |> Enum.map(&to_string/1)
    |> Enum.any?(fn key ->
      key in ["package", "package_id", "id", "name", "library"]
    end)
  end

  defp normalize_identifier(value) do
    value
    |> to_string()
    |> String.trim()
    |> String.downcase()
    |> String.replace(~r/\s+/, "")
  end

  defp normalize_optional(nil), do: nil

  defp normalize_optional(value) do
    value
    |> to_string()
    |> String.trim()
    |> case do
      "" -> nil
      other -> other
    end
  end

  defp normalize_path(path) when is_binary(path) do
    cwd = File.cwd!()

    path
    |> Path.expand()
    |> Path.relative_to(cwd)
    |> case do
      relative ->
        if String.starts_with?(relative, "../") do
          path
        else
          relative
        end
    end
  end

  defp normalize_path(path), do: to_string(path)

  defp normalize_route(value) when is_binary(value) do
    trimmed = String.trim(value)

    cond do
      trimmed == "" ->
        nil

      String.starts_with?(trimmed, "#") ->
        nil

      true ->
        trimmed
        |> route_path_from_uri()
        |> normalize_route_path()
    end
  end

  defp normalize_route(_), do: nil

  defp github_url_for(path) when is_binary(path) do
    relative = normalize_path(path)

    if String.starts_with?(relative, "priv/") or String.starts_with?(relative, "lib/") do
      @repo_base <> relative
    else
      nil
    end
  end

  defp github_url_for(_), do: nil

  defp extract_internal_routes(nil), do: []

  defp extract_internal_routes(html) when is_binary(html) do
    case Floki.parse_fragment(html) do
      {:ok, nodes} ->
        nodes
        |> Floki.find("a[href]")
        |> Enum.map(&extract_href/1)
        |> Enum.map(&normalize_internal_href/1)
        |> Enum.reject(&is_nil/1)

      {:error, _reason} ->
        []
    end
  end

  defp extract_internal_routes(_), do: []

  defp requirement_package_ref(entry) do
    map_value(entry, :package) ||
      map_value(entry, :package_id) ||
      map_value(entry, :id) ||
      map_value(entry, :name) ||
      map_value(entry, :library)
  end

  defp requirement_constraint(entry) do
    map_value(entry, :version) ||
      map_value(entry, :constraint) ||
      map_value(entry, :requirement) ||
      map_value(entry, :min_version)
  end

  defp route_path_from_uri(trimmed) do
    case URI.parse(trimmed) do
      %URI{path: nil} -> trimmed
      %URI{path: path} -> path
    end
  end

  defp normalize_route_path(route) do
    route
    |> String.replace(~r/[?#].*$/, "")
    |> case do
      "" -> "/"
      "/" = root -> root
      path -> ensure_leading_slash(String.trim_trailing(path, "/"))
    end
  end

  defp ensure_leading_slash("/" <> _ = path), do: path
  defp ensure_leading_slash(path), do: "/" <> path

  defp extract_href({_tag, attrs, _children}) do
    Enum.find_value(attrs, fn
      {"href", href} -> href
      _ -> nil
    end)
  end

  defp normalize_internal_href(nil), do: nil

  defp normalize_internal_href(href) when is_binary(href) do
    uri = URI.parse(String.trim(href))

    cond do
      uri.scheme in [nil, ""] ->
        normalize_route(href)

      is_binary(uri.host) and String.downcase(uri.host) in internal_hosts() ->
        normalize_route(href)

      true ->
        nil
    end
  end

  defp integer_literal(nil), do: nil
  defp integer_literal(value) when is_integer(value), do: Integer.to_string(value)
  defp integer_literal(value), do: value |> to_string() |> String.trim()

  defp to_bool_string(nil), do: nil
  defp to_bool_string(value) when is_boolean(value), do: to_string(value)
  defp to_bool_string(value), do: value |> to_string() |> String.trim()

  defp current_git_commit do
    case System.cmd("git", ["rev-parse", "HEAD"], stderr_to_stdout: true) do
      {hash, 0} ->
        hash
        |> String.trim()
        |> case do
          "" -> nil
          value -> value
        end

      _other ->
        nil
    end
  rescue
    _ -> nil
  end

  defp internal_hosts do
    (@default_internal_hosts ++ AgentJido.Site.internal_hosts())
    |> Enum.uniq()
  end

  defp ontology_import_iri, do: canonical_origin() <> "/ontology/content#"
  defp ontology_prefix_iri, do: canonical_origin() <> "/ontology/content#"
  defp resource_prefix_iri, do: canonical_origin() <> "/resource/content/"
  defp canonical_origin, do: "https://" <> AgentJido.Site.canonical_host()

  defp safe_local(value) do
    text = to_string(value)
    short = String.slice(sha256_hex(text), 0, 8)

    base = safe_token(text)

    if base == "", do: "id_#{short}", else: "#{base}_#{short}"
  end

  defp safe_token(value) do
    value
    |> to_string()
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/u, "_")
    |> String.trim("_")
  end

  defp sha256_hex(parts) when is_list(parts) do
    parts
    |> Enum.map_join("|", &to_string/1)
    |> sha256_hex()
  end

  defp sha256_hex(value) when is_binary(value) do
    :crypto.hash(:sha256, value)
    |> Base.encode16(case: :lower)
  end

  defp map_value(map, key, default \\ nil)

  defp map_value(map, key, default) when is_map(map) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key)) || default
  end

  defp map_value(_map, _key, default), do: default

  defp maybe_add_lit(set, subject, predicate, literal, type \\ nil)
  defp maybe_add_lit(set, _subject, _predicate, nil, _type), do: set

  defp maybe_add_lit(set, subject, predicate, literal, type) do
    add_lit(set, subject, predicate, literal, type)
  end

  defp maybe_add_obj(set, _subject, _predicate, nil), do: set

  defp maybe_add_obj(set, subject, predicate, object) do
    add_obj(set, subject, predicate, object)
  end

  defp add_obj(set, subject, predicate, object) do
    MapSet.put(set, {:obj, subject, predicate, object})
  end

  defp add_lit(set, subject, predicate, literal, datatype \\ nil) do
    MapSet.put(set, {:lit, subject, predicate, literal, datatype})
  end

  defp triple_sort_key({:obj, s, p, o}), do: "#{s}|#{p}|#{o}|obj"
  defp triple_sort_key({:lit, s, p, l, d}), do: "#{s}|#{p}|#{l}|#{d}|lit"

  defp render_triple({:obj, subject, predicate, object}) do
    "#{subject} #{predicate} #{object} .\n"
  end

  defp render_triple({:lit, subject, predicate, literal, nil}) do
    "#{subject} #{predicate} #{render_literal(literal)} .\n"
  end

  defp render_triple({:lit, subject, predicate, literal, datatype}) do
    "#{subject} #{predicate} #{render_literal(literal)}^^#{datatype} .\n"
  end

  defp render_literal(value) do
    escaped =
      value
      |> to_string()
      |> String.replace("\\", "\\\\")
      |> String.replace("\"", "\\\"")
      |> String.replace("\n", "\\n")
      |> String.replace("\r", "\\r")

    "\"#{escaped}\""
  end
end
