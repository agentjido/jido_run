defmodule AgentJidoWeb.JidoCommunityShowcaseLive do
  @moduledoc """
  Community showcase page highlighting real projects built with Jido.
  """

  use AgentJidoWeb, :live_view

  alias AgentJido.Community.Showcase
  alias AgentJidoWeb.StructuredData

  import AgentJidoWeb.Jido.MarketingLayouts

  @submit_url "https://github.com/agentjido/jido_run/issues/32"

  @impl true
  def mount(_params, _session, socket) do
    projects = Showcase.all_projects()

    {:ok,
     assign(socket,
       page_title: "Built with Jido",
       meta_description: "Community showcase of real projects built with Jido.",
       structured_data: [
         StructuredData.breadcrumb_list([
           {"Jido", "/"},
           {"Community", "/community"},
           {"Showcase", "/community/showcase"}
         ])
       ],
       projects: projects,
       submit_url: @submit_url
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.marketing_layout
      current_path="/community"
      current_scope={@current_scope}
      analytics_identity={@analytics_identity}
    >
      <div class="container max-w-[1000px] mx-auto px-6 py-12">
        <section class="mb-12">
          <div class="inline-block px-4 py-2 rounded mb-5 bg-primary/10 border border-primary/30">
            <span class="text-primary text-[11px] font-semibold tracking-widest uppercase">
              BUILT WITH JIDO
            </span>
          </div>

          <h1 class="text-3xl font-bold leading-tight mb-4 tracking-tight">
            Community Showcase
          </h1>
          <p class="copy-measure text-sm leading-relaxed text-secondary-foreground mb-6">
            Real projects from the community using Jido in production and experiments.
            Add an entry by submitting a structured Markdown card.
          </p>

          <div class="flex flex-wrap items-center gap-6">
            <div class="flex items-baseline gap-2">
              <span class="text-primary text-2xl font-bold">{length(@projects)}</span>
              <span class="text-muted-foreground text-xs">projects listed</span>
            </div>
            <a
              href={@submit_url}
              target="_blank"
              rel="noopener noreferrer"
              class="text-xs text-primary hover:text-primary/80 transition-colors font-semibold"
            >
              SUBMIT YOUR PROJECT →
            </a>
          </div>
        </section>

        <section :if={@projects == []} class="mb-16">
          <article class="feature-card">
            <h2 class="text-lg font-bold mb-2">No projects listed yet</h2>
            <p class="text-sm text-muted-foreground mb-4">
              Be the first to share what you built with Jido.
            </p>
            <a
              href={@submit_url}
              target="_blank"
              rel="noopener noreferrer"
              class="inline-flex items-center gap-2 text-sm font-semibold text-primary hover:opacity-80 transition-opacity"
            >
              Open showcase issue <.icon name="hero-arrow-top-right-on-square" class="h-4 w-4" />
            </a>
          </article>
        </section>

        <section :if={@projects != []} class="mb-16">
          <div class="grid md:grid-cols-2 gap-4">
            <%= for project <- @projects do %>
              <article id={"showcase-project-#{project.slug}"} class="feature-card h-full flex flex-col">
                <div class="flex items-start justify-between gap-3 mb-3">
                  <div class="flex items-start gap-3">
                    <img
                      :if={project.logo_url}
                      src={project.logo_url}
                      alt={"#{project.title} logo"}
                      class="w-10 h-10 rounded border border-border bg-card object-contain"
                    />
                    <div
                      :if={is_nil(project.logo_url)}
                      class="w-10 h-10 rounded border border-primary/30 bg-primary/10 text-primary text-sm font-bold flex items-center justify-center"
                    >
                      {project_initial(project.title)}
                    </div>
                    <div>
                      <h2 class="text-base font-bold">{project.title}</h2>
                      <p class="text-xs text-muted-foreground mt-1">{project.description}</p>
                    </div>
                  </div>

                  <span
                    :if={project.featured}
                    class="text-[10px] px-2 py-1 rounded bg-accent-cyan/10 border border-accent-cyan/30 text-accent-cyan font-semibold uppercase tracking-wider"
                  >
                    Featured
                  </span>
                </div>

                <div :if={project.tags != []} class="flex flex-wrap gap-1.5 mb-3">
                  <span
                    :for={tag <- project.tags}
                    class="text-[10px] px-2 py-0.5 rounded border border-border bg-surface text-muted-foreground"
                  >
                    {tag}
                  </span>
                </div>

                <div
                  :if={String.trim(project.body) != ""}
                  class="prose prose-sm max-w-none text-muted-foreground mb-4"
                >
                  {Phoenix.HTML.raw(project.body)}
                </div>

                <div class="mt-auto flex flex-wrap items-center gap-3 pt-2">
                  <a
                    href={project.project_url}
                    target="_blank"
                    rel="noopener noreferrer"
                    class="inline-flex items-center gap-2 text-sm font-semibold text-primary hover:opacity-80 transition-opacity"
                  >
                    Visit project <.icon name="hero-arrow-top-right-on-square" class="h-4 w-4" />
                  </a>

                  <a
                    :if={project.repo_url}
                    href={project.repo_url}
                    target="_blank"
                    rel="noopener noreferrer"
                    class="inline-flex items-center gap-2 text-sm text-muted-foreground hover:text-foreground transition-colors"
                  >
                    Source <.icon name="hero-code-bracket" class="h-4 w-4" />
                  </a>
                </div>
              </article>
            <% end %>
          </div>
        </section>

        <section class="mb-16">
          <div class="cta-glow rounded-lg p-12 text-center">
            <h2 class="text-2xl font-bold mb-3">Share what you built</h2>
            <p class="copy-measure mx-auto mb-6 text-sm text-secondary-foreground">
              Open an issue with project name, one-line description, and link.
              We will add it as a structured showcase entry.
            </p>
            <a
              href={@submit_url}
              target="_blank"
              rel="noopener noreferrer"
              class="bg-primary text-primary-foreground hover:bg-primary/90 text-[13px] font-bold px-7 py-3 rounded transition-colors inline-flex items-center gap-2"
            >
              Submit Project <.icon name="hero-arrow-top-right-on-square" class="h-4 w-4" />
            </a>
          </div>
        </section>
      </div>
    </.marketing_layout>
    """
  end

  @spec project_initial(String.t()) :: String.t()
  defp project_initial(title) when is_binary(title) do
    title
    |> String.trim()
    |> String.first()
    |> case do
      nil -> "J"
      value -> String.upcase(value)
    end
  end
end
