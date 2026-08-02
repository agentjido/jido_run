defmodule AgentJidoWeb.JidoExampleLive do
  @moduledoc """
  Show page for an individual interactive example.

  Renders the example's markdown explanation, syntax-highlighted source code,
  and an embedded LiveView running the actual interactive demo.

  Tabs are URL-driven via query params so the URL changes as users navigate.
  Source code is syntax-highlighted at compile time via Makeup and embedded
  in the Example struct.
  """
  use AgentJidoWeb, :live_view

  import AgentJidoWeb.Jido.MarketingLayouts

  alias AgentJido.Examples
  alias AgentJido.Pages
  alias AgentJido.Pages.Page

  @valid_tabs ~w(demo explanation source)

  @impl true
  def mount(_params, session, socket) do
    {:ok, assign(socket, :include_drafts, Map.get(session, "examples_include_drafts", false))}
  end

  @impl true
  def handle_params(%{"slug" => slug} = params, _uri, socket) do
    include_drafts = socket.assigns.include_drafts
    example = Examples.get_example!(slug, include_drafts: include_drafts)

    demo_module =
      example.live_view_module
      |> String.split(".")
      |> Module.safe_concat()

    tab =
      case Map.get(params, "tab") do
        tab when tab in @valid_tabs -> String.to_existing_atom(tab)
        _ -> :explanation
      end

    {active_source, active_source_index} = resolve_active_source(example.sources, Map.get(params, "source"))

    {:noreply,
     socket
     |> assign(:example, example)
     |> assign(:admin_draft_preview?, include_drafts and example.status == :draft)
     |> assign(:demo_module, demo_module)
     |> assign(:active_tab, tab)
     |> assign(:active_source, active_source)
     |> assign(:active_source_index, active_source_index)
     |> assign(:related_resources, related_resources_for(example))
     |> assign(:page_title, example.title)
     |> assign(:meta_description, example.description)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.marketing_layout
      current_path="/examples"
      current_scope={@current_scope}
      analytics_identity={@analytics_identity}
    >
      <div class="container max-w-[1000px] mx-auto px-6 py-12">
        <%!-- Back link --%>
        <div class="mb-8">
          <.link
            navigate="/examples"
            class="text-xs text-secondary-foreground hover:text-foreground transition-colors"
          >
            ← back to examples
          </.link>
        </div>

        <%!-- Header --%>
        <section class="mb-10">
          <div class="flex flex-wrap items-center gap-3 mb-3">
            <span class={"text-[10px] px-2 py-1 rounded font-semibold uppercase tracking-wider #{category_class(@example.category)}"}>
              {@example.category}
            </span>
            <span
              :if={@admin_draft_preview?}
              class="text-[10px] px-2 py-1 rounded font-semibold uppercase tracking-wider bg-accent-yellow/10 border border-accent-yellow/30 text-accent-yellow"
            >
              draft preview
            </span>
            <span
              :if={@example.demo_mode == :simulated}
              class="text-[10px] px-2 py-1 rounded font-semibold uppercase tracking-wider bg-accent-cyan/10 border border-accent-cyan/30 text-accent-cyan"
            >
              simulated
            </span>
            <span class={"text-[10px] px-2 py-1 rounded font-semibold uppercase tracking-wider #{difficulty_class(@example.difficulty)}"}>
              {@example.difficulty}
            </span>
          </div>

          <h1 class="text-3xl font-bold tracking-tight mb-3">{@example.title}</h1>
          <p class="text-sm text-secondary-foreground leading-relaxed max-w-[820px]">
            {@example.description}
          </p>

          <div class="flex gap-2 mt-4 flex-wrap">
            <%= for tag <- @example.tags do %>
              <span class="text-[10px] px-2 py-1 rounded bg-elevated border border-border text-muted-foreground">
                {tag}
              </span>
            <% end %>
          </div>
        </section>

        <section :if={@related_resources != []} class="mb-8 rounded-lg border border-border bg-card p-4">
          <h2 class="text-sm font-bold mb-3">Related guides and notebooks</h2>
          <div class="grid gap-2 sm:grid-cols-2">
            <%= for resource <- @related_resources do %>
              <.resource_link resource={resource} />
            <% end %>
          </div>
        </section>

        <%!-- Tab navigation --%>
        <div class="mb-8 rounded-lg border border-border bg-card/50 p-2">
          <div class="grid gap-2 sm:grid-cols-3">
            <.tab_link
              slug={@example.slug}
              tab="explanation"
              active_tab={@active_tab}
              label="Explanation"
              hint="What this example teaches"
              icon="hero-document-text"
              source_index={@active_source_index}
            />
            <.tab_link
              slug={@example.slug}
              tab="demo"
              active_tab={@active_tab}
              label="Interactive Demo"
              hint="Run the agent and inspect state"
              icon="hero-beaker"
              source_index={@active_source_index}
            />
            <.tab_link
              slug={@example.slug}
              tab="source"
              active_tab={@active_tab}
              label="Source Code"
              hint="Read the production implementation"
              icon="hero-code-bracket"
              source_index={@active_source_index}
            />
          </div>
        </div>

        <%!-- Demo tab --%>
        <div :if={@active_tab == :demo} class="mb-10">
          <div
            :if={@example.demo_mode == :simulated}
            class="mb-4 rounded-md border border-accent-cyan/30 bg-accent-cyan/10 px-4 py-3 text-xs text-accent-cyan"
          >
            <div class="font-semibold uppercase tracking-wider mb-1">Simulated demo</div>
            <div class="text-[11px] text-accent-cyan/90">
              This example uses deterministic fixture data. No live LLM, browser, or network calls are executed.
            </div>
          </div>
          {live_render(@socket, @demo_module, id: "demo-#{@example.slug}", session: %{"example_slug" => @example.slug})}
        </div>

        <%!-- Explanation tab --%>
        <div :if={@active_tab == :explanation} class="mb-10">
          <article class="docs-prose prose max-w-none text-sm leading-relaxed">
            {Phoenix.HTML.raw(@example.body)}
          </article>
        </div>

        <%!-- Source code tab --%>
        <div :if={@active_tab == :source} class="mb-10">
          <%!-- Source file selector --%>
          <div :if={length(@example.sources) > 1} class="flex gap-1 mb-4 flex-wrap">
            <%= for {src, source_index} <- Enum.with_index(@example.sources, 1) do %>
              <.link
                patch={tab_patch(@example.slug, "source", source_index)}
                class={"text-xs px-3 py-2 rounded transition-colors #{if @active_source_index == source_index, do: "bg-primary/10 text-primary border border-primary/30", else: "bg-elevated text-muted-foreground hover:text-foreground border border-border"}"}
              >
                {Path.basename(src.path)}
              </.link>
            <% end %>
          </div>

          <div :if={@active_source} class="rounded-lg border border-border bg-card overflow-hidden">
            <div class="px-4 py-2 border-b border-border bg-elevated flex items-center justify-between">
              <span class="text-[11px] font-mono text-muted-foreground">{@active_source.path}</span>
              <span class="text-[10px] text-muted-foreground/50">
                {String.split(@active_source.content, "\n") |> length()} lines
              </span>
            </div>
            <div class="p-4 overflow-x-auto">
              <div class="text-[12px] leading-relaxed">
                {Phoenix.HTML.raw(@active_source.highlighted)}
              </div>
            </div>
          </div>

          <div
            :if={@active_source == nil}
            class="rounded-lg border border-border bg-card p-8 text-center"
          >
            <p class="text-sm text-muted-foreground">
              No source files configured for this example.
            </p>
          </div>
        </div>
      </div>
    </.marketing_layout>
    """
  end

  # ── Components ──────────────────────────────────────────────

  attr :slug, :string, required: true
  attr :tab, :string, required: true
  attr :active_tab, :atom, required: true
  attr :label, :string, required: true
  attr :hint, :string, required: true
  attr :icon, :string, required: true
  attr :source_index, :integer, default: nil

  defp tab_link(assigns) do
    active = assigns.active_tab == String.to_existing_atom(assigns.tab)

    assigns =
      assigns
      |> assign(:active, active)
      |> assign(:patch_target, tab_patch(assigns.slug, assigns.tab, assigns.source_index))

    ~H"""
    <.link
      patch={@patch_target}
      class={"block rounded-md border px-4 py-3 text-left transition-colors #{if @active, do: "border-primary/40 bg-primary/10 text-primary shadow-sm", else: "border-border text-muted-foreground hover:border-primary/20 hover:text-foreground"}"}
    >
      <div class="flex items-center gap-2 text-sm font-semibold">
        <.icon name={@icon} class="h-4 w-4" />
        <span>{@label}</span>
      </div>
      <p class={"mt-1 text-xs #{if @active, do: "text-primary/80", else: "text-muted-foreground"}"}>
        {@hint}
      </p>
    </.link>
    """
  end

  attr :resource, :map, required: true

  defp resource_link(assigns) do
    ~H"""
    <%= if @resource.external do %>
      <a
        href={@resource.href}
        target="_blank"
        rel="noopener noreferrer"
        class="block rounded-md border border-border bg-elevated/40 p-3 hover:border-primary/30 hover:bg-primary/5 transition-colors"
      >
        <div class="flex items-start gap-3">
          <.icon name={@resource.icon} class="h-4 w-4 text-primary mt-0.5" />
          <div class="min-w-0">
            <div class="text-xs uppercase tracking-wider text-muted-foreground">{@resource.kind}</div>
            <div class="text-sm font-semibold text-foreground">{@resource.label}</div>
            <div class="text-xs text-secondary-foreground mt-1">{@resource.description}</div>
          </div>
        </div>
      </a>
    <% else %>
      <.link
        navigate={@resource.href}
        class="block rounded-md border border-border bg-elevated/40 p-3 hover:border-primary/30 hover:bg-primary/5 transition-colors"
      >
        <div class="flex items-start gap-3">
          <.icon name={@resource.icon} class="h-4 w-4 text-primary mt-0.5" />
          <div class="min-w-0">
            <div class="text-xs uppercase tracking-wider text-muted-foreground">{@resource.kind}</div>
            <div class="text-sm font-semibold text-foreground">{@resource.label}</div>
            <div class="text-xs text-secondary-foreground mt-1">{@resource.description}</div>
          </div>
        </div>
      </.link>
    <% end %>
    """
  end

  # ── Helpers ─────────────────────────────────────────────────

  defp resolve_active_source([], _source_param), do: {nil, nil}

  defp resolve_active_source(sources, source_param) do
    default = {List.first(sources), 1}

    case source_param do
      nil ->
        default

      source ->
        case Integer.parse(source) do
          {index, ""} when index > 0 and index <= length(sources) ->
            {Enum.at(sources, index - 1), index}

          _other ->
            default
        end
    end
  end

  defp tab_patch(slug, tab, source_index) do
    params =
      case {tab, source_index} do
        {"source", index} when is_integer(index) and index > 0 ->
          %{"tab" => tab, "source" => Integer.to_string(index)}

        _other ->
          %{"tab" => tab}
      end

    ~p"/examples/#{slug}?#{params}"
  end

  defp related_resources_for(example) do
    example
    |> Map.get(:related_resources, [])
    |> List.wrap()
    |> Enum.flat_map(&expand_related_resource/1)
    |> Enum.reject(&is_nil/1)
  end

  defp expand_related_resource(resource) when is_map(resource) do
    type = normalize_related_resource_type(resource_value(resource, :type, :docs))

    case type do
      :docs ->
        path = resource_value(resource, :path)

        if is_binary(path) and path != "" do
          kind = resource_value(resource, :kind, "Guide")
          icon = resource_value(resource, :icon, icon_for_kind(kind))
          description = resource_value(resource, :description, "")
          label = resource_value(resource, :label)
          include_livebook = truthy?(resource_value(resource, :include_livebook, false))

          [
            docs_resource(path, kind, icon, description, label),
            maybe_docs_livebook_resource(path, resource, include_livebook)
          ]
          |> Enum.reject(&is_nil/1)
        else
          []
        end

      :external ->
        external_resource(resource)
    end
  end

  defp expand_related_resource(_resource), do: []

  defp docs_resource(path, kind, icon, description, label_override) do
    case Pages.get_page_by_path(path) do
      nil ->
        nil

      page ->
        %{
          kind: kind,
          label: label_override || page.title,
          href: path,
          description: description,
          icon: icon,
          external: false
        }
    end
  end

  defp maybe_docs_livebook_resource(path, resource, true) do
    case Pages.get_page_by_path(path) do
      %Page{} = page ->
        livebook_resource(page, resource)

      _other ->
        nil
    end
  end

  defp maybe_docs_livebook_resource(_path, _resource, false), do: nil

  defp livebook_resource(page, resource) do
    case Page.livebook_url(page, AgentJidoWeb.Endpoint.url()) do
      livebook_url when is_binary(livebook_url) and livebook_url != "" ->
        %{
          kind: "Livebook",
          label: resource_value(resource, :livebook_label, page.title),
          href: livebook_url,
          description:
            resource_value(
              resource,
              :livebook_description,
              "Run the companion notebook in Livebook"
            ),
          icon: resource_value(resource, :livebook_icon, "hero-command-line"),
          external: true
        }

      _other ->
        nil
    end
  end

  defp external_resource(resource) do
    href = resource_value(resource, :href, resource_value(resource, :url))
    label = resource_value(resource, :label)

    if is_binary(href) and href != "" and is_binary(label) and label != "" do
      [
        %{
          kind: resource_value(resource, :kind, "External"),
          label: label,
          href: href,
          description: resource_value(resource, :description, "Related external resource"),
          icon: resource_value(resource, :icon, "hero-link"),
          external: true
        }
      ]
    else
      []
    end
  end

  defp normalize_related_resource_type(type) when type in [:external, "external"], do: :external
  defp normalize_related_resource_type(_type), do: :docs

  defp icon_for_kind(kind) when kind in ["Guide", "Tutorial", "Next"], do: "hero-book-open"
  defp icon_for_kind(kind) when kind in ["Concept", "Reference"], do: "hero-light-bulb"
  defp icon_for_kind("Operations"), do: "hero-server-stack"
  defp icon_for_kind(_kind), do: "hero-document-text"

  defp resource_value(resource, key, default \\ nil) do
    cond do
      Map.has_key?(resource, key) ->
        Map.get(resource, key)

      Map.has_key?(resource, Atom.to_string(key)) ->
        Map.get(resource, Atom.to_string(key))

      true ->
        default
    end
  end

  defp truthy?(value) when value in [true, "true", 1, "1"], do: true
  defp truthy?(_value), do: false

  defp category_class(:core),
    do: "bg-accent-cyan/10 border border-accent-cyan/30 text-accent-cyan"

  defp category_class(:ai),
    do: "bg-accent-yellow/10 border border-accent-yellow/30 text-accent-yellow"

  defp category_class(:production),
    do: "bg-primary/10 border border-primary/30 text-primary"

  defp category_class(_), do: "bg-elevated border border-border text-muted-foreground"

  defp difficulty_class(:beginner),
    do: "bg-accent-green/10 border border-accent-green/30 text-accent-green"

  defp difficulty_class(:intermediate),
    do: "bg-accent-yellow/10 border border-accent-yellow/30 text-accent-yellow"

  defp difficulty_class(:advanced),
    do: "bg-accent-red/10 border border-accent-red/30 text-accent-red"

  defp difficulty_class(_), do: "bg-elevated border border-border text-muted-foreground"
end
