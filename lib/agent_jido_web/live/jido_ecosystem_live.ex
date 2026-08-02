defmodule AgentJidoWeb.JidoEcosystemLive do
  use AgentJidoWeb, :live_view

  alias AgentJido.Ecosystem
  alias AgentJido.Ecosystem.Bookmarks, as: EcosystemBookmarks
  alias AgentJido.Ecosystem.Layering
  alias AgentJido.Ecosystem.SupportLevel
  alias AgentJido.GithubStarsTracker
  alias AgentJidoWeb.Jido.Nav
  alias AgentJidoWeb.MarkdownLinks
  alias AgentJidoWeb.StructuredData

  import AgentJidoWeb.Jido.MarketingCards
  import AgentJidoWeb.Jido.MarketingLayouts

  @layer_order [:foundation, :core, :ai, :app]
  @layer_filter_order [:all, :foundation, :core, :ai, :app]
  @support_level_order [:stable, :beta, :experimental]

  @impl true
  def mount(_params, _session, socket) do
    public_packages = Ecosystem.public_packages()

    {:ok,
     assign(socket,
       page_title: "Jido Ecosystem",
       meta_description: "Explore public Jido packages, support levels, and dependencies from a single ecosystem hub.",
       selected_layer: :all,
       selected_support_levels: [],
       current_params: %{},
       explorer_packages: [],
       compare_rows: [],
       bookmark_count: EcosystemBookmarks.count(),
       package_count: 0,
       layer_count: 0,
       support_levels: Ecosystem.support_levels(),
       orbit_payload_json: Jason.encode!(build_orbit_payload([])),
       structured_data: [
         StructuredData.breadcrumb_list([{"Jido", "/"}, {"Ecosystem", "/ecosystem"}]),
         ecosystem_item_list(public_packages)
       ]
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    public_packages = Ecosystem.public_packages()
    selected_support_levels = parse_support_levels(params)
    selected_layer = parse_layer(params)

    filtered_packages =
      public_packages
      |> filter_packages_by_support_levels(selected_support_levels)
      |> filter_packages_by_layer(selected_layer)

    title_by_id = Map.new(public_packages, &{&1.id, &1.title})
    stars_by_package = GithubStarsTracker.stars_map()

    {:noreply,
     assign(socket,
       current_params: params,
       selected_layer: selected_layer,
       selected_support_levels: selected_support_levels,
       explorer_packages: build_explorer_packages(filtered_packages, title_by_id, stars_by_package),
       compare_rows: build_compare_rows(filtered_packages, title_by_id, stars_by_package),
       orbit_payload_json: Jason.encode!(build_orbit_payload(filtered_packages)),
       package_count: length(filtered_packages),
       layer_count: count_layers(filtered_packages)
     )}
  end

  @impl true
  def handle_event("filter_layer", %{"layer" => layer}, socket) do
    next_layer = toggle_layer(socket.assigns.selected_layer, layer)

    next_params =
      socket.assigns.current_params
      |> Map.delete("layer")
      |> maybe_put_layer(next_layer)

    {:noreply, push_patch(socket, to: ecosystem_index_path(next_params))}
  end

  @impl true
  def handle_event("toggle_support_level", %{"support_level" => level}, socket) do
    next_support_levels =
      socket.assigns.selected_support_levels
      |> toggle_support_level(level)

    next_params =
      socket.assigns.current_params
      |> Map.delete("support_level")
      |> Map.delete("support_levels")
      |> maybe_put_support_levels(next_support_levels)

    {:noreply, push_patch(socket, to: ecosystem_index_path(next_params))}
  end

  @impl true
  def handle_event("clear_filters", _params, socket) do
    {:noreply, push_patch(socket, to: "/ecosystem")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.marketing_layout
      current_path="/ecosystem"
      current_scope={@current_scope}
      analytics_identity={@analytics_identity}
    >
      <div class="container max-w-[1000px] mx-auto px-6 py-12">
        <section class="mb-12">
          <div class="inline-block px-4 py-2 rounded mb-5 bg-primary/10 border border-primary/30">
            <span class="text-primary text-[11px] font-semibold tracking-widest uppercase">
              PACKAGE ECOSYSTEM
            </span>
          </div>

          <h1 class="text-3xl font-bold leading-tight mb-4 tracking-tight">
            Public Jido packages, one ecosystem map.<br />
            <span class="text-primary">Choose what you need without losing the system view.</span>
          </h1>

          <p class="copy-measure text-sm leading-relaxed text-secondary-foreground mb-4">
            The support policy, package explorer, architecture map, and compare table all come from the
            same public package registry. Use the full stack or compose the specific runtime, AI, and
            application packages your system needs.
          </p>

          <p class="copy-measure text-sm leading-relaxed text-secondary-foreground mb-6">
            Package detail pages remain the canonical deep links. This page is the hub for comparing
            packages, understanding support expectations, and tracing how the ecosystem fits together.
          </p>

          <div class="flex flex-wrap items-center gap-6 mb-8">
            <div class="flex items-baseline gap-2">
              <span class="text-primary text-2xl font-bold">{@package_count}</span>
              <span class="text-muted-foreground text-xs">packages</span>
            </div>
            <div class="flex items-baseline gap-2">
              <span class="text-primary text-2xl font-bold">{@layer_count}</span>
              <span class="text-muted-foreground text-xs">layers</span>
            </div>
            <a
              href="#compare"
              class="text-xs text-primary hover:text-primary/80 transition-colors font-semibold"
            >
              COMPARE PACKAGES ↓
            </a>
          </div>
        </section>

        <section class="mb-16">
          <div class="flex justify-between items-center mb-5">
            <span class="text-sm font-bold tracking-wider">SUPPORT LEVELS</span>
            <.link
              navigate="/docs/contributors/package-support-levels"
              class="text-xs text-primary hover:text-primary/80 transition-colors font-semibold"
            >
              VIEW POLICY →
            </.link>
          </div>

          <p class="copy-measure text-sm leading-relaxed text-secondary-foreground mb-5">
            Select one or more support levels. The same filter state applies to the explorer, orbit, and compare table below.
          </p>

          <div class="grid md:grid-cols-3 gap-3">
            <%= for level <- @support_levels do %>
              <button
                id={"support-level-#{level.id}"}
                type="button"
                aria-pressed={to_string(support_level_selected?(@selected_support_levels, level.id))}
                phx-click="toggle_support_level"
                phx-value-support_level={level.id}
                class={"rounded-md border p-4 text-left transition-colors #{support_level_card_class(@selected_support_levels, level.id)}"}
              >
                <div class="text-[11px] font-bold uppercase tracking-wide text-primary mb-2">{level.label}</div>
                <p class="text-xs text-foreground leading-relaxed">{level.summary}</p>
              </button>
            <% end %>
          </div>
        </section>

        <section class="mb-16">
          <div class="flex flex-col gap-4 md:flex-row md:items-end md:justify-between mb-6">
            <div>
              <span class="text-sm font-bold tracking-wider">PACKAGE EXPLORER</span>
              <p class="copy-measure text-sm leading-relaxed text-secondary-foreground mt-2">
                Filter by layer to narrow the public package set. These cards and the compare table stay in sync.
              </p>
            </div>

            <%= if filters_active?(@selected_layer, @selected_support_levels) do %>
              <button
                type="button"
                phx-click="clear_filters"
                class="text-xs text-muted-foreground hover:text-primary transition-colors font-semibold"
              >
                RESET FILTERS
              </button>
            <% end %>
          </div>

          <div class="flex flex-wrap gap-2 mb-6">
            <%= for layer <- layer_filter_order() do %>
              <button
                id={"layer-filter-#{layer}"}
                type="button"
                phx-click="filter_layer"
                phx-value-layer={layer}
                aria-pressed={to_string(@selected_layer == layer)}
                class={"px-4 py-2 text-[11px] rounded transition-colors #{layer_filter_class(@selected_layer, layer)}"}
              >
                {layer_filter_label(layer)}
              </button>
            <% end %>
          </div>

          <%= if @explorer_packages == [] do %>
            <article class="rounded-md border border-border bg-card/60 p-6">
              <div class="text-sm font-bold text-foreground mb-2">No packages match the current filters.</div>
              <p class="text-xs text-muted-foreground leading-relaxed">
                Reset the active filters to return to the full public package set.
              </p>
            </article>
          <% else %>
            <div class="grid md:grid-cols-2 lg:grid-cols-3 gap-4">
              <%= for pkg <- @explorer_packages do %>
                <.package_card
                  name={pkg.name}
                  desc={pkg.desc}
                  layer={pkg.layer}
                  path={pkg.path}
                  links={pkg.links}
                  support_level={pkg.support_level}
                  dependency_labels={pkg.dependency_labels}
                />
              <% end %>
            </div>
          <% end %>
        </section>

        <section :if={@package_count > 0} class="mb-16 hidden lg:block">
          <div class="flex justify-between items-center mb-5">
            <span class="text-sm font-bold tracking-wider">ECOSYSTEM MAP</span>
            <span class="text-[11px] text-muted-foreground">select a package to inspect relationships</span>
          </div>

          <div
            id="ecosystem-orbit"
            phx-update="ignore"
            phx-hook="EcosystemOrbit"
            data-orbit-payload={@orbit_payload_json}
            class="ecosystem-orbit-root"
          >
          </div>
        </section>

        <section id="compare" class="mb-16 scroll-mt-24">
          <div class="flex flex-col gap-3 md:flex-row md:items-end md:justify-between mb-5">
            <div>
              <span class="text-sm font-bold tracking-wider">COMPARE PACKAGES</span>
              <p class="copy-measure text-sm leading-relaxed text-secondary-foreground mt-2">
                Compare layer, support level, direct dependencies, and outbound links across the filtered package set.
              </p>
            </div>
            <span class="text-[11px] text-muted-foreground">{@package_count} rows</span>
          </div>

          <%= if @compare_rows == [] do %>
            <article class="rounded-md border border-border bg-card/60 p-6">
              <div class="text-sm font-bold text-foreground mb-2">No comparison rows are available.</div>
              <p class="text-xs text-muted-foreground leading-relaxed">
                Reset the current filters to compare the full public package set.
              </p>
            </article>
          <% else %>
            <section class="code-block overflow-hidden">
              <div class="code-header">
                <span class="text-[10px] text-muted-foreground">ecosystem_compare.csv</span>
                <span class="text-[10px] text-muted-foreground">{@package_count} rows</span>
              </div>

              <div class="overflow-x-auto">
                <table class="w-full min-w-[760px] text-xs table-fixed">
                  <colgroup>
                    <col class="w-[33%]" />
                    <col class="w-[12%]" />
                    <col class="w-[15%]" />
                    <col class="w-[25%]" />
                    <col class="w-[15%]" />
                  </colgroup>
                  <thead class="bg-elevated text-muted-foreground uppercase tracking-wider">
                    <tr>
                      <th class="text-left font-semibold px-3 py-3">Package</th>
                      <th class="text-left font-semibold px-3 py-3">Layer</th>
                      <th class="text-left font-semibold px-3 py-3">Support Level</th>
                      <th class="text-left font-semibold px-3 py-3">Dependencies</th>
                      <th class="text-left font-semibold px-3 py-3">Links</th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= for row <- @compare_rows do %>
                      <tr id={"compare-row-#{row.id}"} class="border-t border-border align-top">
                        <td class="px-3 py-3">
                          <.link navigate={row.path} class="font-semibold text-foreground hover:text-primary transition-colors">
                            {row.title}
                          </.link>
                          <div class="text-muted-foreground mt-1 break-words">{row.tagline}</div>
                        </td>
                        <td class="px-3 py-3">
                          <.layer_badge layer={row.layer} />
                        </td>
                        <td class="px-3 py-3">
                          <.support_level_badge level={row.support_level} />
                        </td>
                        <td class="px-3 py-3">
                          <%= if row.dependencies == [] do %>
                            <span class="text-muted-foreground">none</span>
                          <% else %>
                            <div class="flex flex-wrap gap-1.5">
                              <%= for dep <- row.dependencies do %>
                                <.link
                                  navigate={dep.path}
                                  class="text-[10px] px-2 py-1 rounded bg-primary/10 text-primary hover:bg-primary/15 transition-colors"
                                >
                                  {dep.title}
                                </.link>
                              <% end %>
                            </div>
                          <% end %>
                        </td>
                        <td class="px-3 py-3">
                          <%= if row.links == [] do %>
                            <span class="text-muted-foreground">n/a</span>
                          <% else %>
                            <div class="flex flex-wrap gap-2">
                              <%= for link <- row.links do %>
                                <a
                                  href={link.href}
                                  target="_blank"
                                  rel="noopener noreferrer"
                                  title={compare_link_title(link, row)}
                                  aria-label={compare_link_aria_label(link, row)}
                                  class={compare_link_class(link, row)}
                                >
                                  <%= if link.icon == :github do %>
                                    <Nav.github_icon class="h-4 w-4" />
                                    <span :if={row.github_stars} class="text-[10px] font-medium text-foreground">
                                      {row.github_stars}
                                    </span>
                                  <% else %>
                                    <.icon name={link.icon} class="h-4 w-4" />
                                  <% end %>
                                  <span class="sr-only">{link.label}</span>
                                </a>
                              <% end %>
                            </div>
                          <% end %>
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            </section>
          <% end %>
        </section>

        <section class="mb-16">
          <div class="rounded-lg border border-border bg-card/60 p-6 md:p-8">
            <div class="flex flex-col gap-4 md:flex-row md:items-end md:justify-between">
              <div>
                <span class="text-sm font-bold tracking-wider">REPO BOOKMARKS</span>
                <p class="copy-measure text-sm leading-relaxed text-secondary-foreground mt-2">
                  Download a flat browser bookmarks file for the full public Jido repo set. The export is generated
                  from ecosystem package metadata, so new public packages with GitHub URLs appear automatically.
                </p>
                <p class="copy-measure text-xs leading-relaxed text-muted-foreground mt-3">
                  Includes {@bookmark_count} GitHub repo bookmarks.
                  <.link navigate="/docs/contributors/ecosystem-atlas" class="text-primary hover:text-primary/80 transition-colors font-semibold ml-1">
                    See the Atlas →
                  </.link>
                </p>
              </div>

              <a
                href="/ecosystem/bookmarks.html"
                class="inline-flex items-center justify-center rounded bg-primary px-5 py-3 text-[13px] font-bold text-primary-foreground transition-colors hover:bg-primary/90"
              >
                DOWNLOAD BOOKMARKS
              </a>
            </div>
          </div>
        </section>

        <section class="mb-16">
          <div class="cta-glow rounded-lg p-12 text-center">
            <h2 class="text-2xl font-bold mb-3">Ready to build?</h2>
            <p class="text-secondary-foreground text-sm mb-6">
              Start with the getting started guide or explore production examples.
            </p>
            <div class="flex gap-3 justify-center">
              <.link
                navigate="/getting-started"
                class="bg-primary text-primary-foreground hover:bg-primary/90 text-[13px] font-bold px-7 py-3 rounded transition-colors"
              >
                GET STARTED →
              </.link>
              <.link
                navigate="/examples"
                class="border border-accent-cyan text-accent-cyan hover:bg-accent-cyan/10 text-[13px] font-medium px-7 py-3 rounded transition-colors"
              >
                VIEW EXAMPLES
              </.link>
            </div>
          </div>
        </section>
      </div>
    </.marketing_layout>
    """
  end

  defp filter_packages_by_support_levels(packages, []), do: packages

  defp filter_packages_by_support_levels(packages, support_levels) do
    Enum.filter(packages, &(SupportLevel.normalize(&1.support_level) in support_levels))
  end

  defp filter_packages_by_layer(packages, :all), do: packages
  defp filter_packages_by_layer(packages, layer), do: Enum.filter(packages, &(Layering.layer_for(&1) == layer))

  defp count_layers(packages) do
    packages
    |> Enum.map(&Layering.layer_for/1)
    |> Enum.uniq()
    |> length()
  end

  defp build_explorer_packages(packages, title_by_id, stars_by_package) do
    packages
    |> Enum.sort_by(fn pkg -> {layer_rank(Layering.layer_for(pkg)), String.downcase(pkg.title)} end)
    |> Enum.map(fn pkg ->
      %{
        id: pkg.id,
        name: pkg.name,
        desc: normalize_text(pkg.tagline),
        layer: Layering.layer_for(pkg),
        path: "/ecosystem/#{pkg.id}",
        links: build_package_links(pkg, stars_by_package),
        support_level: normalize_support_level(pkg.support_level),
        dependency_labels: dependency_labels(pkg, title_by_id, 3)
      }
    end)
  end

  defp build_compare_rows(packages, title_by_id, stars_by_package) do
    packages
    |> Enum.sort_by(fn pkg ->
      {compare_row_order(pkg), layer_rank(Layering.layer_for(pkg)), String.downcase(pkg.title)}
    end)
    |> Enum.map(fn pkg ->
      %{
        id: pkg.id,
        title: pkg.title,
        tagline: normalize_text(pkg.tagline),
        path: "/ecosystem/#{pkg.id}",
        layer: Layering.layer_for(pkg),
        support_level: normalize_support_level(pkg.support_level),
        dependencies: dependency_links(pkg, title_by_id),
        github_stars: github_stars_label(pkg, stars_by_package),
        links: build_compare_links(pkg)
      }
    end)
  end

  defp build_package_links(pkg, stars_by_package) do
    github_label =
      case Map.get(stars_by_package, pkg.id) do
        %{stars: count} when is_integer(count) and count >= 0 ->
          "github ★#{GithubStarsTracker.format_stars(count)}"

        _other ->
          "github"
      end

    []
    |> maybe_push_link("docs", pkg.hexdocs_url)
    |> maybe_push_link("hex", pkg.hex_url)
    |> maybe_push_link(github_label, pkg.github_url)
  end

  defp build_compare_links(pkg) do
    []
    |> maybe_push_compare_link("HexDocs", "hero-book-open", pkg.hexdocs_url)
    |> maybe_push_compare_link("Hex.pm", "hero-cube", pkg.hex_url)
    |> maybe_push_compare_link("GitHub", :github, pkg.github_url)
  end

  defp dependency_links(pkg, title_by_id) do
    pkg.ecosystem_deps
    |> List.wrap()
    |> Enum.filter(&Map.has_key?(title_by_id, &1))
    |> Enum.map(fn dep_id ->
      %{
        id: dep_id,
        title: Map.fetch!(title_by_id, dep_id),
        path: "/ecosystem/#{dep_id}"
      }
    end)
  end

  defp dependency_labels(pkg, title_by_id, max_count) do
    pkg
    |> dependency_links(title_by_id)
    |> Enum.map(& &1.title)
    |> Enum.take(max_count)
  end

  defp maybe_push_link(links, _label, nil), do: links
  defp maybe_push_link(links, label, href), do: links ++ [{label, href}]

  defp maybe_push_compare_link(links, _label, _icon, nil), do: links

  defp maybe_push_compare_link(links, label, icon, href) do
    links ++ [%{label: label, icon: icon, href: href}]
  end

  defp github_stars_label(pkg, stars_by_package) do
    case Map.get(stars_by_package, pkg.id) do
      %{stars: count} when is_integer(count) and count >= 0 ->
        GithubStarsTracker.format_stars(count)

      _other ->
        nil
    end
  end

  defp build_orbit_payload(public_packages) when is_list(public_packages) do
    orbit_packages = packages_for_orbit(public_packages)
    public_ids = MapSet.new(orbit_packages, & &1.id)

    packages =
      orbit_packages
      |> Enum.map(&to_orbit_package(&1, public_ids))
      |> Enum.filter(& &1.visible)
      |> Enum.sort_by(fn pkg ->
        {orbit_layer_rank(pkg.layer), normalize_orbit_order(pkg.order), String.downcase(pkg.name)}
      end)

    center_id =
      packages
      |> Enum.find_value(fn pkg -> if pkg.layer == "core", do: pkg.id, else: nil end)

    domains =
      packages
      |> Enum.map(& &1.domain)
      |> Enum.uniq()
      |> Enum.sort()
      |> Enum.map(fn domain ->
        %{
          id: domain,
          label: domain_label(domain)
        }
      end)

    %{
      center_id: center_id,
      layers: Enum.map(@layer_order, &Atom.to_string/1),
      domains: domains,
      packages: packages
    }
  end

  defp to_orbit_package(pkg, public_ids) do
    layer = Layering.layer_for(pkg)
    deps = pkg.ecosystem_deps |> List.wrap() |> Enum.filter(&MapSet.member?(public_ids, &1))

    %{
      id: pkg.id,
      name: pkg.name,
      title: pkg.title,
      path: "/ecosystem/#{pkg.id}",
      layer: Atom.to_string(layer),
      category: to_string_or_empty(pkg.category),
      domain: orbit_domain(pkg, layer),
      label: orbit_label(pkg),
      maturity: to_string_or_empty(normalize_support_level(pkg.support_level)),
      deps: deps,
      orbit_parent: Map.get(pkg, :orbit_parent),
      order: Map.get(pkg, :orbit_order),
      weight: Map.get(pkg, :orbit_weight),
      visible: Map.get(pkg, :orbit_visible, true)
    }
  end

  defp orbit_domain(pkg, layer) do
    case Map.get(pkg, :orbit_domain) do
      nil ->
        case Map.get(pkg, :category) do
          nil -> Atom.to_string(layer)
          value -> to_string_or_empty(value)
        end

      value ->
        to_string_or_empty(value)
    end
  end

  defp orbit_label(pkg) do
    case Map.get(pkg, :orbit_label) do
      value when is_binary(value) and value != "" -> value
      _other -> pkg.graph_label || pkg.name
    end
  end

  defp domain_label(domain) when is_binary(domain) do
    domain
    |> String.replace("_", " ")
    |> String.split(" ", trim: true)
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp domain_label(other), do: other |> to_string() |> domain_label()

  defp normalize_orbit_order(order) when is_integer(order), do: order
  defp normalize_orbit_order(_order), do: 9_999

  defp compare_row_order(pkg) do
    case Map.get(pkg, :compare_order) do
      order when is_integer(order) -> order
      _other -> 9_999
    end
  end

  defp compare_link_title(%{icon: :github}, %{github_stars: stars}) when is_binary(stars) do
    "GitHub (#{stars} stars)"
  end

  defp compare_link_title(link, _row), do: link.label

  defp compare_link_aria_label(%{icon: :github}, %{title: title, github_stars: stars}) when is_binary(stars) do
    "Open GitHub for #{title} (#{stars} stars)"
  end

  defp compare_link_aria_label(link, row), do: "Open #{link.label} for #{row.title}"

  defp compare_link_class(%{icon: :github}, %{github_stars: stars}) when is_binary(stars) do
    "inline-flex h-8 items-center gap-1.5 rounded bg-elevated px-2 text-muted-foreground hover:text-primary transition-colors"
  end

  defp compare_link_class(_link, _row) do
    "inline-flex h-8 w-8 items-center justify-center rounded bg-elevated text-muted-foreground hover:text-primary transition-colors"
  end

  defp orbit_layer_rank("foundation"), do: 1
  defp orbit_layer_rank("core"), do: 2
  defp orbit_layer_rank("ai"), do: 3
  defp orbit_layer_rank("app"), do: 4
  defp orbit_layer_rank(_layer), do: 99

  defp to_string_or_empty(value) when is_atom(value), do: Atom.to_string(value)
  defp to_string_or_empty(value) when is_binary(value), do: value
  defp to_string_or_empty(value) when is_integer(value), do: Integer.to_string(value)
  defp to_string_or_empty(value) when is_float(value), do: :erlang.float_to_binary(value, decimals: 2)
  defp to_string_or_empty(_value), do: ""

  defp maybe_put_support_levels(params, []), do: params

  defp maybe_put_support_levels(params, support_levels) do
    Map.put(params, "support_levels", Enum.map_join(support_levels, ",", &Atom.to_string/1))
  end

  defp maybe_put_layer(params, :all), do: params
  defp maybe_put_layer(params, layer), do: Map.put(params, "layer", Atom.to_string(layer))

  defp ecosystem_index_path(params) when map_size(params) == 0, do: "/ecosystem"
  defp ecosystem_index_path(params), do: "/ecosystem?" <> URI.encode_query(params)

  defp parse_support_levels(params) do
    params
    |> Map.get("support_levels", Map.get(params, "support_level", ""))
    |> to_string()
    |> String.split(",", trim: true)
    |> Enum.map(&SupportLevel.normalize/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.sort_by(&support_level_rank/1)
  end

  defp parse_layer(params) do
    case params |> Map.get("layer", "all") |> normalize_layer_param() do
      nil -> :all
      layer -> layer
    end
  end

  defp normalize_layer_param(layer) when layer in @layer_filter_order, do: layer

  defp normalize_layer_param(layer) when is_binary(layer) do
    case String.to_existing_atom(layer) do
      parsed when parsed in @layer_filter_order -> parsed
      _other -> nil
    end
  rescue
    ArgumentError -> nil
  end

  defp normalize_layer_param(_layer), do: nil

  defp toggle_support_level(selected_support_levels, level) do
    case SupportLevel.normalize(level) do
      nil ->
        selected_support_levels

      normalized ->
        if normalized in selected_support_levels do
          selected_support_levels
          |> Enum.reject(&(&1 == normalized))
          |> Enum.sort_by(&support_level_rank/1)
        else
          (selected_support_levels ++ [normalized])
          |> Enum.uniq()
          |> Enum.sort_by(&support_level_rank/1)
        end
    end
  end

  defp toggle_layer(selected_layer, layer) do
    case normalize_layer_param(layer) do
      nil ->
        selected_layer

      normalized when normalized == selected_layer and normalized != :all ->
        :all

      normalized ->
        normalized
    end
  end

  defp support_level_rank(level), do: Enum.find_index(@support_level_order, &(&1 == level)) || 99

  defp packages_for_orbit(public_packages) do
    case Enum.find(Ecosystem.public_packages(), &(&1.id == "jido")) do
      nil ->
        public_packages

      anchor_package ->
        [anchor_package | public_packages]
        |> Enum.uniq_by(& &1.id)
    end
  end

  defp layer_rank(:foundation), do: 1
  defp layer_rank(:core), do: 2
  defp layer_rank(:ai), do: 3
  defp layer_rank(:app), do: 4

  defp layer_filter_label(:all), do: "ALL"
  defp layer_filter_label(:foundation), do: "FOUNDATION"
  defp layer_filter_label(:core), do: "CORE"
  defp layer_filter_label(:ai), do: "AI"
  defp layer_filter_label(:app), do: "APPLICATION"

  defp layer_filter_order, do: @layer_filter_order

  defp layer_filter_class(layer, layer), do: active_layer_filter_class(layer)
  defp layer_filter_class(_selected_layer, _layer), do: "border border-border text-muted-foreground hover:text-foreground"

  defp active_layer_filter_class(:all), do: "bg-primary/10 border border-primary text-primary font-semibold"
  defp active_layer_filter_class(:foundation), do: "bg-accent-cyan/10 border border-accent-cyan text-accent-cyan font-semibold"
  defp active_layer_filter_class(:core), do: "bg-primary/10 border border-primary text-primary font-semibold"
  defp active_layer_filter_class(:ai), do: "bg-accent-yellow/10 border border-accent-yellow text-accent-yellow font-semibold"
  defp active_layer_filter_class(:app), do: "bg-accent-red/10 border border-accent-red text-accent-red font-semibold"

  defp filters_active?(:all, []), do: false
  defp filters_active?(_selected_layer, _selected_support_levels), do: true

  defp support_level_selected?(selected_support_levels, level_id), do: level_id in selected_support_levels

  defp support_level_card_class(selected_support_levels, level_id) do
    if level_id in selected_support_levels do
      "bg-primary/10 border-primary text-foreground shadow-[0_0_0_1px_rgba(78,238,180,0.25)]"
    else
      "bg-card border-border hover:border-primary/40"
    end
  end

  defp normalize_support_level(level), do: SupportLevel.normalize(level) || :experimental

  defp normalize_text(text) when is_binary(text), do: text |> String.trim() |> String.replace(~r/\s+/, " ")
  defp normalize_text(_text), do: ""

  defp ecosystem_item_list(packages) do
    %{
      "@context" => "https://schema.org",
      "@type" => "ItemList",
      "name" => "Jido Ecosystem Packages",
      "url" => MarkdownLinks.absolute_url("/ecosystem"),
      "numberOfItems" => length(packages),
      "itemListElement" =>
        packages
        |> Enum.sort_by(fn pkg -> {layer_rank(Layering.layer_for(pkg)), String.downcase(pkg.title)} end)
        |> Enum.with_index(1)
        |> Enum.map(fn {pkg, index} ->
          %{
            "@type" => "ListItem",
            "position" => index,
            "name" => pkg.title,
            "url" => MarkdownLinks.absolute_url("/ecosystem/#{pkg.id}")
          }
        end)
    }
  end
end
