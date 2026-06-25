defmodule AgentJido.Pages do
  @moduledoc """
  Unified Pages system powered by NimblePublisher.

  Replaces the separate Documentation and Training pipelines with a single
  content system that loads pages from `priv/pages/`. Category is derived
  from the first subdirectory: docs/, training/, features/, build/, community/, compare/.

  Provides:
  - Compile-time parsing and validation of .md and .livemd files
  - Pre-indexed lookups by id, path, category, and tag
  - Hierarchical menu tree with proper ordering
  - Per-category prev/next navigation helpers
  - Breadcrumb generation
  - Route generation per category
  """

  alias AgentJido.Pages.MenuNode
  alias AgentJido.Pages.Page

  # NimblePublisher 2.0 parses entries inside `Task.async_stream`, which cannot
  # trigger lazy compilation of the modules our custom parser calls at parse
  # time. Force them to compile first (and register a compile-time dependency)
  # so they are available when the parallel parse tasks run.
  Code.ensure_compiled!(AgentJido.Pages.ContentExpander)
  Code.ensure_compiled!(AgentJido.ReleaseCatalog)
  Code.ensure_compiled!(AgentJido.Ecosystem)
  Code.ensure_compiled!(AgentJido.Ecosystem.Atlas)
  Code.ensure_compiled!(AgentJido.Ecosystem.SupportLevel)

  use NimblePublisher,
    build: Page,
    from: Application.app_dir(:agent_jido, "priv/pages/**/*.{md,livemd}"),
    as: :pages,
    highlighters: [:makeup_elixir, :makeup_js, :makeup_html],
    parser: AgentJido.Pages.LivebookParser

  # --- Compile-time indexes ---

  @pages Enum.sort_by(@pages, & &1.order)

  @published_pages Enum.reject(@pages, & &1.draft)

  @canonical_path_groups @pages
                         |> Enum.group_by(fn page ->
                           page.path
                           |> case do
                             "/" -> "/"
                             other -> String.trim_trailing(other, "/")
                           end
                         end)

  for {canonical_path, pages} <- @canonical_path_groups, length(pages) > 1 do
    files =
      pages
      |> Enum.map_join(", ", & &1.source_path)

    raise ArgumentError,
          "Duplicate canonical page path #{canonical_path}: #{files}"
  end

  @docs_pages Enum.filter(@pages, &(&1.category == :docs))

  for page <- @docs_pages do
    if Regex.match?(~r{/priv/pages/docs/[^/]+/index\.(md|livemd)$}, page.source_path) do
      raise ArgumentError,
            "Docs section roots must use /docs/<section>.md|livemd (not index.*): #{page.source_path}"
    end
  end

  @docs_section_shape Enum.reduce(@docs_pages, %{}, fn page, acc ->
                        segments =
                          page.path
                          |> String.trim_leading("/docs")
                          |> String.trim_leading("/")
                          |> String.split("/", trim: true)

                        case segments do
                          [section] when section != "" ->
                            Map.update(acc, section, %{root?: true, children?: false, child_paths: []}, fn state ->
                              %{state | root?: true}
                            end)

                          [section | _rest] when section != "" ->
                            Map.update(
                              acc,
                              section,
                              %{root?: false, children?: true, child_paths: [page.path]},
                              fn state ->
                                %{state | children?: true, child_paths: [page.path | state.child_paths]}
                              end
                            )

                          _other ->
                            acc
                        end
                      end)

  for {section, state} <- @docs_section_shape, state.children? and not state.root? do
    child_paths =
      state.child_paths
      |> Enum.uniq()
      |> Enum.sort()
      |> Enum.join(", ")

    raise ArgumentError,
          "Docs section #{section} has child pages but no root /docs/#{section}: #{child_paths}"
  end

  @legacy_path_entries (for page <- @pages,
                            legacy_path <- page.legacy_paths || [] do
                          normalized =
                            case legacy_path do
                              "/" -> "/"
                              other -> String.trim_trailing(other, "/")
                            end

                          {normalized, page}
                        end)

  @legacy_path_groups @legacy_path_entries |> Enum.group_by(fn {legacy_path, _page} -> legacy_path end)

  for {legacy_path, entries} <- @legacy_path_groups, length(entries) > 1 do
    paths =
      entries
      |> Enum.map_join(", ", fn {_legacy, page} -> page.path end)

    raise ArgumentError,
          "Duplicate legacy path #{legacy_path} is assigned to multiple pages: #{paths}"
  end

  @canonical_paths_set MapSet.new(Map.keys(@canonical_path_groups))

  for {legacy_path, page} <- @legacy_path_entries do
    if MapSet.member?(@canonical_paths_set, legacy_path) do
      raise ArgumentError,
            "Legacy path #{legacy_path} for #{page.path} conflicts with an existing canonical path"
    end
  end

  @pages_by_id Map.new(@published_pages, &{&1.id, &1})
  @pages_by_path Map.new(@published_pages, fn page ->
                   normalized =
                     case page.path do
                       "/" -> "/"
                       other -> String.trim_trailing(other, "/")
                     end

                   {normalized, page}
                 end)
  @pages_by_route Map.new(@published_pages, fn page ->
                    route =
                      case page.category do
                        :docs ->
                          case page.path do
                            "/" -> "/"
                            other -> String.trim_trailing(other, "/")
                          end

                        :training ->
                          "/training/#{page.id}"

                        :features ->
                          "/features/#{page.id}"

                        :build ->
                          "/build/#{page.id}"

                        :community ->
                          "/community/#{page.id}"

                        :compare ->
                          "/compare/#{page.id}"
                      end

                    {route, page}
                  end)
  @pages_by_legacy_path @legacy_path_entries
                        |> Enum.filter(fn {_legacy_path, page} -> not page.draft end)
                        |> Map.new()

  @pages_by_category @published_pages
                     |> Enum.group_by(& &1.category)
                     |> Map.new()

  @pages_by_tag @published_pages
                |> Enum.flat_map(fn page ->
                  for tag <- page.tags || [], do: {tag, page}
                end)
                |> Enum.group_by(fn {tag, _page} -> tag end, fn {_tag, page} -> page end)
                |> Map.new()

  @tags @published_pages
        |> Enum.flat_map(&(&1.tags || []))
        |> Enum.uniq()
        |> Enum.sort()

  @categories @published_pages
              |> Enum.map(& &1.category)
              |> Enum.uniq()
              |> Enum.sort()

  # --- Error module ---

  defmodule NotFoundError do
    @moduledoc """
    Raised when a page cannot be found by id or path.
    """
    defexception [:message, plug_status: 404]
  end

  # --- Public API ---

  @doc """
  Returns all published pages (excludes drafts), sorted by order.
  """
  @spec all_pages() :: [Page.t()]
  def all_pages, do: @published_pages

  @doc """
  Returns all pages including drafts, sorted by order.
  """
  @spec all_pages_including_drafts() :: [Page.t()]
  def all_pages_including_drafts, do: @pages

  @doc """
  Returns a page by its ID, raises `NotFoundError` if not found.
  """
  @spec get_page!(String.t()) :: Page.t()
  def get_page!(id) do
    Map.get(@pages_by_id, id) ||
      raise NotFoundError, "page with id=#{id} not found"
  end

  @doc """
  Returns a page by its ID, or nil if not found.
  """
  @spec get_page_by_id(String.t()) :: Page.t() | nil
  def get_page_by_id(id), do: Map.get(@pages_by_id, id)

  @doc """
  Returns a page by its path, or nil if not found.
  """
  @spec get_page_by_path(String.t()) :: Page.t() | nil
  def get_page_by_path(path), do: Map.get(@pages_by_path, normalize_path_lookup(path))

  @doc """
  Returns a page by its path, raises `NotFoundError` if not found.
  """
  @spec get_page_by_path!(String.t()) :: Page.t()
  def get_page_by_path!(path) do
    Map.get(@pages_by_path, normalize_path_lookup(path)) ||
      raise NotFoundError, "page with path=#{path} not found"
  end

  @doc """
  Returns a page by its legacy path alias, or nil if not found.
  """
  @spec get_page_by_legacy_path(String.t()) :: Page.t() | nil
  def get_page_by_legacy_path(path), do: Map.get(@pages_by_legacy_path, normalize_path_lookup(path))

  @doc """
  Resolves a request path against canonical and legacy lookups.
  """
  @spec resolve_page_for_path(String.t()) ::
          {:ok, Page.t(), :canonical | :legacy | :route_alias} | :error
  def resolve_page_for_path(path) do
    normalized = normalize_path_lookup(path)

    resolve_page_lookup(normalized, [
      {@pages_by_path, :canonical},
      {@pages_by_legacy_path, :legacy},
      {@pages_by_route, :route_alias}
    ])
  end

  defp resolve_page_lookup(_path, []), do: :error

  defp resolve_page_lookup(path, [{lookup, match_type} | rest]) do
    case Map.get(lookup, path) do
      %Page{} = page -> {:ok, page, match_type}
      nil -> resolve_page_lookup(path, rest)
    end
  end

  @doc """
  Returns all published pages in a given category, or empty list if none.
  """
  @spec pages_by_category(atom()) :: [Page.t()]
  def pages_by_category(category) when is_atom(category) do
    Map.get(@pages_by_category, category, [])
  end

  @doc """
  Returns all published pages with a given tag, or empty list if none.
  """
  @spec pages_by_tag(atom()) :: [Page.t()]
  def pages_by_tag(tag) when is_atom(tag) do
    Map.get(@pages_by_tag, tag, [])
  end

  @doc """
  Returns all unique tags across all published pages.
  """
  @spec all_tags() :: [atom()]
  def all_tags, do: @tags

  @doc """
  Returns all unique categories across all published pages.
  """
  @spec all_categories() :: [atom()]
  def all_categories, do: @categories

  @doc """
  Returns docs section root pages (`/docs/<section>`) ordered for secondary nav.
  """
  @spec docs_sections() :: [Page.t()]
  def docs_sections do
    :docs
    |> pages_by_category()
    |> Enum.filter(&(docs_section_root_page?(&1) and &1.in_menu))
    |> Enum.sort_by(&{&1.order, &1.path})
  end

  @doc """
  Returns docs pages in a section, including the section root and descendants.
  """
  @spec docs_section_pages(String.t()) :: [Page.t()]
  def docs_section_pages(section) when is_binary(section) do
    normalized_section = normalize_docs_section(section)

    :docs
    |> pages_by_category()
    |> Enum.filter(&(docs_page_in_section?(&1, normalized_section) and &1.in_menu))
    |> Enum.sort_by(fn page ->
      # Section root pages always sort first (0), regardless of their order value.
      # This decouples section-tab ordering (controlled by order) from sidebar position.
      root_priority = if docs_section_root_page?(page), do: 0, else: 1
      {root_priority, page.order, page.path}
    end)
  end

  @doc """
  Returns a docs section root page by section slug.
  """
  @spec docs_section_root(String.t()) :: Page.t() | nil
  def docs_section_root(section) when is_binary(section) do
    normalized_section = normalize_docs_section(section)

    :docs
    |> pages_by_category()
    |> Enum.find(fn page -> docs_section_root_page?(page) and docs_section_for_page(page) == normalized_section end)
  end

  @doc """
  Returns the docs section slug for a request path.
  """
  @spec docs_section_for_path(String.t()) :: String.t() | nil
  def docs_section_for_path(path) when is_binary(path) do
    normalized = normalize_path_lookup(path)

    case normalized |> String.trim_leading("/") |> String.split("/", trim: true) do
      ["docs", section | _rest] when section != "" -> section
      _other -> nil
    end
  end

  @doc """
  Returns docs legacy redirect pairs as `{legacy_path, canonical_path}`.
  """
  @spec docs_legacy_redirects() :: [{String.t(), String.t()}]
  def docs_legacy_redirects do
    @pages_by_legacy_path
    |> Enum.map(fn {legacy_path, page} -> {legacy_path, route_for(page)} end)
    |> Enum.filter(fn {_legacy_path, canonical_path} -> String.starts_with?(canonical_path, "/docs") end)
    |> Enum.sort()
  end

  @doc """
  Returns the total number of published pages.
  """
  @spec page_count() :: non_neg_integer()
  def page_count, do: length(@published_pages)

  @doc """
  Returns the full hierarchical menu tree for all published pages.
  """
  @spec menu_tree() :: [MenuNode.t()]
  def menu_tree, do: do_build_menu_tree(@published_pages)

  @doc """
  Returns the menu tree filtered to pages in a specific category.
  """
  @spec menu_tree(atom()) :: [MenuNode.t()]
  def menu_tree(category) when is_atom(category) do
    category
    |> pages_by_category()
    |> do_build_menu_tree()
  end

  @doc """
  Returns the previous and next pages within the same category.

  ## Examples

      iex> {prev, next} = Pages.neighbors("getting-started")
      iex> prev.id
      "overview"
  """
  @spec neighbors(String.t()) :: {Page.t() | nil, Page.t() | nil}
  def neighbors(id) do
    page = get_page_by_id(id)

    if page do
      category_pages = pages_by_category(page.category)
      idx = Enum.find_index(category_pages, &(&1.id == id))
      prev = if idx && idx > 0, do: Enum.at(category_pages, idx - 1)
      next = if idx && idx < length(category_pages) - 1, do: Enum.at(category_pages, idx + 1)
      {prev, next}
    else
      {nil, nil}
    end
  end

  @doc """
  Returns breadcrumb segments for a page.

  ## Examples

      iex> Pages.breadcrumbs(%Page{path: "/docs/getting-started"})
      ["docs", "getting-started"]
  """
  @spec breadcrumbs(Page.t() | String.t()) :: [String.t()]
  def breadcrumbs(%Page{path: path}) do
    path
    |> String.trim("/")
    |> String.split("/")
    |> Enum.filter(&(&1 != ""))
  end

  def breadcrumbs(path) when is_binary(path) do
    path
    |> String.trim("/")
    |> String.split("/")
    |> Enum.filter(&(&1 != ""))
  end

  @doc """
  Returns breadcrumbs with page references where available.

  ## Examples

      iex> Pages.breadcrumbs_with_docs("/docs/getting-started")
      [{"docs", %Page{...}}, {"getting-started", %Page{...}}]
  """
  @spec breadcrumbs_with_docs(String.t()) :: [{String.t(), Page.t() | nil}]
  def breadcrumbs_with_docs(path) when is_binary(path) do
    segments = breadcrumbs(path)

    segments
    |> Enum.with_index()
    |> Enum.map(fn {segment, idx} ->
      partial_path = "/" <> Enum.join(Enum.take(segments, idx + 1), "/")
      page = get_page_by_path(partial_path)
      {segment, page}
    end)
  end

  @doc """
  Generates the URL route for a page based on its category.

  ## Examples

      iex> Pages.route_for(%Page{category: :docs, path: "/docs/getting-started"})
      "/docs/getting-started"

      iex> Pages.route_for(%Page{category: :training, id: "foundations-intro"})
      "/training/foundations-intro"
  """
  @spec route_for(Page.t()) :: String.t()
  def route_for(%Page{category: :docs, path: path}), do: normalize_path_lookup(path)
  def route_for(%Page{category: :training} = p), do: "/training/#{p.id}"
  def route_for(%Page{category: :features} = p), do: "/features/#{p.id}"
  def route_for(%Page{category: :build} = p), do: "/build/#{p.id}"
  def route_for(%Page{category: :community} = p), do: "/community/#{p.id}"
  def route_for(%Page{category: :compare} = p), do: "/compare/#{p.id}"

  # --- Private helpers ---

  defp normalize_path_lookup(path) when is_binary(path) do
    case path do
      "/" -> "/"
      other -> String.trim_trailing(other, "/")
    end
  end

  defp docs_section_root_page?(%Page{category: :docs} = page) do
    case page.path |> String.trim_leading("/docs") |> String.trim_leading("/") |> String.split("/", trim: true) do
      [section] when section != "" -> true
      _other -> false
    end
  end

  defp docs_section_root_page?(_page), do: false

  defp docs_page_in_section?(%Page{category: :docs} = page, section) do
    case docs_section_for_page(page) do
      ^section -> true
      _other -> false
    end
  end

  defp docs_page_in_section?(_page, _section), do: false

  defp docs_section_for_page(%Page{category: :docs, path: path}) do
    case path |> String.trim_leading("/docs") |> String.trim_leading("/") |> String.split("/", trim: true) do
      [section | _rest] when section != "" -> section
      _other -> nil
    end
  end

  defp docs_section_for_page(_page), do: nil

  defp normalize_docs_section(section) do
    section
    |> String.trim()
    |> String.trim("/")
  end

  defp do_build_menu_tree(pages) do
    menu_pages = Enum.filter(pages, & &1.in_menu)

    tree_map =
      Enum.reduce(menu_pages, %{}, fn page, acc ->
        segments =
          page.path
          |> String.trim("/")
          |> case do
            "" -> ["root"]
            other -> String.split(other, "/")
          end

        insert_into_tree(acc, segments, page)
      end)

    map_tree_to_sorted_list(tree_map)
  end

  defp insert_into_tree(tree, [segment], page) do
    Map.update(tree, segment, %{doc: page, children: %{}}, fn existing ->
      Map.put(existing, :doc, page)
    end)
  end

  defp insert_into_tree(tree, [segment | rest], page) do
    Map.update(tree, segment, %{doc: nil, children: insert_into_tree(%{}, rest, page)}, fn
      existing ->
        children = Map.get(existing, :children, %{})
        Map.put(existing, :children, insert_into_tree(children, rest, page))
    end)
  end

  defp map_tree_to_sorted_list(tree) do
    tree
    |> Enum.map(fn {slug, %{doc: doc, children: children_map}} ->
      %MenuNode{
        slug: slug,
        doc: doc,
        order: (doc && doc.order) || 9999,
        children: map_tree_to_sorted_list(children_map)
      }
    end)
    |> Enum.sort_by(fn %MenuNode{order: order, slug: slug} -> {order, slug} end)
  end
end
