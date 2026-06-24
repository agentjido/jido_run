defmodule AgentJidoWeb.Jido.DocsComponents do
  @moduledoc """
  Documentation-specific components for the Jido docs site.
  """
  use AgentJidoWeb, :html

  alias AgentJidoWeb.Jido.Nav
  alias AgentJidoWeb.MarkdownLinks

  attr(:current_path, :string, default: nil)

  def docs_header(assigns) do
    ~H"""
    <header class="z-40 border-b border-border bg-background/90 backdrop-blur-md">
      <Nav.primary_nav
        current_path={@current_path}
        layout_mode={:fluid}
        surface_mode={:flush}
        show_theme_toggle={true}
        mobile_menu_id="docs-primary-mobile-menu"
      />
    </header>
    """
  end

  # Secondary Navigation Component
  attr(:current_path, :string, default: nil)
  attr(:tabs, :list, default: [])

  def docs_secondary_nav(assigns) do
    ~H"""
    <div class="border-b border-border bg-card/50 px-6">
      <nav class="docs-scrollbar flex min-w-0 items-center gap-1 overflow-x-auto overflow-y-hidden">
        <%= for tab <- @tabs do %>
          <%= if tab[:external] do %>
            <a
              href={tab.href}
              target="_blank"
              rel="noopener noreferrer"
              class="flex items-center gap-1 px-4 py-3 text-[13px] whitespace-nowrap transition-colors border-b-2 -mb-[1px] text-muted-foreground border-b-transparent hover:text-foreground hover:border-b-border"
            >
              {tab.label}
              <.icon name="hero-arrow-top-right-on-square" class="h-3 w-3" />
            </a>
          <% else %>
            <.link
              navigate={tab.href}
              class={
                "flex items-center gap-1 px-4 py-3 text-[13px] whitespace-nowrap transition-colors border-b-2 -mb-[1px] " <>
                if Enum.any?(Map.get(tab, :active_paths, [tab.href]), &String.starts_with?(@current_path || "", &1)) do
                  "text-foreground font-medium border-b-primary"
                else
                  "text-muted-foreground border-b-transparent hover:text-foreground hover:border-b-border"
                end
              }
            >
              {tab.label}
            </.link>
          <% end %>
        <% end %>
      </nav>
    </div>
    """
  end

  # Left Sidebar Component
  attr(:nav, :list, required: true)
  attr(:current_path, :string, default: nil)
  attr(:open, :boolean, default: true)

  def docs_sidebar(assigns) do
    ~H"""
    <%= if @open do %>
      <aside class="docs-scrollbar docs-column-height hidden lg:block sticky top-0 self-start w-[260px] shrink-0 overflow-y-auto border-r border-border bg-card">
        <div class="py-4">
          <!-- Jido Docs header -->
          <div class="flex items-center justify-between px-4 mb-4">
            <.link navigate="/docs" class="flex items-center gap-2 text-sm font-medium text-primary hover:text-primary/80 transition-colors">
              <.icon name="hero-home" class="h-4 w-4" /> Jido Docs
            </.link>
            <button
              phx-click="toggle_sidebar"
              class="p-1.5 rounded-md text-muted-foreground hover:text-foreground hover:bg-elevated transition-colors"
              title="Collapse sidebar"
            >
              <.icon name="hero-chevron-left" class="h-4 w-4" />
            </button>
          </div>

          <%= for section <- @nav do %>
            <details class="mb-2 group" open>
              <summary class="list-none w-full flex items-center justify-between px-4 py-2.5 text-[12px] font-bold tracking-[0.05em] uppercase text-foreground hover:text-primary transition-colors cursor-pointer [&::-webkit-details-marker]:hidden">
                <span>{section.title}</span>
                <.icon name="hero-chevron-down" class="h-3.5 w-3.5 text-muted-foreground transition-transform group-open:rotate-180" />
              </summary>

              <div class="mt-1">
                <%= for item <- section.items do %>
                  <%= if item[:external] do %>
                    <a
                      href={item.href}
                      target="_blank"
                      rel="noopener noreferrer"
                      class={
                        "flex items-center justify-between px-4 py-2 ml-2 text-[13px] transition-all duration-150 border-l-2 " <>
                        "border-l-border text-muted-foreground hover:text-foreground hover:bg-elevated hover:border-l-muted-foreground"
                      }
                    >
                      <span>{item.label}</span>
                      <%= if item[:badge] do %>
                        <span class={
                          "text-[9px] font-semibold tracking-wide px-1.5 py-0.5 rounded " <>
                          badge_class(item.badge)
                        }>
                          {item.badge}
                        </span>
                      <% end %>
                    </a>
                  <% else %>
                    <.link
                      navigate={item.href}
                      class={
                        "flex items-center justify-between px-4 py-2 ml-2 text-[13px] transition-all duration-150 border-l-2 " <>
                        if @current_path == item.href do
                          "border-l-primary bg-primary/5 text-primary font-medium"
                        else
                          "border-l-border text-muted-foreground hover:text-foreground hover:bg-elevated hover:border-l-muted-foreground"
                        end
                      }
                    >
                      <span>{item.label}</span>
                      <%= if item[:badge] do %>
                        <span class={
                          "text-[9px] font-semibold tracking-wide px-1.5 py-0.5 rounded " <>
                          badge_class(item.badge)
                        }>
                          {item.badge}
                        </span>
                      <% end %>
                    </.link>
                  <% end %>
                <% end %>
              </div>
            </details>
          <% end %>
        </div>
      </aside>
    <% else %>
      <aside class="docs-scrollbar hidden lg:flex h-full w-[56px] shrink-0 flex-col overflow-y-auto border-r border-border bg-card">
        <button
          phx-click="toggle_sidebar"
          class="m-3 p-2 rounded-md bg-elevated border border-border text-muted-foreground hover:text-foreground transition-colors"
          title="Expand sidebar"
        >
          <.icon name="hero-chevron-right" class="h-4 w-4" />
        </button>

        <.link
          navigate="/docs"
          class="mx-3 p-2 rounded-md text-muted-foreground hover:text-primary hover:bg-primary/10 transition-colors"
          title="Jido Docs"
        >
          <.icon name="hero-home" class="h-4 w-4" />
        </.link>
      </aside>
    <% end %>
    """
  end

  # Right Sidebar Component
  attr(:toc, :list, default: nil)
  attr(:selected_document, :map, default: nil)
  attr(:markdown_copy_url, :string, default: nil)
  attr(:docs_feedback, :map, default: nil)

  def docs_right_sidebar(assigns) do
    ~H"""
    <aside class="docs-column-height hidden lg:flex sticky top-0 self-start w-[260px] shrink-0 flex-col border-l border-border bg-background/55 px-5 py-8">
      <%= if @toc && @toc != [] do %>
        <div class="mb-6 flex min-h-0 flex-1 flex-col rounded-md border border-border/80 bg-card/60 p-3">
          <div class="mb-3 px-1 text-[10px] font-bold tracking-[0.11em] uppercase text-muted-foreground">
            ON THIS PAGE
          </div>
          <nav
            id="docs-right-toc"
            phx-hook="ScrollSpy"
            data-scroll-spy-target="#docs-content"
            class="docs-scrollbar min-h-0 flex-1 space-y-0.5 overflow-y-auto pr-1"
          >
            <%= for item <- @toc do %>
              <a
                href={"##{item.id}"}
                data-toc-link
                data-level={item.level}
                class={
                  "docs-toc-link block -ml-px border-l-2 py-1.5 pr-2 leading-5 transition-colors " <>
                    toc_level_class(item.level)
                }
              >
                {item.title}
              </a>
            <% end %>
          </nav>
        </div>
      <% else %>
        <div class="flex-1" />
      <% end %>

      <!-- Livebook CTA -->
      <%= if livebook_url = livebook_url(@selected_document) do %>
        <div class="shrink-0">
          <a
            href={livebook_url}
            target="_blank"
            rel="noopener noreferrer"
            data-livebook-run="true"
            data-analytics-source="docs"
            data-analytics-channel="quick_links"
            data-analytics-target-url={livebook_url}
            class="group flex w-full items-center justify-between gap-3 rounded-lg bg-primary px-3.5 py-2.5 text-[12px] font-semibold text-primary-foreground shadow-sm ring-1 ring-black/10 transition hover:brightness-110 hover:shadow-md"
          >
            <span class="flex items-center gap-2.5">
              <span class="inline-flex h-6 w-6 items-center justify-center rounded bg-primary-foreground/20">
                <.icon name="hero-book-open" class="h-3.5 w-3.5 text-primary-foreground" />
              </span>
              <span>Run in Livebook</span>
            </span>
            <.icon
              name="hero-arrow-top-right-on-square"
              class="h-3.5 w-3.5 text-primary-foreground opacity-80 group-hover:opacity-100"
            />
          </a>
          <%= if notice = livebook_notice(@selected_document) do %>
            <div class="mt-1.5 px-1 text-[10px] leading-4 text-muted-foreground">
              {notice}
            </div>
          <% end %>
        </div>
      <% end %>

      <%= if @markdown_copy_url do %>
        <div class="mt-4 shrink-0">
          <button
            type="button"
            data-copy-button
            data-copy-source-url={@markdown_copy_url}
            data-copy-success-label="Copied"
            data-analytics-source="docs"
            data-analytics-channel="copy_markdown"
            class="flex w-full items-center justify-center rounded-md border border-border bg-card/70 px-3 py-2 text-[12px] font-semibold text-foreground transition-colors hover:border-primary hover:text-primary"
          >
            <span class="inline-flex items-center justify-center gap-2 text-center">
              <.icon name="hero-document-text" class="h-4 w-4 shrink-0" />
              <span class="leading-none">Copy Markdown</span>
            </span>
          </button>
        </div>
      <% end %>

      <!-- Quick Links -->
      <div class="mt-4 shrink-0 rounded-md border border-border/80 bg-card/75 p-4 shadow-[0_10px_24px_hsl(var(--background)/0.2)]">
        <div class="mb-2 text-[10px] font-semibold tracking-[0.08em] text-muted-foreground">
          QUICK LINKS
        </div>
        <div class="flex flex-col gap-2.5">
          <%= for {label, icon_name, href} <- quick_links(@selected_document) do %>
            <a
              href={href}
              target="_blank"
              rel="noopener noreferrer"
              data-analytics-source="docs"
              data-analytics-channel="quick_links"
              data-analytics-target-url={href}
              class="group flex items-center gap-2 text-[12px] leading-5 text-muted-foreground transition-colors hover:text-primary"
            >
              <.icon name={icon_name} class="h-3.5 w-3.5" />
              <span>{label}</span>
            </a>
          <% end %>
        </div>
      </div>

      <!-- Feedback -->
      <%= if @docs_feedback do %>
        <div class="mt-4 shrink-0 px-1">
          <.feedback_prompt
            id="docs-page-feedback"
            title="Helpful?"
            value={@docs_feedback.value}
            note={@docs_feedback.note || ""}
            submitted={@docs_feedback.submitted}
            select_event="docs_feedback_select"
            submit_event="submit_docs_feedback"
            note_placeholder="What could be improved?"
          />
        </div>
      <% end %>
    </aside>
    """
  end

  defp livebook_url(nil), do: nil

  defp livebook_url(doc) do
    case Map.get(doc, :livebook_url) do
      url when is_binary(url) and url != "" -> url
      _ -> nil
    end
  end

  defp livebook_notice(nil), do: nil

  defp livebook_notice(doc) do
    livebook_meta = Map.get(doc, :livebook, %{}) || %{}

    parts =
      []
      |> maybe_add_elixir_notice(Map.get(livebook_meta, :elixir_version))
      |> maybe_add_env_notice(Map.get(livebook_meta, :required_env_vars, []))

    case parts do
      [] -> nil
      _ -> Enum.join(parts, " · ")
    end
  end

  defp maybe_add_elixir_notice(parts, version) when is_binary(version) and version != "",
    do: parts ++ ["Elixir #{version}"]

  defp maybe_add_elixir_notice(parts, _version), do: parts

  defp maybe_add_env_notice(parts, vars) when is_list(vars) and vars != [] do
    shown = Enum.take(vars, 2) |> Enum.join(", ")
    extra = if length(vars) > 2, do: " +#{length(vars) - 2} more", else: ""
    parts ++ ["Env: #{shown}#{extra}"]
  end

  defp maybe_add_env_notice(parts, _vars), do: parts

  defp quick_links(selected_document) do
    doc = selected_document || %{}

    # Page-specific "View source" link replaces generic GitHub
    github_url =
      case Map.get(doc, :github_url) do
        url when is_binary(url) and url != "" -> url
        _ -> Nav.github_url()
      end

    for_agents_link = for_agents_link(doc)

    default_links = [
      {"View source", "hero-code-bracket", github_url},
      {"For Agents", "hero-link", for_agents_link},
      {"HexDocs", "hero-book-open", Nav.hexdocs_url()},
      {"Hex.pm", "hero-cube", Nav.hex_url()}
    ]

    # Per-page control
    mode = Map.get(doc, :quick_links_mode, :append)
    hide = Map.get(doc, :quick_links_hide_defaults, []) |> Enum.map(&to_string/1)

    custom =
      (Map.get(doc, :quick_links, []) || [])
      |> Enum.map(fn link ->
        {
          to_string(Map.get(link, :label, "")),
          to_string(Map.get(link, :icon, "hero-link")),
          to_string(Map.get(link, :href, ""))
        }
      end)
      |> Enum.filter(fn {label, _icon, href} -> label != "" and href != "" end)

    case mode do
      :replace ->
        custom

      _ ->
        defaults_filtered =
          Enum.reject(default_links, fn {label, _icon, _href} -> label in hide end)

        defaults_filtered ++ custom
    end
  end

  defp for_agents_link(doc) when is_map(doc) do
    case Map.get(doc, :path) || Map.get(doc, "path") do
      path when is_binary(path) and path != "" -> MarkdownLinks.markdown_path(path)
      _other -> "/docs.md"
    end
  end

  defp toc_level_class(level) when is_integer(level) and level >= 3 do
    "pl-5 text-[11px] text-muted-foreground border-l-transparent hover:text-foreground hover:border-l-muted-foreground"
  end

  defp toc_level_class(_level) do
    "pl-3 text-[12px] font-medium text-muted-foreground border-l-transparent hover:text-foreground hover:border-l-muted-foreground"
  end

  # Numbered Card Component
  attr(:number, :string, required: true)
  attr(:title, :string, required: true)
  attr(:description, :string, required: true)
  attr(:href, :string, required: true)

  def numbered_card(assigns) do
    ~H"""
    <.link navigate={@href} class="block group">
      <div class="bg-card border border-border rounded-md p-5 flex gap-4 items-start transition-all duration-200 hover:border-primary hover:-translate-y-0.5">
        <div class="w-8 h-8 rounded-md flex-shrink-0 flex items-center justify-center bg-primary/15 text-primary font-bold text-sm">
          {@number}
        </div>
        <div>
          <div class="text-sm font-semibold text-foreground mb-1 group-hover:text-primary transition-colors">
            {@title}
          </div>
          <p class="text-xs text-muted-foreground leading-relaxed">
            {@description}
          </p>
        </div>
      </div>
    </.link>
    """
  end

  # Icon Card Component
  attr(:icon, :string, required: true)
  attr(:title, :string, required: true)
  attr(:description, :string, required: true)
  attr(:color, :string, default: "green")
  attr(:href, :string, required: true)

  def icon_card(assigns) do
    ~H"""
    <.link navigate={@href} class="block group h-full">
      <div class={
        "bg-card border border-border rounded-md p-5 h-full transition-all duration-200 hover:-translate-y-0.5 " <>
        icon_card_color_class(@color)
      }>
        <div class={"text-2xl mb-3 font-mono " <> icon_text_color_class(@color)}>
          {@icon}
        </div>
        <div class="text-sm font-semibold text-foreground mb-2">
          {@title}
        </div>
        <p class="text-xs text-muted-foreground leading-relaxed">
          {@description}
        </p>
      </div>
    </.link>
    """
  end

  # Helper functions for color classes
  defp badge_class("CORE"), do: "bg-primary/15 text-primary"
  defp badge_class("AI"), do: "bg-accent-yellow/15 text-accent-yellow"
  defp badge_class("APP"), do: "bg-accent-red/15 text-accent-red"
  defp badge_class("FOUNDATION"), do: "bg-accent-cyan/15 text-accent-cyan"
  defp badge_class(_), do: "bg-muted text-muted-foreground"

  defp icon_card_color_class("green"), do: "hover:border-accent-green"
  defp icon_card_color_class("yellow"), do: "hover:border-accent-yellow"
  defp icon_card_color_class("cyan"), do: "hover:border-accent-cyan"
  defp icon_card_color_class("red"), do: "hover:border-accent-red"
  defp icon_card_color_class(_), do: "hover:border-border"

  defp icon_text_color_class("green"), do: "text-accent-green"
  defp icon_text_color_class("yellow"), do: "text-accent-yellow"
  defp icon_text_color_class("cyan"), do: "text-accent-cyan"
  defp icon_text_color_class("red"), do: "text-accent-red"
  defp icon_text_color_class(_), do: "text-primary"
end
