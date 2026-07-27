defmodule AgentJidoWeb.JidoCommunityLive do
  @moduledoc """
  Standalone community page focused on welcoming contributors into the Jido ecosystem.
  """

  use AgentJidoWeb, :live_view

  import AgentJidoWeb.Jido.MarketingLayouts

  alias AgentJidoWeb.Jido.Nav

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Jido Community",
       meta_description: "Build agents with us. Join Discord, collaborate on GitHub, and contribute across the Jido ecosystem.",
       welcome_actions: welcome_actions(),
       start_here_steps: start_here_steps(),
       participation_paths: participation_paths(),
       collaboration_links: collaboration_links(),
       failure_story_request: failure_story_request()
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
        <section class="text-center mb-16 animate-fade-in">
          <div class="inline-block px-4 py-2 rounded mb-5 bg-primary/10 border border-primary/30">
            <span class="text-primary text-[11px] font-semibold tracking-widest uppercase">
              COMMUNITY
            </span>
          </div>

          <h1 class="text-4xl font-bold mb-4 tracking-tight">
            Build agents with us
          </h1>
          <p class="copy-measure-wide mx-auto mb-8 text-lg text-muted-foreground">
            Whether you're exploring Jido for the first time or already shipping workflows, you're welcome here.
            Join the conversation, collaborate in public, and grow with the ecosystem.
          </p>

          <div class="flex flex-wrap justify-center gap-3">
            <%= for action <- @welcome_actions do %>
              <a
                href={action.href}
                target={if(action.external?, do: "_blank", else: nil)}
                rel={if(action.external?, do: "noopener noreferrer", else: nil)}
                class={action.class}
              >
                {action.label}
              </a>
            <% end %>
          </div>
        </section>

        <section id="community-start-here" class="mb-16 opacity-0" phx-hook="ScrollReveal">
          <div class="flex justify-between items-center mb-6">
            <span class="text-sm font-bold tracking-wider uppercase">Start Here</span>
            <span class="text-[11px] text-muted-foreground">15 minutes to get involved</span>
          </div>
          <div class="grid md:grid-cols-3 gap-4">
            <%= for step <- @start_here_steps do %>
              <article class="feature-card h-full">
                <div class="text-[10px] px-2 py-1 rounded w-fit mb-3 bg-primary/10 border border-primary/30 text-primary font-semibold uppercase tracking-wider">
                  Step {step.number}
                </div>
                <h2 class="font-bold text-[15px] mb-2">{step.title}</h2>
                <p class="text-muted-foreground text-xs leading-relaxed mb-4">{step.description}</p>
                <a
                  href={step.href}
                  target={if(step.external?, do: "_blank", else: nil)}
                  rel={if(step.external?, do: "noopener noreferrer", else: nil)}
                  class="inline-block text-xs font-semibold text-primary hover:opacity-80 transition-opacity"
                >
                  {step.cta}
                </a>
              </article>
            <% end %>
          </div>
        </section>

        <section id="community-ways" class="mb-16 opacity-0" phx-hook="ScrollReveal">
          <div class="flex justify-between items-center mb-6">
            <span class="text-sm font-bold tracking-wider uppercase">Ways To Participate</span>
            <span class="text-[11px] text-muted-foreground">questions, ideas, and contributions are welcome</span>
          </div>
          <div class="feature-card">
            <ol class="space-y-4">
              <%= for {path, idx} <- Enum.with_index(@participation_paths, 1) do %>
                <li class="flex items-start gap-3">
                  <span class="inline-flex items-center justify-center w-6 h-6 rounded-full bg-primary/10 border border-primary/30 text-primary text-[11px] font-semibold shrink-0 mt-0.5">
                    {idx}
                  </span>
                  <div>
                    <h2 class="font-bold text-[14px] mb-1">{path.title}</h2>
                    <p class="text-muted-foreground text-xs leading-relaxed">{path.description}</p>
                  </div>
                </li>
              <% end %>
            </ol>
          </div>
        </section>

        <section id="community-github" class="mb-16 opacity-0" phx-hook="ScrollReveal">
          <div class="cta-glow rounded-lg p-10">
            <h2 class="text-2xl font-bold mb-3">Work together on GitHub</h2>
            <p class="text-sm text-secondary-foreground leading-relaxed">
              We build in public on GitHub across the Agent Jido ecosystem.
              Pick a package, open an issue, and collaborate with us.
            </p>
            <ul class="mt-6 space-y-4">
              <%= for link <- @collaboration_links do %>
                <li>
                  <a
                    href={link.href}
                    target={if(link.external?, do: "_blank", else: nil)}
                    rel={if(link.external?, do: "noopener noreferrer", else: nil)}
                    class="inline-flex items-center gap-2 text-sm font-semibold text-primary hover:opacity-80 transition-opacity"
                  >
                    <.icon name={link.icon} class="h-4 w-4" />
                    {link.title}
                    <.icon
                      :if={link.external?}
                      name="hero-arrow-top-right-on-square"
                      class="h-3.5 w-3.5 text-muted-foreground"
                    />
                  </a>
                  <p class="mt-1 ml-6 text-xs text-secondary-foreground">{link.description}</p>
                </li>
              <% end %>
            </ul>
            <p class="mt-4 text-xs text-secondary-foreground">
              We're rolling out clear <code>good first issue</code> labels and will aggregate them across repositories.
            </p>
          </div>
        </section>

        <section id="community-failure-stories" class="mb-16 opacity-0" phx-hook="ScrollReveal">
          <div class="flex justify-between items-center mb-6">
            <span class="text-sm font-bold tracking-wider uppercase">Production Failure Stories</span>
            <span class="text-[11px] text-muted-foreground">real problems become docs and tests</span>
          </div>
          <div class="feature-card">
            <h2 class="font-bold text-[15px] mb-2">{@failure_story_request.headline}</h2>
            <p class="text-muted-foreground text-xs leading-relaxed mb-4">
              {@failure_story_request.intro}
            </p>

            <div class="mb-4">
              <p class="text-[11px] font-semibold uppercase tracking-wider text-muted-foreground mb-2">
                Tell us
              </p>
              <ul class="space-y-1.5">
                <%= for item <- @failure_story_request.what_to_include do %>
                  <li class="flex items-start gap-2 text-xs text-muted-foreground leading-relaxed">
                    <span class="text-primary mt-0.5">•</span>
                    <span>{item}</span>
                  </li>
                <% end %>
              </ul>
            </div>

            <div class="mb-4">
              <p class="text-[11px] font-semibold uppercase tracking-wider text-muted-foreground mb-2">
                What we do with it
              </p>
              <ul class="space-y-1.5">
                <%= for item <- @failure_story_request.conversion do %>
                  <li class="flex items-start gap-2 text-xs text-muted-foreground leading-relaxed">
                    <span class="text-primary mt-0.5">→</span>
                    <span>{item}</span>
                  </li>
                <% end %>
              </ul>
            </div>

            <a
              href={@failure_story_request.submit_url}
              target="_blank"
              rel="noopener noreferrer"
              class="inline-block text-xs font-semibold text-primary hover:opacity-80 transition-opacity"
            >
              {@failure_story_request.cta}
            </a>

            <%= if example = @failure_story_request[:example] do %>
              <p class="mt-5 pt-4 border-t border-border text-[11px] text-muted-foreground leading-relaxed">
                {example.prefix}
                <a
                  href={example.href}
                  class="font-semibold text-primary hover:opacity-80 transition-opacity"
                >
                  {example.label}
                </a>
              </p>
            <% end %>
          </div>
        </section>

        <section id="community-cta" class="opacity-0" phx-hook="ScrollReveal">
          <div class="cta-glow rounded-lg p-12 text-center">
            <h2 class="text-2xl font-bold mb-3">Come build with us</h2>
            <p class="copy-measure mx-auto mb-6 text-sm text-secondary-foreground">
              Join Discord, pick a contribution lane, and ship your first contribution this week.
            </p>
            <a
              href={Nav.discord_url()}
              class="bg-primary text-primary-foreground hover:bg-primary/90 text-[13px] font-bold px-7 py-3 rounded transition-colors inline-block"
            >
              JOIN DISCORD
            </a>
          </div>
        </section>
      </div>
    </.marketing_layout>
    """
  end

  defp welcome_actions do
    [
      %{
        label: "Join Discord",
        href: Nav.discord_url(),
        external?: true,
        class: "bg-primary text-primary-foreground hover:bg-primary/90 text-[13px] font-bold px-7 py-3 rounded transition-colors"
      },
      %{
        label: "Collaborate on GitHub",
        href: "https://github.com/agentjido",
        external?: true,
        class: "border border-accent-cyan text-accent-cyan hover:bg-accent-cyan/10 text-[13px] font-medium px-7 py-3 rounded transition-colors"
      },
      %{
        label: "View Showcase",
        href: "/community/showcase",
        external?: false,
        class:
          "border border-border text-muted-foreground hover:text-foreground hover:border-foreground/40 text-[13px] font-medium px-7 py-3 rounded transition-colors"
      }
    ]
  end

  defp start_here_steps do
    [
      %{
        number: 1,
        title: "Join Discord and say hello",
        description: "Introduce yourself, share what you're building, and ask your first question.",
        cta: "Open Discord",
        href: Nav.discord_url(),
        external?: true
      },
      %{
        number: 2,
        title: "Pick a getting-started path",
        description: "Choose a short onboarding path and run one tutorial so you can contribute with confidence.",
        cta: "Open Getting Started",
        href: "/docs/getting-started",
        external?: false
      },
      %{
        number: 3,
        title: "Open or comment on an issue",
        description: "Share a bug, docs fix, or idea, then collaborate in the open.",
        cta: "Open Issues",
        href: "https://github.com/agentjido/agentjido_xyz/issues",
        external?: true
      }
    ]
  end

  defp participation_paths do
    [
      %{
        title: "Ask questions in Discord",
        description: "Get help fast, share progress, and swap ideas."
      },
      %{
        title: "File bugs and docs improvements",
        description: "Open an issue when something breaks or feels unclear."
      },
      %{
        title: "Test examples and Livebooks",
        description: "Run examples, test guides, and share what worked."
      },
      %{
        title: "Build ecosystem packages",
        description: "Create focused integrations and tools that expand the ecosystem."
      },
      %{
        title: "Propose ideas",
        description: "Bring workflow ideas and use cases to help shape priorities."
      }
    ]
  end

  defp collaboration_links do
    [
      %{
        title: "Agent Jido organization",
        description: "Explore repositories across the ecosystem.",
        href: "https://github.com/agentjido",
        external?: true,
        icon: "hero-book-open"
      },
      %{
        title: "Browse ecosystem packages",
        description: "Each package page links to its repository and issue queue.",
        href: "/ecosystem",
        external?: false,
        icon: "hero-command-line"
      },
      %{
        title: "Open an issue",
        description: "Start with site and docs issues here, then use package issue queues for package-specific work.",
        href: "https://github.com/agentjido/agentjido_xyz/issues",
        external?: true,
        icon: "hero-exclamation-circle-mini"
      }
    ]
  end

  defp failure_story_request do
    %{
      headline: "Tell us when Jido fails in production",
      intro:
        "A real production failure is the most useful thing you can hand us. " <>
          "Every story we can reproduce becomes a public fix note and a regression test, " <>
          "so the same fault does not silently return.",
      what_to_include: [
        "Symptom and impact: what broke, and for whom",
        "The smallest sequence that reproduces it, or the closest you have",
        "Jido packages and versions, runtime, and environment",
        "What you expected, and what actually happened",
        "Redacted logs, telemetry, or traces that show the failure",
        "How supervision, retry, or an operator action recovered it"
      ],
      conversion: [
        "A maintainer writes a public fix note naming the cause and the correction",
        "A regression test locks the corrected behavior so it does not return"
      ],
      submit_url: "https://github.com/agentjido/agentjido_xyz/issues",
      cta: "Submit a failure story",
      # The first concrete instance of the docs+tests conversion path above:
      # a real reproducible fault turned into a public fix note + regression test.
      example: %{
        prefix: "See the first one:",
        label: "how a first-LLM tutorial failure became a fix note and a test",
        href: "/blog/fix-first-llm-tutorial-provider-mismatch"
      }
    }
  end
end
