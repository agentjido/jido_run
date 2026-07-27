defmodule AgentJido.Release.OrphanPageReport do
  @moduledoc """
  Reports orphan public content pages — published Pages-system pages that have
  neither an inbound navigation link nor an inbound related-content link.

  A published page is **reachable** when EITHER:

    * it appears in the navigation menu (`page.in_menu == true`), which the
      per-section sidebar renders, OR
    * at least one other published page or HEEX/EX template links to its route
      (a related-content link).

  An **orphan** is a published page that satisfies neither condition — it cannot
  be reached by following any link from the rest of the site.

  Inbound link targets are collected from every content surface
  (`priv/pages`, `priv/blog`, `priv/examples`, `priv/ecosystem`) and from static
  `lib/agent_jido_web/**` navigation/related-content links, so a page linked from
  a blog post, example, ecosystem page, or template counts as reachable. Links
  inside Livebook code fences and dynamically interpolated HEEX links
  (`navigate={...}`) are ignored — the former are not navigation, and the latter
  are covered by the `in_menu` signal since the sidebar renders them.

  The public page set mirrors the router's compile-time `@page_routes`: published
  `AgentJido.Pages` routes, excluding the retired `/training/*` surface and the
  `/docs` index alias (served by its own route). Draft pages are already excluded
  by the Pages pipeline (`all_pages/0`).
  """

  @internal_md_link ~r/\]\((\/[^)\s]+)\)/
  @heex_link ~r/(?:navigate|patch|href)="(\/[^"]+)"/

  @type page_entry :: %{
          route: String.t(),
          source_path: String.t(),
          title: String.t(),
          in_menu: boolean(),
          inbound: [String.t()]
        }

  @type report :: %{
          generated_at: DateTime.t(),
          public_page_count: non_neg_integer(),
          in_menu_count: non_neg_integer(),
          linked_count: non_neg_integer(),
          orphans: [page_entry()],
          menu_only: [page_entry()],
          report_path: String.t()
        }

  @type option :: {:root, String.t()} | {:report_path, String.t()}

  @doc """
  Run the orphan-page analysis against the site and write the markdown report.

  Returns `{:ok, report}` when no orphans exist and `{:error, report}` when one
  or more published pages have no inbound navigation or related-content link.
  """
  @spec run([option()]) :: {:ok, report()} | {:error, report()}
  def run(opts \\ []) do
    root = opts |> Keyword.get(:root, File.cwd!()) |> Path.expand()

    report_path =
      opts |> Keyword.get(:report_path, "tmp/orphan_page_report.md") |> resolve_report_path(root)

    inbound = collect_inbound_links(root)
    pages = public_pages()

    classified = classify(pages, inbound, root)

    report = %{
      generated_at: DateTime.utc_now(),
      public_page_count: length(classified.entries),
      in_menu_count: Enum.count(classified.entries, & &1.in_menu),
      linked_count: Enum.count(classified.entries, &(&1.inbound != [])),
      orphans: classified.orphans,
      menu_only: classified.menu_only,
      report_path: report_path
    }

    write_report(report)

    if report.orphans == [] do
      {:ok, report}
    else
      {:error, report}
    end
  end

  @doc """
  Enumerate the public content pages under audit as `{route, page}` pairs.

  Mirrors the router's `@page_routes`: every published `AgentJido.Pages` route
  except the `/docs` index alias and the retired `/training/*` surface.
  """
  @spec public_pages() :: [{String.t(), map()}]
  def public_pages do
    AgentJido.Pages.all_pages()
    |> Enum.map(fn page -> {AgentJido.Pages.route_for(page), page} end)
    |> Enum.reject(fn {route, _page} ->
      route == "/docs" or String.starts_with?(route, "/training/")
    end)
  end

  @doc """
  Classify candidate pages against an inbound-link map (pure function).

  `pages` is a list of `{route, page}` pairs where `page` exposes `source_path`,
  `title`, and `in_menu`. `inbound` maps a normalized target path to a list of
  source strings (`"relative/path:line"`). `root` is the repo root used to
  relativize each page's `source_path` so a page that only links to itself does
  not count as its own inbound link.

  Returns the full entry list plus the `orphans` (no menu entry, no inbound link)
  and `menu_only` (in the menu but with no related-content link) subsets.
  """
  @spec classify([{String.t(), map()}], %{String.t() => [String.t()]}, String.t()) :: %{
          entries: [page_entry()],
          orphans: [page_entry()],
          menu_only: [page_entry()]
        }
  def classify(pages, inbound, root) do
    entries =
      pages
      |> Enum.map(fn {route, page} ->
        # The Pages pipeline loads from the compiled app dir
        # (`_build/.../lib/agent_jido/priv/pages/...`). Normalize back to the
        # repo-relative `priv/pages/...` form so the report matches the inbound
        # sources scanned from the working tree and self-links are excluded.
        rel_source =
          page.source_path
          |> repo_relative_source()
          |> then(&Path.relative_to(&1, root))

        inbound_sources =
          inbound
          |> Map.get(route, [])
          |> Enum.reject(fn source -> source_file(source) == rel_source end)
          |> Enum.uniq()
          |> Enum.sort()

        %{
          route: route,
          source_path: rel_source,
          title: page.title,
          in_menu: page.in_menu,
          inbound: inbound_sources
        }
      end)
      |> Enum.sort_by(& &1.route)

    %{
      entries: entries,
      orphans: Enum.filter(entries, &orphan?/1),
      menu_only: Enum.filter(entries, &menu_only?/1)
    }
  end

  @doc """
  Collect inbound internal-link targets across all content surfaces and templates.

  Returns a map of normalized target path → list of `"relative/path:line"`
  source strings.
  """
  @spec collect_inbound_links(String.t()) :: %{String.t() => [String.t()]}
  def collect_inbound_links(root) do
    markdown_links =
      root
      |> content_markdown_paths()
      |> Enum.flat_map(&scan_markdown(root, &1))

    heex_links =
      root
      |> heex_paths()
      |> Enum.flat_map(&scan_heex(root, &1))
      # Dynamically interpolated HEEX links (e.g. navigate={route_for(p)}) are
      # covered by the `in_menu` signal; ignore them here.
      |> Enum.reject(&String.contains?(&1.target, "\#{"))

    (markdown_links ++ heex_links)
    |> Enum.reduce(%{}, fn entry, acc ->
      target = normalize_path(entry.target)
      Map.update(acc, target, [entry.source], fn sources -> [entry.source | sources] end)
    end)
    |> Map.new(fn {target, sources} -> {target, Enum.uniq(sources)} end)
  end

  @doc """
  Render the markdown report body.
  """
  @spec render_report(report()) :: String.t()
  def render_report(report) do
    [
      "# Orphan Page Report\n\n",
      "- Generated: #{DateTime.to_iso8601(report.generated_at)}\n",
      "- Public content pages checked: #{report.public_page_count}\n",
      "- Pages in navigation menu: #{report.in_menu_count}\n",
      "- Pages with an inbound related-content link: #{report.linked_count}\n",
      "- Orphan pages (no menu entry, no inbound link): #{length(report.orphans)}\n",
      "\n",
      orphan_section(report),
      menu_only_section(report)
    ]
    |> IO.iodata_to_binary()
  end

  # ---------------------------------------------------------------------------
  # Classification helpers
  # ---------------------------------------------------------------------------

  defp orphan?(%{in_menu: false, inbound: []}), do: true
  defp orphan?(_entry), do: false

  defp menu_only?(%{in_menu: true, inbound: []}), do: true
  defp menu_only?(_entry), do: false

  defp source_file(source) do
    source |> String.split(":") |> List.first()
  end

  defp repo_relative_source(source_path) do
    case String.split(source_path, "priv/pages/", parts: 2) do
      [_, rest] -> "priv/pages/" <> rest
      _ -> source_path
    end
  end

  # ---------------------------------------------------------------------------
  # Link scanning
  # ---------------------------------------------------------------------------

  defp content_markdown_paths(root) do
    ~w(priv/pages priv/blog priv/examples priv/ecosystem)
    |> Enum.flat_map(fn dir ->
      Path.wildcard(Path.join([root, dir, "**", "*.{md,livemd}"]))
    end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp heex_paths(root) do
    (Path.wildcard(Path.join(root, "lib/agent_jido_web/**/*.heex")) ++
       Path.wildcard(Path.join(root, "lib/agent_jido_web/**/*.ex")))
    |> Enum.sort()
  end

  defp scan_markdown(root, path) do
    relative = Path.relative_to(path, root)

    # Track fenced code blocks so links written inside ```, ~~~`, or indented
    # Elixir cells (mostly in Livebooks) are not mistaken for navigation links.
    {_, links} =
      path
      |> File.stream!([], :line)
      |> Stream.with_index(1)
      |> Enum.reduce({false, []}, fn {line, line_number}, {in_fence?, acc} ->
        cond do
          fence_boundary?(line) ->
            {not in_fence?, acc}

          in_fence? ->
            {in_fence?, acc}

          true ->
            entries =
              @internal_md_link
              |> Regex.scan(line)
              |> Enum.map(fn [_, target] ->
                %{target: target, source: "#{relative}:#{line_number}"}
              end)

            {in_fence?, entries ++ acc}
        end
      end)

    Enum.reverse(links)
  end

  defp scan_heex(root, path) do
    relative = Path.relative_to(path, root)

    path
    |> File.stream!([], :line)
    |> Stream.with_index(1)
    |> Enum.flat_map(fn {line, line_number} ->
      @heex_link
      |> Regex.scan(line)
      |> Enum.map(fn [_, target] ->
        %{target: target, source: "#{relative}:#{line_number}"}
      end)
    end)
  end

  defp fence_boundary?(line) do
    trimmed = String.trim_leading(line)
    String.starts_with?(trimmed, "```") or String.starts_with?(trimmed, "~~~")
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

  # ---------------------------------------------------------------------------
  # Report rendering helpers
  # ---------------------------------------------------------------------------

  defp orphan_section(%{orphans: []}) do
    "## Orphan Pages\n\nNo orphan pages found — every public content page has an " <>
      "inbound navigation or related-content link.\n"
  end

  defp orphan_section(%{orphans: orphans}) do
    lines =
      Enum.map(orphans, fn entry ->
        "- `#{entry.route}` — #{entry.title} (`#{entry.source_path}`)\n"
      end)

    ["## Orphan Pages\n\n", lines]
  end

  defp menu_only_section(%{menu_only: []}), do: ""

  defp menu_only_section(%{menu_only: menu_only}) do
    intro =
      "\n## Reachable Only Via the Menu\n\n" <>
        "These pages appear in the sidebar but have no related-content link from " <>
        "another page or template. They are not orphans (the menu reaches them), " <>
        "but they would become orphans if ever hidden from the menu.\n\n"

    lines =
      Enum.map(menu_only, fn entry ->
        "- `#{entry.route}` — #{entry.title} (`#{entry.source_path}`)\n"
      end)

    [intro, lines]
  end

  # ---------------------------------------------------------------------------
  # Report IO
  # ---------------------------------------------------------------------------

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
end
