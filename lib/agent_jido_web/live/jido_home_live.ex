defmodule AgentJidoWeb.JidoHomeLive do
  use AgentJidoWeb, :live_view

  import AgentJidoWeb.Jido.HomeSections
  import AgentJidoWeb.Jido.MarketingLayouts

  alias AgentJido.Examples.UseCases

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
        <.start_with_one_agent_section />
        <.what_you_can_build_section />
        <.quick_start_code />
        <.agent_model_section />
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

  defp start_with_one_agent_section(assigns) do
    ~H"""
    <section id="start-with-one-agent" class="text-center mb-16 animate-fade-in">
      <div class="max-w-2xl mx-auto rounded-xl border border-primary/20 bg-primary/5 px-6 py-7">
        <span class="home-eyebrow-label text-[11px] font-semibold tracking-widest uppercase">
          Lowest-risk way to start
        </span>
        <h2 class="text-2xl sm:text-3xl font-bold tracking-tight mt-3 mb-3">
          Start with one Agent
        </h2>
        <p class="home-muted-copy text-[15px] leading-relaxed max-w-xl mx-auto mb-5">
          Add a single supervised agent to the Elixir app you already run. No rewrite, no platform migration, and no separate service to deploy. Reach for AI, coordination, and more packages only when you need them.
        </p>
        <.link
          navigate="/features/start-small"
          class="text-primary hover:underline text-[13px] font-semibold"
        >
          How to start with one agent →
        </.link>
      </div>
    </section>
    """
  end

  defp what_you_can_build_section(assigns) do
    # Each use-case card routes to its own scoped examples destination
    # (/examples?use_case=<slug>) instead of all collapsing onto the unfiltered
    # /examples index (jido-e04-t21). The status label on each card is derived
    # from the same example match, so a visitor can tell a runnable example from
    # a planned pattern (jido-e04-t22). Labels flip automatically when the
    # matching public example lands (jido-e08-t24…t29).
    descriptions = %{
      "coding" => "Agents that read, analyze, and refactor code across repositories.",
      "research" => "Multi-step research agents that find sources, verify facts, and produce reports.",
      "documents" => "Extract, classify, and route documents: invoices, contracts, support tickets.",
      "support" => "Agents that resolve issues using your knowledge base and escalate when needed.",
      "devops" => "Agents that watch systems, diagnose problems, and run remediation playbooks.",
      "data-pipelines" => "Agents that collect, transform, and load data from multiple sources on schedule."
    }

    cards =
      Enum.map(UseCases.all(), fn %{slug: slug, label: label} ->
        available = UseCases.available?(slug)
        status = if(available, do: :runnable, else: :planned)
        badge = use_case_status(status)

        %{
          slug: slug,
          title: label,
          desc: Map.fetch!(descriptions, slug),
          link: "/examples?use_case=#{slug}",
          status: status,
          status_label: badge.label,
          status_class: badge.class
        }
      end)

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
          <.link
            navigate={card.link}
            class="home-pillar-card group"
            data-use-case={card.slug}
            data-status={card.status}
          >
            <span class={card.status_class}>{card.status_label}</span>
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

  # The status badge shown on each use-case card (jido-e04-t22). Runnable cards
  # point at a real example; planned cards mark a use case with no public
  # example yet. The copy maps 1:1 to the acceptance condition.
  defp use_case_status(:runnable) do
    %{label: "Runnable example", class: "home-use-case-status home-use-case-status-runnable"}
  end

  defp use_case_status(:planned) do
    %{label: "Planned pattern", class: "home-use-case-status home-use-case-status-planned"}
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

  # Three recommended starting stacks replace the flat package list (jido-e04-t24).
  # The first view reads as three named, explained stacks — Core, AI, Operate —
  # instead of nine unexplained package names. Each stack carries a one-line
  # purpose so a visitor knows what the stack is for and when to reach for it;
  # the Core stack is marked as the recommended place to begin.
  #
  # Each package carries its own one-line role so a visitor knows why it is in
  # the stack (jido-e04-t25). Roles are condensed from the authoritative package
  # taglines in priv/ecosystem/*.md — they explain the package's job, not the
  # stack's. Support-level badges (jido-e04-t26) and deeper stack detail such as
  # dependency blocks and examples (epic jido-e09) remain separate tasks.
  defp ecosystem_section(assigns) do
    stacks = [
      %{
        key: "core",
        name: "Core",
        tone: "core",
        start: true,
        purpose: "The runtime every Jido system runs on — agents, typed Actions, and Signals.",
        packages: [
          %{name: "jido", role: "Agent state, the supervised AgentServer, and Directives."},
          %{name: "jido_action", role: "Typed, validated commands and tools an agent runs."},
          %{name: "jido_signal", role: "CloudEvents messages agents send, route, and replay."}
        ]
      },
      %{
        key: "ai",
        name: "AI",
        tone: "ai",
        purpose: "Add LLM-backed agents, provider choice, and model metadata when you need AI.",
        packages: [
          %{name: "jido_ai", role: "Reasoning strategies, tool use, and accuracy over LLM calls."},
          %{name: "req_llm", role: "Model requests across Anthropic, OpenAI, Google, and more."},
          %{name: "llm_db", role: "Offline model metadata and capability catalog."}
        ]
      },
      %{
        key: "operate",
        name: "Operate",
        tone: "operate",
        purpose: "Ship to production — observability, messaging, and framework integration.",
        packages: [
          %{name: "ash_jido", role: "Turns Ash resources into typed Jido Actions."},
          %{name: "jido_messaging", role: "Chat channels (Slack, Discord, Telegram) for agents."},
          %{name: "jido_otel", role: "Exports Jido telemetry as OpenTelemetry spans."}
        ]
      }
    ]

    assigns = assign(assigns, :stacks, stacks)

    ~H"""
    <section id="ecosystem" class="home-ecosystem-section mb-16 opacity-0" phx-hook="ScrollReveal">
      <div id="home-ecosystem-section">
        <div class="home-ecosystem-header">
          <div>
            <h2 class="text-2xl font-bold tracking-tight">One framework, three starting stacks</h2>
            <p class="home-ecosystem-summary">
              Begin with the Core stack every Jido system runs on. Add AI and Operate packages only when you need them.
            </p>
          </div>

          <.link navigate="/ecosystem" class="home-ecosystem-explore-link">
            Explore the full ecosystem →
          </.link>
        </div>

        <div class="home-ecosystem-rows">
          <article
            :for={stack <- @stacks}
            class={"home-ecosystem-row home-ecosystem-stack home-ecosystem-stack-#{stack.tone}"}
            data-stack={stack.key}
          >
            <div class="home-ecosystem-row-header">
              <h3 class="home-ecosystem-row-title">{stack.name}</h3>
              <span :if={stack[:start]} class="home-ecosystem-start-badge">Start here</span>
            </div>

            <p class="home-ecosystem-stack-purpose">{stack.purpose}</p>

            <ul class="home-ecosystem-packages">
              <li :for={pkg <- stack.packages} class="home-ecosystem-package-role" data-package={pkg.name}>
                <span class="home-ecosystem-stack-package">{pkg.name}</span>
                <span class="home-ecosystem-stack-package-role">{pkg.role}</span>
              </li>
            </ul>
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

  # The four-part Agent model: state, lifecycle, typed boundaries, visible effects.
  # Each part maps to one named Jido concept (Agent, AgentServer, Action/Signal,
  # Directive) so a visitor can see exactly how the framework is built.
  defp agent_model_section(assigns) do
    parts = [
      %{
        icon: "◇",
        part: "State",
        concept: "Agent",
        desc:
          "An Agent is immutable data. It carries a validated state struct and changes only through commands, so every state transition is explicit and unit-testable.",
        accent: :cyan
      },
      %{
        icon: "⟳",
        part: "Lifecycle",
        concept: "AgentServer",
        desc:
          "An AgentServer is the supervised process that runs an Agent. OTP owns start, stop, and restart, so a crash is bounded by your supervision strategy.",
        accent: :green
      },
      %{
        icon: "⧉",
        part: "Typed boundaries",
        concept: "Action / Signal",
        desc:
          "Actions are typed functions that transform state and do work; Signals are typed messages. Agents coordinate through these contracts, not prompt chains.",
        accent: :yellow
      },
      %{
        icon: "▣",
        part: "Visible effects",
        concept: "Directive",
        desc:
          "Side effects the runtime should own — emitting signals, scheduling work, spawning processes — return as Directives, never hidden inside agent state.",
        accent: :red
      }
    ]

    assigns = assign(assigns, :parts, parts)

    ~H"""
    <section id="agent-model" class="home-pillars-section mb-20 opacity-0" phx-hook="ScrollReveal">
      <div class="text-center mb-16">
        <h2 class="text-3xl font-bold tracking-tight mb-4">How an agent is built</h2>
        <p class="home-muted-copy text-sm leading-relaxed max-w-lg mx-auto">
          Every Jido system is four pieces. Each one has one job and one name — no hidden state, no implicit processes.
        </p>
      </div>

      <div class="home-pillars-grid">
        <article
          :for={part <- @parts}
          class="home-pillar-card"
          data-agent-model-part={part.part}
          data-maps-to={part.concept}
        >
          <div class={"home-pillar-chip home-pillar-chip-#{part.accent}"}>
            <span class={"text-2xl leading-none text-accent-#{part.accent}"}>{part.icon}</span>
          </div>
          <span class={"home-agent-model-badge home-agent-model-badge-#{part.accent}"}>
            maps to {part.concept}
          </span>
          <h3 class="text-lg sm:text-xl font-bold mt-1 mb-3 leading-tight">{part.part}</h3>
          <p class="home-muted-copy text-[15px] leading-relaxed max-w-md mx-auto">{part.desc}</p>
        </article>
      </div>

      <div class="text-center mt-12">
        <.link navigate="/docs/getting-started" class="text-primary hover:underline text-[13px] font-semibold">
          Learn the model in the getting started guide →
        </.link>
      </div>
    </section>
    """
  end
end
