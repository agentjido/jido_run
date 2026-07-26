defmodule AgentJido.ContentAssistant do
  @moduledoc """
  Unified content assistant API for retrieval-grounded search responses.
  """

  require Logger

  alias AgentJido.ContentAssistant.LinkPolicy
  alias AgentJido.ContentAssistant.Response
  alias AgentJido.ContentAssistant.Result
  alias AgentJido.ContentAssistant.Retrieval
  alias AgentJido.ContentAssistant.URL

  @default_citation_limit 6
  @default_query_max_length 500
  @default_link_source "content_assistant"
  @fallback_snippet "Open this reference for full context."

  @doc """
  Responds to a content query with deterministic citations.
  """
  @spec respond(String.t(), keyword()) :: {:ok, Response.t()}
  def respond(query, opts \\ [])

  def respond(query, opts) when is_binary(query) and is_list(opts) do
    normalized_query = normalize_query(query, query_max_length(opts))

    if normalized_query == "" do
      {:ok,
       build_response(normalized_query,
         answer_markdown: "",
         answer_mode: :no_results,
         citations: [],
         related_queries: [],
         retrieval_status: :success,
         llm_attempted?: false,
         llm_enhanced?: false,
         enhancement_blocked_reason: nil,
         link_source: @default_link_source,
         link_channel: link_channel(opts),
         query_log_id: Keyword.get(opts, :query_log_id)
       )}
    else
      do_respond(normalized_query, opts)
    end
  end

  def respond(_query, opts), do: respond("", opts)

  defp do_respond(query, opts) do
    case run_retrieval(query, opts) do
      {:ok, citations, retrieval_status} ->
        query_log_id = Keyword.get(opts, :query_log_id)

        if citations == [] do
          {:ok,
           build_response(query,
             answer_markdown: "",
             answer_mode: :no_results,
             citations: [],
             related_queries: related_queries(query, opts),
             retrieval_status: retrieval_status,
             llm_attempted?: false,
             llm_enhanced?: false,
             enhancement_blocked_reason: nil,
             link_source: @default_link_source,
             link_channel: link_channel(opts),
             query_log_id: query_log_id
           )}
        else
          {:ok,
           build_response(query,
             answer_markdown: deterministic_summary(query, citations),
             answer_mode: :deterministic,
             citations: citations,
             related_queries: [],
             retrieval_status: retrieval_status,
             llm_attempted?: false,
             llm_enhanced?: false,
             enhancement_blocked_reason: nil,
             link_source: @default_link_source,
             link_channel: link_channel(opts),
             query_log_id: query_log_id
           )}
        end

      _error ->
        {:ok,
         build_response(query,
           answer_markdown: "",
           answer_mode: :error,
           citations: [],
           related_queries: [],
           retrieval_status: :failure,
           llm_attempted?: false,
           llm_enhanced?: false,
           enhancement_blocked_reason: nil,
           link_source: @default_link_source,
           link_channel: link_channel(opts),
           query_log_id: Keyword.get(opts, :query_log_id)
         )}
    end
  rescue
    error ->
      Logger.warning("ContentAssistant failed to respond: #{Exception.message(error)}")

      {:ok,
       build_response(query,
         answer_markdown: "",
         answer_mode: :error,
         citations: [],
         related_queries: [],
         retrieval_status: :failure,
         llm_attempted?: false,
         llm_enhanced?: false,
         enhancement_blocked_reason: nil,
         link_source: @default_link_source,
         link_channel: link_channel(opts),
         query_log_id: Keyword.get(opts, :query_log_id)
       )}
  end

  defp run_retrieval(query, opts) do
    retrieval_module = Keyword.get(opts, :retrieval_module, retrieval_module())
    retrieval_opts = Keyword.get(opts, :retrieval_opts, [])
    citation_limit = Keyword.get(opts, :citation_limit, @default_citation_limit)

    response =
      cond do
        module_function_exported?(retrieval_module, :query_with_status, 2) ->
          retrieval_module.query_with_status(query, retrieval_opts)

        module_function_exported?(retrieval_module, :query, 2) ->
          retrieval_module.query(query, retrieval_opts)

        true ->
          {:error, :invalid_retrieval_module}
      end

    case response do
      {:ok, results, status} when is_list(results) ->
        {:ok, normalize_results(results, citation_limit), normalize_retrieval_status(status)}

      {:ok, results} when is_list(results) ->
        {:ok, normalize_results(results, citation_limit), :success}

      _other ->
        {:error, :retrieval_failed}
    end
  rescue
    _ -> {:error, :retrieval_failed}
  end

  defp normalize_results(results, limit) when is_list(results) do
    limit = normalize_limit(limit, @default_citation_limit)

    results
    |> Enum.map(&normalize_result/1)
    |> Enum.reject(&is_nil/1)
    |> dedupe_results()
    |> Enum.take(limit)
  end

  defp normalize_results(_results, _limit), do: []

  defp normalize_result(%Result{} = result) do
    case URL.normalize_href(result.url) do
      url when is_binary(url) ->
        %Result{
          result
          | url: url,
            snippet: normalize_snippet(result.snippet),
            source_type: normalize_source_type(result.source_type),
            secondary_url: normalize_optional_href(result.secondary_url),
            page_kind: normalize_page_kind(result.page_kind),
            provider: normalize_provider(result.provider)
        }
        |> ensure_classified()

      _ ->
        nil
    end
  end

  defp normalize_result(%{title: title, snippet: snippet, url: url, source_type: source_type} = map)
       when is_binary(title) and is_binary(snippet) and is_binary(url) do
    case URL.normalize_href(url) do
      normalized_url when is_binary(normalized_url) ->
        %Result{
          title: String.trim(title),
          snippet: normalize_snippet(snippet),
          url: normalized_url,
          source_type: normalize_source_type(source_type),
          score: result_value(map, :score),
          external?: truthy?(result_value(map, :external?)),
          provider: normalize_provider(result_value(map, :provider)),
          package_id: result_value(map, :package_id),
          package_name: result_value(map, :package_name),
          package_title: result_value(map, :package_title),
          package_version: result_value(map, :package_version),
          page_kind: normalize_page_kind(result_value(map, :page_kind)),
          secondary_url: normalize_optional_href(result_value(map, :secondary_url))
        }
        |> ensure_classified()

      _ ->
        nil
    end
  end

  defp normalize_result(_result), do: nil

  # Every public citation carries a content type and proof level so a user can
  # distinguish a definition, guide, package surface, example, and case study
  # (jido-e10-t28). The local retrieval path classifies from rich metadata;
  # results that arrive without a classification (backend maps, stubs) get a
  # best-effort type from the fields already on the Result.
  defp ensure_classified(%Result{content_type: nil} = result) do
    content_type =
      Result.classify_content_type(
        source_type: result.source_type,
        page_kind: result.page_kind,
        url: result.url
      )

    %Result{result | content_type: content_type, proof_level: Result.proof_level_for(content_type)}
  end

  defp ensure_classified(%Result{content_type: content_type} = result) do
    %Result{result | proof_level: result.proof_level || Result.proof_level_for(content_type)}
  end

  defp result_value(map, key), do: Map.get(map, key) || Map.get(map, Atom.to_string(key))

  defp normalize_source_type(source_type) when source_type in [:docs, :blog, :ecosystem, :ecosystem_docs],
    do: source_type

  defp normalize_source_type(source_type) when is_binary(source_type) do
    case String.downcase(String.trim(source_type)) do
      "docs" -> :docs
      "documentation" -> :docs
      "blog" -> :blog
      "ecosystem" -> :ecosystem
      "ecosystem_docs" -> :ecosystem_docs
      _ -> :docs
    end
  end

  defp normalize_source_type(_source_type), do: :docs

  defp normalize_retrieval_status(:success), do: :success
  defp normalize_retrieval_status(:fallback), do: :fallback
  defp normalize_retrieval_status(_status), do: :success

  defp normalize_limit(limit, _default) when is_integer(limit) and limit > 0, do: limit
  defp normalize_limit(_limit, default), do: default

  defp dedupe_results(results) when is_list(results) do
    results
    |> Enum.reduce(%{}, fn
      %Result{url: url, score: score} = result, acc ->
        Map.update(acc, url, result, &best_result(&1, result, score))

      _, acc ->
        acc
    end)
    |> Map.values()
    |> Enum.sort_by(fn %Result{score: score} -> score_value(score) end, :desc)
  end

  defp dedupe_results(_results), do: []

  defp best_result(%Result{score: existing_score} = existing, result, score) do
    if score_value(score) > score_value(existing_score), do: result, else: existing
  end

  defp score_value(score) when is_number(score), do: score * 1.0
  defp score_value(_score), do: 0.0

  defp normalize_snippet(snippet) when is_binary(snippet) do
    snippet
    |> String.replace(~r/\s+/u, " ")
    |> String.trim()
    |> case do
      "" ->
        @fallback_snippet

      cleaned ->
        if Regex.match?(~r{^/[^\s]*$}, cleaned) do
          @fallback_snippet
        else
          truncate_line(cleaned, 320)
        end
    end
  end

  defp normalize_snippet(_snippet), do: @fallback_snippet

  defp build_response(query, attrs) when is_binary(query) and is_list(attrs) do
    markdown = Keyword.get(attrs, :answer_markdown, "")
    citations = Keyword.fetch!(attrs, :citations)
    link_source = Keyword.get(attrs, :link_source, @default_link_source)
    link_channel = Keyword.get(attrs, :link_channel, "content_assistant")

    html =
      markdown
      |> markdown_to_html()
      |> LinkPolicy.apply(citations, source: link_source, channel: link_channel)

    %Response{
      query: query,
      answer_markdown: markdown,
      answer_html: html,
      answer_mode: Keyword.fetch!(attrs, :answer_mode),
      citations: citations,
      related_queries: normalize_related_queries(Keyword.get(attrs, :related_queries, [])),
      retrieval_status: Keyword.fetch!(attrs, :retrieval_status),
      llm_attempted?: Keyword.fetch!(attrs, :llm_attempted?),
      llm_enhanced?: Keyword.fetch!(attrs, :llm_enhanced?),
      enhancement_blocked_reason: Keyword.fetch!(attrs, :enhancement_blocked_reason),
      query_log_id: Keyword.get(attrs, :query_log_id)
    }
  end

  defp markdown_to_html(markdown) when is_binary(markdown) do
    case MDEx.to_html(markdown) do
      {:ok, html} ->
        html

      {:error, _reason} ->
        markdown
        |> Phoenix.HTML.html_escape()
        |> Phoenix.HTML.safe_to_string()
    end
  end

  defp markdown_to_html(_markdown), do: ""

  @spec deterministic_summary(String.t(), [Result.t()]) :: String.t()
  defp deterministic_summary(query, citations) do
    citation_count = length(citations)
    sources = citations |> Enum.map(&source_label(&1.source_type)) |> Enum.uniq() |> Enum.join(", ")
    reference_label = if citation_count == 1, do: "reference", else: "references"

    [
      "Found #{citation_count} relevant #{reference_label} for \"#{query}\".",
      source_summary(sources),
      "Open the citations below for full context."
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n\n")
  end

  defp source_summary(""), do: nil
  defp source_summary(sources), do: "Sources: #{sources}."

  defp normalize_related_queries(related_queries) when is_list(related_queries) do
    related_queries
    |> Enum.filter(&is_binary/1)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
    |> Enum.take(4)
  end

  defp normalize_related_queries(_related_queries), do: []

  @spec source_label(atom()) :: String.t()
  defp source_label(:docs), do: "Docs"
  defp source_label(:blog), do: "Blog"
  defp source_label(:ecosystem), do: "Ecosystem"
  defp source_label(:ecosystem_docs), do: "HexDocs"
  defp source_label(:examples), do: "Example"
  defp source_label(:skills), do: "Skill"
  defp source_label(_), do: "Content"

  defp normalize_optional_href(nil), do: nil

  defp normalize_optional_href(url) do
    URL.normalize_href(url)
  end

  defp normalize_page_kind(page_kind) when page_kind in [:module, :guide, :readme, :task], do: page_kind

  defp normalize_page_kind(page_kind) when is_binary(page_kind) do
    case String.downcase(String.trim(page_kind)) do
      "module" -> :module
      "guide" -> :guide
      "readme" -> :readme
      "task" -> :task
      _ -> nil
    end
  end

  defp normalize_page_kind(_page_kind), do: nil

  defp normalize_provider(provider) when provider in [:hexdocs], do: provider

  defp normalize_provider(provider) when is_binary(provider) do
    case String.downcase(String.trim(provider)) do
      "hexdocs" -> :hexdocs
      "" -> nil
      other -> other
    end
  end

  defp normalize_provider(_provider), do: nil

  defp truthy?(value), do: value in [true, "true", 1, "1", "on"]

  @spec truncate_line(String.t(), pos_integer()) :: String.t()
  defp truncate_line(text, max_len) when is_binary(text) and max_len > 0 do
    if String.length(text) <= max_len do
      text
    else
      String.slice(text, 0, max_len) <> "..."
    end
  end

  defp content_assistant_cfg do
    Application.get_env(:agent_jido, AgentJido.ContentAssistant, [])
  end

  defp config_value(config, key, default)
  defp config_value(config, key, default) when is_list(config), do: Keyword.get(config, key, default)
  defp config_value(config, key, default) when is_map(config), do: Map.get(config, key, default)
  defp config_value(_config, _key, default), do: default

  defp query_max_length(opts) when is_list(opts) do
    case Keyword.get(opts, :query_max_length, config_value(content_assistant_cfg(), :query_max_length, @default_query_max_length)) do
      value when is_integer(value) and value > 0 -> value
      _ -> @default_query_max_length
    end
  end

  defp query_max_length(_opts), do: @default_query_max_length

  defp normalize_query(query, max_length) when is_binary(query) and is_integer(max_length) and max_length > 0 do
    query
    |> String.trim()
    |> String.slice(0, max_length)
  end

  defp normalize_query(_query, _max_length), do: ""

  defp link_channel(opts) when is_list(opts) do
    case Keyword.get(opts, :surface) do
      "content_assistant_modal" -> "content_assistant_modal"
      "content_assistant_page" -> "content_assistant_page"
      _ -> "content_assistant_page"
    end
  end

  defp link_channel(_opts), do: "content_assistant_page"

  defp related_queries(query, opts) when is_binary(query) and is_list(opts) do
    retrieval_module = Keyword.get(opts, :retrieval_module, retrieval_module())
    retrieval_opts = Keyword.get(opts, :retrieval_opts, [])

    if module_function_exported?(retrieval_module, :suggest_related_queries, 2) do
      retrieval_module.suggest_related_queries(query, retrieval_opts)
    else
      []
    end
  rescue
    _ -> []
  end

  defp related_queries(_query, _opts), do: []

  defp retrieval_module do
    Application.get_env(:agent_jido, :content_assistant_retrieval_module, Retrieval)
  end

  defp module_function_exported?(module, function, arity)
       when is_atom(module) and is_atom(function) and is_integer(arity) and arity >= 0 do
    Code.ensure_loaded?(module) and function_exported?(module, function, arity)
  end

  defp module_function_exported?(_module, _function, _arity), do: false
end
