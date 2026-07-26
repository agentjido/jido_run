defmodule AgentJido.MCP.DocsCLI do
  @moduledoc """
  CLI helper for asking questions against the docs MCP HTTP endpoint.
  """

  alias AgentJido.MCP.HTTPClient

  @default_endpoint "http://localhost:4001/mcp/docs"
  @default_limit 5
  @default_read_count 1
  @preview_line_count 12

  @spec main([String.t()]) :: no_return()
  def main(argv) when is_list(argv) do
    case run(argv) do
      {:ok, output} ->
        IO.puts(output)
        System.halt(0)

      {:error, output} ->
        IO.puts(:stderr, output)
        System.halt(1)
    end
  end

  @spec run([String.t()], keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def run(argv, opts \\ []) when is_list(argv) and is_list(opts) do
    argv = normalize_argv(argv)

    {switches, positional, invalid} =
      OptionParser.parse(argv,
        strict: [
          endpoint: :string,
          limit: :integer,
          read: :integer,
          json: :boolean,
          sections: :boolean,
          control: :boolean,
          get: :string,
          help: :boolean
        ],
        aliases: [e: :endpoint, l: :limit, r: :read, j: :json, s: :sections, c: :control, g: :get, h: :help]
      )

    with :ok <- validate_invalid(invalid),
         {:ok, command} <- build_command(switches, positional),
         :ok <- validate_numeric_bounds(switches),
         endpoint <- endpoint(switches),
         client_module <- Keyword.get(opts, :client_module, HTTPClient),
         {:ok, _init} <- client_module.initialize(endpoint, []),
         {:ok, payload} <- execute(command, endpoint, switches, client_module),
         {:ok, output} <- render(payload, command, switches) do
      {:ok, output}
    else
      {:error, message} ->
        {:error, usage(message)}
    end
  end

  defp normalize_argv(["--" | rest]), do: rest
  defp normalize_argv(argv), do: argv

  defp validate_invalid([]), do: :ok

  defp validate_invalid(invalid) do
    invalid_message =
      invalid
      |> Enum.map(fn {flag, _value} -> flag end)
      |> Enum.map_join(", ", &to_string/1)

    {:error, "Unknown options: #{invalid_message}"}
  end

  defp build_command(switches, positional) do
    case command_conflict(switches, positional) do
      nil ->
        resolve_command(switches, positional)

      message ->
        {:error, message}
    end
  end

  defp command_conflict(switches, positional) do
    cond do
      switches[:help] ->
        nil

      switches[:sections] && (is_binary(switches[:get]) || positional != []) ->
        "--sections cannot be combined with a query or --get"

      switches[:control] && (switches[:sections] || is_binary(switches[:get]) || positional != []) ->
        "--control cannot be combined with a query, --sections, or --get"

      switches[:get] && positional != [] ->
        "--get cannot be combined with a free-form query"

      true ->
        nil
    end
  end

  defp resolve_command(switches, positional) do
    cond do
      switches[:help] ->
        {:error, nil}

      switches[:sections] ->
        {:ok, :sections}

      switches[:control] ->
        {:ok, :control}

      is_binary(switches[:get]) ->
        {:ok, {:get, switches[:get]}}

      true ->
        resolve_search_command(positional)
    end
  end

  defp resolve_search_command(positional) when positional != [], do: {:ok, {:search, Enum.join(positional, " ")}}
  defp resolve_search_command(_positional), do: {:error, "Pass a question, or use --sections, --control, or --get /docs/..."}

  defp validate_numeric_bounds(switches) do
    case switches[:limit] do
      value when is_integer(value) and value <= 0 -> {:error, "--limit must be greater than 0"}
      _other -> validate_read_count(switches[:read])
    end
  end

  defp validate_read_count(value) when is_integer(value) and value < 0, do: {:error, "--read must be 0 or greater"}
  defp validate_read_count(_value), do: :ok

  defp endpoint(switches) do
    switches[:endpoint] || System.get_env("MCP_DOCS_URL") || @default_endpoint
  end

  defp execute(:sections, endpoint, _switches, client_module) do
    client_module.list_sections(endpoint, [])
  end

  defp execute(:control, endpoint, _switches, client_module) do
    client_module.get_operational_control(endpoint, [])
  end

  defp execute({:get, path}, endpoint, _switches, client_module) do
    client_module.get_doc(endpoint, path, [])
  end

  defp execute({:search, query}, endpoint, switches, client_module) do
    limit = switches[:limit] || @default_limit
    read_count = switches[:read] || @default_read_count

    with {:ok, search_result} <- client_module.search_docs(endpoint, query, limit, []),
         {:ok, previews} <- maybe_fetch_previews(search_result, endpoint, client_module, read_count) do
      {:ok, %{"search" => search_result, "previews" => previews}}
    end
  end

  defp maybe_fetch_previews(_search_result, _endpoint, _client_module, 0), do: {:ok, []}

  defp maybe_fetch_previews(search_result, endpoint, client_module, read_count) do
    results =
      search_result
      |> structured_content()
      |> Map.get("results", [])
      |> Enum.take(read_count)

    previews =
      Enum.map(results, fn result ->
        path = result["path"]

        case client_module.get_doc(endpoint, path, []) do
          {:ok, doc_result} ->
            structured = structured_content(doc_result)

            %{
              "title" => structured["title"],
              "path" => structured["path"],
              "section" => structured["section"],
              "preview" => markdown_preview(structured["markdown"])
            }

          {:error, message} ->
            %{
              "title" => result["title"],
              "path" => path,
              "error" => message
            }
        end
      end)

    {:ok, previews}
  end

  defp render(payload, command, switches) do
    if switches[:json] do
      {:ok, Jason.encode!(payload, pretty: true)}
    else
      render_plain(payload, command)
    end
  end

  defp render_plain(%{"search" => search_result, "previews" => previews}, {:search, query}) do
    structured = structured_content(search_result)
    results = Map.get(structured, "results", [])

    lines =
      [
        "Question: #{query}",
        "Retrieval status: #{Map.get(structured, "retrieval_status", "unknown")}",
        ""
      ] ++
        render_search_results(results) ++
        render_previews(previews)

    {:ok, Enum.join(lines, "\n")}
  end

  defp render_plain(result, {:get, _path}) do
    structured = structured_content(result)

    lines =
      [
        "Title: #{structured["title"]}",
        "Path: #{structured["path"]}",
        "Section: #{structured["section"]}",
        "Canonical URL: #{structured["canonical_url"]}",
        maybe_line("GitHub URL", structured["github_url"]),
        maybe_line("Livebook URL", structured["livebook_url"])
      ]
      |> Enum.reject(&is_nil/1)
      |> Kernel.++(["", "Preview:", markdown_preview(structured["markdown"])])

    {:ok, Enum.join(lines, "\n")}
  end

  defp render_plain(result, :sections) do
    sections =
      result
      |> structured_content()
      |> Map.get("sections", [])

    lines =
      ["Documentation sections: #{length(sections)}", ""] ++
        Enum.flat_map(sections, &render_section/1)

    {:ok, Enum.join(lines, "\n")}
  end

  defp render_plain(result, :control) do
    structured = structured_content(result)
    overview = Map.get(structured, "overview", %{})
    dimensions = Map.get(structured, "dimensions", [])
    proof = Map.get(structured, "proof", %{})

    lines =
      [
        "Operational control overview: #{overview["title"]}",
        "Path: #{overview["path"]}",
        "Canonical URL: #{overview["canonical_url"]}",
        "",
        "Control dimensions: #{length(dimensions)}"
      ] ++
        Enum.flat_map(dimensions, fn dimension ->
          ["  - #{dimension["label"]}: #{dimension["description"]}"]
        end) ++
        render_control_proof(proof) ++
        ["", "Overview preview:", markdown_preview(overview["markdown"])]

    {:ok, Enum.join(lines, "\n")}
  end

  defp render_control_proof(%{"related_pages" => related, "matrix_packages" => packages, "release_basis" => release_basis}) do
    related_lines =
      case related do
        [] -> []
        _ -> ["", "Proof pages:"] ++ Enum.map(related, &"  - #{&1["title"]} (#{&1["path"]})")
      end

    package_lines =
      case packages do
        [] -> []
        _ -> ["", "Package proof:"] ++ Enum.map(packages, &"  - #{&1["label"]} (#{&1["path"]})")
      end

    basis_lines = if is_binary(release_basis) and release_basis != "", do: ["", "Release basis: #{release_basis}"], else: []

    related_lines ++ package_lines ++ basis_lines
  end

  defp render_control_proof(_proof), do: []

  defp render_search_results([]), do: ["No matching documentation pages found."]

  defp render_search_results(results) do
    ["Top matches:"] ++
      Enum.flat_map(Enum.with_index(results, 1), fn {result, index} ->
        [
          "#{index}. #{result["title"]}",
          "   #{result["path"]}",
          "   section=#{result["section"]} score=#{format_score(result["score"])}",
          "   #{result["snippet"]}",
          ""
        ]
      end)
  end

  defp render_previews([]), do: []

  defp render_previews(previews) do
    ["Top doc previews:"] ++
      Enum.flat_map(previews, fn preview ->
        case preview do
          %{"error" => message, "path" => path, "title" => title} ->
            [title || "Document", "   #{path}", "   error=#{message}", ""]

          %{"title" => title, "path" => path, "section" => section, "preview" => body} ->
            [title, "   #{path} (#{section})", indent_block(body, 3), ""]
        end
      end)
  end

  defp render_section(section) do
    header = "#{section["title"]} (#{section["section"]})"
    root = "  root: #{section["path"]}"
    count = "  pages: #{section["page_count"]}"

    pages =
      Enum.map(section["pages"], fn page ->
        "  - #{page["title"]} (#{page["path"]})"
      end)

    [header, root, count] ++ pages ++ [""]
  end

  defp structured_content(%{"structuredContent" => structured}) when is_map(structured), do: structured
  defp structured_content(result) when is_map(result), do: result

  defp maybe_line(_label, nil), do: nil
  defp maybe_line(label, value), do: "#{label}: #{value}"

  defp format_score(score) when is_float(score), do: :erlang.float_to_binary(score, decimals: 3)
  defp format_score(score) when is_integer(score), do: Integer.to_string(score)
  defp format_score(_score), do: "n/a"

  defp markdown_preview(markdown) when is_binary(markdown) do
    markdown
    |> String.split("\n")
    |> drop_until_heading()
    |> Enum.map(&String.trim_trailing/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.take(@preview_line_count)
    |> Enum.join("\n")
  end

  defp markdown_preview(_markdown), do: "No markdown preview available."

  defp drop_until_heading(lines) do
    case Enum.drop_while(lines, &(not String.starts_with?(&1, "#"))) do
      [] -> lines
      remaining -> remaining
    end
  end

  defp indent_block(block, spaces) do
    prefix = String.duplicate(" ", spaces)

    block
    |> String.split("\n")
    |> Enum.map_join("\n", &(prefix <> &1))
  end

  defp usage(reason) do
    banner =
      [
        reason,
        "Usage:",
        "  mix run scripts/ask_mcp_docs.exs -- \"How do plugins work?\"",
        "  mix run scripts/ask_mcp_docs.exs -- --get /docs/learn/ai-chat-agent",
        "  mix run scripts/ask_mcp_docs.exs -- --sections",
        "  mix run scripts/ask_mcp_docs.exs -- --control",
        "",
        "Options:",
        "  -e, --endpoint URL   MCP docs endpoint (default: #{@default_endpoint})",
        "  -l, --limit N        Search result limit (default: #{@default_limit})",
        "  -r, --read N         Fetch previews for the top N search hits (default: #{@default_read_count})",
        "  -g, --get PATH       Fetch one docs page by canonical or legacy path",
        "  -s, --sections       List documentation sections and child pages",
        "  -c, --control        Retrieve the canonical operational-control overview and proof",
        "  -j, --json           Print JSON instead of formatted text",
        "  -h, --help           Show this message"
      ]
      |> Enum.reject(&is_nil/1)

    Enum.join(banner, "\n")
  end
end
