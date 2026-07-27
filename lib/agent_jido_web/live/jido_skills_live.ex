defmodule AgentJidoWeb.JidoSkillsLive do
  @moduledoc """
  Standalone catalog page for the vendored upstream Jido package skills.
  """

  use AgentJidoWeb, :live_view

  alias AgentJido.UpstreamSkillCatalog

  import AgentJidoWeb.Jido.MarketingLayouts

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Jido Skills",
       meta_description: "Package-oriented Jido skills catalog with one card per external package and a router skill for package selection.",
       package_entries: UpstreamSkillCatalog.package_entries(),
       router_entries: UpstreamSkillCatalog.router_entries(),
       repo_url: UpstreamSkillCatalog.repo_url()
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.marketing_layout
      current_path="/skills"
      current_scope={@current_scope}
      analytics_identity={@analytics_identity}
    >
      <div class="container max-w-[1000px] mx-auto px-6 py-12">
        <section class="mb-12">
          <div class="inline-block px-4 py-2 rounded mb-5 bg-primary/10 border border-primary/30">
            <span class="text-primary text-[11px] font-semibold tracking-widest uppercase">
              SKILLS
            </span>
          </div>

          <h1 class="text-3xl font-bold leading-tight mb-4 tracking-tight">
            Package skills for contributors and adopters
          </h1>
          <p class="copy-measure text-sm leading-relaxed text-secondary-foreground mb-4">
            This page organizes the vendored upstream skills copied from <a
              href={@repo_url}
              target="_blank"
              rel="noopener noreferrer"
              class="text-primary hover:opacity-80 transition-opacity"
            >arrowcircle/jido-skills</a>.
            Each card maps to one external package so contributors can pick the right skill set for the package they are working in, instead of scanning one long mixed catalog.
          </p>
          <p class="copy-measure text-sm leading-relaxed text-secondary-foreground">
            The router skill stays up front as the starting point when package boundaries are unclear. The builder-skills demo still lives in the runtime foundations example; this page is intentionally package-first.
          </p>
        </section>

        <section :if={@router_entries != []} class="mb-12">
          <div class="flex items-center justify-between mb-6">
            <span class="text-sm font-bold tracking-wider uppercase">Start Here</span>
            <span class="text-[11px] text-muted-foreground">use the router when unsure which package to start with</span>
          </div>

          <%!-- jido-e10-t26: "use the router when unsure" guidance from the
               upstream skills README, so users do not load the full catalog by
               default. --%>
          <p class="copy-measure text-sm leading-relaxed text-secondary-foreground mb-3">
            If you do not know which package skill to start with, use the router skill first. The router will:
          </p>
          <ul class="copy-measure list-disc pl-5 text-sm leading-relaxed text-secondary-foreground mb-6 space-y-1">
            <li>identify the anchor package skill,</li>
            <li>pull in adjacent skills only when the task crosses their boundaries, and</li>
            <li>avoid loading the entire ecosystem by default.</li>
          </ul>

          <%= for entry <- @router_entries do %>
            <article id={"router-skill-card-#{entry.id}"} class="feature-card border-primary/30 bg-primary/5">
              <div class="flex flex-wrap items-center gap-3 mb-3">
                <span class="text-[10px] px-2 py-1 rounded bg-primary/10 border border-primary/30 text-primary font-semibold uppercase tracking-wider">
                  Router Skill
                </span>
                <span class="text-[11px] font-mono text-muted-foreground">{entry.name}</span>
              </div>
              <h2 class="text-xl font-bold text-foreground mb-2">{entry.title}</h2>
              <p class="text-sm text-secondary-foreground leading-relaxed mb-5">{entry.description}</p>
              <dl class="space-y-2 text-[11px] mb-5">
                <div :if={entry.task} class="flex gap-2">
                  <dt class="w-24 shrink-0 text-muted-foreground uppercase tracking-wider">Use for</dt>
                  <dd class="text-foreground">{entry.task}</dd>
                </div>
                <div :if={entry.use_when != []} class="flex gap-2">
                  <dt class="w-24 shrink-0 text-muted-foreground uppercase tracking-wider">Triggers</dt>
                  <dd class="text-foreground">{Enum.map_join(entry.use_when, ", ", & &1)}</dd>
                </div>
                <div :if={entry.maturity_note} class="flex gap-2">
                  <dt class="w-24 shrink-0 text-muted-foreground uppercase tracking-wider">Maturity</dt>
                  <dd class="text-foreground">{entry.maturity_note}</dd>
                </div>
                <div class="flex gap-2">
                  <dt class="w-24 shrink-0 text-muted-foreground uppercase tracking-wider">Source</dt>
                  <dd class="text-foreground break-all">{entry.skill_source_path}</dd>
                </div>
              </dl>
              <div class="grid gap-3 md:grid-cols-2 mb-5">
                <div class="rounded-md border border-border bg-card/70 p-4">
                  <div class="text-[10px] uppercase tracking-wider text-muted-foreground mb-1">Agent Files</div>
                  <div class="text-sm font-semibold text-foreground">{length(entry.agent_files)}</div>
                </div>
                <div class="rounded-md border border-border bg-card/70 p-4">
                  <div class="text-[10px] uppercase tracking-wider text-muted-foreground mb-1">Reference Files</div>
                  <div class="text-sm font-semibold text-foreground">{length(entry.reference_files)}</div>
                </div>
              </div>
              <div class="flex flex-wrap gap-3">
                <a
                  href={entry.upstream_url}
                  target="_blank"
                  rel="noopener noreferrer"
                  class="text-xs font-semibold px-3 py-2 rounded border border-primary/30 bg-primary/10 text-primary hover:bg-primary/15 transition-colors"
                >
                  Open Upstream Skill
                </a>
                <.link
                  navigate="/examples/jido-ai-skills-runtime-foundations?tab=demo"
                  class="text-xs font-semibold px-3 py-2 rounded border border-border text-muted-foreground hover:text-foreground hover:border-foreground/40 transition-colors"
                >
                  Open Builder Skills Demo
                </.link>
              </div>
            </article>
          <% end %>
        </section>

        <section>
          <div class="flex items-center justify-between mb-6">
            <span class="text-sm font-bold tracking-wider uppercase">External Packages</span>
            <span class="text-[11px] text-muted-foreground">one card per external package skill</span>
          </div>

          <div class="grid md:grid-cols-2 gap-4">
            <%= for entry <- @package_entries do %>
              <article id={"skill-card-#{entry.id}"} class="feature-card h-full flex flex-col">
                <div class="flex items-start justify-between gap-3 mb-3">
                  <div>
                    <div class="text-[10px] uppercase tracking-wider text-muted-foreground mb-1">External Package</div>
                    <h2 class="text-base font-bold text-foreground">{entry.title}</h2>
                  </div>
                  <span class="text-[10px] font-mono text-muted-foreground bg-card px-2 py-1 rounded border border-border">
                    {entry.name}
                  </span>
                </div>

                <p class="text-sm text-secondary-foreground leading-relaxed mb-4">{entry.description}</p>

                <dl class="space-y-2 text-[11px] mb-5">
                  <div class="flex gap-2">
                    <dt class="w-24 shrink-0 text-muted-foreground uppercase tracking-wider">Package</dt>
                    <dd class="text-foreground">
                      <span class="font-mono break-all">{entry.package_name || "—"}</span>
                      <span :if={entry.package_title && entry.package_title != entry.title} class="text-muted-foreground">
                        ({entry.package_title})
                      </span>
                    </dd>
                  </div>
                  <div :if={entry.task} class="flex gap-2">
                    <dt class="w-24 shrink-0 text-muted-foreground uppercase tracking-wider">Use for</dt>
                    <dd class="text-foreground">{entry.task}</dd>
                  </div>
                  <div :if={entry.use_when != []} class="flex gap-2">
                    <dt class="w-24 shrink-0 text-muted-foreground uppercase tracking-wider">Triggers</dt>
                    <dd class="text-foreground">{Enum.map_join(entry.use_when, ", ", & &1)}</dd>
                  </div>
                  <div :if={entry.maturity_note} class="flex gap-2">
                    <dt class="w-24 shrink-0 text-muted-foreground uppercase tracking-wider">Maturity</dt>
                    <dd class="text-foreground">{entry.maturity_note}</dd>
                  </div>
                  <div class="flex gap-2">
                    <dt class="w-24 shrink-0 text-muted-foreground uppercase tracking-wider">Source</dt>
                    <dd class="text-foreground break-all">{entry.skill_source_path}</dd>
                  </div>
                  <div class="flex gap-2">
                    <dt class="w-24 shrink-0 text-muted-foreground uppercase tracking-wider">Files</dt>
                    <dd class="text-foreground">{length(entry.agent_files) + length(entry.reference_files)}</dd>
                  </div>
                </dl>

                <div class="mt-auto flex flex-wrap gap-2">
                  <a
                    href={entry.upstream_url}
                    target="_blank"
                    rel="noopener noreferrer"
                    class="text-xs font-semibold px-3 py-2 rounded border border-accent-cyan/30 bg-accent-cyan/10 text-accent-cyan hover:bg-accent-cyan/15 transition-colors"
                  >
                    Open Upstream Skill
                  </a>
                  <a
                    :if={entry.hexdocs_url}
                    href={entry.hexdocs_url}
                    target="_blank"
                    rel="noopener noreferrer"
                    class="text-xs font-semibold px-3 py-2 rounded border border-border text-muted-foreground hover:text-foreground hover:border-foreground/40 transition-colors"
                  >
                    HexDocs
                  </a>
                  <a
                    :if={entry.hex_url}
                    href={entry.hex_url}
                    target="_blank"
                    rel="noopener noreferrer"
                    class="text-xs font-semibold px-3 py-2 rounded border border-border text-muted-foreground hover:text-foreground hover:border-foreground/40 transition-colors"
                  >
                    Hex
                  </a>
                  <.link
                    :if={entry.ecosystem_path}
                    navigate={entry.ecosystem_path}
                    class="text-xs font-semibold px-3 py-2 rounded border border-border text-muted-foreground hover:text-foreground hover:border-foreground/40 transition-colors"
                  >
                    Ecosystem Page
                  </.link>
                </div>
              </article>
            <% end %>
          </div>
        </section>
      </div>
    </.marketing_layout>
    """
  end
end
