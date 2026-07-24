defmodule AgentJidoWeb.Jido.MarketingLayouts do
  @moduledoc """
  Layout components for Jido marketing pages.
  """
  use AgentJidoWeb, :html

  alias AgentJidoWeb.Jido.Nav

  attr :title, :string, default: "Jido"
  attr :current_path, :string, default: "/"
  attr :show_nav_modals, :boolean, default: true
  attr :layout_class, :string, default: ""
  attr :current_scope, :any, default: nil
  attr :analytics_identity, :any, default: nil
  slot :inner_block, required: true

  def marketing_layout(assigns) do
    ~H"""
    <div class={"min-h-screen flex flex-col bg-background text-foreground #{@layout_class}"}>
      <.marketing_header current_path={@current_path} />
      <Nav.primary_nav_modals
        :if={@show_nav_modals}
        current_scope={@current_scope}
        analytics_identity={@analytics_identity}
      />
      <main class="flex-1">
        {render_slot(@inner_block)}
      </main>
      <.marketing_footer />
    </div>
    """
  end

  attr :current_path, :string, default: "/"

  def marketing_header(assigns) do
    ~H"""
    <header class="sticky top-0 z-50 bg-background/80 backdrop-blur-md pt-6 pb-12" id="main-header" phx-hook="ScrollShrink">
      <Nav.primary_nav
        current_path={@current_path}
        layout_mode={:constrained}
        show_theme_toggle={true}
        mobile_menu_id="marketing-primary-mobile-menu"
      />
    </header>
    """
  end

  def marketing_footer(assigns) do
    assigns =
      assigns
      |> assign(:company_links, Nav.footer_company_links())
      |> assign(:resource_links, Nav.footer_resource_links())
      |> assign(:package_links, Nav.footer_package_links())
      |> assign(:social_links, Nav.social_links())
      |> assign(:current_year, Date.utc_today().year)

    ~H"""
    <footer class="border-t border-border bg-background">
      <div class="container max-w-[1000px] mx-auto px-6 py-12 md:py-16">
        <div class="grid grid-cols-2 md:grid-cols-6 gap-8 md:gap-12">
          <%!-- Brand Column --%>
          <div class="col-span-2">
            <Nav.logo class="mb-4" show_version={false} logo_size="w-8 h-8 text-sm" text_size="text-lg" />
            <p class="text-muted-foreground text-sm mb-6">
              The Elixir framework for long-running agent systems.
            </p>

            <%!-- Status Indicator --%>
            <div class="flex items-center gap-2 mb-6">
              <span class="w-2 h-2 rounded-full bg-primary animate-pulse" />
              <span class="text-muted-foreground text-xs">All systems operational</span>
            </div>

            <div class="text-muted-foreground text-xs space-y-1">
              <p>Made with ❤️ for the BEAM</p>
              <p>
                Copyright © 2025-{@current_year}
                <a
                  href="https://mike-hostetler.com"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="hover:text-foreground transition-colors"
                >
                  Mike Hostetler
                </a>
              </p>
            </div>
          </div>

          <%!-- Project --%>
          <div>
            <p class="text-xs font-bold tracking-wider text-foreground mb-4">PROJECT</p>
            <ul class="space-y-3">
              <%= for {label, href} <- @company_links do %>
                <li>
                  <.link navigate={href} class="text-sm text-muted-foreground hover:text-foreground transition-colors">
                    {label}
                  </.link>
                </li>
              <% end %>
            </ul>
          </div>

          <%!-- Resources --%>
          <div>
            <p class="text-xs font-bold tracking-wider text-foreground mb-4">RESOURCES</p>
            <ul class="space-y-3">
              <%= for {label, href} <- @resource_links do %>
                <li>
                  <.link navigate={href} class="text-sm text-muted-foreground hover:text-foreground transition-colors">
                    {label}
                  </.link>
                </li>
              <% end %>
            </ul>
          </div>

          <%!-- Social --%>
          <div>
            <p class="text-xs font-bold tracking-wider text-foreground mb-4">SOCIAL</p>
            <ul class="space-y-3">
              <%= for {icon, label, href} <- @social_links do %>
                <li>
                  <a
                    href={href}
                    target="_blank"
                    rel="noopener noreferrer"
                    class="flex items-center gap-2 text-sm text-muted-foreground hover:text-foreground transition-colors"
                  >
                    <Nav.social_icon icon={icon} /> {label}
                  </a>
                </li>
              <% end %>
            </ul>
          </div>

          <%!-- Packages --%>
          <div>
            <p class="text-xs font-bold tracking-wider text-foreground mb-4">PACKAGES</p>
            <ul class="space-y-3">
              <%= for {label, href} <- @package_links do %>
                <li>
                  <a href={href} target="_blank" rel="noopener noreferrer" class="text-sm text-muted-foreground hover:text-foreground transition-colors">
                    {label}
                  </a>
                </li>
              <% end %>
            </ul>
          </div>
        </div>

        <%!-- Bottom Bar --%>
        <div class="mt-12 pt-8 border-t border-border flex flex-col md:flex-row justify-between items-center gap-4">
          <div class="flex items-center gap-4 text-xs text-muted-foreground">
            <span>Apache License 2.0</span>
          </div>
          <div class="flex items-center gap-2">
            <span class="text-xs text-muted-foreground">Jido core v{Nav.jido_version()}</span>
          </div>
        </div>
      </div>
    </footer>
    """
  end
end
