defmodule AgentJido.ContentAssistant.Retrieval do
  @moduledoc """
  Arcana-backed retrieval context for content assistant citations.
  """

  import Ecto.Query

  alias AgentJido.Blog
  alias AgentJido.ContentAssistant.Result
  alias AgentJido.ContentAssistant.URL
  alias AgentJido.Ecosystem
  alias AgentJido.Examples
  alias AgentJido.Examples.Taxonomy
  alias AgentJido.Pages
  alias AgentJido.UpstreamSkillCatalog
  alias Arcana.Collection
  alias Arcana.Document

  @default_limit 10
  @default_mode :hybrid
  @collections ["site_docs", "site_blog", "site_ecosystem", "site_ecosystem_docs", "site_examples", "site_skills"]
  @snippet_max_length 320
  @disabled_route_prefixes ["/training", "/search"]
  @broad_package_phrases [
    "what is",
    "compare",
    " vs ",
    " versus ",
    "which package",
    "when should i use",
    "should i use",
    "difference between",
    "overview"
  ]
  @example_intent_terms ["example", "examples", "demo", "walkthrough", "sample"]
  @skill_intent_terms ["skill", "skills"]
  @api_intent_terms [
    "module",
    "function",
    "callback",
    "config",
    "configure",
    "how to",
    "how do i",
    "error",
    "undefined",
    "setup",
    "install",
    "usage",
    "guide"
  ]

  @type query_status :: :success | :fallback
  @type search_fun :: (String.t(), keyword() -> {:ok, [map()]} | {:error, term()})
  @type document_lookup_fun :: ([map()], module() -> %{optional(String.t()) => map()})
  @type fallback_fun :: (String.t(), keyword() -> [Result.t()])

  @doc """
  Searches Arcana across docs/blog/ecosystem collections.

  Returns normalized `t:Result.t/0` entries and always falls back to `{:ok, []}`
  on Arcana backend failures.

  ## Options

    * `:repo` - Ecto repo (defaults to `AgentJido.Repo`)
    * `:limit` - Maximum result count (default: 10)
    * `:mode` - Arcana search mode (default: `:hybrid`)
    * `:collections` - Collections to target (default: docs/blog/ecosystem)
    * `:search_fun` - Injected Arcana search function for testing
    * `:document_lookup_fun` - Injected metadata lookup function for testing
    * `:fallback_fun` - Injected local fallback function for backend failure scenarios

  """
  @spec query(String.t(), keyword()) :: {:ok, [Result.t()]}
  def query(query, opts \\ []) do
    case query_with_status(query, opts) do
      {:ok, results, _status} -> {:ok, results}
    end
  end

  @doc """
  Searches Arcana and returns normalized results with backend fallback status.
  """
  @spec query_with_status(String.t(), keyword()) :: {:ok, [Result.t()], query_status}
  def query_with_status(query, opts \\ [])

  def query_with_status(query, opts) when is_binary(query) do
    query = String.trim(query)

    if query == "" do
      {:ok, [], :success}
    else
      run_query(query, opts)
    end
  end

  def query_with_status(_query, _opts), do: {:ok, [], :success}

  defp run_query(query, opts) do
    repo = Keyword.get(opts, :repo, AgentJido.Repo)
    mode = Keyword.get(opts, :mode, @default_mode)
    limit = normalize_limit(Keyword.get(opts, :limit, @default_limit))
    collections = Keyword.get(opts, :collections, @collections)
    search_fun = Keyword.get(opts, :search_fun, &Arcana.search/2)
    document_lookup_fun = Keyword.get(opts, :document_lookup_fun, &fetch_document_index/2)
    fallback_fun = Keyword.get(opts, :fallback_fun, &local_fallback_query/2)

    search_opts =
      [repo: repo, collections: collections, limit: limit, mode: mode]
      |> maybe_put_graph_opt(opts)

    try do
      case safe_search(search_fun, query, search_opts) do
        {:ok, rows} when is_list(rows) ->
          docs_by_id = safe_document_lookup(document_lookup_fun, rows, repo)

          normalized_results =
            rows
            |> normalize_results(docs_by_id)
            |> rerank_results(query)

          primary_results = filter_disabled_results(normalized_results, limit)

          cond do
            primary_results != [] ->
              {:ok, primary_results, :success}

            # Backend returned rows but all normalized results were retired routes
            # (for example /training). In this case, try fallback before returning empty.
            normalized_results != [] ->
              fallback_response(fallback_fun, query, limit)

            true ->
              {:ok, [], :success}
          end

        _other ->
          fallback_response(fallback_fun, query, limit)
      end
    rescue
      _ -> fallback_response(fallback_fun, query, limit)
    end
  end

  defp fallback_response(fallback_fun, query, limit) do
    fallback_results =
      safe_fallback_search(fallback_fun, query, limit)
      |> rerank_results(query)
      |> filter_disabled_results(limit)

    {:ok, fallback_results, :fallback}
  end

  @doc """
  Default Arcana collections used for site-wide search.
  """
  @spec collections() :: [String.t()]
  def collections, do: @collections

  @doc """
  Returns suggested nearby queries for no-results experiences.
  """
  @spec suggest_related_queries(String.t(), keyword()) :: [String.t()]
  def suggest_related_queries(query, opts \\ [])

  def suggest_related_queries(query, opts) when is_binary(query) and is_list(opts) do
    terms = tokenize_query(query)

    if terms == [] do
      []
    else
      limit =
        case Keyword.get(opts, :suggestion_limit, 4) do
          value when is_integer(value) and value > 0 -> value
          _ -> 4
        end

      query_downcase = String.downcase(String.trim(query))

      docs_candidates =
        Pages.all_pages()
        |> Enum.reject(&(&1.category == :training))
        |> Enum.map(&normalize_string(&1.title))
        |> Enum.filter(&is_binary/1)

      blog_candidates =
        Blog.all_posts()
        |> Enum.map(&normalize_string(&1.title))
        |> Enum.filter(&is_binary/1)

      (docs_candidates ++ blog_candidates)
      |> Enum.uniq()
      |> Enum.map(fn candidate ->
        score = lexical_score(candidate, candidate, terms, query_downcase)
        {candidate, score}
      end)
      |> Enum.filter(fn {_candidate, score} -> score > 0 end)
      |> Enum.sort_by(fn {candidate, score} -> {-score, candidate} end)
      |> Enum.map(&elem(&1, 0))
      |> Enum.take(limit)
    end
  rescue
    _ -> []
  end

  def suggest_related_queries(_query, _opts), do: []

  defp safe_search(search_fun, query, opts) do
    search_fun.(query, opts)
  rescue
    _ -> {:error, :search_failed}
  catch
    _, _ -> {:error, :search_failed}
  end

  defp safe_document_lookup(document_lookup_fun, rows, repo) do
    document_lookup_fun.(rows, repo)
  rescue
    _ -> %{}
  catch
    _, _ -> %{}
  end

  defp safe_fallback_search(fallback_fun, query, limit) do
    fallback_fun.(query, limit: limit)
    |> normalize_fallback_results()
  rescue
    _ -> []
  catch
    _, _ -> []
  end

  # Filters the fallback function's output to valid results without truncating.
  # `fallback_response` reranks (intent boosts can reorder results) and then
  # applies the result limit, so truncating here by raw lexical score would
  # drop low-raw-score-but-high-intent matches before reranking.
  defp normalize_fallback_results(results) when is_list(results) do
    Enum.filter(results, &match?(%Result{}, &1))
  end

  defp normalize_fallback_results(_results), do: []

  defp maybe_put_graph_opt(search_opts, retrieval_opts)
       when is_list(search_opts) and is_list(retrieval_opts) do
    if Keyword.has_key?(retrieval_opts, :graph) do
      Keyword.put(search_opts, :graph, Keyword.get(retrieval_opts, :graph))
    else
      search_opts
    end
  end

  defp maybe_put_graph_opt(search_opts, _retrieval_opts), do: search_opts

  defp local_fallback_query(query, _opts) do
    terms = tokenize_query(query)

    if terms == [] do
      []
    else
      query_downcase = String.downcase(query)

      page_results =
        Pages.all_pages()
        |> Enum.reject(&(&1.category == :training))
        |> Enum.map(&build_page_fallback_result(&1, terms, query_downcase))

      blog_results =
        Blog.all_posts()
        |> Enum.map(&build_blog_fallback_result(&1, terms, query_downcase))

      ecosystem_results =
        Ecosystem.public_packages()
        |> Enum.map(&build_ecosystem_fallback_result(&1, terms, query_downcase))

      example_results =
        Examples.all_examples()
        |> Enum.map(&build_example_fallback_result(&1, terms, query_downcase))

      skill_results =
        UpstreamSkillCatalog.package_entries()
        |> Enum.map(&build_skill_fallback_result(&1, terms, query_downcase))

      # Return every scored, non-disabled candidate. The caller
      # (`fallback_response`) reranks (intent boosts can reorder results) and
      # then applies the result limit, so truncating here by raw lexical score
      # would cut low-raw-score-but-high-intent matches (e.g. an example for an
      # "<topic> example" query) before reranking ever sees them.
      (page_results ++ blog_results ++ ecosystem_results ++ example_results ++ skill_results)
      |> Enum.reject(&is_nil/1)
      |> Enum.sort_by(&(&1.score || 0.0), :desc)
      |> Enum.reject(&disabled_result?/1)
    end
  end

  defp filter_disabled_results(results, limit) when is_list(results) do
    results
    |> Enum.reject(&disabled_result?/1)
    |> Enum.take(limit)
  end

  defp filter_disabled_results(_results, _limit), do: []

  defp disabled_result?(%Result{url: url}) when is_binary(url), do: disabled_path?(url)
  defp disabled_result?(_result), do: false

  defp disabled_path?(url) when is_binary(url) do
    case URI.parse(url).path do
      nil ->
        false

      path when is_binary(path) ->
        Enum.any?(@disabled_route_prefixes, fn prefix ->
          path == prefix or String.starts_with?(path, prefix <> "/")
        end)
    end
  end

  defp build_page_fallback_result(page, terms, query_downcase) do
    title = normalize_string(page.title) || default_title(:docs)
    description = normalize_string(page.description)
    body_text = strip_html(page.body)
    searchable_text = join_searchable_text([description, body_text])
    score = lexical_score(title, searchable_text, terms, query_downcase)

    if score > 0 do
      snippet_source =
        case description do
          nil -> body_text
          description_text -> description_text <> " " <> body_text
        end

      %Result{
        title: title,
        snippet: snippet_for(snippet_source, query_downcase),
        url: URL.normalize_href(Pages.route_for(page)) || "/",
        source_type: :docs,
        score: score
      }
    end
  end

  defp build_blog_fallback_result(post, terms, query_downcase) do
    title = normalize_string(post.title) || default_title(:blog)
    description = normalize_string(post.description)
    body_text = strip_html(post.body)
    searchable_text = join_searchable_text([description, body_text, Enum.join(post.tags || [], " ")])
    score = lexical_score(title, searchable_text, terms, query_downcase)

    if score > 0 do
      snippet_source =
        case description do
          nil -> body_text
          description_text -> description_text <> " " <> body_text
        end

      %Result{
        title: title,
        snippet: snippet_for(snippet_source, query_downcase),
        url: URL.normalize_href("/blog/#{post.id}") || "/",
        source_type: :blog,
        score: score
      }
    end
  end

  defp build_ecosystem_fallback_result(package, terms, query_downcase) do
    title = normalize_string(package.title || package.name) || default_title(:ecosystem)
    description = normalize_string(package.description || package.tagline)
    body_text = strip_html(package.body)

    features =
      package.key_features
      |> List.wrap()
      |> Enum.join(" ")

    searchable_text = join_searchable_text([description, features, body_text, package.id, package.name])
    score = lexical_score(title, searchable_text, terms, query_downcase)

    if score > 0 do
      snippet_source =
        case description do
          nil -> body_text
          description_text -> description_text <> " " <> body_text
        end

      %Result{
        title: title,
        snippet: snippet_for(snippet_source, query_downcase),
        url: URL.normalize_href("/ecosystem/#{package.id}") || "/",
        source_type: :ecosystem,
        score: score
      }
    end
  end

  defp build_example_fallback_result(example, terms, query_downcase) do
    title = normalize_string(example.title) || default_title(:examples)
    description = normalize_string(example.description)
    outcome = normalize_string(example.outcome)
    body_text = strip_html(example.body)
    tags = Enum.join(example.tags || [], " ")
    packages = Enum.join(List.wrap(example.packages), " ")

    tasks =
      example.tags
      |> Taxonomy.tasks_for()
      |> Enum.map_join(" ", fn task ->
        task |> Atom.to_string() |> String.replace("_", " ")
      end)

    # Rank examples on their identity + curated topic fields (title, slug,
    # tags, tasks, description, outcome, packages). The rendered body is prose
    # and source code where the word "example" is ubiquitous; scoring against
    # it lets a generic term drown out the discriminating topic term (the
    # slug), so a "<topic> example" query ranks the wrong example. The body
    # still feeds the snippet below.
    searchable_text =
      join_searchable_text([example.slug, tags, tasks, description, outcome, packages])

    score = lexical_score(title, searchable_text, terms, query_downcase)

    if score > 0 do
      snippet_source =
        case description do
          nil -> join_searchable_text([outcome, body_text])
          description_text -> description_text <> " " <> join_searchable_text([outcome, body_text])
        end

      %Result{
        title: title,
        snippet: snippet_for(snippet_source, query_downcase),
        url: URL.normalize_href("/examples/#{example.slug}") || "/",
        source_type: :examples,
        score: score
      }
    end
  end

  defp build_skill_fallback_result(entry, terms, query_downcase) do
    title = normalize_string(entry.title || entry.name) || default_title(:skills)
    description = normalize_string(entry.description)

    # Rank skills on identity + discriminating fields (title, name, ecosystem
    # package id, description). A package skill query ("<package> skill") should
    # surface the matching card, and the package id is the most discriminating
    # term for that intent.
    searchable_text =
      join_searchable_text([entry.title, entry.name, entry.ecosystem_package_id, description])

    score = lexical_score(title, searchable_text, terms, query_downcase)

    if score > 0 do
      %Result{
        title: title,
        snippet: snippet_for(description || title, query_downcase),
        url: URL.normalize_href(skill_card_url(entry.id)) || "/",
        source_type: :skills,
        score: score
      }
    end
  end

  # The package skills catalog renders one card per skill at /skills. Anchor a
  # result to the card's DOM id so a hit lands on the matching skill (jido-e10
  # E10-T03).
  defp skill_card_url(skill_id), do: "/skills#skill-card-#{skill_id}"

  defp tokenize_query(query) when is_binary(query) do
    query
    |> String.downcase()
    |> String.split(~r/[^[:alnum:]_]+/u, trim: true)
    |> Enum.uniq()
  end

  defp tokenize_query(_query), do: []

  defp join_searchable_text(parts) do
    parts
    |> Enum.filter(&is_binary/1)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join(" ")
  end

  defp lexical_score(title, searchable_text, terms, query_downcase) do
    title_down = String.downcase(title || "")
    text_down = String.downcase(searchable_text || "")

    phrase_title_bonus = if query_downcase != "" and String.contains?(title_down, query_downcase), do: 6.0, else: 0.0
    phrase_text_bonus = if query_downcase != "" and String.contains?(text_down, query_downcase), do: 3.0, else: 0.0

    term_bonus =
      Enum.reduce(terms, 0.0, fn term, acc ->
        title_hits = count_occurrences(title_down, term) * 2
        text_hits = count_occurrences(text_down, term)
        acc + title_hits + text_hits
      end)

    phrase_title_bonus + phrase_text_bonus + term_bonus
  end

  defp count_occurrences(_text, term) when term in [nil, ""], do: 0

  defp count_occurrences(text, term) when is_binary(text) do
    text
    |> String.split(term)
    |> length()
    |> Kernel.-(1)
    |> max(0)
  end

  defp snippet_for(nil, _query_downcase), do: ""

  defp snippet_for(text, query_downcase) when is_binary(text) do
    clean_text =
      text
      |> strip_html()
      |> normalize_string()
      |> case do
        nil -> ""
        normalized -> normalized
      end

    if clean_text == "" do
      ""
    else
      downcase_text = String.downcase(clean_text)

      excerpt =
        case :binary.match(downcase_text, query_downcase) do
          {match_index, _match_len} when is_integer(match_index) ->
            start_index = max(match_index - 90, 0)
            String.slice(clean_text, start_index, 240)

          :nomatch ->
            String.slice(clean_text, 0, 240)
        end

      trim_snippet(excerpt, @snippet_max_length)
    end
  end

  defp strip_html(text) when is_binary(text) do
    text
    |> String.replace(~r/<[^>]*>/u, " ")
    |> String.replace(~r/\s+/u, " ")
    |> String.trim()
  end

  defp strip_html(_text), do: ""

  defp fetch_document_index(rows, repo) do
    document_ids =
      rows
      |> Enum.map(&value(&1, :document_id))
      |> Enum.map(&normalize_uuid/1)
      |> Enum.filter(&is_binary/1)
      |> Enum.uniq()

    if document_ids == [] do
      %{}
    else
      query =
        from(d in Document,
          left_join: c in Collection,
          on: c.id == d.collection_id,
          where: d.id in ^document_ids,
          select: %{
            id: d.id,
            source_id: d.source_id,
            collection: c.name,
            metadata: d.metadata
          }
        )

      repo
      |> then(& &1.all(query))
      |> Map.new(&{&1.id, &1})
    end
  end

  defp normalize_results(rows, docs_by_id) when is_map(docs_by_id) do
    Enum.map(rows, &normalize_result(&1, docs_by_id))
  end

  defp normalize_results(rows, _docs_by_id), do: Enum.map(rows, &normalize_result(&1, %{}))

  defp normalize_result(row, docs_by_id) do
    raw_document_id = value(row, :document_id)

    normalized_document_id =
      row
      |> value(:document_id)
      |> normalize_uuid()

    doc = document_for_row(docs_by_id, raw_document_id, normalized_document_id)
    row_metadata = value(row, :metadata, %{}) |> normalize_metadata()
    doc_metadata = value(doc, :metadata, %{}) |> normalize_metadata()
    metadata = Map.merge(row_metadata, doc_metadata)
    collection = value(doc, :collection)
    source_id = value(doc, :source_id)
    source_type = resolve_source_type(collection, metadata)

    %Result{
      title: resolve_title(metadata, source_type),
      snippet: resolve_snippet(row, metadata),
      url: resolve_url(row, collection, metadata, source_id, source_type),
      source_type: source_type,
      score: resolve_score(value(row, :score)),
      external?: resolve_external?(source_type, metadata),
      provider: resolve_provider(source_type, metadata),
      package_id: string_value(metadata, :package_id),
      package_name: string_value(metadata, :package_name),
      package_title: string_value(metadata, :package_title),
      package_version: string_value(metadata, :package_version),
      page_kind: resolve_page_kind(metadata),
      secondary_url: resolve_secondary_url(source_type, metadata)
    }
  end

  defp document_for_row(docs_by_id, raw_document_id, normalized_document_id) when is_map(docs_by_id) do
    cond do
      is_binary(normalized_document_id) and Map.has_key?(docs_by_id, normalized_document_id) ->
        Map.get(docs_by_id, normalized_document_id, %{})

      Map.has_key?(docs_by_id, raw_document_id) ->
        Map.get(docs_by_id, raw_document_id, %{})

      true ->
        %{}
    end
  end

  defp document_for_row(_docs_by_id, _raw_document_id, _normalized_document_id), do: %{}

  defp resolve_title(metadata, source_type) do
    string_value(metadata, :title) ||
      string_value(metadata, :name) ||
      string_value(metadata, :id) ||
      default_title(source_type)
  end

  defp resolve_snippet(row, metadata) do
    row
    |> value(:text)
    |> normalize_string()
    |> case do
      nil -> string_value(metadata, :description) || string_value(metadata, :tagline) || ""
      text -> text
    end
    |> trim_snippet(@snippet_max_length)
  end

  defp resolve_url(row, collection, metadata, source_id, :ecosystem_docs) do
    normalize_any_url(string_value(metadata, :outbound_url)) ||
      normalize_any_url(string_value(metadata, :crawl_url)) ||
      resolve_url(row, collection, metadata, source_id, :docs)
  end

  defp resolve_url(row, collection, metadata, source_id, _source_type) do
    canonical_route(collection, metadata, source_id) ||
      normalize_internal_url(string_value(metadata, :url)) ||
      row_text_route(row) ||
      "/"
  end

  defp resolve_source_type(collection, metadata) do
    case normalize_collection(collection) do
      "site_docs" -> :docs
      "site_blog" -> :blog
      "site_ecosystem" -> :ecosystem
      "site_ecosystem_docs" -> :ecosystem_docs
      "site_examples" -> :examples
      "site_skills" -> :skills
      _ -> resolve_source_type_from_metadata(metadata)
    end
  end

  defp resolve_source_type_from_metadata(metadata) do
    case string_value(metadata, :source_type) do
      "documentation" -> :docs
      "docs" -> :docs
      "blog" -> :blog
      "ecosystem" -> :ecosystem
      "ecosystem_docs" -> :ecosystem_docs
      "examples" -> :examples
      "skills" -> :skills
      _ -> :docs
    end
  end

  defp canonical_route(collection, metadata, source_id) do
    case normalize_collection(collection) do
      "site_docs" -> normalize_internal_url(string_value(metadata, :path)) || docs_route_from_source_id(source_id)
      "site_blog" -> route_from_collection_id(metadata, source_id, "blog:", "/blog/")
      "site_ecosystem" -> route_from_collection_id(metadata, source_id, "ecosystem:", "/ecosystem/")
      "site_examples" -> route_from_collection_id(metadata, source_id, "examples:", "/examples/")
      "site_skills" -> skills_route(metadata, source_id)
      _other -> nil
    end
  end

  # Package skills live on a single /skills catalog page, one card per skill.
  # Anchor the route to the matching card's DOM id (jido-e10 E10-T03).
  defp skills_route(metadata, source_id) do
    case string_value(metadata, :id) || source_id_suffix(source_id, "skills:") do
      nil -> nil
      id -> normalize_internal_url("/skills#skill-card-#{id}")
    end
  end

  defp docs_route_from_source_id(source_id) do
    source_id
    |> source_id_suffix("docs:")
    |> case do
      nil ->
        nil

      suffix ->
        normalized =
          if String.starts_with?(suffix, "/") do
            suffix
          else
            "/" <> suffix
          end

        normalize_internal_url(normalized)
    end
  end

  defp row_text_route(row) do
    row
    |> value(:text)
    |> extract_route_from_text()
  end

  defp extract_route_from_text(text) when is_binary(text) do
    text
    |> String.split(~r/\R/u, trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.find_value(&normalize_internal_url/1)
  end

  defp extract_route_from_text(_text), do: nil

  defp normalize_internal_url(nil), do: nil

  defp normalize_internal_url(url) when is_binary(url) do
    candidate = String.trim(url)

    cond do
      candidate == "" ->
        nil

      String.starts_with?(candidate, "/") ->
        normalize_path(candidate)

      true ->
        normalize_internal_http_url(candidate)
    end
  end

  defp normalize_internal_url(_url), do: nil

  defp normalize_any_url(nil), do: nil
  defp normalize_any_url(url), do: URL.normalize_href(url)

  defp route_from_collection_id(metadata, source_id, prefix, route_prefix) do
    case string_value(metadata, :id) || source_id_suffix(source_id, prefix) do
      nil -> nil
      id -> normalize_internal_url(route_prefix <> id)
    end
  end

  defp normalize_internal_http_url(candidate) do
    case URI.parse(candidate) do
      %URI{scheme: scheme, host: host, path: path, query: query, fragment: fragment}
      when scheme in ["http", "https"] and is_binary(path) and is_binary(host) ->
        if internal_host?(host), do: normalize_path_with_parts(path, query, fragment)

      _other ->
        nil
    end
  end

  defp normalize_path(path) when is_binary(path) do
    case URI.parse(path) do
      %URI{path: parsed_path, query: query, fragment: fragment} when is_binary(parsed_path) ->
        normalize_path_with_parts(parsed_path, query, fragment)

      _ ->
        nil
    end
  end

  defp normalize_path(_path), do: nil

  defp normalize_path_with_parts(path, query, fragment) when is_binary(path) do
    normalized_path =
      path
      |> String.trim()
      |> case do
        "" -> "/"
        "/" <> _ = absolute -> absolute
        relative -> "/" <> relative
      end

    query_part = if is_binary(query) and query != "", do: "?" <> query, else: ""
    fragment_part = if is_binary(fragment) and fragment != "", do: "#" <> fragment, else: ""

    normalized_path <> query_part <> fragment_part
  end

  defp normalize_path_with_parts(_path, _query, _fragment), do: nil

  defp internal_host?(host) when is_binary(host) do
    host_down = String.downcase(host)

    host_down in AgentJido.Site.internal_hosts()
  end

  defp internal_host?(_host), do: false

  defp source_id_suffix(source_id, prefix) when is_binary(source_id) and is_binary(prefix) do
    if String.starts_with?(source_id, prefix) do
      source_id
      |> String.replace_prefix(prefix, "")
      |> normalize_string()
    else
      nil
    end
  end

  defp source_id_suffix(_source_id, _prefix), do: nil

  defp default_title(:docs), do: "Documentation"
  defp default_title(:blog), do: "Blog"
  defp default_title(:ecosystem), do: "Ecosystem"
  defp default_title(:ecosystem_docs), do: "HexDocs"
  defp default_title(:examples), do: "Example"
  defp default_title(:skills), do: "Skill"

  defp normalize_collection(value) when is_binary(value), do: String.trim(value)
  defp normalize_collection(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize_collection(_value), do: nil

  defp normalize_uuid(value) when is_binary(value) do
    case Ecto.UUID.cast(value) do
      {:ok, uuid} ->
        uuid

      :error ->
        case Ecto.UUID.load(value) do
          {:ok, uuid} -> uuid
          :error -> nil
        end
    end
  end

  defp normalize_uuid(_value), do: nil

  defp normalize_metadata(metadata) when is_map(metadata), do: metadata
  defp normalize_metadata(_metadata), do: %{}

  defp resolve_external?(:ecosystem_docs, _metadata), do: true
  defp resolve_external?(_source_type, metadata), do: truthy?(value(metadata, :external?))

  defp resolve_provider(:ecosystem_docs, metadata) do
    case string_value(metadata, :provider) do
      nil -> :hexdocs
      provider -> provider
    end
  end

  defp resolve_provider(_source_type, metadata), do: string_value(metadata, :provider)

  defp resolve_page_kind(metadata) do
    case string_value(metadata, :page_kind) do
      "module" -> :module
      "guide" -> :guide
      "readme" -> :readme
      "task" -> :task
      _other -> nil
    end
  end

  defp resolve_secondary_url(:ecosystem_docs, metadata) do
    normalize_internal_url(string_value(metadata, :package_url))
  end

  defp resolve_secondary_url(_source_type, _metadata), do: nil

  defp resolve_score(score) when is_integer(score), do: score * 1.0
  defp resolve_score(score) when is_float(score), do: score
  defp resolve_score(_score), do: nil

  defp score_value(score) when is_number(score), do: score * 1.0
  defp score_value(_score), do: 0.0

  defp rerank_results(results, query) when is_list(results) and is_binary(query) do
    broad_package_query? = broad_package_query?(query)
    api_style_query? = api_style_query?(query) and not broad_package_query?
    example_intent_query? = example_intent_query?(query)
    skill_intent_query? = skill_intent_query?(query)

    results
    |> Enum.with_index()
    |> Enum.sort_by(fn {%Result{} = result, index} ->
      {
        skill_priority_group(result, skill_intent_query?),
        -(score_value(result.score) +
            ranking_bonus(result, broad_package_query?, api_style_query?, example_intent_query?)),
        index
      }
    end)
    |> Enum.map(&elem(&1, 0))
  end

  defp rerank_results(results, _query), do: results

  defp ranking_bonus(%Result{source_type: :ecosystem}, true, _api_style_query?, _example_intent?),
    do: 25.0

  defp ranking_bonus(%Result{source_type: :ecosystem_docs}, true, _api_style_query?, _example_intent?),
    do: -5.0

  defp ranking_bonus(%Result{source_type: :ecosystem_docs}, _broad_package_query?, true, _example_intent?),
    do: 25.0

  defp ranking_bonus(%Result{source_type: :ecosystem}, _broad_package_query?, true, _example_intent?),
    do: -5.0

  defp ranking_bonus(%Result{source_type: :docs}, _broad_package_query?, true, _example_intent?),
    do: 2.0

  # Example-intent queries ("persistence example", "auth demo") should surface
  # examples above generic docs/blog matches. The boost is sized to lift an
  # example that matches the topic (high lexical score) above docs/blog pages
  # without promoting weakly-matching examples that only share the generic word
  # "example".
  defp ranking_bonus(%Result{source_type: :examples}, _broad_package_query?, _api_style_query?, true),
    do: 20.0

  defp ranking_bonus(_result, _broad_package_query?, _api_style_query?, _example_intent?), do: 0.0

  defp broad_package_query?(query) when is_binary(query) do
    query_downcase = String.downcase(String.trim(query))
    Enum.any?(@broad_package_phrases, &String.contains?(query_downcase, &1))
  end

  defp broad_package_query?(_query), do: false

  defp example_intent_query?(query) when is_binary(query) do
    query_downcase = String.downcase(String.trim(query))
    Enum.any?(@example_intent_terms, &String.contains?(query_downcase, &1))
  end

  defp example_intent_query?(_query), do: false

  # Package-skill queries ("<package> skill") should surface the matching skill
  # card above docs/blog matches. The word "skill" is ubiquitous across doc
  # bodies, so raw lexical scores inflate docs far above the skill card, which
  # does not even contain "skill" in its identity fields. A flat additive
  # boost cannot reliably overcome that, so skill-intent queries give skill
  # cards structural priority in `rerank_results`: skills sort above non-skill
  # results (group 0 before 1), ordered within by their own lexical score. The
  # group is uniform for non-skill-intent queries, so other ranking is
  # unchanged (jido-e10 E10-T03).
  defp skill_priority_group(%Result{source_type: :skills}, true), do: 0
  defp skill_priority_group(_result, _skill_intent_query?), do: 1

  defp skill_intent_query?(query) when is_binary(query) do
    query_downcase = String.downcase(String.trim(query))
    Enum.any?(@skill_intent_terms, &String.contains?(query_downcase, &1))
  end

  defp skill_intent_query?(_query), do: false

  defp api_style_query?(query) when is_binary(query) do
    query_downcase = String.downcase(String.trim(query))

    Enum.any?(@api_intent_terms, &String.contains?(query_downcase, &1)) or
      String.match?(query, ~r/\b[A-Z][A-Za-z0-9_]*(?:\.[A-Z][A-Za-z0-9_]*)+\b/u) or
      String.match?(query_downcase, ~r/\b[a-z_!?]+\/\d+\b/u) or
      String.contains?(query, "(")
  end

  defp api_style_query?(_query), do: false

  defp trim_snippet(text, max_len) when is_binary(text) do
    if String.length(text) <= max_len do
      text
    else
      String.slice(text, 0, max_len) <> "..."
    end
  end

  defp trim_snippet(_text, _max_len), do: ""

  defp normalize_limit(limit) when is_integer(limit) and limit > 0, do: limit
  defp normalize_limit(_limit), do: @default_limit

  defp normalize_string(value) when is_binary(value) do
    value
    |> String.trim()
    |> case do
      "" -> nil
      text -> text
    end
  end

  defp normalize_string(_value), do: nil

  defp string_value(map, key) do
    map
    |> value(key)
    |> normalize_string()
  end

  defp truthy?(value), do: value in [true, "true", 1, "1", "on"]

  defp value(map, key, default \\ nil)

  defp value(map, key, default) when is_map(map) and is_atom(key) do
    case Map.fetch(map, key) do
      {:ok, found} ->
        found

      :error ->
        Map.get(map, Atom.to_string(key), default)
    end
  end

  defp value(map, key, default) when is_map(map), do: Map.get(map, key, default)
  defp value(_map, _key, default), do: default
end
