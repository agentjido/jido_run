defmodule AgentJidoWeb.MarkdownContent do
  @moduledoc """
  Resolves markdown payloads for public site routes.
  """

  alias AgentJido.Blog
  alias AgentJido.Community.Showcase
  alias AgentJido.Ecosystem
  alias AgentJido.Ecosystem.ControlMatrix
  alias AgentJido.Examples
  alias AgentJido.Pages
  alias AgentJido.ReleaseCatalog

  # Mirrors the browser Examples hub (jido_examples_live.ex), which groups the
  # live examples under these three category headings in this order.
  @example_category_order [:core, :ai, :production]

  @doc """
  Returns true when the request path is in the markdown-enabled public route set.
  """
  @spec eligible_public_path?(String.t()) :: boolean()
  def eligible_public_path?(path) when is_binary(path) do
    not excluded_prefix?(path) and allowed_prefix?(path)
  end

  @doc """
  Resolves a markdown payload for a request path.

  Returns `:no_match` when the path should fall through to normal routing.
  """
  @spec resolve(String.t(), String.t()) :: {:ok, String.t()} | :no_match
  def resolve(path, absolute_url) when is_binary(path) and is_binary(absolute_url) do
    case resolve_path(path, absolute_url) do
      {:ok, markdown} ->
        {:ok, markdown}

      {:fallback, title, summary} ->
        {:ok, fallback_markdown(title, absolute_url, summary)}

      :no_match ->
        :no_match
    end
  end

  defp resolve_path(path, absolute_url) do
    resolve_from_pages(path) ||
      resolve_from_blog(path) ||
      resolve_from_ecosystem(path, absolute_url) ||
      resolve_from_examples(path, absolute_url) ||
      resolve_from_showcase(path) ||
      resolve_misc(path) ||
      :no_match
  end

  # The Docs hub is generated from the same content records as the rendered
  # browser hub (Pages.docs_sections/0 + docs_section_pages/1), iterated in that
  # list's order, so the browser and Markdown hubs present the sections in the
  # same ORDER — not just the same inventory — instead of drifting against a
  # hand-written index page. See E06-T22 and E10-T13.
  defp resolve_from_pages("/docs") do
    {:ok, docs_hub_markdown()}
  end

  # The Build and Compare hubs render a generated grid from
  # Pages.pages_by_category/1 in the browser (page_live.ex), but /build.md and
  # /compare.md served the raw index.md source — including its `%{...}` Elixir
  # frontmatter block, which is not valid Markdown. Generate a full Markdown
  # hub from the same content records the browser hub uses (heading, intro, and
  # an inventory of the leaf pages) so the browser and Markdown hubs stay
  # aligned. See E06-T23.
  defp resolve_from_pages("/build") do
    {:ok, generic_hub_markdown(:build)}
  end

  defp resolve_from_pages("/compare") do
    {:ok, generic_hub_markdown(:compare)}
  end

  defp resolve_from_pages(path) do
    case Pages.resolve_page_for_path(path) do
      {:ok, _page, :legacy} ->
        # Preserve existing redirect behavior for legacy routes.
        :no_match

      {:ok, page, _resolution} ->
        case read_source_markdown(map_get(page, :source_path)) do
          {:ok, markdown} ->
            # Expand release placeholders so the public `.md` payload carries real
            # dependency requirements instead of raw `{{mix_dep:*}}` tokens. This
            # keeps the Markdown endpoint in parity with the rendered HTML page
            # (see E01-T08). Pages are the surface that uses these tokens.
            {:ok, ReleaseCatalog.expand_placeholders(markdown)}

          _other ->
            {:fallback, map_get(page, :title) || "Site Page", page_summary(page)}
        end

      :error ->
        nil
    end
  end

  defp docs_hub_markdown do
    section_blocks =
      Pages.docs_sections()
      |> Enum.map(&format_docs_hub_section/1)
      |> Enum.reject(&(&1 in ["", nil]))
      |> Enum.join("\n\n")

    """
    # Documentation

    Everything you need to build and run multi-agent systems with Jido - from your first agent to production deployment.

    ## Documentation

    #{section_blocks}

    ---

    This inventory is generated from the same content records as the rendered Docs hub.
    """
  end

  # Mirrors the browser hub (page_live.ex): a section root page's label, route,
  # description, and the in-menu pages beneath it (excluding the root itself, so
  # the count matches `section_page_count/1`).
  defp format_docs_hub_section(section_page) do
    section = Pages.docs_section_for_path(Pages.route_for(section_page))
    label = map_get(section_page, :menu_label) || map_get(section_page, :title)
    route = Pages.route_for(section_page)

    section_pages =
      if section do
        section
        |> Pages.docs_section_pages()
        |> Enum.reject(&(&1.path == section_page.path))
      else
        []
      end

    description =
      section_page
      |> map_get(:description)
      |> to_string()
      |> String.trim()

    header =
      ("- **[#{label}](#{route})**#{count_suffix(length(section_pages))}" <>
         if(description == "", do: "", else: " — #{description}")) <>
        status_suffix(section_page)

    child_lines =
      Enum.map(section_pages, fn page ->
        page_label = map_get(page, :menu_label) || map_get(page, :title)
        "  - [#{page_label}](#{Pages.route_for(page)})"
      end)

    Enum.join([header | child_lines], "\n")
  end

  defp count_suffix(0), do: ""
  defp count_suffix(count), do: " (#{count} pages)"

  # Mirrors the browser generic hub (page_live.ex handle_generic_index): the
  # category's index page supplies the heading and intro, and each leaf page is
  # listed with its title, description, and route — so the Markdown inventory
  # matches the rendered grid instead of serving the raw index source.
  defp generic_hub_markdown(category) when category in [:build, :compare] do
    pages = Pages.pages_by_category(category)
    %{title: title, intro: intro} = generic_hub_intro(category, pages)

    inventory =
      pages
      |> Enum.reject(&hub_root_page?(&1, category))
      |> Enum.map(&format_generic_hub_entry/1)
      |> Enum.join("\n")

    """
    # #{title}

    #{intro}

    #{inventory}

    ---

    This inventory is generated from the same content records as the rendered #{title} hub.
    """
  end

  defp generic_hub_intro(category, pages) do
    root = Enum.find(pages, &hub_root_page?(&1, category))

    title =
      (root && map_get(root, :title)) ||
        generic_hub_default_title(category)

    intro =
      root
      |> map_get(:description)
      |> to_string()
      |> String.trim()
      |> case do
        "" -> generic_hub_default_intro(category)
        value -> value
      end

    %{title: title, intro: intro}
  end

  defp hub_root_page?(page, category) do
    map_get(page, :path) == "/#{category}"
  end

  defp format_generic_hub_entry(page) do
    title = map_get(page, :title)
    route = Pages.route_for(page)

    description =
      page
      |> map_get(:description)
      |> to_string()
      |> String.trim()

    base =
      if description == "",
        do: "- [#{title}](#{route})",
        else: "- [#{title}](#{route}) — #{description}"

    # Append a status tag so draft/experimental content cannot look complete in
    # the Markdown inventory either (mirrors the browser hub card badge).
    base <> status_suffix(page)
  end

  # Mirrors the browser hub card badge: a `(Draft)` / `(Experimental)` tag when
  # the page is not yet stable, empty for published content. See E06-T24.
  defp status_suffix(page) do
    case Pages.content_status_label(page) do
      nil -> ""
      label -> " (#{label})"
    end
  end

  defp generic_hub_default_title(category) do
    category |> to_string() |> Phoenix.Naming.humanize()
  end

  defp generic_hub_default_intro(_category) do
    "Explore practical resources for building and operating production systems with Jido."
  end

  defp resolve_from_blog("/blog") do
    {:fallback, "Engineering Blog", "Product updates, release notes, and practical guides for building reliable AI agents in Elixir and on the BEAM."}
  end

  defp resolve_from_blog("/blog/tags/" <> tag_path) do
    if valid_single_segment?(tag_path) do
      tag = String.trim(tag_path)

      try do
        posts = Blog.get_posts_by_tag!(tag)

        {:fallback, "Blog tag: #{tag}", "Posts tagged with #{tag}. Matching posts: #{length(posts)}."}
      rescue
        Blog.NotFoundError -> :no_match
      end
    else
      :no_match
    end
  end

  defp resolve_from_blog("/blog/" <> slug) do
    if valid_single_segment?(slug) do
      try do
        post = Blog.get_post_by_id!(slug)

        case read_source_markdown(map_get(post, :source_path)) do
          {:ok, markdown} ->
            {:ok, markdown}

          _other ->
            {:fallback, map_get(post, :title) || "Blog Post", post_summary(post)}
        end
      rescue
        Blog.NotFoundError -> :no_match
      end
    else
      :no_match
    end
  end

  defp resolve_from_blog(_path), do: nil

  # The Ecosystem hub (`/ecosystem`) renders the recommended starting stacks
  # and a full package explorer/compare view from the public package registry
  # in the browser (jido_ecosystem_live.ex), but `/ecosystem.md` served a short
  # fallback stub. Generate a full Markdown hub from the same registry the
  # browser hub uses so the browser and Markdown inventories agree: the three
  # recommended stacks with each package's explicit supported range, source, and
  # support level, plus a full package inventory carrying each package's layer,
  # support level, and full link set. See E10-T12.
  defp resolve_from_ecosystem("/ecosystem", absolute_url) do
    {:ok, ecosystem_hub_markdown(absolute_url)}
  end

  # The legacy matrix/package-matrix routes are 301-redirected to the hub by the
  # LegacyRouteRedirect plug, so these clauses are normally shadowed. Resolve
  # them to the same generated hub (rather than a stub) so the inventory stays
  # useful if a redirect is ever removed. See E10-T12.
  defp resolve_from_ecosystem("/ecosystem/matrix", absolute_url) do
    {:ok, ecosystem_hub_markdown(absolute_url)}
  end

  defp resolve_from_ecosystem("/ecosystem/package-matrix", absolute_url) do
    {:ok, ecosystem_hub_markdown(absolute_url)}
  end

  defp resolve_from_ecosystem("/ecosystem/" <> id_path, _absolute_url) do
    if valid_single_segment?(id_path) do
      id_path
      |> String.trim()
      |> Ecosystem.get_public_package()
      |> resolve_markdown_target("Ecosystem Package", &package_summary/1, &map_get(&1, :path), &map_get(&1, :title))
    else
      :no_match
    end
  end

  defp resolve_from_ecosystem(_path, _absolute_url), do: nil

  defp ecosystem_hub_markdown(absolute_url) do
    stacks = Ecosystem.Stacks.matrix()

    """
    # Jido Ecosystem

    Public Jido packages, support levels, and recommended starting stacks from one ecosystem hub. The recommended stacks list the explicit supported range for every package, and the package inventory carries each package's layer, support level, and full link set.

    ## Recommended stacks

    The three recommended starting stacks — Core, AI, and Operate — each with the explicit supported range for every package. Each range is derived from the registry: a published package pins to its Hex major (`~> X.0`) and an unreleased package falls back to its public GitHub repo. These are the same ranges the home dependency blocks install.

    #{format_ecosystem_stacks(stacks)}

    ## Operational control

    Compare the nine operational-control dimensions across the packages that participate in the controlled-Agent stack and the host application that owns the rest. For each dimension and column the matrix states the boundary — whether the control is **Supplied** by the column, **Carried / preserved** with the host deciding, or **Application-owned** — and the clause that grounds it. Package columns link to their package page for the release version, support level, and proof behind each claim.

    #{format_operational_control_section()}

    ## Package inventory

    The full public package set in canonical layer order. Each entry carries the package's layer, support level, and full link set — its package page, HexDocs, Hex.pm, and GitHub.

    #{format_ecosystem_inventory(absolute_url)}

    ---

    This inventory is generated from the same content records as the rendered Ecosystem hub.
    """
  end

  # Mirrors the browser STACK COMPATIBILITY table (jido_ecosystem_live.ex): the
  # three stacks in display order, each package rendered with the supported
  # range, source, and support level the machine-readable delivery needs.
  defp format_ecosystem_stacks(stacks) do
    stacks
    |> Enum.map(&format_ecosystem_stack/1)
    |> Enum.reject(&(&1 in ["", nil]))
    |> Enum.join("\n\n")
  end

  defp format_ecosystem_stack(stack) do
    rows =
      stack.packages
      |> Enum.map(&format_stack_package_row/1)
      |> Enum.join("\n")

    "### #{stack.name}\n\n#{stack.purpose}\n\n#{rows}"
  end

  defp format_stack_package_row(pkg) do
    [
      "- **[#{pkg.name}](#{pkg.path})** — #{field_or_dash(pkg.role)}",
      "  - Range: #{stack_range_label(pkg.range)}",
      "  - Source: #{field_or_dash(pkg.source_label)}",
      "  - Support level: #{ecosystem_support_label(pkg.support_level)}"
    ]
    |> Enum.join("\n")
  end

  defp stack_range_label(nil), do: "Not specified"
  defp stack_range_label(range), do: range

  # Mirrors the browser hub's normalize_support_level/1 (jido_ecosystem_live.ex):
  # a missing level reads as Experimental so the Markdown never understates the
  # boundary a package carries.
  defp ecosystem_support_label(level) do
    normalized = Ecosystem.SupportLevel.normalize(level) || :experimental
    Ecosystem.SupportLevel.label(normalized)
  end

  # Mirrors the browser PACKAGE EXPLORER / COMPARE table: every public package
  # in canonical layer order, each rendered with its layer, support level, and
  # the full external link set — not just the internal detail route.
  defp format_ecosystem_inventory(absolute_url) do
    Ecosystem.public_packages()
    |> Enum.sort_by(fn pkg ->
      {ecosystem_layer_rank(Ecosystem.Layering.layer_for(pkg)), String.downcase(pkg.title)}
    end)
    |> Enum.map(&format_ecosystem_package_entry(&1, absolute_url))
    |> Enum.join("\n")
  end

  defp format_ecosystem_package_entry(pkg, absolute_url) do
    id = map_get(pkg, :id)
    route = "/ecosystem/#{id}"
    layer = ecosystem_layer_label(Ecosystem.Layering.layer_for(pkg))
    support = ecosystem_support_label(map_get(pkg, :support_level))

    links =
      [
        link_line("HexDocs", map_get(pkg, :hexdocs_url)),
        link_line("Hex.pm", map_get(pkg, :hex_url)),
        link_line("GitHub", map_get(pkg, :github_url))
      ]
      |> Enum.reject(&is_nil/1)

    ([
       "- **[#{map_get(pkg, :title)}](#{route})** — #{field_or_dash(map_get(pkg, :tagline))}",
       "  - Layer: #{layer}",
       "  - Support level: #{support}"
     ] ++ links ++ ["  - URL: #{package_url(id, absolute_url)}"])
    |> Enum.join("\n")
  end

  defp link_line(_label, nil), do: nil
  defp link_line(_label, ""), do: nil
  defp link_line(label, href), do: "  - #{label}: #{href}"

  # Mirrors the browser OPERATIONAL CONTROL matrix (jido_ecosystem_live.ex) so a
  # machine client receives the same qualified control claims a browser reader
  # sees: the nine capabilities in comparison order, each with its description
  # and one line per column carrying the cell's boundary role and grounding
  # clause; a legend; and a release-basis note with the proof link. The roles,
  # clauses, and column links come straight from ControlMatrix so the Markdown
  # cannot drift from the browser's qualified claims. See jido-e10-t29.
  defp format_operational_control_section do
    matrix = ControlMatrix.matrix()
    columns = ControlMatrix.columns()

    [
      format_control_matrix(matrix, columns),
      control_matrix_legend(),
      control_matrix_release_basis()
    ]
    |> Enum.join("\n\n")
  end

  defp format_control_matrix(matrix, columns) do
    matrix
    |> Enum.map(&format_control_row(&1, columns))
    |> Enum.join("\n\n")
  end

  defp format_control_row(row, columns) do
    description =
      row
      |> Map.get(:description)
      |> to_string()
      |> String.trim()

    cell_lines =
      columns
      |> Enum.map(&format_control_cell(row, &1))
      |> Enum.join("\n")

    "### #{row.label}\n\n#{description}\n\n#{cell_lines}"
  end

  defp format_control_cell(row, column) do
    cell = Map.fetch!(row.cells, column.key)

    "- #{control_column_header(column)} — #{ControlMatrix.role_label(cell.role)}: #{cell.text}"
  end

  # Package columns link to their package page (the browser table draws the
  # same link); the synthetic host column carries no link.
  defp control_column_header(%{path: path, label: label})
       when is_binary(path) and path != "" do
    "**[#{label}](#{path})**"
  end

  defp control_column_header(%{label: label}) do
    "**#{label}**"
  end

  # Mirrors the browser legend (jido_ecosystem_live.ex): one line per role so a
  # machine reader sees the same boundary vocabulary the browser draws.
  defp control_matrix_legend do
    supplies = ControlMatrix.role_label(:supplies)
    preserves = ControlMatrix.role_label(:preserves)
    app = ControlMatrix.role_label(:app)

    [
      "Legend:",
      "- **#{supplies}** — the column provides this control.",
      "- **#{preserves}** — the column carries or preserves context but the host decides.",
      "- **#{app}** — the application or platform owns this; the column does not supply it."
    ]
    |> Enum.join("\n")
  end

  # Mirrors the browser "Release basis" note (jido_ecosystem_live.ex): each
  # package's release version, support level, and proof live on its package
  # page; the full claim boundaries live on Security and governance. This is the
  # proof link that qualifies the matrix claims.
  defp control_matrix_release_basis do
    "Release basis. Each package column's release version, support level, and proof are stated on its package page; experimental or unreleased packages describe their documented boundary here and do not back a general production claim. The full claim boundaries are on the [Security and governance](/docs/operations/security-and-governance) page."
  end

  defp package_url(id, absolute_url) do
    "#{origin_from(absolute_url)}/ecosystem/#{id}"
  end

  defp ecosystem_layer_rank(:foundation), do: 1
  defp ecosystem_layer_rank(:core), do: 2
  defp ecosystem_layer_rank(:ai), do: 3
  defp ecosystem_layer_rank(:app), do: 4
  defp ecosystem_layer_rank(_layer), do: 99

  defp ecosystem_layer_label(:foundation), do: "Foundation"
  defp ecosystem_layer_label(:core), do: "Core"
  defp ecosystem_layer_label(:ai), do: "AI"
  defp ecosystem_layer_label(:app), do: "Application"
  defp ecosystem_layer_label(layer), do: layer |> Atom.to_string() |> String.capitalize()

  # The Examples hub (`/examples`) renders a category-grouped grid from the
  # live Example records in the browser (jido_examples_live.ex), but `/examples.md`
  # served a short fallback stub. Generate a full Markdown hub from the same
  # records the browser hub uses so the browser and Markdown inventories agree,
  # and so each entry carries the task, outcome, packages, maturity, and URL the
  # machine-readable delivery needs. See E10-T11.
  defp resolve_from_examples("/examples", absolute_url) do
    {:ok, examples_hub_markdown(absolute_url)}
  end

  defp resolve_from_examples("/examples/" <> slug_path, _absolute_url) do
    if valid_single_segment?(slug_path) do
      slug_path
      |> String.trim()
      |> Examples.get_example()
      |> resolve_markdown_target("Example", &example_summary/1, &map_get(&1, :source_path), &map_get(&1, :title))
    else
      :no_match
    end
  end

  defp resolve_from_examples(_path, _absolute_url), do: nil

  # Mirrors the browser Examples hub (jido_examples_live.ex): the live examples
  # grouped by category in canonical order, each rendered with the task it
  # performs (its description), the outcome it proves, the Jido packages it
  # exercises, the package maturity, and its absolute URL.
  defp examples_hub_markdown(absolute_url) do
    category_blocks =
      @example_category_order
      |> Enum.map(&format_examples_category_block(&1, absolute_url))
      |> Enum.reject(&(&1 in ["", nil]))
      |> Enum.join("\n\n")

    """
    # Jido Examples

    Interactive and production-oriented examples for agent workflows, orchestration, and reliability patterns. Each entry lists the task it performs, the outcome it proves, the Jido packages it exercises, the package maturity, and its URL.

    #{category_blocks}

    ---

    This inventory is generated from the same content records as the rendered Examples hub.
    """
  end

  defp format_examples_category_block(category, absolute_url) do
    entries =
      category
      |> Examples.examples_by_category()
      |> Enum.map(&format_example_entry(&1, absolute_url))
      |> Enum.join("\n")

    if entries == "", do: nil, else: "## #{examples_category_heading(category)}\n\n#{entries}"
  end

  defp format_example_entry(example, absolute_url) do
    slug = map_get(example, :slug)
    route = "/examples/#{slug}"

    [
      "- **[#{map_get(example, :title)}](#{route})**",
      "  - Task: #{field_or_dash(map_get(example, :description))}",
      "  - Outcome: #{field_or_dash(map_get(example, :outcome))}",
      "  - Packages: #{field_or_dash(join_list(map_get(example, :packages)))}",
      "  - Maturity: #{field_or_dash(map_get(example, :package_maturity))}",
      "  - URL: #{example_url(slug, absolute_url)}"
    ]
    |> Enum.join("\n")
  end

  # Mirrors the browser hub's category_heading/1 (jido_examples_live.ex) so the
  # Markdown section labels match the rendered grid.
  defp examples_category_heading(:core), do: "Getting Started"
  defp examples_category_heading(:ai), do: "AI-Powered Agents"
  defp examples_category_heading(:production), do: "Production Patterns"
  defp examples_category_heading(category), do: Phoenix.Naming.humanize(category)

  defp join_list(value) do
    value
    |> List.wrap()
    |> Enum.map(&to_string/1)
    |> Enum.join(", ")
  end

  defp field_or_dash(value) do
    case value |> to_string() |> String.trim() do
      "" -> "Not specified"
      other -> other
    end
  end

  defp example_url(slug, absolute_url) do
    "#{origin_from(absolute_url)}/examples/#{slug}"
  end

  defp origin_from(absolute_url) do
    parsed = URI.parse(absolute_url)

    cond do
      parsed.scheme != nil and parsed.host not in [nil, ""] ->
        port_suffix =
          case {parsed.scheme, parsed.port} do
            {"https", 443} -> ""
            {"http", 80} -> ""
            {_, port} when is_integer(port) -> ":#{port}"
            _ -> ""
          end

        "#{parsed.scheme}://#{parsed.host}#{port_suffix}"

      true ->
        String.trim_trailing(AgentJidoWeb.Endpoint.url(), "/")
    end
  end

  defp resolve_from_showcase("/community") do
    {:fallback, "Jido Community", "Build agents with us. Join Discord, collaborate on GitHub, and contribute across the Jido ecosystem."}
  end

  defp resolve_from_showcase("/community/showcase") do
    count = Showcase.project_count()

    summary =
      "Community showcase of real projects built with Jido. " <>
        "#{count} project#{if count == 1, do: "", else: "s"} currently listed."

    {:fallback, "Built with Jido Showcase", summary}
  end

  defp resolve_from_showcase(_path), do: nil

  defp resolve_markdown_target(nil, _default_title, _summary_fun, _path_fun, _title_fun), do: :no_match

  defp resolve_markdown_target(item, default_title, summary_fun, path_fun, title_fun) do
    case read_source_markdown(path_fun.(item)) do
      {:ok, markdown} ->
        {:ok, markdown}

      _other ->
        {:fallback, title_fun.(item) || default_title, summary_fun.(item)}
    end
  end

  defp resolve_misc("/") do
    {:fallback, "Agent Jido",
     "The Elixir framework for long-running agent systems. Build supervised agents, typed tools, and explicit workflows on Elixir/OTP."}
  end

  defp resolve_misc("/getting-started") do
    {:fallback, "Getting Started", "First-step onboarding route for building your first agent workflow with Jido."}
  end

  defp resolve_misc("/features") do
    {:fallback, "Jido Features",
     "Runtime capabilities, orchestration strategies, and ecosystem components for long-running agent systems on Elixir/OTP."}
  end

  defp resolve_misc("/compare") do
    {:fallback, "Compare Jido", "Compare Jido's supervised, explicit agent model with other agent and orchestration frameworks."}
  end

  defp resolve_misc("/skills") do
    {:fallback, "Jido Skills Catalog",
     "Vendored upstream Jido package skills plus the router skill, surfaced as a public catalog page in the workbench."}
  end

  defp resolve_misc(_path), do: nil

  defp fallback_markdown(title, absolute_url, summary) do
    normalized_summary = normalize_summary(summary)

    """
    # #{title}

    Canonical URL: #{absolute_url}

    #{normalized_summary}

    ---
    This markdown payload is generated from the rendered route when direct source markdown is not available.
    """
  end

  defp page_summary(page) do
    map_get(page, :description) || plain_text(map_get(page, :body))
  end

  defp post_summary(post) do
    map_get(post, :description) || plain_text(map_get(post, :body))
  end

  defp package_summary(package) do
    map_get(package, :tagline) || map_get(package, :description) || plain_text(map_get(package, :body))
  end

  defp example_summary(example) do
    map_get(example, :description) || plain_text(map_get(example, :body))
  end

  defp normalize_summary(summary) when is_binary(summary) do
    summary
    |> String.trim()
    |> case do
      "" -> "No additional summary available."
      value -> value
    end
  end

  defp normalize_summary(_summary), do: "No additional summary available."

  defp plain_text(value) when is_binary(value) do
    value
    |> String.replace(~r/<[^>]+>/, " ")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
    |> String.slice(0, 280)
  end

  defp plain_text(_value), do: ""

  defp read_source_markdown(path) when is_binary(path) and path != "" do
    case read_if_regular(path) do
      {:ok, markdown} ->
        {:ok, markdown}

      {:error, :missing} ->
        with reconstructed when is_binary(reconstructed) <- reconstruct_packaged_path(path),
             {:ok, markdown} <- read_if_regular(reconstructed) do
          {:ok, markdown}
        else
          _other -> {:error, :missing}
        end
    end
  end

  defp read_source_markdown(_path), do: {:error, :missing}

  defp read_if_regular(path) do
    if File.regular?(path), do: File.read(path), else: {:error, :missing}
  end

  # Pages are compiled with absolute source paths from the build host.
  # At runtime (e.g. release image), that absolute root changes. Rebuild
  # a runtime-local path from the first `/priv/...` suffix if present.
  defp reconstruct_packaged_path(path) when is_binary(path) do
    case String.split(path, "/priv/", parts: 2) do
      [_prefix, suffix] when suffix != "" ->
        Path.join(Application.app_dir(:agent_jido), Path.join("priv", suffix))

      _other ->
        nil
    end
  end

  defp map_get(map, key) when is_map(map) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end

  defp valid_single_segment?(segment) when is_binary(segment) do
    trimmed = String.trim(segment)
    trimmed != "" and not String.contains?(trimmed, "/")
  end

  defp allowed_prefix?(path) do
    path == "/" or
      path == "/getting-started" or
      String.starts_with?(path, "/docs") or
      String.starts_with?(path, "/blog") or
      String.starts_with?(path, "/ecosystem") or
      String.starts_with?(path, "/features") or
      String.starts_with?(path, "/build") or
      String.starts_with?(path, "/community") or
      String.starts_with?(path, "/examples") or
      String.starts_with?(path, "/compare")
  end

  defp excluded_prefix?(path) do
    String.starts_with?(path, "/users") or
      String.starts_with?(path, "/dashboard") or
      String.starts_with?(path, "/dev") or
      String.starts_with?(path, "/assets") or
      String.starts_with?(path, "/og/") or
      path == "/feed" or
      path == "/sitemap.xml"
  end
end
