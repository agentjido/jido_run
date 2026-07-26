defmodule AgentJido.MCP.DocsTools do
  @moduledoc """
  MCP tool implementations for read-only documentation retrieval.
  """

  alias AgentJido.ContentAssistant.Result
  alias AgentJido.ContentAssistant.Retrieval
  alias AgentJido.ContentAssistant.URL
  alias AgentJido.MCP
  alias AgentJido.Pages
  alias AgentJidoWeb.MarkdownContent

  @docs_collection ["site_docs"]

  @type tool_result :: %{
          required(String.t()) => term()
        }

  @spec tools() :: [map()]
  def tools do
    [
      %{
        "name" => "search_docs",
        "description" =>
          "Search published Agent Jido documentation pages (/docs/**) with citation-friendly snippets. v1 is docs only — examples, skills, ecosystem packages, blog, and compare pages are not indexed.",
        "inputSchema" => search_docs_input_schema(),
        "outputSchema" => search_docs_output_schema()
      },
      %{
        "name" => "get_doc",
        "description" => "Fetch the markdown payload and metadata for a documentation page by path.",
        "inputSchema" => get_doc_input_schema(),
        "outputSchema" => get_doc_output_schema()
      },
      %{
        "name" => "list_sections",
        "description" => "List the published documentation sections and their visible child pages.",
        "inputSchema" => list_sections_input_schema(),
        "outputSchema" => list_sections_output_schema()
      }
    ]
  end

  @spec call_tool(String.t(), map(), keyword()) :: {:ok, tool_result()} | {:error, map()}
  def call_tool("search_docs", arguments, opts), do: search_docs(arguments, opts)
  def call_tool("get_doc", arguments, opts), do: get_doc(arguments, opts)
  def call_tool("list_sections", arguments, opts), do: list_sections(arguments, opts)

  def call_tool(name, _arguments, _opts) do
    {:error, %{"code" => "unknown_tool", "message" => "Unknown tool #{inspect(name)}"}}
  end

  @spec search_docs(map(), keyword()) :: {:ok, tool_result()} | {:error, map()}
  def search_docs(arguments, opts) when is_map(arguments) and is_list(opts) do
    with {:ok, query} <- require_non_empty_string(arguments, "query", MCP.query_max_length()),
         {:ok, limit} <- optional_limit(arguments, "limit", MCP.default_search_limit(), MCP.max_search_limit()) do
      retrieval_module = Keyword.get(opts, :retrieval_module, Retrieval)
      retrieval_opts = Keyword.get(opts, :retrieval_opts, [])

      retrieval_opts =
        retrieval_opts
        |> Keyword.put(:collections, @docs_collection)
        |> Keyword.put_new(:mode, :hybrid)
        |> Keyword.put_new(:limit, limit)
        |> Keyword.put_new(:fallback_fun, &docs_local_fallback/2)

      {results, retrieval_status} =
        case retrieval_module.query_with_status(query, retrieval_opts) do
          {:ok, rows, status} -> {normalize_search_results(rows, limit), normalize_status(status)}
          {:ok, rows} -> {normalize_search_results(rows, limit), "success"}
          _other -> {[], "fallback"}
        end

      structured =
        %{
          "query" => query,
          "retrieval_status" => retrieval_status,
          "results" => results
        }

      {:ok,
       tool_result(
         "Found #{length(results)} documentation result#{if length(results) == 1, do: "", else: "s"} for #{inspect(query)}.",
         structured
       )}
    end
  end

  def search_docs(_arguments, _opts) do
    {:error, %{"code" => "invalid_arguments", "message" => "search_docs expects an object argument"}}
  end

  @spec get_doc(map(), keyword()) :: {:ok, tool_result()} | {:error, map()}
  def get_doc(arguments, opts) when is_map(arguments) and is_list(opts) do
    with {:ok, requested_path} <- require_non_empty_string(arguments, "path"),
         {:ok, normalized_path} <- normalize_doc_path(requested_path),
         {:ok, page, resolution} <- resolve_docs_page(normalized_path, opts),
         {:ok, markdown} <- resolve_markdown(Pages.route_for(page), opts) do
      canonical_path = Pages.route_for(page)

      structured =
        %{
          "title" => page.title,
          "path" => canonical_path,
          "canonical_url" => MCP.canonical_url(canonical_path),
          "section" => Pages.docs_section_for_path(canonical_path),
          "markdown" => markdown,
          "github_url" => page.github_url,
          "livebook_url" => page.livebook_url,
          "legacy_resolution" => legacy_resolution_payload(normalized_path, canonical_path, resolution)
        }
        |> Enum.reject(fn {_key, value} -> is_nil(value) end)
        |> Map.new()

      {:ok, tool_result(markdown, structured)}
    end
  end

  def get_doc(_arguments, _opts) do
    {:error, %{"code" => "invalid_arguments", "message" => "get_doc expects an object argument"}}
  end

  @spec list_sections(map(), keyword()) :: {:ok, tool_result()} | {:error, map()}
  def list_sections(arguments, opts) when is_map(arguments) and is_list(opts) do
    if map_size(arguments) > 0 do
      {:error, %{"code" => "invalid_arguments", "message" => "list_sections does not accept arguments"}}
    else
      pages_module = Keyword.get(opts, :pages_module, Pages)

      sections =
        pages_module.docs_sections()
        |> Enum.map(fn root ->
          section = pages_module.docs_section_for_path(root.path)
          section_pages = pages_module.docs_section_pages(section)
          child_pages = Enum.reject(section_pages, &(&1.path == root.path))

          %{
            "title" => root.title,
            "path" => root.path,
            "canonical_url" => MCP.canonical_url(root.path),
            "section" => section,
            "page_count" => length(section_pages),
            "pages" =>
              Enum.map(child_pages, fn page ->
                %{
                  "title" => page.title,
                  "path" => page.path,
                  "canonical_url" => MCP.canonical_url(page.path),
                  "description" => page.description
                }
                |> Enum.reject(fn {_key, value} -> is_nil(value) end)
                |> Map.new()
              end)
          }
        end)

      structured = %{"sections" => sections}

      {:ok,
       tool_result(
         "Listed #{length(sections)} documentation section#{if length(sections) == 1, do: "", else: "s"}.",
         structured
       )}
    end
  end

  def list_sections(_arguments, _opts) do
    {:error, %{"code" => "invalid_arguments", "message" => "list_sections expects an object argument"}}
  end

  defp tool_result(text, structured_content) do
    %{
      "content" => [%{"type" => "text", "text" => text}],
      "structuredContent" => structured_content,
      "isError" => false
    }
  end

  defp normalize_search_results(rows, limit) when is_list(rows) do
    rows
    |> Enum.map(&normalize_search_result/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.take(limit)
  end

  defp normalize_search_results(_rows, _limit), do: []

  defp normalize_search_result(%Result{} = result) do
    case normalize_doc_path(result.url) do
      {:ok, path} ->
        %{
          "title" => result.title,
          "path" => path,
          "canonical_url" => MCP.canonical_url(path),
          "section" => Pages.docs_section_for_path(path),
          "snippet" => result.snippet,
          "score" => result.score
        }
        |> Enum.reject(fn {_key, value} -> is_nil(value) end)
        |> Map.new()

      _ ->
        nil
    end
  end

  defp normalize_search_result(%{title: title, snippet: snippet, url: url} = result) do
    normalize_search_result(%Result{
      title: title,
      snippet: snippet,
      url: url,
      source_type: :docs,
      score: Map.get(result, :score) || Map.get(result, "score")
    })
  end

  defp normalize_search_result(_result), do: nil

  defp docs_local_fallback(query, opts) do
    limit =
      case Keyword.get(opts, :limit, MCP.default_search_limit()) do
        value when is_integer(value) and value > 0 -> value
        _ -> MCP.default_search_limit()
      end

    terms = tokenize(query)
    query_downcase = String.downcase(String.trim(query))

    if terms == [] do
      []
    else
      Pages.pages_by_category(:docs)
      |> Enum.map(&fallback_result(&1, terms, query_downcase))
      |> Enum.reject(&is_nil/1)
      |> Enum.sort_by(&(&1.score || 0.0), :desc)
      |> Enum.take(limit)
    end
  end

  defp fallback_result(page, terms, query_downcase) do
    searchable_text =
      [page.description, strip_html(page.body), Enum.join(page.tags || [], " ")]
      |> Enum.filter(&is_binary/1)
      |> Enum.join(" ")

    score = lexical_score(page.title, searchable_text, terms, query_downcase)

    if score > 0 do
      %Result{
        title: page.title,
        snippet: truncate_text(searchable_text, 320),
        url: page.path,
        source_type: :docs,
        score: score
      }
    end
  end

  defp normalize_status(:fallback), do: "fallback"
  defp normalize_status(_status), do: "success"

  defp resolve_docs_page(path, opts) do
    pages_module = Keyword.get(opts, :pages_module, Pages)

    case pages_module.resolve_page_for_path(path) do
      {:ok, %{category: :docs} = page, resolution} ->
        {:ok, page, resolution}

      {:ok, _page, _resolution} ->
        {:error, %{"code" => "not_found", "message" => "No documentation page exists for #{inspect(path)}"}}

      :error ->
        {:error, %{"code" => "not_found", "message" => "No documentation page exists for #{inspect(path)}"}}
    end
  end

  defp resolve_markdown(path, opts) do
    markdown_resolver = Keyword.get(opts, :markdown_resolver, &MarkdownContent.resolve/2)

    case markdown_resolver.(path, MCP.canonical_url(path)) do
      {:ok, markdown} when is_binary(markdown) -> {:ok, markdown}
      _other -> {:error, %{"code" => "not_found", "message" => "Could not resolve markdown for #{inspect(path)}"}}
    end
  end

  defp legacy_resolution_payload(_requested_path, _canonical_path, :canonical), do: nil

  defp legacy_resolution_payload(requested_path, canonical_path, resolution) do
    %{
      "requested_path" => requested_path,
      "resolved_path" => canonical_path,
      "resolution" => to_string(resolution)
    }
  end

  defp require_non_empty_string(arguments, key, max_length \\ nil) when is_map(arguments) and is_binary(key) do
    value =
      arguments
      |> Map.get(key)
      |> case do
        binary when is_binary(binary) -> String.trim(binary)
        _other -> ""
      end

    cond do
      value == "" ->
        {:error, %{"code" => "invalid_arguments", "message" => "#{key} must be a non-empty string"}}

      is_integer(max_length) and String.length(value) > max_length ->
        {:error,
         %{
           "code" => "invalid_arguments",
           "message" => "#{key} must be #{max_length} characters or fewer"
         }}

      true ->
        {:ok, value}
    end
  end

  defp optional_limit(arguments, key, default, max_limit) when is_map(arguments) do
    case Map.get(arguments, key, default) do
      value when is_integer(value) and value > 0 and value <= max_limit -> {:ok, value}
      value when is_integer(value) -> {:error, %{"code" => "invalid_arguments", "message" => "#{key} must be between 1 and #{max_limit}"}}
      nil -> {:ok, default}
      _other -> {:error, %{"code" => "invalid_arguments", "message" => "#{key} must be an integer"}}
    end
  end

  defp normalize_doc_path(value) when is_binary(value) do
    value
    |> String.trim()
    |> URL.normalize_href()
    |> case do
      nil -> {:error, %{"code" => "invalid_arguments", "message" => "path must be a valid path or same-site URL"}}
      normalized -> normalized |> strip_markdown_suffix() |> ensure_docs_path()
    end
  end

  defp normalize_doc_path(_value) do
    {:error, %{"code" => "invalid_arguments", "message" => "path must be a string"}}
  end

  defp strip_markdown_suffix(path) do
    if String.ends_with?(path, ".md"), do: String.trim_trailing(path, ".md"), else: path
  end

  defp ensure_docs_path("/docs" <> _rest = path), do: {:ok, path}

  defp ensure_docs_path(path) do
    {:error, %{"code" => "not_found", "message" => "No documentation page exists for #{inspect(path)}"}}
  end

  defp tokenize(query) do
    query
    |> String.downcase()
    |> String.split(~r/[^[:alnum:]_]+/u, trim: true)
    |> Enum.uniq()
  end

  defp lexical_score(title, searchable_text, terms, query_downcase)
       when is_binary(title) and is_binary(searchable_text) and is_binary(query_downcase) do
    title_down = String.downcase(title)
    text_down = String.downcase(searchable_text)

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

  defp strip_html(text) when is_binary(text) do
    text
    |> String.replace(~r/<[^>]*>/u, " ")
    |> String.replace(~r/\s+/u, " ")
    |> String.trim()
  end

  defp strip_html(_text), do: ""

  defp truncate_text(text, max_len) when is_binary(text) and is_integer(max_len) do
    if String.length(text) <= max_len, do: text, else: String.slice(text, 0, max_len) <> "..."
  end

  defp search_docs_input_schema do
    %{
      "type" => "object",
      "additionalProperties" => false,
      "required" => ["query"],
      "properties" => %{
        "query" => %{"type" => "string", "minLength" => 1, "maxLength" => MCP.query_max_length()},
        "limit" => %{"type" => "integer", "minimum" => 1, "maximum" => MCP.max_search_limit()}
      }
    }
  end

  defp search_docs_output_schema do
    %{
      "type" => "object",
      "required" => ["query", "retrieval_status", "results"],
      "properties" => %{
        "query" => %{"type" => "string"},
        "retrieval_status" => %{"type" => "string", "enum" => ["success", "fallback"]},
        "results" => %{
          "type" => "array",
          "items" => %{
            "type" => "object",
            "required" => ["title", "path", "canonical_url", "section", "snippet"],
            "properties" => %{
              "title" => %{"type" => "string"},
              "path" => %{"type" => "string"},
              "canonical_url" => %{"type" => "string"},
              "section" => %{"type" => "string"},
              "snippet" => %{"type" => "string"},
              "score" => %{"type" => "number"}
            }
          }
        }
      }
    }
  end

  defp get_doc_input_schema do
    %{
      "type" => "object",
      "additionalProperties" => false,
      "required" => ["path"],
      "properties" => %{
        "path" => %{"type" => "string", "minLength" => 1}
      }
    }
  end

  defp get_doc_output_schema do
    %{
      "type" => "object",
      "required" => ["title", "path", "canonical_url", "section", "markdown", "github_url"],
      "properties" => %{
        "title" => %{"type" => "string"},
        "path" => %{"type" => "string"},
        "canonical_url" => %{"type" => "string"},
        "section" => %{"type" => "string"},
        "markdown" => %{"type" => "string"},
        "github_url" => %{"type" => "string"},
        "livebook_url" => %{"type" => "string"},
        "legacy_resolution" => %{"type" => "object"}
      }
    }
  end

  defp list_sections_input_schema do
    %{
      "type" => "object",
      "additionalProperties" => false,
      "properties" => %{}
    }
  end

  defp list_sections_output_schema do
    %{
      "type" => "object",
      "required" => ["sections"],
      "properties" => %{
        "sections" => %{
          "type" => "array",
          "items" => %{
            "type" => "object",
            "required" => ["title", "path", "canonical_url", "section", "page_count", "pages"],
            "properties" => %{
              "title" => %{"type" => "string"},
              "path" => %{"type" => "string"},
              "canonical_url" => %{"type" => "string"},
              "section" => %{"type" => "string"},
              "page_count" => %{"type" => "integer"},
              "pages" => %{
                "type" => "array",
                "items" => %{
                  "type" => "object",
                  "required" => ["title", "path", "canonical_url"],
                  "properties" => %{
                    "title" => %{"type" => "string"},
                    "path" => %{"type" => "string"},
                    "canonical_url" => %{"type" => "string"},
                    "description" => %{"type" => "string"}
                  }
                }
              }
            }
          }
        }
      }
    }
  end
end
