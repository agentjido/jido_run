defmodule AgentJido.Release.LinkAudit do
  @moduledoc """
  Audits internal and external links for public website content.

  Internal links are matched against router patterns from `AgentJidoWeb.Router.__routes__/0`.
  The global catch-all route (`/*path`) is intentionally excluded so links that only
  resolve to a 404 fallback are still flagged.
  """

  @type source_kind :: :md | :heex
  @type link_ref :: %{source: String.t(), path: String.t(), kind: source_kind()}
  @type external_ref :: %{source: String.t(), url: String.t(), status: integer() | :error, reason: String.t() | nil}

  @type report :: %{
          generated_at: DateTime.t(),
          route_count: non_neg_integer(),
          internal_count: non_neg_integer(),
          unmatched_internal: [link_ref()],
          external_count: non_neg_integer(),
          external_warnings: [external_ref()],
          external_failures: [external_ref()],
          allowed_prefixes: [String.t()],
          report_path: String.t()
        }

  @type option ::
          {:root, String.t()}
          | {:include_heex, boolean()}
          | {:check_external, boolean()}
          | {:allow_prefixes, [String.t()]}
          | {:report_path, String.t()}

  @internal_md_link ~r/\]\((\/[^)\s]+)\)/
  @external_md_link ~r/\]\((https?:\/\/[^)\s]+)\)/
  @heex_link ~r/(?:navigate|patch|href)="(\/[^"]+)"/

  @doc """
  Run the link audit and write the markdown report.

  Returns `{:ok, report}` when no blocking findings exist and `{:error, report}`
  when unmatched internal links or external hard failures are detected.
  """
  @spec run([option()]) :: {:ok, report()} | {:error, report()}
  def run(opts \\ []) do
    root = opts |> Keyword.get(:root, File.cwd!()) |> Path.expand()
    include_heex = Keyword.get(opts, :include_heex, false)
    check_external = Keyword.get(opts, :check_external, false)
    allowed_prefixes = Keyword.get(opts, :allow_prefixes, [])
    report_path = opts |> Keyword.get(:report_path, "tmp/link_audit_report.md") |> resolve_report_path(root)

    routes = route_patterns()

    internal_links =
      root
      |> collect_markdown_internal_links()
      |> maybe_collect_heex_internal_links(root, include_heex)

    unmatched_internal =
      internal_links
      |> Enum.reject(
        &(ignored_path?(&1.path) or matches_any_route?(&1.path, routes) or
            legacy_redirect?(&1.path) or allowed_unmatched?(&1.path, allowed_prefixes))
      )

    {external_count, external_warnings, external_failures} =
      if check_external do
        root
        |> collect_markdown_external_links()
        |> Enum.uniq_by(& &1.url)
        |> check_external_links()
      else
        {0, [], []}
      end

    report = %{
      generated_at: DateTime.utc_now(),
      route_count: length(routes),
      internal_count: length(internal_links),
      unmatched_internal: Enum.sort_by(unmatched_internal, &{&1.path, &1.source}),
      external_count: external_count,
      external_warnings: Enum.sort_by(external_warnings, &{&1.url, &1.source}),
      external_failures: Enum.sort_by(external_failures, &{&1.url, &1.source}),
      allowed_prefixes: allowed_prefixes,
      report_path: report_path
    }

    write_report(report)

    if report.unmatched_internal == [] and report.external_failures == [] do
      {:ok, report}
    else
      {:error, report}
    end
  end

  @doc """
  Render the markdown report body.
  """
  @spec render_report(report()) :: String.t()
  def render_report(report) do
    [
      "# Link Audit Report\n\n",
      "- Generated: #{DateTime.to_iso8601(report.generated_at)}\n",
      "- Route patterns checked: #{report.route_count}\n",
      "- Internal links checked: #{report.internal_count}\n",
      "- Unmatched internal links: #{length(report.unmatched_internal)}\n",
      external_header_lines(report),
      allowed_prefix_line(report),
      "\n",
      unmatched_internal_section(report),
      external_warning_section(report),
      external_failure_section(report)
    ]
    |> IO.iodata_to_binary()
  end

  @spec route_patterns() :: [String.t()]
  def route_patterns do
    AgentJidoWeb.Router.__routes__()
    |> Enum.filter(&(&1.verb in [:get, :*]))
    |> Enum.map(&normalize_path(&1.path))
    |> Enum.reject(&(&1 == "/*path"))
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp collect_markdown_internal_links(root) do
    root
    |> markdown_paths()
    |> Enum.flat_map(&scan_file_for_links(root, &1, @internal_md_link, :md, :path, skip_code_fences: true))
    |> Enum.uniq()
  end

  defp maybe_collect_heex_internal_links(links, _root, false), do: links

  defp maybe_collect_heex_internal_links(links, root, true) do
    heex_links =
      root
      |> heex_paths()
      |> Enum.flat_map(&scan_file_for_links(root, &1, @heex_link, :heex, :path))
      |> Enum.reject(&String.contains?(&1.path, "\#{"))

    (links ++ heex_links) |> Enum.uniq()
  end

  defp collect_markdown_external_links(root) do
    root
    |> markdown_paths()
    |> Enum.flat_map(&scan_file_for_links(root, &1, @external_md_link, :md, :url, skip_code_fences: true))
    |> Enum.uniq()
  end

  defp scan_file_for_links(root, path, regex, kind, value_key, opts \\ []) do
    skip_code_fences = Keyword.get(opts, :skip_code_fences, false)
    relative = Path.relative_to(path, root)

    # Track fenced code blocks so links written inside ```, ~~~`, or indented
    # Elixir cells are not mistaken for navigation links. This matters most for
    # Livebooks, whose code cells frequently contain brackets and parentheses.
    {_, links} =
      path
      |> File.stream!([], :line)
      |> Stream.with_index(1)
      |> Enum.reduce({false, []}, fn {line, line_number}, {in_fence?, acc} ->
        cond do
          skip_code_fences and fence_boundary?(line) ->
            {not in_fence?, acc}

          skip_code_fences and in_fence? ->
            {in_fence?, acc}

          true ->
            matches = extract_matches(regex, line, value_key, relative, line_number, kind)

            {in_fence?, Enum.reduce(matches, acc, fn match, inner -> [match | inner] end)}
        end
      end)

    Enum.reverse(links)
  end

  defp extract_matches(regex, line, value_key, relative, line_number, kind) do
    regex
    |> Regex.scan(line)
    |> Enum.map(&build_link_match(&1, value_key, relative, line_number, kind))
  end

  defp build_link_match([_full, captured], :path, relative, line_number, kind) do
    %{path: normalize_path(captured), source: "#{relative}:#{line_number}", kind: kind}
  end

  defp build_link_match([_full, captured], :url, relative, line_number, kind) do
    %{url: String.trim(captured), source: "#{relative}:#{line_number}", kind: kind}
  end

  defp fence_boundary?(line) do
    trimmed = String.trim_leading(line)
    String.starts_with?(trimmed, "```") or String.starts_with?(trimmed, "~~~")
  end

  defp markdown_paths(root) do
    (Path.wildcard(Path.join(root, "priv/pages/**/*.md")) ++
       Path.wildcard(Path.join(root, "priv/pages/**/*.livemd")))
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp heex_paths(root) do
    (Path.wildcard(Path.join(root, "lib/agent_jido_web/**/*.heex")) ++
       Path.wildcard(Path.join(root, "lib/agent_jido_web/**/*.ex")))
    |> Enum.sort()
  end

  defp normalize_path(path) do
    path
    |> String.trim()
    |> String.replace(~r/[?#].*$/, "")
    |> trim_trailing_slash()
  end

  defp trim_trailing_slash("/"), do: "/"

  defp trim_trailing_slash(path) do
    if String.ends_with?(path, "/"), do: String.trim_trailing(path, "/"), else: path
  end

  defp matches_any_route?(path, routes) do
    Enum.any?(routes, &route_matches?(path, &1))
  end

  defp route_matches?(path, route_pattern) do
    do_route_match?(segments(path), segments(route_pattern))
  end

  defp segments(path), do: path |> normalize_path() |> String.split("/", trim: true)

  defp do_route_match?(_path, [segment | _rest]) when binary_part(segment, 0, 1) == "*", do: true
  defp do_route_match?([], []), do: true
  defp do_route_match?(_path, []), do: false
  defp do_route_match?([], _route), do: false

  defp do_route_match?([path_segment | path_rest], [route_segment | route_rest]) do
    cond do
      String.starts_with?(route_segment, ":") -> do_route_match?(path_rest, route_rest)
      route_segment == path_segment -> do_route_match?(path_rest, route_rest)
      true -> false
    end
  end

  defp ignored_path?(path) do
    String.starts_with?(path, "/assets/") or
      String.starts_with?(path, "/images/") or
      String.starts_with?(path, "/fonts/") or
      path in ["/favicon.ico", "/robots.txt"]
  end

  defp allowed_unmatched?(path, prefixes) do
    Enum.any?(prefixes, &String.starts_with?(path, &1))
  end

  # A link to a path that the site redirects (301) to a canonical route is not
  # broken. This keeps the audit in parity with the runtime LegacyRedirects
  # table (jido-e01: E01-T13/T14/T15).
  defp legacy_redirect?(path) do
    is_binary(AgentJidoWeb.LegacyRedirects.destination(path))
  end

  defp check_external_links(external_links) do
    :ok = ensure_http_clients_started()

    {warnings, failures} =
      Enum.reduce(external_links, {[], []}, fn link, {warnings_acc, failures_acc} ->
        case external_status(link.url) do
          {:ok, status} when status in 200..399 ->
            {warnings_acc, failures_acc}

          {:ok, status} when status in [403, 405, 429] ->
            {[%{source: link.source, url: link.url, status: status, reason: nil} | warnings_acc], failures_acc}

          {:ok, status} ->
            {warnings_acc, [%{source: link.source, url: link.url, status: status, reason: nil} | failures_acc]}

          {:error, reason} ->
            error_reason = Exception.message(reason)
            {warnings_acc, [%{source: link.source, url: link.url, status: :error, reason: error_reason} | failures_acc]}
        end
      end)

    {length(external_links), warnings, failures}
  end

  defp ensure_http_clients_started do
    _ = Application.ensure_all_started(:inets)
    _ = Application.ensure_all_started(:ssl)
    :ok
  end

  defp external_status(url) do
    request = {String.to_charlist(url), [user_agent_header()]}
    http_opts = [timeout: 20_000, connect_timeout: 8_000, autoredirect: true]

    case :httpc.request(:get, request, http_opts, []) do
      {:ok, {{_http_version, status_code, _reason_phrase}, _headers, _body}} ->
        {:ok, status_code}

      {:error, reason} ->
        {:error, normalize_http_error(reason)}
    end
  end

  defp user_agent_header, do: {~c"user-agent", ~c"agentjido-link-audit/1.0"}

  defp normalize_http_error(reason) when is_atom(reason), do: %RuntimeError{message: Atom.to_string(reason)}
  defp normalize_http_error(reason) when is_binary(reason), do: %RuntimeError{message: reason}
  defp normalize_http_error(reason), do: %RuntimeError{message: inspect(reason)}

  defp resolve_report_path(report_path, root) do
    case Path.type(report_path) do
      :absolute -> report_path
      :relative -> Path.join(root, report_path)
      :volumerelative -> report_path
    end
  end

  defp write_report(report) do
    report.report_path
    |> Path.dirname()
    |> File.mkdir_p!()

    File.write!(report.report_path, render_report(report))
  end

  defp external_header_lines(%{external_count: count, external_warnings: warnings, external_failures: failures})
       when count > 0 do
    [
      "- External links checked (unique URLs): #{count}\n",
      "- External warnings: #{length(warnings)}\n",
      "- External failures: #{length(failures)}\n"
    ]
  end

  defp external_header_lines(_report), do: ""

  defp allowed_prefix_line(%{allowed_prefixes: []}), do: ""
  defp allowed_prefix_line(%{allowed_prefixes: prefixes}), do: "- Allowed unmatched prefixes: #{Enum.join(prefixes, " ")}\n"

  defp unmatched_internal_section(%{unmatched_internal: []}), do: ""

  defp unmatched_internal_section(%{unmatched_internal: unmatched_internal}) do
    grouped =
      unmatched_internal
      |> Enum.group_by(& &1.path, & &1.source)
      |> Enum.sort_by(fn {path, _sources} -> path end)
      |> Enum.map(fn {path, sources} ->
        "- `#{path}` (#{length(sources)}): #{Enum.join(Enum.sort(sources), ", ")}\n"
      end)

    ["## Unmatched Internal Links\n", grouped]
  end

  defp external_warning_section(%{external_warnings: []}), do: ""

  defp external_warning_section(%{external_warnings: warnings}) do
    lines =
      warnings
      |> Enum.map(fn warning ->
        "- `#{warning.url}` [#{warning.status}] at #{warning.source}\n"
      end)

    ["\n## External Link Warnings\n", lines]
  end

  defp external_failure_section(%{external_failures: []}), do: ""

  defp external_failure_section(%{external_failures: failures}) do
    lines =
      failures
      |> Enum.map(fn failure ->
        status =
          case failure.status do
            :error -> "error: #{failure.reason}"
            code -> to_string(code)
          end

        "- `#{failure.url}` [#{status}] at #{failure.source}\n"
      end)

    ["\n## External Link Failures\n", lines]
  end
end
