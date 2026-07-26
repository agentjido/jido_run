defmodule AgentJidoWeb.JidoEcosystemPackageLive do
  use AgentJidoWeb, :live_view

  alias AgentJido.Ecosystem
  alias AgentJido.Ecosystem.Layering
  alias AgentJido.Ecosystem.SupportLevel
  alias AgentJido.GithubStarsTracker
  alias AgentJidoWeb.MarkdownLinks

  import AgentJidoWeb.Jido.MarketingCards
  import AgentJidoWeb.Jido.MarketingLayouts

  @max_cliff_notes 6
  @fallback_cliff_notes 4
  @resource_group_order [:start_here, :guides, :examples, :reference]
  @relationship_group_order [:builds_on, :works_with, :next_step]
  @default_builds_on_reason "Core package this library builds on directly."

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    package = Ecosystem.get_public_package!(id)
    stars = GithubStarsTracker.stars_for(package.id)
    support_level = SupportLevel.definition(package.support_level) || SupportLevel.definition(:experimental)
    package_hero_summary = hero_summary(package)
    faq_items = faq_items(package)
    keywords = package_meta_keywords(package)

    {:ok,
     assign(socket,
       page_title: package_page_title(package, package_hero_summary),
       og_title: package_og_title(package, package_hero_summary),
       meta_description: package_meta_description(package, package_hero_summary),
       og_description: package_og_description(package, package_hero_summary),
       meta_keywords: keywords,
       package: package,
       layer: Layering.layer_for(package),
       package_links: package_links(package, stars),
       markdown_action: MarkdownLinks.markdown_action(package, MarkdownLinks.absolute_url("/ecosystem/#{package.id}")),
       hero_summary: package_hero_summary,
       support_level: support_level,
       tested_version: package_tested_version(package),
       last_synced: package_last_synced(package),
       use_when: landing_use_when(package),
       not_for: landing_not_for(package),
       resource_groups: resource_groups(package),
       cliff_notes: cliff_notes(package),
       major_components: major_components(package),
       module_map: module_map(package),
       related_package_groups: related_package_groups(package),
       faq_items: faq_items,
       install: landing_install(package),
       structured_data: package_structured_data(package, package_hero_summary, keywords, faq_items)
     )}
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
        <div class="mb-8">
          <.link navigate="/ecosystem" class="text-xs text-muted-foreground hover:text-primary transition-colors">
            ← back to ecosystem
          </.link>
        </div>

        <section class="ecosystem-package-hero mb-12">
          <div class="flex flex-wrap items-center gap-3 mb-4">
            <.layer_badge layer={@layer} />
            <.support_level_badge level={@support_level.id} />
            <span class="text-[11px] uppercase tracking-wide text-muted-foreground">
              version {@package.version}
            </span>
            <span class="text-[11px] uppercase tracking-wide text-muted-foreground">
              hex {@package.hex_status}
            </span>
            <span class="text-[11px] uppercase tracking-wide text-muted-foreground">
              tested {@tested_version}
            </span>
            <span class="text-[11px] uppercase tracking-wide text-muted-foreground">
              synced {@last_synced}
            </span>
            <span class="text-[11px] uppercase tracking-wide text-muted-foreground">
              package {@package.name}
            </span>
            <span :if={present?(@package.elixir)} class="text-[11px] uppercase tracking-wide text-muted-foreground">
              elixir {@package.elixir}
            </span>
          </div>

          <h1 class="text-3xl font-bold tracking-tight mb-3">{@package.title}</h1>
          <p class="copy-measure-wide mb-4 text-sm leading-relaxed text-secondary-foreground">
            {@hero_summary}
          </p>
          <p class="copy-measure-wide mb-6 text-xs leading-relaxed text-muted-foreground">
            <span class="font-semibold text-foreground">{SupportLevel.label(@package.support_level)} support.</span>
            {@support_level.short_commitment}
          </p>

          <%= if @package_links != [] do %>
            <div class="flex gap-2 flex-wrap mb-5">
              <%= for link <- @package_links do %>
                <a
                  href={link.href}
                  target="_blank"
                  rel="noopener noreferrer"
                  class={"text-xs px-3 py-2 rounded border transition-colors font-semibold #{cta_link_class(link.kind)}"}
                >
                  {link.label}
                </a>
              <% end %>
            </div>
          <% end %>

          <div :if={@install} class="code-block overflow-hidden mb-4">
            <div class="code-header">
              <span class="text-[10px] text-muted-foreground">{@install.label}</span>
              <span class="text-[10px] text-muted-foreground">{@install.source_label}</span>
            </div>
            <div class="p-4">
              <p :if={@install.note != ""} class="text-[11px] leading-relaxed text-muted-foreground mb-3">
                {@install.note}
              </p>
              <pre class="text-[11px] leading-relaxed whitespace-pre-wrap">{@install.snippet}</pre>
            </div>
          </div>

          <a
            href={@markdown_action.url}
            target="_blank"
            rel="noopener noreferrer"
            class="inline-flex text-[10px] font-semibold uppercase tracking-[0.22em] text-muted-foreground hover:text-primary transition-colors"
          >
            View package metadata source →
          </a>
        </section>

        <section :if={@use_when != [] or @not_for != []} class="mb-12">
          <h2 class="text-sm font-bold tracking-wider mb-4">WHEN TO USE {@package.title}</h2>
          <div class="grid gap-4 md:grid-cols-2">
            <article :if={@use_when != []} class="bg-card border border-border rounded-md p-5">
              <div class="text-[10px] uppercase tracking-wide text-muted-foreground mb-3">Use This When</div>
              <ul class="space-y-3 text-sm text-foreground/90">
                <li :for={item <- @use_when} class="leading-relaxed">
                  {item}
                </li>
              </ul>
            </article>

            <article :if={@not_for != []} class="bg-card border border-border rounded-md p-5">
              <div class="text-[10px] uppercase tracking-wide text-muted-foreground mb-3">Not The Right Fit When</div>
              <ul class="space-y-3 text-sm text-foreground/90">
                <li :for={item <- @not_for} class="leading-relaxed">
                  {item}
                </li>
              </ul>
            </article>
          </div>
        </section>

        <section :if={@resource_groups != []} class="mb-12">
          <h2 class="text-sm font-bold tracking-wider mb-4">START HERE</h2>
          <div class="grid gap-4 md:grid-cols-2">
            <article :for={group <- @resource_groups} class="bg-card border border-border rounded-md p-5">
              <div class="text-[10px] uppercase tracking-wide text-muted-foreground mb-4">{group.title}</div>
              <div class="space-y-4">
                <div :for={resource <- group.items} class="border-t border-border/70 pt-4 first:border-t-0 first:pt-0">
                  <.link
                    :if={resource.internal}
                    navigate={resource.href}
                    class="text-sm font-semibold text-foreground hover:text-primary transition-colors"
                  >
                    {resource.label}
                  </.link>
                  <a
                    :if={!resource.internal}
                    href={resource.href}
                    target="_blank"
                    rel="noopener noreferrer"
                    class="text-sm font-semibold text-foreground hover:text-primary transition-colors"
                  >
                    {resource.label}
                  </a>
                  <p :if={resource.description != ""} class="text-xs leading-relaxed text-muted-foreground mt-2">
                    {resource.description}
                  </p>
                </div>
              </div>
            </article>
          </div>
        </section>

        <section :if={@major_components != []} class="mb-12">
          <h2 class="text-sm font-bold tracking-wider mb-4">KEY MODULES</h2>
          <div class="ecosystem-major-components-grid">
            <%= for component <- @major_components do %>
              <article class="ecosystem-major-component-card">
                <div class="text-sm font-bold text-foreground mb-1">{component.name}</div>
                <p :if={component.summary != ""} class="text-xs text-muted-foreground leading-relaxed">
                  {component.summary}
                </p>
                <div class="flex gap-2 mt-3 flex-wrap">
                  <a
                    :if={component.docs_url}
                    href={component.docs_url}
                    target="_blank"
                    rel="noopener noreferrer"
                    class="text-[10px] px-2 py-1 rounded border border-accent-cyan/40 bg-accent-cyan/10 text-accent-cyan hover:bg-accent-cyan/15 transition-colors font-semibold"
                  >
                    hexdocs
                  </a>
                  <a
                    :if={component.github_url}
                    href={component.github_url}
                    target="_blank"
                    rel="noopener noreferrer"
                    class="text-[10px] px-2 py-1 rounded border border-border bg-elevated text-foreground hover:text-primary transition-colors font-semibold"
                  >
                    github
                  </a>
                </div>
              </article>
            <% end %>
          </div>
        </section>

        <section :if={@module_map} class="mb-12">
          <h2 class="text-sm font-bold tracking-wider mb-4">{@module_map.title}</h2>
          <div class="ecosystem-module-map">
            <%= for row <- @module_map.rows do %>
              <div class="ecosystem-module-row">
                <div class="ecosystem-module-row-label">{row.label}</div>
                <div class="ecosystem-module-row-nodes" style={"--module-cols: #{max(length(row.nodes), 1)}"}>
                  <%= for node <- row.nodes do %>
                    <article class="ecosystem-module-node">
                      <.link :if={node.path} navigate={node.path} class="text-xs font-semibold text-foreground hover:text-primary transition-colors">
                        {node.label}
                      </.link>
                      <span :if={!node.path} class="text-xs font-semibold text-foreground">{node.label}</span>
                      <p :if={node.note != ""} class="text-[10px] text-muted-foreground leading-relaxed mt-1">{node.note}</p>
                    </article>
                  <% end %>
                </div>
              </div>
            <% end %>

            <%= if @module_map.edges != [] do %>
              <div class="mt-4">
                <div class="text-[10px] uppercase tracking-wider text-muted-foreground mb-2">Flow</div>
                <div class="flex flex-wrap gap-2">
                  <%= for edge <- @module_map.edges do %>
                    <span class="ecosystem-module-edge">
                      {edge.from} -> {edge.to}
                      <span :if={edge.label != ""} class="text-muted-foreground">({edge.label})</span>
                    </span>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        </section>

        <section :if={@related_package_groups != []} class="mb-12">
          <h2 class="text-sm font-bold tracking-wider mb-4">RELATED PACKAGES</h2>
          <div class="grid gap-4 md:grid-cols-3">
            <article :for={group <- @related_package_groups} class="bg-card border border-border rounded-md p-5">
              <div class="text-[10px] uppercase tracking-wide text-muted-foreground mb-4">{group.title}</div>
              <div class="space-y-4">
                <div :for={pkg <- group.items} class="border-t border-border/70 pt-4 first:border-t-0 first:pt-0">
                  <.link navigate={pkg.path} class="text-sm font-semibold text-foreground hover:text-primary transition-colors">
                    {pkg.title}
                  </.link>
                  <p class="text-xs leading-relaxed text-muted-foreground mt-2">{pkg.reason}</p>
                  <div class="flex gap-2 mt-3 flex-wrap">
                    <.link navigate={pkg.path} class="text-[10px] px-2 py-1 rounded bg-primary/10 text-primary hover:bg-primary/15 transition-colors">
                      ecosystem page
                    </.link>
                    <a
                      :if={pkg.external_href}
                      href={pkg.external_href}
                      target="_blank"
                      rel="noopener noreferrer"
                      class="text-[10px] px-2 py-1 rounded bg-elevated text-muted-foreground hover:text-primary transition-colors"
                    >
                      {pkg.external_label}
                    </a>
                  </div>
                </div>
              </div>
            </article>
          </div>
        </section>

        <section :if={@cliff_notes != []} class="mb-12">
          <h2 class="text-sm font-bold tracking-wider mb-4">AT A GLANCE</h2>
          <div class="ecosystem-cliff-notes-grid">
            <%= for note <- @cliff_notes do %>
              <article class="ecosystem-cliff-note">
                {note}
              </article>
            <% end %>
          </div>
        </section>

        <section :if={@faq_items != []} class="mb-12">
          <h2 class="text-sm font-bold tracking-wider mb-4">FAQ</h2>
          <div class="space-y-3">
            <details :for={item <- @faq_items} class="bg-card border border-border rounded-md p-4">
              <summary class="cursor-pointer text-sm font-semibold text-foreground">
                {item.question}
              </summary>
              <p class="text-xs leading-relaxed text-muted-foreground mt-3">
                {item.answer}
              </p>
            </details>
          </div>
        </section>

        <section class="ecosystem-package-details mb-12">
          <h2 class="text-sm font-bold tracking-wider mb-4">DEEP DIVE</h2>
          <article class="prose max-w-none text-sm leading-relaxed text-foreground prose-headings:text-foreground prose-p:text-foreground/90 prose-li:text-foreground/90 prose-strong:text-foreground prose-code:text-foreground">
            {Phoenix.HTML.raw(@package.body)}
          </article>
        </section>
      </div>
    </.marketing_layout>
    """
  end

  defp package_links(pkg, stars) do
    github_label =
      case stars do
        %{stars: count} when is_integer(count) and count >= 0 ->
          "GitHub ★#{GithubStarsTracker.format_stars(count)}"

        _other ->
          "GitHub"
      end

    issue_queue_href = issue_queue_url(pkg.github_url)

    []
    |> maybe_push_cta(:docs, "Docs", pkg.hexdocs_url)
    |> maybe_push_cta(:hex, "Hex", pkg.hex_url)
    |> maybe_push_cta(:github, github_label, pkg.github_url)
    |> maybe_push_cta(:issues, "Issues", issue_queue_href)
  end

  defp maybe_push_cta(links, _kind, _label, nil), do: links
  defp maybe_push_cta(links, _kind, _label, ""), do: links

  defp maybe_push_cta(links, kind, label, href) do
    links ++ [%{kind: kind, label: label, href: href}]
  end

  defp hero_summary(pkg) do
    summary = normalize_text(pkg.landing_summary)

    if summary == "" do
      normalize_text(pkg.tagline)
    else
      summary
    end
  end

  # The version this package's registry entry was validated against. Falls back
  # to the package `version` (kept in sync with the installed release for
  # dependency packages by the version-freshness gate) so every package page
  # surfaces a tested version.
  defp package_tested_version(pkg) do
    case normalize_optional_text(pkg.tested_version) do
      nil -> pkg.version
      version -> version
    end
  end

  # The date this package's registry entry was last synced. Falls back to the
  # registry-wide reconciliation date so freshness is visible on every page
  # before per-package sync dates are populated.
  defp package_last_synced(pkg) do
    case normalize_optional_text(pkg.last_synced) do
      nil -> Ecosystem.registry_last_synced()
      date -> date
    end
  end

  defp package_page_title(pkg, summary) do
    case package_seo_value(pkg, :title) do
      "" ->
        case normalize_text(summary) do
          "" -> pkg.title
          normalized -> "#{pkg.title}: #{normalized}"
        end

      title ->
        title
    end
  end

  defp package_og_title(pkg, summary) do
    case package_seo_value(pkg, :og_title) do
      "" -> package_page_title(pkg, summary)
      title -> title
    end
  end

  defp package_meta_description(pkg, summary) do
    case package_seo_value(pkg, :description) do
      "" ->
        package_default_meta_description(pkg, summary)

      description ->
        description
    end
  end

  defp package_default_meta_description(pkg, summary) do
    case normalize_text(summary) do
      "" -> "Learn about #{package_description_prefix(pkg)} in the Jido ecosystem and how it fits into production Elixir systems."
      normalized_summary -> normalized_summary
    end
  end

  defp package_description_prefix(pkg) do
    case SupportLevel.label(pkg.support_level) do
      nil -> pkg.title
      label -> "#{pkg.title} (#{label})"
    end
  end

  defp package_og_description(pkg, summary) do
    case package_seo_value(pkg, :og_description) do
      "" -> package_meta_description(pkg, summary)
      description -> description
    end
  end

  defp package_meta_keywords(pkg) do
    pkg
    |> package_keyword_values()
    |> Enum.join(", ")
  end

  defp package_keyword_values(pkg) do
    seo_keywords =
      pkg
      |> package_seo()
      |> get_key(:keywords, [])
      |> normalize_keyword_list()

    source_keywords =
      if seo_keywords == [] do
        [
          pkg.title,
          pkg.name,
          "elixir",
          "#{pkg.title} package",
          Layering.layer_for(pkg) |> Atom.to_string(),
          SupportLevel.label(pkg.support_level),
          pkg.elixir | List.wrap(pkg.tags)
        ]
        |> normalize_keyword_list()
      else
        seo_keywords
      end

    source_keywords
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end

  defp landing_use_when(pkg), do: normalize_string_list(pkg.landing_use_when)
  defp landing_not_for(pkg), do: normalize_string_list(pkg.landing_not_for)

  defp cliff_notes(pkg) do
    custom_notes = normalize_string_list(pkg.landing_cliff_notes) |> Enum.take(@max_cliff_notes)

    case custom_notes do
      [] ->
        pkg.key_features
        |> normalize_string_list()
        |> Enum.take(@fallback_cliff_notes)

      notes ->
        notes
    end
  end

  defp resource_groups(pkg) do
    items = normalize_resource_items(pkg.landing_resources)

    @resource_group_order
    |> Enum.map(fn group ->
      group_items = Enum.filter(items, &(&1.group == group))

      if group_items == [] do
        nil
      else
        %{id: group, title: resource_group_title(group), items: group_items}
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_resource_items(items) when is_list(items) do
    items
    |> Enum.map(fn item ->
      group = item |> get_key(:group, nil) |> normalize_resource_group()
      label = item |> get_key(:label, "") |> normalize_text()
      href = item |> get_key(:href, "") |> normalize_text()
      description = item |> get_key(:description, "") |> normalize_text()

      if is_nil(group) or label == "" or href == "" do
        nil
      else
        %{
          group: group,
          label: label,
          href: href,
          description: description,
          internal: internal_path?(href)
        }
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_resource_items(_), do: []

  defp normalize_resource_group(group) when is_atom(group) and group in @resource_group_order, do: group

  defp normalize_resource_group(group) when is_binary(group) do
    group
    |> String.trim()
    |> String.downcase()
    |> case do
      "start_here" -> :start_here
      "guides" -> :guides
      "examples" -> :examples
      "reference" -> :reference
      _other -> nil
    end
  end

  defp normalize_resource_group(_group), do: nil

  defp resource_group_title(:start_here), do: "Start Here"
  defp resource_group_title(:guides), do: "Guides"
  defp resource_group_title(:examples), do: "Examples"
  defp resource_group_title(:reference), do: "Reference"

  defp related_package_groups(pkg) do
    resolved_items = pkg |> related_package_source_items() |> resolve_related_package_items()

    @relationship_group_order
    |> Enum.map(fn relationship ->
      items = Enum.filter(resolved_items, &(&1.relationship == relationship))

      if items == [] do
        nil
      else
        %{id: relationship, title: relationship_title(relationship), items: items}
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp related_package_source_items(pkg) do
    case normalize_related_package_items(pkg.landing_related_packages) do
      [] -> fallback_related_package_items(pkg)
      items -> items
    end
  end

  defp resolve_related_package_items(source_items) do
    source_items
    |> Enum.reduce({MapSet.new(), []}, &resolve_related_package_item/2)
    |> elem(1)
  end

  defp resolve_related_package_item(item, {seen, acc}) do
    dedupe_key = {item.relationship, item.id}

    if MapSet.member?(seen, dedupe_key) do
      {seen, acc}
    else
      {MapSet.put(seen, dedupe_key), append_resolved_package(acc, resolve_related_package(item))}
    end
  end

  defp append_resolved_package(acc, nil), do: acc
  defp append_resolved_package(acc, resolved), do: acc ++ [resolved]

  defp normalize_related_package_items(items) when is_list(items) do
    items
    |> Enum.map(fn item ->
      id = item |> get_key(:id, nil) |> normalize_text()
      relationship = item |> get_key(:relationship, nil) |> normalize_relationship()
      reason = item |> get_key(:reason, "") |> normalize_text()

      if id == "" or is_nil(relationship) or reason == "" do
        nil
      else
        %{id: id, relationship: relationship, reason: reason}
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_related_package_items(_), do: []

  defp fallback_related_package_items(pkg) do
    pkg.ecosystem_deps
    |> List.wrap()
    |> Enum.map(fn id ->
      normalized = normalize_text(id)

      if normalized == "" do
        nil
      else
        %{
          id: normalized,
          relationship: :builds_on,
          reason: fallback_builds_on_reason(pkg)
        }
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_relationship(value) when is_atom(value) and value in @relationship_group_order, do: value

  defp normalize_relationship(value) when is_binary(value) do
    value
    |> String.trim()
    |> String.downcase()
    |> case do
      "builds_on" -> :builds_on
      "works_with" -> :works_with
      "next_step" -> :next_step
      _other -> nil
    end
  end

  defp normalize_relationship(_value), do: nil

  defp relationship_title(:builds_on), do: "Builds on"
  defp relationship_title(:works_with), do: "Works with"
  defp relationship_title(:next_step), do: "Add next"

  defp fallback_builds_on_reason(pkg) do
    case normalize_text(pkg.title) do
      "" -> @default_builds_on_reason
      title -> "#{title} builds directly on this ecosystem package."
    end
  end

  defp resolve_related_package(%{id: id, relationship: relationship, reason: reason}) do
    case Ecosystem.get_public_package(id) do
      nil ->
        nil

      related ->
        {label, href} = external_doc_link(related)

        %{
          id: related.id,
          relationship: relationship,
          title: related.title,
          path: "/ecosystem/#{related.id}",
          reason: reason,
          external_label: label,
          external_href: href
        }
    end
  end

  defp major_components(pkg) do
    pkg.landing_major_components
    |> normalize_major_components(pkg)
  end

  defp normalize_major_components(components, pkg) when is_list(components) do
    components
    |> Enum.map(fn component ->
      name =
        component
        |> get_key(:name, get_key(component, :module, ""))
        |> normalize_text()

      summary = component |> get_key(:summary, "") |> normalize_text()

      docs_url =
        component
        |> get_key(:docs_url, get_key(component, :hexdocs_url, nil))
        |> normalize_optional_text()
        |> Kernel.||(derived_module_docs_url(name, pkg.hexdocs_url))

      github_url = component |> get_key(:github_url, nil) |> normalize_optional_text()

      if name == "" do
        nil
      else
        %{
          name: name,
          summary: summary,
          docs_url: docs_url,
          github_url: github_url
        }
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_major_components(_, _pkg), do: []

  defp derived_module_docs_url(name, hexdocs_url) do
    normalized_name = normalize_text(name)
    normalized_docs = normalize_optional_text(hexdocs_url)

    cond do
      normalized_name == "" or is_nil(normalized_docs) ->
        nil

      Regex.match?(~r/^[A-Z][A-Za-z0-9_.]+$/, normalized_name) ->
        "#{String.trim_trailing(normalized_docs, "/")}/#{normalized_name}.html"

      true ->
        nil
    end
  end

  defp module_map(pkg) do
    map = pkg.landing_module_map

    rows =
      map
      |> get_key(:rows, [])
      |> normalize_map_rows()

    if rows == [] do
      nil
    else
      %{
        title: get_key(map, :title, "HOW MODULES FIT TOGETHER") |> normalize_text() |> default_if_empty("HOW MODULES FIT TOGETHER"),
        rows: rows,
        edges:
          map
          |> get_key(:edges, [])
          |> normalize_map_edges()
      }
    end
  end

  defp normalize_map_rows(rows) when is_list(rows) do
    rows
    |> Enum.map(fn row ->
      label = row |> get_key(:label, "Layer") |> normalize_text() |> default_if_empty("Layer")

      nodes =
        row
        |> get_key(:nodes, [])
        |> normalize_map_nodes()

      if nodes == [] do
        nil
      else
        %{label: label, nodes: nodes}
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_map_rows(_), do: []

  defp normalize_map_nodes(nodes) when is_list(nodes) do
    nodes
    |> Enum.map(fn node ->
      id = node |> get_key(:id, nil) |> normalize_text()
      label = node |> get_key(:label, id) |> normalize_text() |> default_if_empty(id)
      note = node |> get_key(:note, "") |> normalize_text()

      if label == "" do
        nil
      else
        %{
          id: id,
          label: label,
          note: note,
          path: module_node_path(id)
        }
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_map_nodes(_), do: []

  defp normalize_map_edges(edges) when is_list(edges) do
    edges
    |> Enum.map(fn edge ->
      from = edge |> get_key(:from, "") |> normalize_text()
      to = edge |> get_key(:to, "") |> normalize_text()
      label = edge |> get_key(:label, "") |> normalize_text()

      if from == "" or to == "" do
        nil
      else
        %{from: from, to: to, label: label}
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_map_edges(_), do: []

  defp module_node_path(""), do: nil

  defp module_node_path(id) do
    case Ecosystem.get_public_package(id) do
      nil -> nil
      _pkg -> "/ecosystem/#{id}"
    end
  end

  defp faq_items(pkg) do
    pkg.landing_faq
    |> normalize_faq_items()
  end

  defp normalize_faq_items(items) when is_list(items) do
    items
    |> Enum.map(fn item ->
      question = item |> get_key(:question, "") |> normalize_text()
      answer = item |> get_key(:answer, "") |> normalize_text()

      if question == "" or answer == "" do
        nil
      else
        %{question: question, answer: answer}
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_faq_items(_), do: []

  defp landing_install(pkg) do
    install = pkg.landing_install
    snippet = install |> get_key(:snippet, "") |> normalize_multiline_text()
    source = install |> get_key(:source, nil) |> normalize_install_source()

    if snippet == "" do
      nil
    else
      %{
        label:
          install
          |> get_key(:label, install_source_label(source))
          |> normalize_text()
          |> default_if_empty(install_source_label(source)),
        note: install |> get_key(:note, "") |> normalize_text(),
        source: source,
        source_label: install_source_label(source),
        snippet: snippet
      }
    end
  end

  defp normalize_install_source(source) when is_atom(source), do: source

  defp normalize_install_source(source) when is_binary(source) do
    source
    |> String.trim()
    |> String.downcase()
    |> case do
      "hex" -> :hex
      "github" -> :github
      "manual" -> :manual
      _other -> nil
    end
  end

  defp normalize_install_source(_source), do: nil

  defp install_source_label(:hex), do: "Hex package"
  defp install_source_label(:github), do: "GitHub dependency"
  defp install_source_label(:manual), do: "Manual install"
  defp install_source_label(_source), do: "Install"

  defp package_structured_data(pkg, summary, keywords, faq_items) do
    [
      %{
        "@context" => "https://schema.org",
        "@type" => "BreadcrumbList",
        "itemListElement" => [
          breadcrumb_item(1, "Jido", "/"),
          breadcrumb_item(2, "Ecosystem", "/ecosystem"),
          breadcrumb_item(3, pkg.title, "/ecosystem/#{pkg.id}")
        ]
      },
      software_source_code_schema(pkg, summary, keywords),
      faq_page_schema(faq_items)
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp software_source_code_schema(pkg, summary, keywords) do
    same_as =
      [pkg.hexdocs_url, pkg.hex_url, pkg.github_url]
      |> Enum.reject(&(is_nil(&1) or &1 == ""))

    %{
      "@context" => "https://schema.org",
      "@type" => "SoftwareSourceCode",
      "name" => pkg.title,
      "description" => normalize_text(summary),
      "url" => MarkdownLinks.absolute_url("/ecosystem/#{pkg.id}"),
      "codeRepository" => pkg.github_url,
      "downloadUrl" => pkg.hex_url,
      "programmingLanguage" => "Elixir",
      "runtimePlatform" => "Elixir/OTP",
      "license" => pkg.license,
      "version" => pkg.version,
      "keywords" => keywords,
      "sameAs" => if(same_as == [], do: nil, else: same_as),
      "maintainer" => %{
        "@type" => "Organization",
        "name" => "Jido"
      }
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) or value == "" end)
    |> Map.new()
  end

  defp faq_page_schema([]), do: nil

  defp faq_page_schema(items) do
    %{
      "@context" => "https://schema.org",
      "@type" => "FAQPage",
      "mainEntity" =>
        Enum.map(items, fn item ->
          %{
            "@type" => "Question",
            "name" => item.question,
            "acceptedAnswer" => %{
              "@type" => "Answer",
              "text" => item.answer
            }
          }
        end)
    }
  end

  defp breadcrumb_item(position, name, path) do
    %{
      "@type" => "ListItem",
      "position" => position,
      "name" => name,
      "item" => MarkdownLinks.absolute_url(path)
    }
  end

  defp package_seo(pkg), do: Map.get(pkg, :seo, %{}) || %{}

  defp package_seo_value(pkg, key) do
    pkg
    |> package_seo()
    |> get_key(key, "")
    |> normalize_text()
  end

  defp normalize_keyword_list(value) when is_list(value) do
    value
    |> Enum.flat_map(&normalize_keyword_list/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp normalize_keyword_list(value) when is_binary(value) do
    value
    |> String.split(",", trim: true)
    |> Enum.map(&normalize_text/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp normalize_keyword_list(value) when is_atom(value), do: normalize_keyword_list(Atom.to_string(value))
  defp normalize_keyword_list(_value), do: []

  defp normalize_string_list(value) when is_list(value) do
    value
    |> Enum.map(&normalize_text/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp normalize_string_list(value) when is_binary(value) do
    text = normalize_text(value)
    if text == "", do: [], else: [text]
  end

  defp normalize_string_list(_), do: []

  defp normalize_multiline_text(text) when is_binary(text), do: text |> String.trim() |> String.replace(~r/\r\n?/, "\n")
  defp normalize_multiline_text(_), do: ""

  defp normalize_text(text) when is_binary(text), do: text |> String.trim() |> String.replace(~r/\s+/, " ")
  defp normalize_text(_), do: ""

  defp normalize_optional_text(value) do
    value
    |> normalize_text()
    |> case do
      "" -> nil
      text -> text
    end
  end

  defp default_if_empty("", fallback), do: fallback
  defp default_if_empty(value, _fallback), do: value

  defp internal_path?(href), do: String.starts_with?(normalize_text(href), "/")

  defp get_key(map, key, default) when is_map(map) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key), default)
  end

  defp get_key(_map, _key, default), do: default

  defp external_doc_link(pkg) do
    cond do
      present?(pkg.hexdocs_url) -> {"hexdocs", pkg.hexdocs_url}
      present?(pkg.hex_url) -> {"hex", pkg.hex_url}
      present?(pkg.github_url) -> {"github", pkg.github_url}
      true -> {nil, nil}
    end
  end

  defp issue_queue_url(github_url) do
    case normalize_optional_text(github_url) do
      nil ->
        nil

      trimmed ->
        case URI.parse(trimmed) do
          %URI{scheme: scheme, host: host, path: path}
          when scheme in ["http", "https"] and host in ["github.com", "www.github.com"] ->
            github_issue_url(path)

          _other ->
            nil
        end
    end
  end

  defp github_issue_url(path) do
    case path |> to_string() |> String.trim("/") |> String.split("/", trim: true) do
      [owner, repo | _rest] when owner != "" and repo != "" ->
        "https://github.com/#{owner}/#{String.trim_trailing(repo, ".git")}/issues"

      _other ->
        nil
    end
  end

  defp cta_link_class(:docs),
    do: "border-accent-cyan/50 bg-accent-cyan/15 text-accent-cyan hover:bg-accent-cyan/20"

  defp cta_link_class(:hex),
    do: "border-accent-yellow/50 bg-accent-yellow/12 text-accent-yellow hover:bg-accent-yellow/20"

  defp cta_link_class(:github),
    do: "border-border bg-elevated text-foreground hover:text-primary hover:border-primary/40"

  defp cta_link_class(:issues),
    do: "border-accent-green/50 bg-accent-green/10 text-accent-green hover:bg-accent-green/20"

  defp cta_link_class(_kind), do: "border-border bg-elevated text-foreground hover:text-primary"

  defp present?(nil), do: false
  defp present?(""), do: false
  defp present?(_), do: true
end
