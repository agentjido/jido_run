defmodule AgentJido.MCP.DocsTools do
  @moduledoc """
  MCP tool implementations for read-only documentation retrieval.
  """

  alias AgentJido.ContentAssistant.Result
  alias AgentJido.ContentAssistant.Retrieval
  alias AgentJido.ContentAssistant.URL
  alias AgentJido.Ecosystem.ControlMatrix
  alias AgentJido.Ecosystem.Stacks
  alias AgentJido.Examples
  alias AgentJido.Examples.Example
  alias AgentJido.MCP
  alias AgentJido.Pages
  alias AgentJidoWeb.MarkdownContent

  @docs_collection ["site_docs"]

  # The canonical operational-control overview: the Security and governance guide,
  # the one docs page that draws every control boundary (what Jido supplies, what
  # the application/platform owns, and the proof for each). A client retrieves it
  # by name through get_operational_control rather than guessing a control term in
  # search_docs (jido-e10-t30).
  @control_overview_path "/docs/operations/security-and-governance"

  # The docs pages the canonical control overview cites as the proof/grounding for
  # its claims — the rate-limit/quota surface, the journal retention/access surface,
  # the production readiness checklist, the incident playbooks, and the operational
  # controls onboarding lane. Mirrors the links in security-and-governance.md so a
  # client receives the same proof pointers a browser reader follows. See
  # jido-e10-t30.
  @control_proof_pages [
    "/docs/operations/rate-limits-and-cost-budgets",
    "/docs/operations/journal-retention-access-and-deletion",
    "/docs/operations/production-readiness-checklist",
    "/docs/operations/incident-playbooks",
    "/docs/getting-started/operational-controls"
  ]

  # Mirrors the browser and ecosystem-markdown "Release basis" note: each
  # package's release version, support level, and proof live on its package page,
  # and the full claim boundaries live on the overview. This qualifies every
  # control claim the tool returns (jido-e10-t30).
  @control_release_basis "Each package's release version, support level, and proof are stated on its package page; experimental or unreleased packages describe their documented boundary only and do not back a general production claim. The full claim boundaries are on the Security and governance overview."

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
      },
      %{
        "name" => "get_operational_control",
        "description" =>
          "Retrieve the canonical operational-control overview and its proof without a text search. Returns the Security and governance documentation page (the overview that draws every control boundary), the nine control dimensions, the documentation pages that ground each claim, and the package columns whose package pages carry release version, support level, and proof. Use this instead of guessing an operational-control term (identity, authorization, audit, policy, quota, approval, redaction) in search_docs.",
        "inputSchema" => get_operational_control_input_schema(),
        "outputSchema" => get_operational_control_output_schema()
      },
      %{
        "name" => "get_example",
        "description" =>
          "Fetch the canonical Markdown and metadata for a single published interactive example by path or slug (e.g. /examples/counter-agent or counter-agent). Returns the same Markdown the public /examples/<slug>.md endpoint serves, plus the example's proof metadata (outcome, packages, package maturity, difficulty, run command) and content metadata (content type, status, version, last validated). Examples are not indexed by search_docs; use this tool to retrieve one directly.",
        "inputSchema" => get_example_input_schema(),
        "outputSchema" => get_example_output_schema()
      },
      %{
        "name" => "get_recommended_stack",
        "description" =>
          "Retrieve a recommended starting package set (an ecosystem stack) by key — core, ai, or operate — with each package's explicit supported range, source, support level, package-page link, and a copyable mix.exs deps/0 block you can paste to install the set. Omit the key to return all three recommended starting stacks. Use this to answer 'which packages should I start with?' instead of guessing a package name in search_docs. Package composition and ranges come from the same registry as the home dependency blocks and the Ecosystem compatibility matrix, so the recommended set never drifts from install.",
        "inputSchema" => get_recommended_stack_input_schema(),
        "outputSchema" => get_recommended_stack_output_schema()
      }
    ]
  end

  @spec call_tool(String.t(), map(), keyword()) :: {:ok, tool_result()} | {:error, map()}
  def call_tool("search_docs", arguments, opts), do: search_docs(arguments, opts)
  def call_tool("get_doc", arguments, opts), do: get_doc(arguments, opts)
  def call_tool("list_sections", arguments, opts), do: list_sections(arguments, opts)
  def call_tool("get_operational_control", arguments, opts), do: get_operational_control(arguments, opts)
  def call_tool("get_example", arguments, opts), do: get_example(arguments, opts)
  def call_tool("get_recommended_stack", arguments, opts), do: get_recommended_stack(arguments, opts)

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

  @spec get_operational_control(map(), keyword()) :: {:ok, tool_result()} | {:error, map()}
  def get_operational_control(arguments, opts) when is_map(arguments) and is_list(opts) do
    # Deterministic query path (jido-e10-t30): no query argument. A client calls
    # this tool by name to retrieve the canonical control overview and its proof
    # instead of guessing an operational-control term in search_docs.
    if map_size(arguments) > 0 do
      {:error, %{"code" => "invalid_arguments", "message" => "get_operational_control does not accept arguments"}}
    else
      pages_module = Keyword.get(opts, :pages_module, Pages)
      control_matrix_module = Keyword.get(opts, :control_matrix_module, ControlMatrix)

      with {:ok, page, resolution} <- resolve_docs_page(@control_overview_path, opts),
           {:ok, markdown} <- resolve_markdown(Pages.route_for(page), opts) do
        canonical_path = Pages.route_for(page)

        overview =
          %{
            "title" => page.title,
            "path" => canonical_path,
            "canonical_url" => MCP.canonical_url(canonical_path),
            "section" => Pages.docs_section_for_path(canonical_path),
            "markdown" => markdown,
            "legacy_resolution" => legacy_resolution_payload(@control_overview_path, canonical_path, resolution)
          }
          |> Enum.reject(fn {_key, value} -> is_nil(value) end)
          |> Map.new()

        dimensions =
          control_matrix_module.capabilities()
          |> Enum.map(fn capability ->
            %{
              "key" => to_string(capability.key),
              "label" => capability.label,
              "description" => capability.description
            }
          end)

        proof = %{
          "related_pages" => control_proof_pages(pages_module),
          "matrix_packages" => control_matrix_packages(control_matrix_module),
          "release_basis" => @control_release_basis
        }

        structured = %{
          "overview" => overview,
          "dimensions" => dimensions,
          "proof" => proof
        }

        {:ok,
         tool_result(
           "Returned the canonical operational-control overview (#{page.title}) with #{length(dimensions)} control dimensions and proof.",
           structured
         )}
      end
    end
  end

  def get_operational_control(_arguments, _opts) do
    {:error, %{"code" => "invalid_arguments", "message" => "get_operational_control expects an object argument"}}
  end

  @spec get_example(map(), keyword()) :: {:ok, tool_result()} | {:error, map()}
  def get_example(arguments, opts) when is_map(arguments) and is_list(opts) do
    # Example retrieval is the first scope expansion beyond the docs-only surface
    # (jido-e10-t18). A client retrieves one published example by path or slug and
    # receives its canonical Markdown — byte-identical to the public
    # /examples/<slug>.md endpoint, because both flow through MarkdownContent.resolve/2
    # — plus the example's proof and content metadata. Examples stay out of
    # search_docs (still docs-only); this is the deterministic retrieval path.
    with {:ok, requested} <- require_non_empty_string(arguments, "path"),
         {:ok, slug} <- normalize_example_path(requested),
         {:ok, example} <- resolve_example(slug, opts),
         {:ok, markdown} <- resolve_markdown("/examples/#{slug}", opts) do
      path = "/examples/#{slug}"

      structured =
        %{
          "title" => example.title,
          "path" => path,
          "canonical_url" => MCP.canonical_url(path),
          "category" => to_string(example.category),
          "markdown" => markdown,
          "metadata" => example_metadata_payload(example)
        }
        |> Enum.reject(fn {_key, value} -> is_nil(value) end)
        |> Map.new()

      {:ok, tool_result(markdown, structured)}
    end
  end

  def get_example(_arguments, _opts) do
    {:error, %{"code" => "invalid_arguments", "message" => "get_example expects an object argument"}}
  end

  @spec get_recommended_stack(map(), keyword()) :: {:ok, tool_result()} | {:error, map()}
  def get_recommended_stack(arguments, opts) when is_map(arguments) and is_list(opts) do
    # Ecosystem stack retrieval (jido-e10-t19): a client asks for a recommended
    # package set — one of the three recommended starting stacks (Core, AI,
    # Operate) — and receives its packages with explicit supported ranges,
    # source, support level, package-page links, and a copyable mix.exs deps/0
    # block. Omit the stack key to browse all three. Package composition and
    # ranges flow straight from AgentJido.Ecosystem.Stacks — the single source of
    # truth for the home dependency blocks and the Ecosystem compatibility matrix
    # — so the recommended set a client installs cannot drift from the browser
    # surface or the /ecosystem markdown hub.
    stacks_module = Keyword.get(opts, :stacks_module, Stacks)
    requested = Map.get(arguments, "stack")

    with {:ok, requested_key} <- normalize_stack_key(requested, stacks_module) do
      selected =
        stacks_module.matrix()
        |> Enum.filter(fn stack -> requested_key == nil or stack.key == requested_key end)

      stacks_payload = Enum.map(selected, &stack_payload(&1, stacks_module))
      structured = %{"stacks" => stacks_payload}

      package_count =
        stacks_payload
        |> Enum.map(fn stack -> length(stack["packages"]) end)
        |> Enum.sum()

      {:ok, tool_result(recommended_stack_summary(stacks_payload, package_count), structured)}
    end
  end

  def get_recommended_stack(_arguments, _opts) do
    {:error, %{"code" => "invalid_arguments", "message" => "get_recommended_stack expects an object argument"}}
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

  defp resolve_example(slug, opts) do
    examples_module = Keyword.get(opts, :examples_module, Examples)

    case examples_module.get_example(slug) do
      %Example{} = example -> {:ok, example}
      nil -> {:error, %{"code" => "not_found", "message" => "No example exists for #{inspect(slug)}"}}
    end
  end

  # Accepts an example path (/examples/<slug> or /examples/<slug>.md), a bare
  # slug (counter-agent), or a same-site URL, and returns the single-segment
  # slug the Examples registry keys on. Multi-segment and non-example paths
  # resolve to a not_found error so the tool cannot serve a non-example route.
  defp normalize_example_path(value) when is_binary(value) do
    trimmed = String.trim(value)

    if trimmed == "" do
      {:error, %{"code" => "invalid_arguments", "message" => "path must be a non-empty string"}}
    else
      case trimmed |> extract_example_slug() do
        nil ->
          {:error, %{"code" => "not_found", "message" => "No example exists for #{inspect(trimmed)}"}}

        slug ->
          {:ok, slug}
      end
    end
  end

  defp normalize_example_path(_value) do
    {:error, %{"code" => "invalid_arguments", "message" => "path must be a string"}}
  end

  defp extract_example_slug(value) do
    # URL.normalize_href extracts the path from a same-site absolute URL and
    # passes rooted paths through unchanged, but it rejects scheme-less bare
    # slugs (treating them as malformed absolute URLs). Fall back to a rooted
    # form of the value so a bare slug like "counter-agent" is accepted.
    candidate =
      case URL.normalize_href(value) do
        normalized when is_binary(normalized) ->
          normalized

        nil ->
          if String.starts_with?(value, "/"), do: value, else: "/" <> value
      end

    candidate
    |> strip_markdown_suffix()
    |> example_slug_from_path()
  end

  defp example_slug_from_path("/examples/" <> rest) do
    trimmed = String.trim(rest)
    if trimmed != "" and not String.contains?(trimmed, "/"), do: trimmed, else: nil
  end

  defp example_slug_from_path("/" <> slug) do
    # A bare slug (e.g. "counter-agent") reaches here as "/counter-agent".
    trimmed = String.trim(slug)
    if trimmed != "" and not String.contains?(trimmed, "/"), do: trimmed, else: nil
  end

  defp example_slug_from_path(_other), do: nil

  defp legacy_resolution_payload(_requested_path, _canonical_path, :canonical), do: nil

  defp legacy_resolution_payload(requested_path, canonical_path, resolution) do
    %{
      "requested_path" => requested_path,
      "resolved_path" => canonical_path,
      "resolution" => to_string(resolution)
    }
  end

  # The docs pages the overview cites as proof, resolved to their titles through
  # the page registry so a client gets a stable, human-readable pointer for each.
  defp control_proof_pages(pages_module) do
    @control_proof_pages
    |> Enum.map(fn path ->
      case pages_module.get_page_by_path(path) do
        %{title: title} ->
          %{
            "title" => title,
            "path" => path,
            "canonical_url" => MCP.canonical_url(path)
          }

        nil ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  # The control packages whose package pages carry release version, support level,
  # and proof. Comes from ControlMatrix so the pointers cannot drift from the
  # browser and ecosystem-markdown matrix (jido-e10-t29).
  defp control_matrix_packages(control_matrix_module) do
    control_matrix_module.package_columns()
    |> Enum.map(fn column ->
      %{
        "key" => column.key,
        "label" => column.label,
        "path" => column.path,
        "canonical_url" => MCP.canonical_url(column.path)
      }
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> Map.new()
    end)
  end

  # Optional stack key: absent (or nil) returns all three recommended starting
  # stacks; a known key returns just that one. Matched case-insensitively so a
  # client passing "Core" or "AI" still resolves. Unknown keys and non-strings
  # are rejected so the tool cannot fabricate a recommended package set.
  defp normalize_stack_key(nil, _stacks_module), do: {:ok, nil}

  defp normalize_stack_key(value, stacks_module) when is_binary(value) do
    trimmed = String.trim(value)

    if trimmed == "" do
      {:error, %{"code" => "invalid_arguments", "message" => "stack must be a non-empty string"}}
    else
      known = Enum.map(stacks_module.stacks(), & &1.key)
      candidate = String.downcase(trimmed)

      if candidate in known do
        {:ok, candidate}
      else
        {:error,
         %{
           "code" => "not_found",
           "message" =>
             "No recommended stack exists for #{inspect(trimmed)} (expected one of #{Enum.join(known, ", ")})"
         }}
      end
    end
  end

  defp normalize_stack_key(_value, _stacks_module) do
    {:error, %{"code" => "invalid_arguments", "message" => "stack must be a string"}}
  end

  # One recommended package set: the stack identity, each package with its
  # explicit range/source/support and package-page link, and the copyable
  # mix.exs deps/0 block (built from the same enriched rows the Ecosystem
  # compatibility matrix renders).
  defp stack_payload(matrix_stack, stacks_module) do
    %{
      "key" => matrix_stack.key,
      "name" => matrix_stack.name,
      "purpose" => matrix_stack.purpose,
      "packages" => Enum.map(matrix_stack.packages, &stack_package_payload/1),
      "dependency_block" => stacks_module.dependency_block(matrix_stack.packages)
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp stack_package_payload(pkg) do
    %{
      "name" => pkg.name,
      "role" => pkg.role,
      "range" => pkg.range,
      "source" => to_string(pkg.source),
      "source_label" => pkg.source_label,
      "support_level" => to_string(pkg.support_level),
      "path" => pkg.path,
      "canonical_url" => MCP.canonical_url(pkg.path)
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp recommended_stack_summary([], _package_count) do
    "Returned no recommended starting stacks."
  end

  defp recommended_stack_summary([stack], package_count) do
    "Returned the #{stack["name"]} recommended starting stack (#{package_count} package#{plural_suffix(package_count)}) with a copyable mix.exs deps block."
  end

  defp recommended_stack_summary(stacks, package_count) do
    "Returned #{length(stacks)} recommended starting stacks (#{package_count} package#{plural_suffix(package_count)} total) with copyable mix.exs deps blocks."
  end

  defp plural_suffix(1), do: ""
  defp plural_suffix(_count), do: "s"

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

  defp get_operational_control_input_schema do
    %{
      "type" => "object",
      "additionalProperties" => false,
      "properties" => %{}
    }
  end

  defp get_operational_control_output_schema do
    %{
      "type" => "object",
      "required" => ["overview", "dimensions", "proof"],
      "properties" => %{
        "overview" => %{
          "type" => "object",
          "required" => ["title", "path", "canonical_url", "section", "markdown"],
          "properties" => %{
            "title" => %{"type" => "string"},
            "path" => %{"type" => "string"},
            "canonical_url" => %{"type" => "string"},
            "section" => %{"type" => "string"},
            "markdown" => %{"type" => "string"},
            "legacy_resolution" => %{"type" => "object"}
          }
        },
        "dimensions" => %{
          "type" => "array",
          "items" => %{
            "type" => "object",
            "required" => ["key", "label", "description"],
            "properties" => %{
              "key" => %{"type" => "string"},
              "label" => %{"type" => "string"},
              "description" => %{"type" => "string"}
            }
          }
        },
        "proof" => %{
          "type" => "object",
          "required" => ["related_pages", "matrix_packages", "release_basis"],
          "properties" => %{
            "related_pages" => %{
              "type" => "array",
              "items" => %{
                "type" => "object",
                "required" => ["title", "path", "canonical_url"],
                "properties" => %{
                  "title" => %{"type" => "string"},
                  "path" => %{"type" => "string"},
                  "canonical_url" => %{"type" => "string"}
                }
              }
            },
            "matrix_packages" => %{
              "type" => "array",
              "items" => %{
                "type" => "object",
                "required" => ["key", "label"],
                "properties" => %{
                  "key" => %{"type" => "string"},
                  "label" => %{"type" => "string"},
                  "path" => %{"type" => "string"},
                  "canonical_url" => %{"type" => "string"}
                }
              }
            },
            "release_basis" => %{"type" => "string"}
          }
        }
      }
    }
  end

  defp get_example_input_schema do
    %{
      "type" => "object",
      "additionalProperties" => false,
      "required" => ["path"],
      "properties" => %{
        "path" => %{"type" => "string", "minLength" => 1}
      }
    }
  end

  defp get_example_output_schema do
    %{
      "type" => "object",
      "required" => ["title", "path", "canonical_url", "category", "markdown", "metadata"],
      "properties" => %{
        "title" => %{"type" => "string"},
        "path" => %{"type" => "string"},
        "canonical_url" => %{"type" => "string"},
        "category" => %{"type" => "string"},
        "markdown" => %{"type" => "string"},
        "metadata" => %{
          "type" => "object",
          "properties" => %{
            "content_type" => %{"type" => "string"},
            "status" => %{"type" => "string"},
            "version" => %{"type" => "string"},
            "last_validated" => %{"type" => "string"},
            "outcome" => %{"type" => "string"},
            "packages" => %{"type" => "array", "items" => %{"type" => "string"}},
            "package_maturity" => %{"type" => "string"},
            "difficulty" => %{"type" => "string"},
            "run_command" => %{"type" => "string"}
          }
        }
      }
    }
  end

  defp get_recommended_stack_input_schema do
    %{
      "type" => "object",
      "additionalProperties" => false,
      "properties" => %{
        "stack" => %{
          "type" => "string",
          "minLength" => 1,
          "enum" => ["core", "ai", "operate"],
          "description" =>
            "Optional recommended starting stack key: core (runtime foundation), ai (LLM-backed agents), or operate (production). Omit to return all three."
        }
      }
    }
  end

  defp get_recommended_stack_output_schema do
    %{
      "type" => "object",
      "required" => ["stacks"],
      "properties" => %{
        "stacks" => %{
          "type" => "array",
          "items" => %{
            "type" => "object",
            "required" => ["key", "name", "purpose", "packages"],
            "properties" => %{
              "key" => %{"type" => "string"},
              "name" => %{"type" => "string"},
              "purpose" => %{"type" => "string"},
              "packages" => %{
                "type" => "array",
                "items" => %{
                  "type" => "object",
                  "required" => ["name", "role", "path"],
                  "properties" => %{
                    "name" => %{"type" => "string"},
                    "role" => %{"type" => "string"},
                    "range" => %{"type" => "string"},
                    "source" => %{"type" => "string", "enum" => ["hex", "github", "unknown"]},
                    "source_label" => %{"type" => "string"},
                    "support_level" => %{
                      "type" => "string",
                      "enum" => ["stable", "beta", "experimental"]
                    },
                    "path" => %{"type" => "string"},
                    "canonical_url" => %{"type" => "string"}
                  }
                }
              },
              "dependency_block" => %{"type" => "string"}
            }
          }
        }
      }
    }
  end

  # The example's structured metadata: the proof contract (outcome, packages,
  # maturity, difficulty, run command) plus the content metadata (content type,
  # status, version, last validated). The content-metadata fields mirror
  # AgentJidoWeb.MarkdownContent's private example_metadata/1 exactly so the
  # structured `metadata.status`/`version`/`last_validated` agree with the
  # `## Content metadata` block appended to the returned `markdown`
  # (jido-e10-t16). Keep these in step with that module.
  defp example_metadata_payload(%Example{} = example) do
    %{
      "content_type" => "Example",
      "status" => example_status_label(example),
      "version" => tested_with_label(example.tested_with),
      "last_validated" => present_string(example.last_validated),
      "outcome" => present_string(example.outcome),
      "packages" => Enum.map(List.wrap(example.packages), &to_string/1),
      "package_maturity" => present_string(example.package_maturity),
      "difficulty" => to_string(example.difficulty),
      "run_command" => present_string(example.run_command)
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  # Mirrors AgentJidoWeb.MarkdownContent.example_status_label/1: an example's
  # best maturity signal is its package_maturity, falling back to the live/draft
  # lifecycle label.
  defp example_status_label(%Example{} = example) do
    case present_string(example.package_maturity) do
      nil -> lifecycle_label(example.status)
      maturity -> maturity
    end
  end

  defp lifecycle_label(:live), do: "Live"
  defp lifecycle_label(:draft), do: "Draft"
  defp lifecycle_label(other) when is_atom(other), do: other |> Atom.to_string() |> String.capitalize()
  defp lifecycle_label(_), do: nil

  # Mirrors AgentJidoWeb.MarkdownContent.tested_with_label/1.
  defp tested_with_label(value) when is_map(value) and map_size(value) > 0 do
    value
    |> Enum.map(fn {pkg, ver} -> "#{pkg} #{ver}" end)
    |> Enum.sort()
    |> Enum.join(", ")
  end

  defp tested_with_label(_), do: nil

  # Mirrors AgentJidoWeb.MarkdownContent.present_string/1.
  defp present_string(value) do
    case value |> to_string() |> String.trim() do
      "" -> nil
      other -> other
    end
  end
end
