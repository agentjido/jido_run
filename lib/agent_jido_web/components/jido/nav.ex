defmodule AgentJidoWeb.Jido.Nav do
  @moduledoc """
  Shared navigation constants and icon components used across marketing,
  docs, and footer surfaces.
  """
  use AgentJidoWeb, :html

  @jido_version_fallback "unknown"
  @content_assistant_modal_id "primary-nav-content-assistant-modal"
  @premium_support_enabled false
  @premium_support_href "mailto:support@agentjido.com?subject=Premium%20Support%20Inquiry"

  @primary_nav_links [
    {"Features", "/features"},
    {"Ecosystem", "/ecosystem"},
    {"Examples", "/examples"},
    {"Community", "/community"},
    {"Docs", "/docs"}
  ]

  @footer_package_links [
    {"jido", "https://hex.pm/packages/jido"},
    {"jido_ai", "https://hex.pm/packages/jido_ai"},
    {"req_llm", "https://hex.pm/packages/req_llm"}
  ]

  @discord_url "https://jido.run/discord"

  @social_links [
    {:discord, "Discord", @discord_url},
    {:github, "GitHub", "https://github.com/agentjido/jido"},
    {:x, "x.com", "https://x.com/agentjido"},
    {:llmdb, "LLMDB", "https://llmcatalog.dev"}
  ]

  @github_url "https://github.com/agentjido/jido"
  @hex_url "https://hex.pm/packages/jido"
  @hexdocs_url "https://hexdocs.pm/jido"

  @type layout_mode :: :constrained | :fluid

  @doc "Shared primary navigation links."
  @spec primary_nav_links() :: [{String.t(), String.t()}]
  def primary_nav_links, do: @primary_nav_links

  @doc "Compatibility alias for legacy callers."
  @spec marketing_nav_links() :: [{String.t(), String.t()}]
  def marketing_nav_links, do: @primary_nav_links

  @doc "Compatibility alias for legacy callers."
  @spec docs_nav_links() :: [{String.t(), String.t()}]
  def docs_nav_links, do: @primary_nav_links

  @spec footer_company_links() :: [{String.t(), String.t()}]
  def footer_company_links do
    [
      {"Blog", "/blog"},
      {"Features", primary_nav_path!("Features")},
      {"Ecosystem", primary_nav_path!("Ecosystem")},
      {"Community", primary_nav_path!("Community")}
    ]
  end

  @spec footer_resource_links() :: [{String.t(), String.t()}]
  def footer_resource_links do
    [
      {"Docs", primary_nav_path!("Docs")},
      {"Skills", "/skills"},
      {"Examples", primary_nav_path!("Examples")},
      {"Compare", "/compare"}
    ]
  end

  @spec footer_package_links() :: [{String.t(), String.t()}]
  def footer_package_links, do: @footer_package_links

  @spec social_links() :: [{atom(), String.t(), String.t()}]
  def social_links, do: @social_links

  @spec github_url() :: String.t()
  def github_url, do: @github_url

  @spec hex_url() :: String.t()
  def hex_url, do: @hex_url

  @spec hexdocs_url() :: String.t()
  def hexdocs_url, do: @hexdocs_url

  @spec discord_url() :: String.t()
  def discord_url, do: @discord_url

  @spec content_assistant_modal_id() :: String.t()
  def content_assistant_modal_id, do: @content_assistant_modal_id

  @spec premium_support_enabled?() :: boolean()
  def premium_support_enabled?, do: @premium_support_enabled

  @spec premium_support_href() :: String.t()
  def premium_support_href, do: @premium_support_href

  @spec jido_version() :: String.t()
  def jido_version do
    case Application.spec(:jido, :vsn) do
      nil ->
        _ = Application.load(:jido)
        jido_version(Application.spec(:jido, :vsn))

      vsn ->
        jido_version(vsn)
    end
  end

  @spec jido_version(term()) :: String.t()
  def jido_version(vsn) when is_list(vsn), do: List.to_string(vsn)
  def jido_version(vsn) when is_binary(vsn), do: vsn
  def jido_version(_), do: @jido_version_fallback

  attr(:current_path, :string, default: "/")
  attr(:layout_mode, :atom, default: :constrained, values: [:constrained, :fluid])
  attr(:surface_mode, :atom, default: :framed, values: [:framed, :flush])
  attr(:show_theme_toggle, :boolean, default: false)
  attr(:mobile_menu_id, :string, default: "primary-nav-mobile-menu")

  @doc "Unified primary nav for marketing and docs."
  @spec primary_nav(map()) :: Phoenix.LiveView.Rendered.t()
  def primary_nav(assigns) do
    assigns =
      assigns
      |> assign(:nav_links, @primary_nav_links)
      |> assign(:content_assistant_modal_id, @content_assistant_modal_id)
      |> assign(:premium_support_enabled, @premium_support_enabled)
      |> assign(:premium_support_href, @premium_support_href)
      |> assign(:container_class, nav_container_class(assigns.layout_mode))
      |> assign(:nav_surface_class, nav_surface_class(assigns.surface_mode))
      |> assign(:mobile_menu_class, mobile_menu_class(assigns.surface_mode))

    ~H"""
    <div class={@container_class}>
      <nav class={@nav_surface_class}>
        <div class="flex items-center gap-6">
          <.logo show_version={false} />

          <div class="hidden md:flex items-center gap-6">
            <%= for {label, href} <- @nav_links do %>
              <.link
                navigate={href}
                class={
                  "text-xs transition-colors " <>
                    if active_nav_link?(@current_path, href) do
                      "text-primary font-semibold"
                    else
                      "text-secondary-foreground hover:text-foreground"
                    end
                }
              >
                {label}
              </.link>
            <% end %>
          </div>
        </div>

        <div class="hidden md:flex items-center gap-3">
          <.theme_toggle_button :if={@show_theme_toggle} id="primary-nav-theme-toggle" />

          <button
            id="primary-nav-content-assistant-trigger"
            type="button"
            phx-click={show_modal(@content_assistant_modal_id)}
            class="inline-flex items-center gap-2 rounded border border-primary/30 bg-primary/5 px-3 py-2 text-xs font-medium text-primary transition-colors hover:bg-primary/[0.12]"
            aria-label="Search Cmd+K"
            title="Search (Ctrl/Cmd+K)"
          >
            <.icon name="hero-magnifying-glass" class="h-3.5 w-3.5" />
            <span>Search</span>
            <span class="ml-1 hidden rounded border border-primary/30 bg-primary/5 px-1.5 py-0.5 text-[10px] font-normal text-primary lg:inline-flex">
              Cmd+K
            </span>
          </button>

          <a
            :if={@premium_support_enabled}
            href={@premium_support_href}
            class="text-xs font-medium bg-gradient-to-r from-accent-yellow to-accent-red bg-clip-text text-transparent hover:opacity-80 transition-opacity"
          >
            Premium Support
          </a>
        </div>

        <button
          type="button"
          class="md:hidden inline-flex h-9 w-9 items-center justify-center rounded border border-border bg-surface text-foreground"
          phx-click={JS.toggle(to: "##{@mobile_menu_id}")}
          aria-label="Toggle navigation menu"
        >
          <.icon name="hero-bars-3" class="h-5 w-5" />
        </button>
      </nav>

      <div id={@mobile_menu_id} class={@mobile_menu_class}>
        <%= for {label, href} <- @nav_links do %>
          <.link
            navigate={href}
            class={
              "block rounded px-3 py-2 text-xs transition-colors " <>
                if active_nav_link?(@current_path, href) do
                  "text-primary bg-primary/10 font-semibold"
                else
                  "text-secondary-foreground hover:text-foreground hover:bg-muted"
                end
            }
          >
            {label}
          </.link>
        <% end %>

        <button
          type="button"
          phx-click={show_modal(@content_assistant_modal_id)}
          class="w-full rounded border border-border bg-surface px-3 py-2 text-left text-xs text-muted-foreground transition-colors hover:border-foreground/40 hover:text-foreground"
        >
          <span class="inline-flex items-center gap-2">
            <.icon name="hero-magnifying-glass" class="h-3.5 w-3.5" /> Search
          </span>
        </button>

        <.theme_toggle_button
          :if={@show_theme_toggle}
          id="primary-nav-mobile-theme-toggle"
          class="w-full justify-center"
        />

        <a
          :if={@premium_support_enabled}
          href={@premium_support_href}
          class="block px-3 py-2 text-xs rounded bg-gradient-to-r from-accent-yellow to-accent-red bg-clip-text text-transparent font-medium"
        >
          Premium Support
        </a>
      </div>
    </div>
    """
  end

  attr(:id, :string, default: "primary-nav-theme-toggle")
  attr(:class, :string, default: "")

  @doc "Icon-only dark/light toggle used by the primary nav."
  @spec theme_toggle_button(map()) :: Phoenix.LiveView.Rendered.t()
  def theme_toggle_button(assigns) do
    ~H"""
    <button
      id={@id}
      phx-hook="ThemeToggle"
      aria-label="Toggle theme"
      class={"inline-flex h-9 w-9 items-center justify-center rounded border border-border bg-surface text-muted-foreground transition-colors hover:text-foreground hover:border-foreground/40 #{@class}"}
    >
      <svg
        data-theme-icon="moon"
        xmlns="http://www.w3.org/2000/svg"
        class="h-4 w-4"
        fill="none"
        viewBox="0 0 24 24"
        stroke="currentColor"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          stroke-width="1.75"
          d="M21 12.79A9 9 0 1 1 11.21 3c0 .45.05.89.14 1.31A7 7 0 0 0 19.69 12.65c.44.09.87.14 1.31.14Z"
        />
      </svg>
      <svg
        data-theme-icon="sun"
        xmlns="http://www.w3.org/2000/svg"
        class="hidden h-4 w-4"
        fill="none"
        viewBox="0 0 24 24"
        stroke="currentColor"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          stroke-width="1.75"
          d="M12 3v2.25m0 13.5V21m6.364-15.364-1.591 1.591M7.227 16.773l-1.591 1.591M21 12h-2.25M5.25 12H3m15.364 6.364-1.591-1.591M7.227 7.227 5.636 5.636M15.75 12a3.75 3.75 0 1 1-7.5 0 3.75 3.75 0 0 1 7.5 0Z"
        />
      </svg>
    </button>
    """
  end

  @doc "Site-global modals controlled by primary nav actions."
  attr(:current_scope, :any, default: nil)
  attr(:analytics_identity, :any, default: nil)

  @spec primary_nav_modals(map()) :: Phoenix.LiveView.Rendered.t()
  def primary_nav_modals(assigns) do
    assigns =
      assigns
      |> assign(:content_assistant_modal_id, @content_assistant_modal_id)

    ~H"""
    <div id="primary-nav-modal-root">
      <.live_component
        module={AgentJidoWeb.ContentAssistantModalComponent}
        id={@content_assistant_modal_id}
        current_scope={@current_scope}
        analytics_identity={@analytics_identity}
      />
    </div>
    """
  end

  defp nav_container_class(:constrained), do: "container max-w-[1000px] mx-auto px-6"
  defp nav_container_class(:fluid), do: "w-full"

  defp nav_surface_class(:framed),
    do: "nav-surface flex items-center justify-between px-4 py-3 sm:px-6 sm:py-4"

  defp nav_surface_class(:flush),
    do: "flex items-center justify-between px-4 py-3 sm:px-6 sm:py-4"

  defp mobile_menu_class(:framed), do: "hidden md:hidden mt-3 nav-surface p-4 space-y-2"
  defp mobile_menu_class(:flush), do: "hidden md:hidden border-t border-border bg-card p-4 space-y-2"

  defp active_nav_link?(current_path, "/features") do
    path = current_path || ""
    path == "/features" or String.starts_with?(path, "/features/")
  end

  defp active_nav_link?(current_path, href) do
    path = current_path || ""
    path == href or String.starts_with?(path, href <> "/")
  end

  defp primary_nav_path!(label) do
    case Enum.find(@primary_nav_links, fn {entry_label, _path} -> entry_label == label end) do
      {^label, path} -> path
      nil -> raise ArgumentError, "missing primary nav label: #{label}"
    end
  end

  @doc "Jido logo mark — gradient J block + JIDO text."
  attr(:class, :string, default: "")
  attr(:logo_size, :string, default: "w-7 h-7 text-sm")
  attr(:text_size, :string, default: "text-base")
  attr(:show_version, :boolean, default: true)

  def logo(assigns) do
    ~H"""
    <.link navigate="/" class={"flex items-center gap-2.5 #{@class}"}>
      <div class={"rounded flex items-center justify-center font-bold text-primary-foreground bg-gradient-to-br from-primary to-accent-yellow transition-all duration-300 #{@logo_size}"}>
        J
      </div>
      <span class={"font-bold tracking-wide transition-all duration-300 #{@text_size}"}>JIDO</span>
      <span :if={@show_version} class="text-muted-foreground text-[11px] ml-1">{jido_version()}</span>
    </.link>
    """
  end

  attr(:class, :string, default: "w-4 h-4")

  def discord_icon(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 24 24" fill="currentColor">
      <path d="M20.317 4.37a19.791 19.791 0 0 0-4.885-1.515.074.074 0 0 0-.079.037c-.21.375-.444.864-.608 1.25a18.27 18.27 0 0 0-5.487 0 12.64 12.64 0 0 0-.617-1.25.077.077 0 0 0-.079-.037A19.736 19.736 0 0 0 3.677 4.37a.07.07 0 0 0-.032.027C.533 9.046-.32 13.58.099 18.057a.082.082 0 0 0 .031.057 19.9 19.9 0 0 0 5.993 3.03.078.078 0 0 0 .084-.028 14.09 14.09 0 0 0 1.226-1.994.076.076 0 0 0-.041-.106 13.107 13.107 0 0 1-1.872-.892.077.077 0 0 1-.008-.128 10.2 10.2 0 0 0 .372-.292.074.074 0 0 1 .077-.01c3.928 1.793 8.18 1.793 12.062 0a.074.074 0 0 1 .078.01c.12.098.246.198.373.292a.077.077 0 0 1-.006.127 12.299 12.299 0 0 1-1.873.892.077.077 0 0 0-.041.107c.36.698.772 1.362 1.225 1.993a.076.076 0 0 0 .084.028 19.839 19.839 0 0 0 6.002-3.03.077.077 0 0 0 .032-.054c.5-5.177-.838-9.674-3.549-13.66a.061.061 0 0 0-.031-.03zM8.02 15.33c-1.183 0-2.157-1.085-2.157-2.419 0-1.333.956-2.419 2.157-2.419 1.21 0 2.176 1.096 2.157 2.42 0 1.333-.956 2.418-2.157 2.418zm7.975 0c-1.183 0-2.157-1.085-2.157-2.419 0-1.333.955-2.419 2.157-2.419 1.21 0 2.176 1.096 2.157 2.42 0 1.333-.946 2.418-2.157 2.418z" />
    </svg>
    """
  end

  attr(:class, :string, default: "w-4 h-4")

  def github_icon(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 24 24" fill="currentColor">
      <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z" />
    </svg>
    """
  end

  attr(:class, :string, default: "w-4 h-4")

  def x_icon(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 24 24" fill="currentColor">
      <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z" />
    </svg>
    """
  end

  attr(:class, :string, default: "w-4 h-4")

  def llmdb_icon(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 24 24" fill="currentColor">
      <path d="M12 3C7.03 3 3 4.343 3 6v12c0 1.657 4.03 3 9 3s9-1.343 9-3V6c0-1.657-4.03-3-9-3zm0 2c4.419 0 7 1 7 1s-2.581 1-7 1-7-1-7-1 2.581-1 7-1zm0 4c4.419 0 7-1 7-1v2c0 .06-2.581 1-7 1s-7-.94-7-1V8c0 .06 2.581 1 7 1zm0 4c4.419 0 7-1 7-1v2c0 .06-2.581 1-7 1s-7-.94-7-1v-2c0 .06 2.581 1 7 1zm0 4c4.419 0 7-1 7-1v2c0 .06-2.581 1-7 1s-7-.94-7-1v-2c0 .06 2.581 1 7 1z" />
    </svg>
    """
  end

  @doc "Renders the appropriate social icon for a given key."
  attr(:icon, :atom, required: true)
  attr(:class, :string, default: "w-4 h-4")

  @spec social_icon(map()) :: Phoenix.LiveView.Rendered.t()
  def social_icon(assigns) do
    ~H"""
    <%= case @icon do %>
      <% :discord -> %>
        <.discord_icon class={@class} />
      <% :github -> %>
        <.github_icon class={@class} />
      <% :x -> %>
        <.x_icon class={@class} />
      <% :llmdb -> %>
        <.llmdb_icon class={@class} />
      <% _ -> %>
        <span />
    <% end %>
    """
  end
end
