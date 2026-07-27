defmodule AgentJidoWeb.PageLive do
  @moduledoc """
  Unified LiveView for rendering pages from the Pages content system.

  Dispatches to the appropriate layout based on page category:
  - `:docs` → Docs shell with sidebar + table of contents
  - `:training` → Marketing layout with prev/next nav and metadata badges
  - `:features`, `:build`, `:community` → Marketing layout
  """
  use AgentJidoWeb, :live_view

  alias AgentJido.Analytics
  alias AgentJido.Ecosystem
  alias AgentJido.Pages
  alias AgentJidoWeb.MarkdownLinks

  import AgentJidoWeb.Jido.DocsComponents
  import AgentJidoWeb.Jido.MarketingLayouts

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(sidebar_open: true)
     |> assign(:docs_feedback, empty_docs_feedback())}
  end

  @impl true
  def handle_params(params, uri, socket) do
    parsed_uri = URI.parse(uri)
    path = parsed_uri.path || "/"
    request_url = MarkdownLinks.absolute_url(path, parsed_uri.query)

    socket =
      socket
      |> assign(:request_path, path)
      |> assign(:request_url, request_url)

    case socket.assigns.live_action do
      :index -> handle_index(socket, path)
      :show -> handle_show(socket, path, params)
    end
  end

  # --- Index handlers ---

  defp handle_index(socket, "/docs" <> _) do
    handle_docs_index(socket)
  end

  defp handle_index(socket, "/training" <> _) do
    handle_training_index(socket)
  end

  defp handle_index(socket, "/" <> rest) do
    category = rest |> String.split("/") |> hd() |> String.to_existing_atom()
    handle_generic_index(socket, category)
  rescue
    _ -> handle_generic_index(socket, :docs)
  end

  defp handle_docs_index(socket) do
    documents = Pages.pages_by_category(:docs)
    secondary_tabs = docs_secondary_tabs()
    sidebar = sidebar_nav("/docs")

    docs_filter = :all
    sections = Pages.docs_sections_filtered(docs_filter)

    toc = [
      %{id: "get-started", title: "Get Started", level: 2},
      %{id: "documentation", title: "Documentation", level: 2},
      %{id: "package-ecosystem", title: "Package Ecosystem", level: 2},
      %{id: "community", title: "Join the Community", level: 2}
    ]

    {:noreply,
     assign(socket,
       page_title: "Jido Documentation",
       meta_description: "Reference docs and implementation guides for building reliable multi-agent systems with Jido.",
       layout_type: :docs_shell,
       category: :docs,
       documents: documents,
       markdown_copy_url: nil,
       selected_document: nil,
       docs_secondary_tabs: secondary_tabs,
       docs_sidebar_nav: sidebar,
       docs_sections: sections,
       docs_filter: docs_filter,
       docs_work_types: Pages.docs_work_types(),
       page: nil,
       markdown_action: nil,
       toc: toc,
       related_package_entries: []
     )}
  end

  defp handle_training_index(socket) do
    modules = Pages.pages_by_category(:training)
    track_groups = build_track_groups(modules)

    {:noreply,
     assign(socket,
       page_title: "Training",
       meta_description: "Hands-on learning modules for building and operating reliable multi-agent workflows with Jido.",
       layout_type: :training_index,
       category: :training,
       markdown_copy_url: nil,
       modules: modules,
       track_groups: track_groups,
       page: nil,
       markdown_action: nil,
       selected_document: nil,
       toc: []
     )}
  end

  defp handle_generic_index(socket, category) do
    pages = Pages.pages_by_category(category)
    %{title: title, description: description} = generic_index_metadata(category)

    {:noreply,
     assign(socket,
       page_title: title,
       meta_description: description,
       layout_type: :marketing_shell,
       category: category,
       markdown_copy_url: nil,
       pages: pages,
       page: nil,
       markdown_action: nil,
       selected_document: nil,
       toc: []
     )}
  end

  # --- Show handlers ---

  defp handle_show(socket, path, _params) do
    # Try to find page by matching path patterns
    page = find_page_for_path(path)

    case page do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "Page not found")
         |> push_navigate(to: fallback_path(path))}

      page ->
        # Measure movement from onboarding into the Operate / long-running path
        # (jido-e12-t27) — the operations hub and its runbooks are the
        # "long-running agent path" a visitor steps onto after building a first
        # agent. Fire only on the connected mount (the static render would
        # otherwise double-count) and only for an operations page. The
        # per-visitor dedup in the dashboard breakdown collapses repeat
        # operations-page views to one conversion.
        maybe_track_long_running_path_entry(socket, path)

        body_with_heading_ids = ensure_heading_ids(page.body)
        page = %{page | body: body_with_heading_ids}
        toc = build_toc(page.body)
        layout_type = layout_for(page.category)
        page_seo = page_seo(page)
        noindex? = seo_value(page_seo, :noindex) == true
        markdown_action = MarkdownLinks.markdown_action(page, socket.assigns.request_url)
        markdown_copy_url = if page.category == :docs, do: MarkdownLinks.markdown_path(page.path), else: nil

        # E06-T26: resolve the guide's related packages to their public ecosystem
        # entries so the docs shell can render each package's role and maturity
        # near the instructions. Unresolved ids (not a public ecosystem package)
        # are dropped so a guide never links to a missing package page.
        related_package_entries = resolve_related_packages(page.related_packages)

        assigns = [
          page_title: page.title,
          meta_description: page_meta_description(page),
          og_description: seo_value(page_seo, :og_description),
          canonical_url: seo_value(page_seo, :canonical_url),
          robots: if(noindex?, do: ["noindex", "nofollow"]),
          og_image: seo_value(page_seo, :og_image) || page.og_image,
          layout_type: layout_type,
          category: page.category,
          page: page,
          markdown_action: markdown_action,
          markdown_copy_url: markdown_copy_url,
          selected_document: page,
          toc: toc,
          document_content: %{html: page.body, toc: toc},
          related_package_entries: related_package_entries
        ]

        assigns =
          case page.category do
            :docs ->
              documents = Pages.pages_by_category(:docs)
              secondary_tabs = docs_secondary_tabs()
              sidebar = sidebar_nav(path)
              docs_feedback = existing_docs_feedback(socket, path)

              assigns ++
                [
                  documents: documents,
                  docs_secondary_tabs: secondary_tabs,
                  docs_sidebar_nav: sidebar,
                  docs_feedback: docs_feedback
                ]

            :training ->
              {prev, next} = Pages.neighbors(page.id)
              assigns ++ [previous_module: prev, next_module: next]

            _ ->
              assigns
          end

        {:noreply, assign(socket, assigns)}
    end
  end

  defp find_page_for_path(path) do
    case Pages.resolve_page_for_path(path) do
      {:ok, page, _resolution} -> page
      :error -> nil
    end
  end

  defp fallback_path("/docs" <> _), do: "/docs"
  defp fallback_path("/training" <> _), do: "/training"
  defp fallback_path("/features" <> _), do: "/features"
  defp fallback_path("/build" <> _), do: "/build"
  defp fallback_path("/community" <> _), do: "/community"
  defp fallback_path(_), do: "/"

  defp generic_index_metadata(:build) do
    %{
      title: "Build with Jido",
      description: "Implementation blueprints and practical build paths for shipping Jido-powered agent systems."
    }
  end

  defp generic_index_metadata(:community) do
    %{
      title: "Jido Community",
      description: "Learning paths, adoption playbooks, and case studies from teams building with Jido."
    }
  end

  defp generic_index_metadata(category) do
    %{
      title: category |> to_string() |> Phoenix.Naming.humanize(),
      description: "Explore practical resources for building and operating production systems with Jido."
    }
  end

  defp page_meta_description(page) do
    case page.description |> to_string() |> String.trim() do
      "" -> "Explore implementation guidance and production practices for building with Jido."
      description -> description
    end
  end

  defp page_seo(page) do
    Map.get(page, :seo, %{}) || %{}
  end

  defp seo_value(seo, key) do
    Map.get(seo, key) || Map.get(seo, Atom.to_string(key))
  end

  # E06-T26: turn a guide's `related_packages` frontmatter (%{id, role} maps)
  # into render entries that carry the resolved package name, maturity, and
  # ecosystem link alongside the guide-specific role. Only public ecosystem
  # packages are linked, so a guide never points at a missing package page.
  defp resolve_related_packages(related_packages) when is_list(related_packages) do
    related_packages
    |> Enum.flat_map(fn entry -> resolve_related_package_entry(entry) end)
  end

  defp resolve_related_packages(_), do: []

  defp resolve_related_package_entry(%{id: id} = entry) when is_binary(id) do
    case Ecosystem.get_public_package(id) do
      %Ecosystem.Package{} = pkg ->
        role = entry[:role] || pkg.tagline

        [
          %{
            id: pkg.id,
            name: pkg.name,
            role: role,
            maturity: pkg.support_level || pkg.maturity,
            href: "/ecosystem/#{pkg.id}"
          }
        ]

      nil ->
        []
    end
  end

  defp resolve_related_package_entry(_), do: []

  # --- Layout dispatch ---

  defp layout_for(:docs), do: :docs_shell
  defp layout_for(:training), do: :training_shell
  defp layout_for(:features), do: :marketing_shell
  defp layout_for(:build), do: :marketing_shell
  defp layout_for(:community), do: :marketing_shell
  defp layout_for(:compare), do: :marketing_shell

  # --- TOC building ---

  defp ensure_heading_ids(html_content) when is_binary(html_content) do
    {placeholder_html, pre_blocks} = extract_pre_blocks(html_content)

    normalized_html =
      case Floki.parse_fragment(placeholder_html) do
        {:ok, nodes} ->
          {nodes_with_ids, _used_ids} = add_heading_ids(nodes, MapSet.new())
          Floki.raw_html(nodes_with_ids)

        {:error, _} ->
          placeholder_html
      end

    restore_pre_blocks(normalized_html, pre_blocks)
  end

  defp ensure_heading_ids(html_content), do: to_string(html_content || "")

  @pre_block_pattern ~r/<pre\b[^>]*>.*?<\/pre>/is

  defp extract_pre_blocks(html) when is_binary(html) do
    @pre_block_pattern
    |> Regex.scan(html)
    |> Enum.map(&hd/1)
    |> Enum.with_index()
    |> Enum.reduce({html, []}, fn {block, index}, {acc_html, acc_blocks} ->
      token = "__JIDO_PRE_BLOCK_#{index}__"
      replaced = String.replace(acc_html, block, token, global: false)
      {replaced, [{token, block} | acc_blocks]}
    end)
  end

  defp restore_pre_blocks(html, blocks) when is_binary(html) and is_list(blocks) do
    Enum.reduce(blocks, html, fn {token, block}, acc ->
      String.replace(acc, token, block)
    end)
  end

  defp add_heading_ids(nodes, used_ids) when is_list(nodes) do
    Enum.map_reduce(nodes, used_ids, &add_heading_ids/2)
  end

  defp add_heading_ids({tag, attrs, children}, used_ids) when tag in ["h1", "h2", "h3"] do
    existing_id =
      attrs
      |> Enum.find_value(fn
        {"id", id} -> id
        _ -> nil
      end)
      |> normalize_heading_id()

    {children_with_ids, used_after_children} = add_heading_ids(children, used_ids)

    candidate_base =
      existing_id ||
        {tag, attrs, children_with_ids}
        |> Floki.text()
        |> slugify()

    {id, used_after_id} = reserve_unique_id(candidate_base, used_after_children)
    attrs = [{"id", id} | Enum.reject(attrs, fn {key, _value} -> key == "id" end)]

    {{tag, attrs, children_with_ids}, used_after_id}
  end

  defp add_heading_ids({tag, attrs, children}, used_ids) do
    {children_with_ids, used_after_children} = add_heading_ids(children, used_ids)
    {{tag, attrs, children_with_ids}, used_after_children}
  end

  defp add_heading_ids(other, used_ids), do: {other, used_ids}

  defp normalize_heading_id(id) when is_binary(id) do
    case String.trim(id) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp normalize_heading_id(_id), do: nil

  defp reserve_unique_id(base, used_ids) do
    base =
      case normalize_heading_id(base) do
        nil -> "section"
        normalized -> normalized
      end

    unique_id = unique_id(base, used_ids, 1)
    {unique_id, MapSet.put(used_ids, unique_id)}
  end

  defp unique_id(base, used_ids, attempt) do
    candidate =
      if attempt == 1 do
        base
      else
        "#{base}-#{attempt}"
      end

    if MapSet.member?(used_ids, candidate) do
      unique_id(base, used_ids, attempt + 1)
    else
      candidate
    end
  end

  defp build_toc(html_content) do
    case Floki.parse_fragment(html_content) do
      {:ok, document} ->
        document
        |> Floki.find("h1, h2, h3")
        |> Enum.map(&header_to_toc_item/1)

      {:error, _} ->
        []
    end
  end

  defp slugify(text) do
    text
    |> String.downcase()
    |> String.replace(~r/[^\w-]+/, "-")
    |> String.trim("-")
  end

  # --- Training helpers ---

  @track_order [:foundations, :coordination, :integration, :operations]

  defp build_track_groups(modules) do
    grouped = Enum.group_by(modules, & &1.track)

    @track_order
    |> Enum.map(fn track -> {track, Map.get(grouped, track, [])} end)
    |> Enum.reject(fn {_track, track_modules} -> track_modules == [] end)
  end

  def track_label(:foundations), do: "Foundations"
  def track_label(:coordination), do: "Agent Coordination"
  def track_label(:integration), do: "App Integration"
  def track_label(:operations), do: "Production Operations"
  def track_label(track), do: track |> to_string() |> Phoenix.Naming.humanize()

  def difficulty_badge(:beginner), do: "bg-accent-green/10 text-accent-green"
  def difficulty_badge(:intermediate), do: "bg-accent-yellow/10 text-accent-yellow"
  def difficulty_badge(:advanced), do: "bg-accent-red/10 text-accent-red"
  def difficulty_badge(_), do: "bg-elevated text-muted-foreground"

  def difficulty_class(:beginner),
    do: "bg-accent-green/10 border border-accent-green/30 text-accent-green"

  def difficulty_class(:intermediate),
    do: "bg-accent-yellow/10 border border-accent-yellow/30 text-accent-yellow"

  def difficulty_class(:advanced),
    do: "bg-accent-red/10 border border-accent-red/30 text-accent-red"

  def difficulty_class(_), do: "bg-elevated border border-border text-muted-foreground"

  # Status label styling for hub cards — draft/experimental content must read as
  # not-yet-complete instead of blending in with stable cards. See E06-T24.
  @doc false
  def status_badge_class(:draft),
    do: "bg-accent-yellow/10 border border-accent-yellow/30 text-accent-yellow"

  def status_badge_class(:experimental),
    do: "bg-accent-cyan/10 border border-accent-cyan/30 text-accent-cyan"

  def status_badge_class(_), do: "bg-elevated text-muted-foreground"

  # Docs hub audience/outcome filter chip — the selected lens reads as the
  # primary affordance, the rest stay neutral. See E06-T25.
  @doc false
  def filter_chip_class(true = _active) do
    "px-3 py-1.5 rounded-full text-[12px] font-semibold border border-primary bg-primary/10 text-primary transition-colors"
  end

  def filter_chip_class(false = _active) do
    "px-3 py-1.5 rounded-full text-[12px] font-medium border border-border bg-card text-muted-foreground hover:border-border-strong hover:text-foreground transition-colors"
  end

  @doc false
  def section_page_count(section_page) do
    section = Pages.docs_section_for_path(Pages.route_for(section_page))

    if section do
      Pages.docs_section_pages(section)
      |> Enum.reject(&(&1.path == section_page.path))
      |> length()
    else
      0
    end
  end

  @section_icons %{
    "getting-started" => "hero-rocket-launch",
    "concepts" => "hero-light-bulb",
    "learn" => "hero-academic-cap",
    "guides" => "hero-wrench-screwdriver",
    "contributors" => "hero-user-group",
    "reference" => "hero-book-open",
    "operations" => "hero-server-stack"
  }

  @section_colors %{
    "getting-started" => "green",
    "concepts" => "yellow",
    "learn" => "cyan",
    "guides" => "red",
    "contributors" => "yellow",
    "reference" => "green",
    "operations" => "cyan"
  }

  @doc false
  def section_icon(section_page) do
    section = Pages.docs_section_for_path(Pages.route_for(section_page))
    Map.get(@section_icons, section, "hero-document-text")
  end

  @doc false
  def section_color(section_page) do
    section = Pages.docs_section_for_path(Pages.route_for(section_page))
    Map.get(@section_colors, section, "green")
  end

  defp section_color_classes("green"), do: "text-accent-green border-accent-green/30 bg-accent-green/10"
  defp section_color_classes("yellow"), do: "text-accent-yellow border-accent-yellow/30 bg-accent-yellow/10"
  defp section_color_classes("cyan"), do: "text-accent-cyan border-accent-cyan/30 bg-accent-cyan/10"
  defp section_color_classes("red"), do: "text-accent-red border-accent-red/30 bg-accent-red/10"
  defp section_color_classes(_), do: "text-primary border-primary/30 bg-primary/10"

  defp section_icon_color("green"), do: "text-accent-green"
  defp section_icon_color("yellow"), do: "text-accent-yellow"
  defp section_icon_color("cyan"), do: "text-accent-cyan"
  defp section_icon_color("red"), do: "text-accent-red"
  defp section_icon_color(_), do: "text-primary"

  defp section_hover_class("green"), do: "hover:border-accent-green"
  defp section_hover_class("yellow"), do: "hover:border-accent-yellow"
  defp section_hover_class("cyan"), do: "hover:border-accent-cyan"
  defp section_hover_class("red"), do: "hover:border-accent-red"
  defp section_hover_class(_), do: "hover:border-border"

  # --- Sidebar for docs ---

  def sidebar_nav(request_path \\ "/docs") do
    case Pages.docs_section_for_path(request_path) do
      nil -> sidebar_sections_for_overview()
      section -> sidebar_sections_for_section(section)
    end
  end

  defp docs_secondary_tabs do
    Pages.docs_sections()
    |> Enum.map(fn page ->
      section = Pages.docs_section_for_path(page.path)

      %{
        label: Map.get(page, :menu_label) || page.title,
        href: Pages.route_for(page),
        active_paths: ["/docs/#{section}"]
      }
    end)
  end

  defp sidebar_sections_for_overview do
    items =
      Pages.docs_sections()
      |> Enum.map(fn page ->
        %{label: Map.get(page, :menu_label) || page.title, href: Pages.route_for(page)}
      end)

    [%{title: "Documentation", items: items}]
  end

  defp sidebar_sections_for_section(section) do
    pages = Pages.docs_section_pages(section)
    root_page = Pages.docs_section_root(section)

    title =
      case root_page do
        nil -> section |> String.replace("-", " ") |> Phoenix.Naming.humanize()
        page -> Map.get(page, :menu_label) || page.title
      end

    items =
      pages
      |> Enum.map(fn page ->
        %{label: Map.get(page, :menu_label) || page.title, href: Pages.route_for(page)}
      end)

    [%{title: title, items: items}]
  end

  # --- Events ---

  @impl true
  def handle_event("docs_feedback_select", %{"value" => "helpful"}, socket) do
    if docs_feedback_locked?(socket) do
      {:noreply, assign(socket, :docs_feedback, existing_docs_feedback(socket, socket.assigns.request_path || "/"))}
    else
      analytics_module().track_feedback_safe(socket.assigns.current_scope, %{
        event: "feedback_submitted",
        source: "docs",
        channel: "docs_sidebar",
        path: socket.assigns.request_path || "/",
        feedback_value: "helpful",
        feedback_note: nil,
        visitor_id: get_in(socket.assigns, [:analytics_identity, :visitor_id]),
        session_id: get_in(socket.assigns, [:analytics_identity, :session_id]),
        metadata: %{
          surface: "docs_page",
          page_id: Map.get(socket.assigns.selected_document || %{}, :id)
        }
      })

      {:noreply,
       socket
       |> put_flash(:info, "Thanks. Your feedback was recorded.")
       |> assign(:docs_feedback, %{submitted: true, value: "helpful", note: nil})}
    end
  end

  def handle_event("docs_feedback_select", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("submit_docs_feedback", %{"feedback" => feedback_params}, socket) do
    feedback_value = normalize_feedback_value(Map.get(feedback_params, "value"))

    feedback_note =
      if feedback_value == "not_helpful" do
        normalize_feedback_note(Map.get(feedback_params, "note"))
      else
        nil
      end

    if feedback_value in ["helpful", "not_helpful"] and not docs_feedback_locked?(socket) do
      analytics_module().track_feedback_safe(socket.assigns.current_scope, %{
        event: "feedback_submitted",
        source: "docs",
        channel: "docs_sidebar",
        path: socket.assigns.request_path || "/",
        feedback_value: feedback_value,
        feedback_note: feedback_note,
        visitor_id: get_in(socket.assigns, [:analytics_identity, :visitor_id]),
        session_id: get_in(socket.assigns, [:analytics_identity, :session_id]),
        metadata: %{
          surface: "docs_page",
          page_id: Map.get(socket.assigns.selected_document || %{}, :id)
        }
      })

      {:noreply,
       socket
       |> put_flash(:info, "Thanks. Your feedback was recorded.")
       |> assign(:docs_feedback, %{
         submitted: true,
         value: feedback_value,
         note: feedback_note
       })}
    else
      {:noreply, assign(socket, :docs_feedback, existing_docs_feedback(socket, socket.assigns.request_path || "/"))}
    end
  end

  @impl true
  def handle_event("toggle_sidebar", _, socket) do
    {:noreply, update(socket, :sidebar_open, &(!&1))}
  end

  # Audience/outcome Docs hub filter (E06-T25). A builder selects the kind of
  # work they are doing; the section grid narrows to the sections that serve it.
  # `:all` restores the full inventory. Unknown values fall back to `:all` so a
  # bad value can never empty the grid.
  @impl true
  def handle_event("select_docs_filter", %{"work_type" => work_type}, socket) do
    docs_filter = normalize_docs_filter(work_type)

    {:noreply,
     socket
     |> assign(:docs_filter, docs_filter)
     |> assign(:docs_sections, Pages.docs_sections_filtered(docs_filter))}
  end

  defp normalize_feedback_value(value) when is_binary(value) do
    case String.trim(value) do
      "helpful" -> "helpful"
      "not_helpful" -> "not_helpful"
      _ -> nil
    end
  end

  defp normalize_feedback_value(_value), do: nil

  defp normalize_feedback_note(value) when is_binary(value) do
    value
    |> String.trim()
    |> String.slice(0, 500)
    |> case do
      "" -> nil
      note -> note
    end
  end

  defp normalize_feedback_note(_value), do: nil

  defp normalize_docs_filter("all"), do: :all

  defp normalize_docs_filter(work_type) when is_binary(work_type) do
    normalized = String.to_existing_atom(work_type)

    if normalized in Pages.docs_work_type_ids(), do: normalized, else: :all
  rescue
    ArgumentError -> :all
  end

  defp docs_feedback_locked?(socket) do
    current_feedback = socket.assigns[:docs_feedback] || %{}

    if Map.get(current_feedback, :submitted, false) do
      true
    else
      existing_docs_feedback(socket, socket.assigns.request_path || "/").submitted
    end
  end

  defp existing_docs_feedback(socket, path) when is_binary(path) do
    module = analytics_module()
    visitor_id = get_in(socket.assigns, [:analytics_identity, :visitor_id])
    session_id = get_in(socket.assigns, [:analytics_identity, :session_id])

    if function_exported?(module, :latest_feedback_for_identity, 4) do
      normalize_existing_feedback(module.latest_feedback_for_identity(visitor_id, session_id, path, surface: "docs_page"))
    else
      empty_docs_feedback()
    end
  rescue
    _ -> empty_docs_feedback()
  end

  defp existing_docs_feedback(_socket, _path), do: empty_docs_feedback()

  defp empty_docs_feedback do
    %{submitted: false, value: nil, note: nil}
  end

  defp header_to_toc_item({tag_name, attrs, _content} = header) do
    %{
      id: header_id(attrs, header),
      title: Floki.text(header),
      level: String.to_integer(String.trim_leading(tag_name, "h")),
      children: []
    }
  end

  defp header_id(attrs, header) do
    Enum.find_value(attrs, fn
      {"id", id} -> id
      _ -> nil
    end) || slugify(Floki.text(header))
  end

  defp normalize_existing_feedback(%{feedback_value: value, feedback_note: note}) do
    case normalize_feedback_value(value) do
      nil ->
        empty_docs_feedback()

      normalized_value ->
        %{
          submitted: true,
          value: normalized_value,
          note: normalize_feedback_note(note)
        }
    end
  end

  defp normalize_existing_feedback(_other), do: empty_docs_feedback()

  defp analytics_module do
    Application.get_env(:agent_jido, :analytics_module, Analytics)
  end

  # Records a `long_running_path_entered` event when a connected visitor lands on
  # an operations page — the Operate / long-running path (jido-e12-t27). The dead
  # render never fires (it would double-count), and only `/docs/operations` pages
  # fire, so a non-operations docs page records nothing. Admin scopes are excluded
  # by Analytics.track_event_safe, so admin preview traffic is never counted. The
  # event carries the operations page slug as section_id; the per-visitor dedup in
  # the dashboard breakdown collapses repeat operations-page views to one
  # conversion per visitor.
  defp maybe_track_long_running_path_entry(socket, path) when is_binary(path) do
    if connected?(socket) and operations_path?(path) do
      slug = long_running_path_section_id(path)

      analytics_module().track_event_safe(socket.assigns.current_scope, %{
        event: "long_running_path_entered",
        source: "operate",
        channel: "long_running_path",
        path: path,
        section_id: slug,
        visitor_id: get_in(socket.assigns, [:analytics_identity, :visitor_id]),
        session_id: get_in(socket.assigns, [:analytics_identity, :session_id]),
        metadata: %{surface: "operations", page: slug}
      })
    end

    socket
  end

  defp maybe_track_long_running_path_entry(socket, _path), do: socket

  defp operations_path?("/docs/operations"), do: true
  defp operations_path?("/docs/operations/" <> _), do: true
  defp operations_path?(_), do: false

  defp long_running_path_section_id("/docs/operations"), do: "operations"
  defp long_running_path_section_id("/docs/operations/" <> slug), do: slug
  defp long_running_path_section_id(path) when is_binary(path), do: path
end
