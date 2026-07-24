defmodule AgentJidoWeb.JidoHomeLive do
  use AgentJidoWeb, :live_view

  import AgentJidoWeb.Jido.HomeSections
  import AgentJidoWeb.Jido.MarketingLayouts

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Jido — the Elixir framework for long-running agent systems",
       meta_description:
         "Jido is the Elixir framework for long-running agent systems. Build supervised agents, typed tools, and explicit workflows on Elixir/OTP."
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.marketing_layout
      current_path="/"
      layout_class="home-layout"
      current_scope={@current_scope}
      analytics_identity={@analytics_identity}
    >
      <div id="home-page" class="container max-w-[1000px] mx-auto px-6">
        <.hero_section />
        <.what_you_can_build_section />
        <.quick_start_code />
        <.pillars_section />
        <.why_elixir_otp_section />
        <.ecosystem_section />
        <.build_first_agent_cta />
      </div>
    </.marketing_layout>
    """
  end

  defp hero_section(assigns) do
    ~H"""
    <section class="text-center mb-16 animate-fade-in">
      <div class="inline-block bg-primary/10 border border-primary/30 px-4 py-2 rounded mb-6">
        <span class="home-eyebrow-label text-[11px] font-semibold tracking-widest">
          OPEN-SOURCE ELIXIR FRAMEWORK
        </span>
      </div>

      <h1 class="text-4xl sm:text-[42px] font-bold leading-tight mb-5 tracking-tight">
        Build long-running agents <br />
        <span class="text-primary">on the BEAM.</span>
      </h1>

      <p class="text-secondary-foreground text-[15px] leading-relaxed mb-6 max-w-lg mx-auto">
        Jido gives Elixir teams supervised Agent processes, typed tools, and explicit workflows. Add one Agent to your current application, then add AI and coordination when you need them.
      </p>

      <div class="flex items-center gap-4 justify-center mb-12">
        <.link
          navigate="/docs/getting-started"
          class="bg-primary text-primary-foreground hover:bg-primary/90 text-[13px] font-bold px-7 py-5 rounded transition-colors"
        >
          BUILD YOUR FIRST AGENT →
        </.link>
        <.link
          id="home-failure-drill-cta"
          navigate="/examples/failure-drill-agent"
          class="home-subtle-link text-[13px] font-semibold transition-colors"
        >
          RUN A FAILURE DRILL →
        </.link>
      </div>

      <p class="home-muted-copy text-[11px] leading-relaxed max-w-xl mx-auto -mt-6">
        Already an Elixir developer?
        <.link
          id="home-elixir-expert-guide-link"
          navigate="/docs/getting-started/elixir-developers"
          class="text-primary hover:underline font-semibold ml-1"
        >
          Jump to the expert guide.
        </.link>
        <span class="mx-2">•</span>
        New to Elixir?
        <.link
          navigate="/docs/getting-started/new-to-elixir"
          class="text-primary hover:underline font-semibold ml-1"
        >
          Start here.
        </.link>
      </p>
    </section>
    """
  end

  defp what_you_can_build_section(assigns) do
    cards = [
      %{
        title: "Coding agents",
        desc: "Agents that read, analyze, and refactor code across repositories."
      },
      %{
        title: "Research and synthesis",
        desc: "Multi-step research agents that find sources, verify facts, and produce reports."
      },
      %{
        title: "Document processing",
        desc: "Extract, classify, and route documents: invoices, contracts, support tickets."
      },
      %{
        title: "Customer support",
        desc: "Agents that resolve issues using your knowledge base and escalate when needed."
      },
      %{
        title: "DevOps and monitoring",
        desc: "Agents that watch systems, diagnose problems, and run remediation playbooks."
      },
      %{
        title: "Data pipelines",
        desc: "Agents that collect, transform, and load data from multiple sources on schedule."
      }
    ]

    assigns = assign(assigns, :cards, cards)

    ~H"""
    <section
      id="what-you-can-build"
      class="home-pillars-section mb-20 opacity-0"
      phx-hook="ScrollReveal"
    >
      <div class="text-center mb-16">
        <h2 class="text-3xl font-bold tracking-tight mb-4">What you can build with Jido</h2>
        <p class="home-muted-copy text-sm leading-relaxed max-w-lg mx-auto">
          From single-purpose assistants to coordinated multi-agent workflows.
        </p>
      </div>

      <div class="home-pillars-grid">
        <%= for card <- @cards do %>
          <.link navigate="/examples" class="home-pillar-card group">
            <h3 class="text-lg sm:text-xl font-bold mb-3 leading-tight group-hover:text-primary transition-colors duration-200">
              {card.title}
            </h3>
            <p class="home-muted-copy text-[15px] leading-relaxed max-w-md mx-auto">
              {card.desc}
            </p>
          </.link>
        <% end %>
      </div>
    </section>
    """
  end

  defp pillars_section(assigns) do
    pillars = [
      %{
        icon: "◉",
        title: "Supervised failure handling",
        desc:
          "OTP supervision contains failures and restarts a crashed AgentServer by your restart strategy. Add persistence and idempotent Actions when work must survive a restart.",
        icon_color_class: "text-accent-green",
        chip_class: "home-pillar-chip home-pillar-chip-green",
        link_class: "home-pillar-link home-pillar-link-green",
        link: "/features/agents-that-self-heal"
      },
      %{
        icon: "⧉",
        title: "Multi-agent workflows you can test",
        desc:
          "Agents coordinate through typed Actions and Signals, not prompt chains. An Agent is data; an AgentServer is the process that runs it. Debug and test each step independently, just like regular code.",
        icon_color_class: "text-accent-cyan",
        chip_class: "home-pillar-chip home-pillar-chip-cyan",
        link_class: "home-pillar-link home-pillar-link-cyan",
        link: "/features/multi-agent-coordination"
      },
      %{
        icon: "⬡",
        title: "Instrument agent lifecycles",
        desc:
          "Jido emits telemetry for lifecycle and Action execution. Add OpenTelemetry export via jido_otel when its maturity fits your application.",
        icon_color_class: "text-accent-yellow",
        chip_class: "home-pillar-chip home-pillar-chip-yellow",
        link_class: "home-pillar-link home-pillar-link-yellow",
        link: "/features/observe-everything"
      },
      %{
        icon: "▣",
        title: "Start small, grow safely",
        desc:
          "Add one agent to your existing Elixir app. No rewrite, no platform migration. Add more agents, tools, and packages only when you need them.",
        icon_color_class: "text-accent-red",
        chip_class: "home-pillar-chip home-pillar-chip-red",
        link_class: "home-pillar-link home-pillar-link-red",
        link: "/features/start-small"
      }
    ]

    assigns = assign(assigns, :pillars, pillars)

    ~H"""
    <section id="pillars" class="home-pillars-section mb-20 opacity-0" phx-hook="ScrollReveal">
      <div class="text-center mb-16">
        <h2 class="text-3xl font-bold tracking-tight mb-4">Why teams choose Jido</h2>
        <p class="home-muted-copy text-sm leading-relaxed max-w-lg mx-auto">
          Agent frameworks are everywhere. Here's what makes this one different.
        </p>
      </div>

      <div class="home-pillars-grid">
        <%= for pillar <- @pillars do %>
          <.link navigate={pillar.link} class="home-pillar-card group">
            <div class={pillar.chip_class}>
              <span class={"text-2xl leading-none #{pillar.icon_color_class}"}>{pillar.icon}</span>
            </div>
            <h3 class="text-lg sm:text-xl font-bold mb-3 leading-tight group-hover:text-primary transition-colors duration-200">
              {pillar.title}
            </h3>
            <p class="home-muted-copy text-[15px] leading-relaxed max-w-md mx-auto mb-4">{pillar.desc}</p>
            <span class={pillar.link_class}>Learn more →</span>
          </.link>
        <% end %>
      </div>
    </section>
    """
  end

  defp ecosystem_section(assigns) do
    ~H"""
    <section id="ecosystem" class="home-ecosystem-section mb-16 opacity-0" phx-hook="ScrollReveal">
      <div id="home-ecosystem-section">
        <div class="home-ecosystem-header">
          <div>
            <h2 class="text-2xl font-bold tracking-tight">One framework, many packages</h2>
            <p class="home-ecosystem-summary">
              Start with the core. Add AI, tools, and integrations as you need them.
            </p>
          </div>

          <.link navigate="/ecosystem" class="home-ecosystem-explore-link">
            Explore the full ecosystem →
          </.link>
        </div>

        <div class="home-ecosystem-rows">
          <article class="home-ecosystem-row">
            <div class="home-ecosystem-row-header">
              <h3 class="home-ecosystem-row-title">Core</h3>
            </div>
            <p class="home-ecosystem-packages">
              <span>jido</span>
              <span class="home-ecosystem-separator" aria-hidden="true">·</span>
              <span>jido_action</span>
              <span class="home-ecosystem-separator" aria-hidden="true">·</span>
              <span>jido_signal</span>
            </p>
          </article>

          <article class="home-ecosystem-row">
            <div class="home-ecosystem-row-header">
              <h3 class="home-ecosystem-row-title">Add AI when ready</h3>
            </div>
            <p class="home-ecosystem-packages">
              <span>jido_ai</span>
              <span class="home-ecosystem-separator" aria-hidden="true">·</span>
              <span>req_llm</span>
              <span class="home-ecosystem-separator" aria-hidden="true">·</span>
              <span>llm_db</span>
            </p>
          </article>

          <article class="home-ecosystem-row">
            <div class="home-ecosystem-row-header">
              <h3 class="home-ecosystem-row-title">Integrate and extend</h3>
            </div>
            <p class="home-ecosystem-packages">
              <span>ash_jido</span>
              <span class="home-ecosystem-separator" aria-hidden="true">·</span>
              <span>jido_messaging</span>
              <span class="home-ecosystem-separator" aria-hidden="true">·</span>
              <span>jido_otel</span>
            </p>
          </article>
        </div>
      </div>
    </section>
    """
  end

  defp why_elixir_otp_section(assigns) do
    features = [
      %{
        icon: "◉",
        title: "Process isolation",
        desc: "Each Agent runs in its own lightweight process with isolated memory, so a failure is bounded by your supervision topology.",
        tone: :green
      },
      %{
        icon: "⟳",
        title: "Supervision and recovery",
        desc: "OTP supervisors detect crashes and restart Agents by your restart strategy. Failure handling is part of the runtime, not bolted on.",
        tone: :yellow
      },
      %{
        icon: "⚡",
        title: "Massive concurrency",
        desc: "The BEAM scheduler runs many concurrent agent processes with true parallelism. No thread pools, no async/await gymnastics.",
        tone: :cyan
      }
    ]

    assigns = assign(assigns, :features, features)

    ~H"""
    <section id="why-elixir-otp" class="home-why-otp-section mb-16 opacity-0" phx-hook="ScrollReveal">
      <div class="home-why-otp-header">
        <h2 class="text-2xl font-bold tracking-tight mb-3">Why an agent framework on Elixir?</h2>
        <p class="home-muted-copy text-sm max-w-md mx-auto leading-relaxed">
          The BEAM was designed for long-running, concurrent, fault-tolerant systems — the same qualities agent workloads need. Raw GenServer gives you the process model; Jido adds typed Actions and Signals, Directives for side effects, and a supervised lifecycle so agent behavior stays explicit and testable.
        </p>
      </div>

      <div class="home-why-otp-cards">
        <article :for={feature <- @features} class="home-why-otp-card">
          <div class={"home-why-otp-icon home-why-otp-icon-#{feature.tone}"}>{feature.icon}</div>
          <div>
            <h3 class="home-why-otp-title">{feature.title}</h3>
            <p class="home-why-otp-desc">{feature.desc}</p>
          </div>
        </article>
      </div>

      <div class="home-why-otp-links">
        <.link
          navigate="/docs/getting-started/new-to-elixir"
          class="home-why-otp-link-primary"
        >
          New to Elixir? Here's why it's worth learning. →
        </.link>
        <.link
          navigate="/features/beam-for-ai-builders"
          class="home-why-otp-link-secondary"
        >
          Coming from Python or TypeScript? →
        </.link>
        <.link
          navigate="/docs/getting-started/elixir-developers"
          class="home-why-otp-link-secondary"
        >
          Already an Elixir developer? →
        </.link>
      </div>
    </section>
    """
  end

  @quick_start_define_html ~S"""
  <span class="syntax-keyword">defmodule</span> <span class="syntax-type">MyApp.Counter</span> <span class="syntax-keyword">do</span>
    <span class="syntax-keyword">use</span> <span class="syntax-type">Jido.Agent</span>,
      name: <span class="syntax-string">"counter"</span>,
      schema: &lbrack;count: &lbrack;type: :integer, default: 0&rbrack;&rbrack;
  <span class="syntax-keyword">end</span>

  <span class="syntax-keyword">defmodule</span> <span class="syntax-type">MyApp.Increment</span> <span class="syntax-keyword">do</span>
    <span class="syntax-keyword">use</span> <span class="syntax-type">Jido.Action</span>, name: <span class="syntax-string">"increment"</span>
    <span class="syntax-keyword">def</span> run(%{by: by}, %{state: %{count: count}}), <span class="syntax-keyword">do</span>: {:ok, %{count: count + by}}
  <span class="syntax-keyword">end</span>
  """

  @quick_start_terminal_lines [
    %{type: :comment, text: "# Agents are data — no runtime or API key required"},
    %{type: :input, text: "agent = MyApp.Counter.new()"},
    %{type: :spacer, text: nil},
    %{type: :comment, text: "# Run a validated, deterministic action"},
    %{type: :input, text: "{agent, _} = MyApp.Counter.cmd(agent, {MyApp.Increment, %{by: 3}})"},
    %{type: :output, text: "agent.state  #=> %{count: 3}"}
  ]

  defp quick_start_code(assigns) do
    assigns =
      assigns
      |> assign(:define_code_html, Phoenix.HTML.raw(String.trim(@quick_start_define_html)))
      |> assign(:terminal_lines, @quick_start_terminal_lines)

    ~H"""
    <section id="quick-start" class="home-quickstart-section mb-16 opacity-0" phx-hook="ScrollReveal">
      <div class="home-quickstart-header">
        <div>
          <h2 class="text-2xl font-bold tracking-tight mb-2">Quick start</h2>
          <p class="home-quickstart-summary">
            Define an agent, run a validated action, inspect deterministic state. No API key required.
          </p>
          <p class="home-muted-copy text-[11px] mt-1">
            Open source. Core packages are Beta. No separate runtime service is required.
          </p>
        </div>
        <.link navigate="/docs/getting-started" class="home-quickstart-guide-link">
          full getting started guide →
        </.link>
      </div>

      <div class="code-block overflow-hidden home-quickstart-shell">
        <div class="code-header">
          <span class="home-muted-copy text-xs">lib/my_app/support_agent.ex</span>
          <.link navigate="/docs/getting-started" class="home-quickstart-header-link">
            View full example →
          </.link>
        </div>
        <div class="home-quickstart-pane">
          <pre class="home-quickstart-code"><code><%= @define_code_html %></code></pre>
        </div>

        <div class="code-header mt-1">
          <span class="home-muted-copy text-xs">iex -S mix</span>
          <div class="flex items-center gap-3">
            <.link navigate="/training/agent-fundamentals" class="home-quickstart-header-link">
              TRAINING
            </.link>
            <.link navigate="/docs" class="home-subtle-link text-[10px]">
              DOCS
            </.link>
          </div>
        </div>
        <div class="home-quickstart-terminal">
          <div class="home-quickstart-terminal-content">
            <%= for line <- @terminal_lines do %>
              <%= case line.type do %>
                <% :spacer -> %>
                  <div class="home-quickstart-spacer" aria-hidden="true"></div>
                <% :comment -> %>
                  <div class="syntax-comment">{line.text}</div>
                <% :output -> %>
                  <div class="home-quickstart-output">{line.text}</div>
                <% :input -> %>
                  <div>
                    <span class="home-quickstart-prompt">iex&gt; </span>
                    <span class="home-quickstart-input">{line.text}</span>
                  </div>
              <% end %>
            <% end %>
          </div>
        </div>
      </div>
    </section>
    """
  end
end
