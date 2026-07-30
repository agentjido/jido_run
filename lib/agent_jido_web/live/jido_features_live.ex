defmodule AgentJidoWeb.JidoFeaturesLive do
  @moduledoc """
  Features landing page for the Jido platform.
  """
  use AgentJidoWeb, :live_view

  import AgentJidoWeb.Jido.MarketingLayouts

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "How Jido Works",
       meta_description: "The architecture behind agents that stay up, recover from crashes, and coordinate under real load.",
       categories: categories()
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.marketing_layout
      current_path="/features"
      current_scope={@current_scope}
      analytics_identity={@analytics_identity}
    >
      <div class="container max-w-[1000px] mx-auto px-6 py-12">
        <section class="text-center mb-16 animate-fade-in">
          <div class="inline-block px-4 py-2 rounded mb-5 bg-primary/10 border border-primary/30">
            <span class="text-primary text-[11px] font-semibold tracking-widest uppercase">
              FEATURES
            </span>
          </div>
          <h1 class="text-4xl font-bold mb-4 tracking-tight">
            How Jido <span class="text-primary">works</span>
          </h1>
          <p class="copy-measure-wide mx-auto mb-8 text-lg text-muted-foreground">
            The architecture behind agents that stay up, recover from crashes, and coordinate under real load.
          </p>
        </section>

        <section
          id="operational-control-introduction"
          class="mb-16 rounded-lg border border-primary/20 bg-primary/5 p-8 opacity-0"
          phx-hook="ScrollReveal"
        >
          <div class="mb-3 text-[11px] font-semibold uppercase tracking-widest text-primary">
            Operational control
          </div>
          <h2 class="mb-4 text-2xl font-bold">Supervise, constrain, and inspect Agent work</h2>
          <p class="copy-measure-wide mb-5 text-sm leading-relaxed text-secondary-foreground">
            Jido gives your application explicit runtime surfaces:
            <.link navigate="/docs/operations/supervision-and-failure-boundaries" class="text-primary hover:underline">
              OTP supervision
            </.link>
            controls the Agent lifecycle,
            <.link navigate="/docs/concepts/actions" class="text-primary hover:underline">
              typed Actions
            </.link>
            define capabilities,
            <.link navigate="/docs/operations/security-and-governance" class="text-primary hover:underline">
              policy hooks
            </.link>
            can deny protected work,
            <.link navigate="/docs/concepts/signals" class="text-primary hover:underline">
              Signals
            </.link>
            carry causal context, and
            <.link navigate="/docs/operations/telemetry-and-traces" class="text-primary hover:underline">
              telemetry
            </.link>
            shows what the runtime did.
          </p>
          <p class="copy-measure-wide text-xs leading-relaxed text-muted-foreground">
            Your application still owns authentication, policy sources, durable audit storage, and compliance controls.
            Telemetry is operational observation; it is not an audit log.
          </p>
        </section>

        <section id="features-category-explorer" class="mb-16 opacity-0" phx-hook="ScrollReveal">
          <div class="flex justify-between items-center mb-6">
            <span class="text-sm font-bold tracking-wider uppercase">Features</span>
            <span class="text-[11px] text-muted-foreground">what you can build and how it works</span>
          </div>
          <div class="grid md:grid-cols-2 gap-4">
            <%= for category <- @categories do %>
              <.category_card category={category} />
            <% end %>
          </div>
        </section>

        <div class="text-center mb-16">
          <.link navigate="/compare" class="text-sm text-primary hover:underline">
            See how Jido compares to other frameworks →
          </.link>
        </div>

        <section id="features-cta" class="opacity-0" phx-hook="ScrollReveal">
          <div class="cta-glow rounded-lg p-12 text-center">
            <h2 class="text-2xl font-bold mb-3">Ready to build?</h2>
            <p class="copy-measure mx-auto mb-6 text-sm text-secondary-foreground">
              Go from zero to a running, supervised agent.
            </p>
            <div class="flex flex-wrap justify-center gap-3">
              <.link
                navigate="/docs/getting-started"
                class="bg-primary text-primary-foreground hover:bg-primary/90 text-[13px] font-bold px-7 py-3 rounded transition-colors"
              >
                GET STARTED →
              </.link>
              <.link
                navigate="/examples"
                class="border border-primary/30 text-primary hover:bg-primary/10 text-[13px] font-medium px-7 py-3 rounded transition-colors"
              >
                SEE EXAMPLES
              </.link>
            </div>
          </div>
        </section>
      </div>
    </.marketing_layout>
    """
  end

  attr :category, :map, required: true

  defp category_card(assigns) do
    ~H"""
    <article class="feature-card h-full">
      <div class="flex items-start justify-between gap-3 mb-3">
        <.link navigate={@category.deep_dive} class="font-bold text-[15px] hover:text-primary transition-colors">
          {@category.title}
        </.link>
        <span class="text-[10px] px-2 py-1 rounded border border-border bg-surface text-muted-foreground uppercase tracking-wider">
          {@category.badge}
        </span>
      </div>

      <p class="text-muted-foreground text-xs leading-relaxed mb-4">{@category.summary}</p>

      <ul class="space-y-1.5 text-xs text-secondary-foreground mb-4">
        <%= for capability <- @category.capabilities do %>
          <li>• {capability}</li>
        <% end %>
      </ul>

      <div class="flex flex-wrap gap-2 mb-4">
        <%= for package <- @category.packages do %>
          <.package_chip package={package} />
        <% end %>
      </div>

      <div class="text-[11px] text-muted-foreground">
        <span class="font-semibold text-foreground">Best for:</span> {@category.audience}
      </div>

      <%!-- jido-e11-t20: a proof link beside every production claim. Each card
           makes a behavioral claim (supervision, coordination, observability,
           ...); this routes the visitor to the one runnable example that backs
           it, so the claim is openable rather than asserted. The example slug is
           verified live in jido_features_proof_links_test.exs. --%>
      <div class="feature-card-proof mt-4 flex items-center gap-2">
        <span class="text-[10px] px-2 py-0.5 rounded border border-primary/30 bg-primary/10 text-primary uppercase tracking-wider">
          Proof
        </span>
        <.link
          navigate={@category.proof.href}
          class="text-xs font-medium text-primary hover:underline"
          data-feature-proof={@category.slug}
          data-analytics-event="feature_proof_viewed"
          data-analytics-source="features"
          data-analytics-section-id={"feature-#{@category.slug}"}
          data-analytics-target-url={@category.proof.href}
        >
          {@category.proof.label}
        </.link>
      </div>

      <.link navigate={@category.deep_dive} class="inline-block mt-3 text-xs text-primary hover:underline">
        open deep dive ->
      </.link>
    </article>
    """
  end

  attr :package, :map, required: true

  defp package_chip(assigns) do
    ~H"""
    <.link
      navigate={"/ecosystem/#{@package.id}"}
      class="text-[10px] px-2 py-1 rounded border border-border bg-elevated text-foreground hover:border-primary/40 transition-colors"
    >
      {@package.label} · {status_label(@package.status)}
    </.link>
    """
  end

  defp status_label(:stable), do: "Stable"
  defp status_label(:beta), do: "Beta"
  defp status_label(:experimental), do: "Experimental"
  defp status_label(:planned), do: "Planned"
  defp status_label(_), do: "Unknown"

  # Each card carries a `proof` link to the single runnable example that backs
  # its production claim (jido-e11-t20). The slugs are verified live in
  # jido_features_proof_links_test.exs, so a card whose proof points at a
  # missing or non-live example fails the build.
  defp categories do
    [
      %{
        title: "How Jido agents work",
        slug: "how-agents-work",
        badge: "agents",
        summary:
          "An agent is a struct with state, actions, and tools, running inside a supervised process. See the anatomy of an agent and how each piece connects.",
        capabilities: [
          "Define agents with state, actions, and tools",
          "Run agents under OTP supervision",
          "Inspect and test agent behavior independently"
        ],
        packages: [
          %{id: "jido", label: "jido", status: :beta}
        ],
        audience: "All developers",
        deep_dive: "/features/how-agents-work",
        proof: %{label: "Run the counter agent →", href: "/examples/counter-agent"}
      },
      %{
        title: "Give agents tools",
        slug: "tools",
        badge: "tools",
        summary:
          "Tools are typed Actions with input/output contracts. Define a tool, attach it to an agent, and let it call APIs, query databases, or browse the web.",
        capabilities: [
          "Define tools as typed Actions with contracts",
          "Attach tools to agents at definition time",
          "Validate tool I/O at execution boundaries"
        ],
        packages: [
          %{id: "jido_action", label: "jido_action", status: :beta},
          %{id: "jido_ai", label: "jido_ai", status: :beta}
        ],
        audience: "AI product engineers",
        deep_dive: "/features/tools",
        proof: %{label: "See tools in the coding assistant →", href: "/examples/coding-assistant"}
      },
      %{
        title: "Any model, any provider",
        slug: "llm-support",
        badge: "llm",
        summary: "Works with OpenAI, Anthropic, Google, Mistral, and local models. Swap providers without changing agent code.",
        capabilities: [
          "Provider abstraction through req_llm",
          "Model capability tracking with llm_db",
          "Swap models without code changes"
        ],
        packages: [
          %{id: "jido_ai", label: "jido_ai", status: :beta},
          %{id: "req_llm", label: "req_llm", status: :stable},
          %{id: "llm_db", label: "llm_db", status: :stable}
        ],
        audience: "AI engineers, mixed-stack evaluators",
        deep_dive: "/features/llm-support",
        proof: %{
          label: "See multi-provider chat →",
          href: "/examples/jido-ai-weather-multi-turn-context"
        }
      },
      %{
        title: "Agents that stay up",
        slug: "agents-that-self-heal",
        badge: "reliability",
        summary:
          "Each agent runs in its own BEAM process under OTP supervision. When an agent crashes, its supervisor restarts it as a fresh process with clean state.",
        capabilities: [
          "Process isolation for every agent",
          "Automatic crash recovery via OTP supervisors",
          "No external orchestrator or health checker needed"
        ],
        packages: [
          %{id: "jido", label: "jido", status: :beta}
        ],
        audience: "Platform engineers, SRE teams",
        deep_dive: "/features/agents-that-self-heal",
        proof: %{label: "Run the failure drill →", href: "/examples/failure-drill-agent"}
      },
      %{
        title: "Agents that work together",
        slug: "multi-agent-coordination",
        badge: "coordination",
        summary: "Agents communicate through Signals and respond with Actions. Coordination is explicit code you can read, test, and debug.",
        capabilities: [
          "Typed Signals for inter-agent communication",
          "Route-to-Action coordination contracts",
          "Test coordination logic independently"
        ],
        packages: [
          %{id: "jido_signal", label: "jido_signal", status: :beta},
          %{id: "jido_action", label: "jido_action", status: :beta}
        ],
        audience: "AI product engineers, staff architects",
        deep_dive: "/features/multi-agent-coordination",
        proof: %{label: "See signals route between agents →", href: "/examples/signal-routing-agent"}
      },
      %{
        title: "See what every agent is doing",
        slug: "observe-everything",
        badge: "observability",
        summary: "Built-in telemetry emits events for every agent lifecycle transition. OpenTelemetry integration traces workflows across processes.",
        capabilities: [
          "Telemetry events for agent lifecycle",
          "OpenTelemetry trace integration",
          "Cross-process workflow tracing"
        ],
        packages: [
          %{id: "jido", label: "jido", status: :beta},
          %{id: "jido_otel", label: "jido_otel", status: :experimental}
        ],
        audience: "SRE/platform engineers, technical leads",
        deep_dive: "/features/observe-everything",
        proof: %{label: "See the operations agent →", href: "/examples/operations-agent"}
      },
      %{
        title: "Start small, grow safely",
        slug: "start-small",
        badge: "adoption",
        summary: "Add one agent to your existing Elixir app. No rewrite, no platform migration. Each package composes without lock-in.",
        capabilities: [
          "Start with one supervised agent",
          "Add packages incrementally as needed",
          "No lock-in or platform rewrite required"
        ],
        packages: [
          %{id: "jido", label: "jido", status: :beta},
          %{id: "jido_action", label: "jido_action", status: :beta}
        ],
        audience: "Staff architects, engineering managers",
        deep_dive: "/features/start-small",
        proof: %{label: "See the data pipeline →", href: "/examples/data-pipeline-agent"}
      }
    ]
  end
end
