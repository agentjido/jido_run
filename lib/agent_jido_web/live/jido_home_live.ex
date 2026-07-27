defmodule AgentJidoWeb.JidoHomeLive do
  use AgentJidoWeb, :live_view

  import AgentJidoWeb.Jido.HomeSections
  import AgentJidoWeb.Jido.MarketingLayouts

  alias AgentJido.Ecosystem
  alias AgentJido.Ecosystem.Stacks, as: EcosystemStacks
  alias AgentJido.Ecosystem.SupportLevel
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
        <.operational_control_section />
        <.pillars_section />
        <.why_elixir_otp_section />
        <.why_not_genserver_section />
        <.ecosystem_section />
        <.do_i_need_ai_section />
        <.is_jido_a_separate_service_section />
        <.build_first_agent_cta />
      </div>
    </.marketing_layout>
    """
  end

  defp hero_section(assigns) do
    ~H"""
    <section id="home-hero" class="text-center mb-16 animate-fade-in">
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
          id="home-hero-cta"
          navigate="/docs/getting-started"
          data-analytics-event="cta_clicked"
          data-analytics-source="home"
          data-analytics-channel="home_hero"
          data-analytics-section-id="hero"
          data-analytics-target-url="/docs/getting-started"
          data-analytics-card-type="hero_cta"
          class="bg-primary text-primary-foreground hover:bg-primary/90 text-[13px] font-bold px-7 py-5 rounded transition-colors"
        >
          BUILD YOUR FIRST AGENT →
        </.link>
        <.link
          id="home-failure-drill-cta"
          navigate="/examples/failure-drill-agent"
          data-analytics-event="card_clicked"
          data-analytics-source="home"
          data-analytics-channel="home_failure_drill"
          data-analytics-section-id="failure-drill"
          data-analytics-target-url="/examples/failure-drill-agent"
          data-analytics-card-type="failure_drill"
          class="home-subtle-link text-[13px] font-semibold transition-colors"
        >
          RUN A FAILURE DRILL →
        </.link>
      </div>

      <%!-- Primary audience first (jido-e04-t07): Elixir engineers get a fast-lane
           to the expert guide. Non-Elixir evaluation collapses to a single
           secondary link below (jido-e04-t08) — an expansion route, not a co-equal
           peer persona — so the first viewport no longer splits attention across
           three personas. The "New to Elixir?" peer persona that used to sit
           beside this link has left the first viewport; it remains reachable lower
           on the page in the "Why an agent framework on Elixir?" section. --%>
      <p class="home-muted-copy text-[11px] leading-relaxed max-w-xl mx-auto -mt-6">
        Already an Elixir developer?
        <.link
          id="home-elixir-expert-guide-link"
          navigate="/docs/getting-started/elixir-developers"
          class="text-primary hover:underline font-semibold ml-1"
        >
          Jump to the expert guide.
        </.link>
      </p>

      <p class="home-muted-copy text-[11px] leading-relaxed max-w-xl mx-auto mt-3">
        <.link
          id="home-non-elixir-evaluation-link"
          navigate="/features/beam-for-ai-builders"
          class="text-primary hover:underline font-semibold"
          data-hero-audience="non-elixir-evaluation"
        >
          Coming from Python or TypeScript? →
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
          data-analytics-event="cta_clicked"
          data-analytics-source="home"
          data-analytics-channel="home_adoption"
          data-analytics-section-id="start-with-one-agent"
          data-analytics-target-url="/features/start-small"
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
    #
    # When a use case has named one best entry point (jido-e08-t25), the card
    # also surfaces a direct link to that single example beneath the scoped
    # destination, so a visitor who wants the one best starting example can jump
    # straight to it instead of picking it out of the scoped list. The scoped
    # destination stays the card's primary link, so the E04-T21 invariant —
    # every card links to its own scoped destination — still holds.
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
          status_class: badge.class,
          entry_point: UseCases.entry_point(slug)
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
          <div class="home-use-case-card" data-use-case-card={card.slug}>
            <.link
              navigate={card.link}
              class="home-pillar-card group"
              data-use-case={card.slug}
              data-status={card.status}
              data-analytics-event="card_clicked"
              data-analytics-source="home"
              data-analytics-channel="home_use_case"
              data-analytics-section-id={card.slug}
              data-analytics-target-url={card.link}
              data-analytics-card-type="use_case_card"
            >
              <span class={card.status_class}>{card.status_label}</span>
              <h3 class="text-lg sm:text-xl font-bold mb-3 leading-tight group-hover:text-primary transition-colors duration-200">
                {card.title}
              </h3>
              <p class="home-muted-copy text-[15px] leading-relaxed max-w-md mx-auto">
                {card.desc}
              </p>
            </.link>
            <.link
              :if={card.entry_point}
              navigate={card.entry_point.href}
              class="home-use-case-entry-point"
              data-use-case-entry-point={card.slug}
              data-entry-point={card.entry_point.slug}
            >
              Start with {card.entry_point.title} →
            </.link>
          </div>
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
  # stack's.
  #
  # Each package also shows its public support level — Stable, Beta, or
  # Experimental — resolved from the authoritative ecosystem registry at render
  # time (jido-e04-t26), so the home badge tracks package maturity instead of a
  # hardcoded copy that can drift. Each stack also carries a copyable, installable
  # mix.exs dependency block (jido-e09-t08); deeper stack detail such as runnable
  # examples remains a separate task.
  #
  # Each stack also carries a "Do not use this when" negative-fit note
  # (jido-e09-t10) so a builder can tell when a stack is the wrong pick, not just
  # when it is the right one. The note is the other half of selection guidance —
  # the purpose says when to reach for the stack; the negative fit says when not
  # to. Each note names a real reason that stack is the wrong choice for that
  # situation, so the three notes are distinct and not the same caveat repeated.
  #
  # Each stack also carries a production-next-step link (jido-e09-t11) — the last
  # selection step. The purpose, negative fit, and dependency block let a builder
  # choose and install a stack; this link moves them from "installed" into the
  # Operate guidance that stack needs in production. Each stack routes to the
  # operations page that covers its own production concern (Core -> bounding
  # failure with supervision, AI -> rate and cost budgets, Operate -> telemetry
  # and traces), so the three destinations are distinct rather than one shared
  # link to the operations hub.
  #
  # Stack composition (key, name, purpose, packages, roles) and the explicit
  # supported package ranges live in `AgentJido.Ecosystem.Stacks` (jido-e09-t36),
  # the single source of truth shared with the Ecosystem compatibility matrix.
  # The home-specific overlays here — visual tone, the "start here" badge, the
  # negative-fit note, and the production-next-step link — are presentation, not
  # composition, so they stay local and are merged onto the shared definition.
  @home_stack_overlays %{
    "core" => %{
      tone: "core",
      start: true,
      do_not_use_when:
        "you expect built-in LLM calls or production tooling. Core is the supervised runtime — add the AI stack for model reasoning or the Operate stack for observability and integrations.",
      next_step: %{
        label: "Bound failure in production",
        href: "/docs/operations/supervision-and-failure-boundaries"
      }
    },
    "ai" => %{
      tone: "ai",
      do_not_use_when:
        "no agent in your system calls an LLM. The AI stack adds model providers, reasoning, and tool use — and the cost of an LLM dependency — so add it only when an agent actually reasons over a model.",
      next_step: %{
        label: "Set rate and cost budgets",
        href: "/docs/operations/rate-limits-and-cost-budgets"
      }
    },
    "operate" => %{
      tone: "operate",
      do_not_use_when:
        "you are not yet shipping to production. Operate adds observability, messaging, and Ash integration; pulling it in before there is an agent to operate only adds dependencies you do not yet need.",
      next_step: %{
        label: "Wire telemetry and traces",
        href: "/docs/operations/telemetry-and-traces"
      }
    }
  }

  defp ecosystem_section(assigns) do
    stacks =
      EcosystemStacks.stacks()
      |> Enum.map(fn stack ->
        overlay = Map.fetch!(@home_stack_overlays, stack.key)
        packages = Enum.map(stack.packages, &with_support_level/1)

        Map.merge(stack, %{
          tone: overlay.tone,
          start: overlay[:start],
          do_not_use_when: overlay.do_not_use_when,
          next_step: overlay[:next_step],
          packages: packages,
          dependency_block: EcosystemStacks.dependency_block(stack.packages)
        })
      end)

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

            <p class="home-ecosystem-stack-negative-fit" data-stack-negative-fit={stack.key}>
              <span class="home-ecosystem-stack-negative-fit-label">Do not use this when</span>
              <span class="home-ecosystem-stack-negative-fit-text">{stack.do_not_use_when}</span>
            </p>

            <ul class="home-ecosystem-packages">
              <li
                :for={pkg <- stack.packages}
                class="home-ecosystem-package-role"
                data-package={pkg.name}
                data-support-level={pkg.support_level}
              >
                <span class="home-ecosystem-stack-package">{pkg.name}</span>
                <span class="home-ecosystem-stack-package-role">{pkg.role}</span>
                <span class={
                    "home-ecosystem-support-level home-ecosystem-support-level-#{pkg.support_level}"
                  }>
                  {pkg.support_level_label}
                </span>
              </li>
            </ul>

            <div :if={stack.dependency_block} class="home-ecosystem-stack-deps">
              <div class="code-block overflow-hidden">
                <div class="code-header">
                  <span class="home-muted-copy text-[10px]">{stack.name} stack · mix.exs</span>
                  <button
                    type="button"
                    data-copy-button
                    data-content={stack.dependency_block}
                    data-copy-success-label="Copied"
                    data-analytics-source="home"
                    data-analytics-channel="copy_stack_deps"
                    class="home-ecosystem-deps-copy"
                  >
                    Copy
                  </button>
                </div>
                <pre class="home-ecosystem-stack-deps-code">{stack.dependency_block}</pre>
              </div>
            </div>

            <.link
              :if={stack[:next_step]}
              navigate={stack.next_step.href}
              class="home-ecosystem-stack-next-step"
              data-stack-next-step={stack.key}
              data-analytics-event="card_clicked"
              data-analytics-source="home"
              data-analytics-channel="home_package_stack"
              data-analytics-section-id={stack.key}
              data-analytics-target-url={stack.next_step.href}
              data-analytics-card-type="package_stack"
            >
              {stack.next_step.label} →
            </.link>
          </article>
        </div>
      </div>
    </section>
    """
  end

  # Attaches a package's public support level so each home package carries a
  # Stable, Beta, or Experimental badge (jido-e04-t26). The level is resolved
  # from the authoritative ecosystem registry at render time — the same
  # derive-from-source-of-truth approach the use-case status labels use
  # (jido-e04-t22) — so the badge tracks package maturity instead of a hardcoded
  # copy that drifts. A package with no recorded level falls back to
  # :experimental, the most conservative public claim, so the badge is always
  # visible.
  defp with_support_level(%{name: name} = pkg) do
    level = package_support_level(name)

    Map.merge(pkg, %{
      support_level: level,
      support_level_label: SupportLevel.label(level)
    })
  end

  defp package_support_level(name) do
    case Ecosystem.get_public_package(name) do
      %{support_level: level} when level in [:stable, :beta, :experimental] -> level
      _other -> :experimental
    end
  end

  # Each recommended stack ships a copyable mix.exs dependency block
  # (jido-e09-t08) so a builder can paste the stack into a project and
  # `mix deps.get` resolves. The block — and the explicit supported package
  # range each line encodes — is derived from the authoritative ecosystem
  # registry by `AgentJido.Ecosystem.Stacks` (jido-e09-t36), the single shared
  # source for both the home dependency blocks and the Ecosystem compatibility
  # matrix, so neither drifts into a hardcoded copy.
  #
  # A package published to Hex pins to its published MAJOR (`~> X.0`) rather
  # than an exact version. The registry records each package's version
  # independently, so exact per-package pins can be mutually incompatible
  # (e.g. an older req_llm expects a different llm_db than llm_db's recorded
  # version). A major pin lets the resolver pick a compatible within-major set,
  # which is what makes the block actually install — the task's acceptance bar.
  # A package not yet on Hex falls back to its public GitHub repo, which also
  # resolves on `mix deps.get`.

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

  # "Why not just a GenServer?" objection block (jido-e04-t28). The most common
  # objection from experienced Elixir developers lands directly after the "Why
  # an agent framework on Elixir?" section, where that audience already gathers
  # and where GenServer is already named. The block states the objection
  # honestly — a plain GenServer is the right tool for many single-purpose
  # processes — and names the design pressure where Jido earns its place (a
  # callback that mixes validation, persistence, and side effects), then routes
  # the visitor to the existing reference Livebook for the full side-by-side
  # comparison and the honest "when GenServer is enough" call. The acceptance
  # condition is the route: it must reach that reference page.
  defp why_not_genserver_section(assigns) do
    ~H"""
    <section id="why-not-a-genserver" class="text-center mb-16 animate-fade-in">
      <div
        id="home-why-not-genserver-objection"
        class="max-w-2xl mx-auto rounded-xl border border-primary/20 bg-primary/5 px-6 py-7"
        data-objection="why-not-a-genserver"
      >
        <span class="home-eyebrow-label text-[11px] font-semibold tracking-widest uppercase">
          Common question
        </span>
        <h2 class="text-2xl sm:text-3xl font-bold tracking-tight mt-3 mb-3">
          Why not just a GenServer?
        </h2>
        <p class="home-muted-copy text-[15px] leading-relaxed max-w-xl mx-auto mb-5">
          For many single-purpose processes, a plain GenServer is the right tool. Jido earns its place when a callback starts mixing validation, persistence, and side effects: it separates what an agent decides — pure Actions, typed Signals, and Directives — from how the runtime executes it under OTP supervision, so each piece stays testable and composable.
        </p>
        <.link
          navigate="/docs/reference/why-not-just-a-genserver"
          class="text-primary hover:underline text-[13px] font-semibold"
          data-objection-link="why-not-a-genserver-reference"
        >
          Read the full comparison →
        </.link>
      </div>
    </section>
    """
  end

  # "Do I need AI?" objection block (jido-e04-t29). A visitor who hears "agent
  # framework" often assumes an LLM is required and that they need a model
  # provider and API key before they can start. The block lands directly after
  # the ecosystem section, which is where the Core and AI stacks are introduced
  # side by side, so the objection reads as the natural follow-up to "there are
  # two stacks." The acceptance condition is the answer plus the two routes: the
  # answer is "No" — the Core runtime is supervised agents with typed Actions
  # and Signals, no model, no API key — and the visitor is routed to the core
  # path (start with one agent, no AI) and to the AI path (any model, any
  # provider) for the agents that do reason over a model. Reach for the AI stack
  # only then; keep it out of every agent that does not.
  defp do_i_need_ai_section(assigns) do
    ~H"""
    <section id="do-i-need-ai" class="text-center mb-16 animate-fade-in">
      <div
        id="home-do-i-need-ai-objection"
        class="max-w-2xl mx-auto rounded-xl border border-primary/20 bg-primary/5 px-6 py-7"
        data-objection="do-i-need-ai"
      >
        <span class="home-eyebrow-label text-[11px] font-semibold tracking-widest uppercase">
          Common question
        </span>
        <h2 class="text-2xl sm:text-3xl font-bold tracking-tight mt-3 mb-3">
          Do I need AI?
        </h2>
        <p class="home-muted-copy text-[15px] leading-relaxed max-w-xl mx-auto mb-5">
          No. Jido's Core runtime is supervised agents with typed Actions and Signals — no model, no API key, no LLM dependency. The quick start runs a counter without ever calling a model. Reach for the AI stack only when an agent needs to reason over a model, and keep it out of every agent that does not.
        </p>
        <div class="flex flex-wrap items-center justify-center gap-x-4 gap-y-2">
          <.link
            navigate="/features/start-small"
            class="text-primary hover:underline text-[13px] font-semibold"
            data-objection-link="do-i-need-ai-core"
          >
            Start without AI →
          </.link>
          <span class="home-muted-copy">·</span>
          <.link
            navigate="/features/llm-support"
            class="text-primary hover:underline text-[13px] font-semibold"
            data-objection-link="do-i-need-ai-ai"
          >
            When you do want AI →
          </.link>
        </div>
      </div>
    </section>
    """
  end

  # "Is Jido a separate service?" objection block (jido-e04-t30). A visitor
  # evaluating adoption often assumes an "agent framework" means another process
  # to deploy and operate alongside their app. The block lands after the other
  # home objection blocks, forming a small FAQ cluster before the closing
  # build-CTA. The acceptance condition is the answer: it must explain the
  # library model (Jido is a dependency you add to the Elixir app you already
  # run, not a separate service, sidecar, or platform) and the supervision-tree
  # model (your agents start as children of your existing supervision tree —
  # same release, same node, same restart rules — so there is no separate
  # process to deploy or keep in sync). The route proves both: /features/start-small
  # shows adding one agent directly to application.ex's supervisor.
  defp is_jido_a_separate_service_section(assigns) do
    ~H"""
    <section id="is-jido-a-separate-service" class="text-center mb-16 animate-fade-in">
      <div
        id="home-is-jido-a-separate-service-objection"
        class="max-w-2xl mx-auto rounded-xl border border-primary/20 bg-primary/5 px-6 py-7"
        data-objection="is-jido-a-separate-service"
      >
        <span class="home-eyebrow-label text-[11px] font-semibold tracking-widest uppercase">
          Common question
        </span>
        <h2 class="text-2xl sm:text-3xl font-bold tracking-tight mt-3 mb-3">
          Is Jido a separate service?
        </h2>
        <p class="home-muted-copy text-[15px] leading-relaxed max-w-xl mx-auto mb-5">
          No. Jido is a library, not a service. You add it as a dependency to the Elixir application you already run, and your agents start as children of your existing supervision tree — same release, same node, same restart rules. There is no separate process to deploy, operate, or keep in sync. Add one agent under your supervisor and it lives alongside your repo, endpoint, and queues.
        </p>
        <.link
          navigate="/features/start-small"
          class="text-primary hover:underline text-[13px] font-semibold"
          data-objection-link="is-jido-a-separate-service-start-small"
        >
          See it in your supervision tree →
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
        <.link
          navigate="/docs/getting-started"
          class="home-quickstart-guide-link"
          data-analytics-event="cta_clicked"
          data-analytics-source="home"
          data-analytics-channel="home_quickstart"
          data-analytics-section-id="quick-start"
          data-analytics-target-url="/docs/getting-started"
        >
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
        <.link
          navigate="/docs/getting-started"
          class="text-primary hover:underline text-[13px] font-semibold"
          data-analytics-event="cta_clicked"
          data-analytics-source="home"
          data-analytics-channel="home_agent_model"
          data-analytics-section-id="agent-model"
          data-analytics-target-url="/docs/getting-started"
        >
          Learn the model in the getting started guide →
        </.link>
      </div>
    </section>
    """
  end

  # Operational control section (jido-e04-t34). Sits directly after the Agent
  # model so a visitor sees how to *control* agent work immediately after
  # learning how an agent is built. The four blocks answer the acceptance
  # condition in order — who initiated work, what was allowed, what happened,
  # and how failure was handled — each tied to a named Jido control surface
  # (incoming Signal context, fail-closed authorization, causal Journal +
  # telemetry, OTP supervision) rather than a promise.
  #
  # Below the four blocks, a proof-card layer routes each control to the place
  # a visitor can see it. The first proof card, "Supervise the lifecycle"
  # (jido-e04-t35), links the failure-handling block to AgentServer supervision
  # (/features/agents-that-self-heal) and a runnable failure-boundary proof
  # (/examples/failure-drill-agent). The second, "Constrain capabilities"
  # (jido-e04-t36), links the what-was-allowed block to the five capability
  # surfaces a visitor can pin down — typed Actions (/docs/concepts/actions),
  # effects via Directives (/docs/concepts/directives), and tool allowlists,
  # policy hooks, and quotas on the governance page that bounds them
  # (/docs/operations/security-and-governance). The third, "Trace what
  # happened" (jido-e04-t37), links the what-happened block to the three
  # records that reconstruct work — causal Signals (/docs/concepts/signals),
  # the durable Journal you configure for causal history
  # (/docs/concepts/persistence), and correlated telemetry that joins the
  # trace (/docs/reference/telemetry-and-observability). The fourth, "Integrate
  # your control system" (jido-e04-t38), names the boundaries Jido defers to
  # your stack and routes each to where it is owned — the IAM/identity boundary
  # in front of Jido (/docs/operations/security-and-governance), Ash actor and
  # tenant context (/ecosystem/ash_jido), durable Journal storage
  # (/docs/concepts/persistence), the SIEM audit-export boundary
  # (/docs/operations/security-and-governance), and OTel export
  # (/docs/reference/telemetry-and-observability). A "Telemetry is not an audit
  # log" caveat note (jido-e04-t39) caps the proof-card layer so an evaluator
  # cannot read the traceability story as compliance: it states that correlated
  # telemetry is operational signal, not tamper-evident evidence, and that a
  # durable audit history is the Signal Journal you deliberately configure —
  # with retention, access control, and tamper evidence as application concerns
  # — and routes each concept to its authoritative page. An "Agent IDs are not
  # authenticated principals" caveat note (jido-e04-t40) then bounds the
  # identity claim the "who initiated work" card raises: Agent IDs (and Signal
  # and trace IDs) are correlation metadata — handles for following work, not a
  # verified identity — because authentication and IAM are an
  # application/platform boundary in front of Jido, and it routes to the
  # governance page that states it. A capstone "one integrated controlled
  # agent" card (jido-e04-t41) then routes the whole section to a single
  # runnable example (/examples/controlled-agent) that proves the complete
  # control path — who initiated work, what was allowed, what happened, and
  # how failure was handled — in one supervised run, instead of leaving the
  # four controls as separate doc destinations. A control-focused CTA for
  # platform and SRE evaluators (jido-e04-t42) then closes the section:
  # addressed to the control-evaluation audience, it routes them to the
  # Operations hub (/docs/operations) — the page that opens the long-running
  # agent architecture and the worked examples that prove each control surface —
  # with the governance page carried as a secondary link for the security
  # evaluator. A short production-path index (jido-e07-t34) is folded into that
  # CTA so the site's main position links the full proof path: the ordered
  # long-running agent path (each step an Operations page) ending on the
  # controlled-Agent run that proves the complete path in one go.
  defp operational_control_section(assigns) do
    controls = [
      %{
        icon: "◍",
        question: "Who initiated work",
        slug: "who-initiated",
        accent: :cyan,
        answer:
          "Every incoming Signal carries the context that started it — principal, tenant, request, and causation. prepare_signal/2 verifies and enriches that context before an Action runs, so each piece of work is attributable to the caller, not to the agent."
      },
      %{
        icon: "▦",
        question: "What was allowed",
        slug: "what-was-allowed",
        accent: :yellow,
        answer:
          "Typed Actions name exactly what an agent can do. prepare_action/3 is fail-closed: an Action runs only when an allowlist and policy permit it. Quotas cap tokens, requests, and tool calls, so runaway work stops at a budget."
      },
      %{
        icon: "↳",
        question: "What happened",
        slug: "what-happened",
        accent: :green,
        answer:
          "A durable Signal Journal, when you configure one, keeps causal history — every Signal that entered and the Actions and Directives it triggered. Correlated telemetry joins the trace, so you can reconstruct what ran and why."
      },
      %{
        icon: "↺",
        question: "How failure was handled",
        slug: "how-failure-was-handled",
        accent: :red,
        answer:
          "Each AgentServer runs under OTP supervision with an explicit restart strategy. Retryable and terminal errors take different paths, poison work lands in a dead letter, and the supervisor restarts a crashed process by your rules — never silently."
      }
    ]

    assigns = assign(assigns, :controls, controls)

    ~H"""
    <section
      id="operational-control"
      class="home-pillars-section mb-20 opacity-0"
      phx-hook="ScrollReveal"
    >
      <div class="text-center mb-16">
        <h2 class="text-3xl font-bold tracking-tight mb-4">Operational control</h2>
        <p class="home-muted-copy text-sm leading-relaxed max-w-lg mx-auto">
          For each piece of agent work, Jido answers four questions: who started it, what it was allowed to do, what it did, and how failure was contained.
        </p>
      </div>

      <div class="home-pillars-grid">
        <article
          :for={control <- @controls}
          class="home-pillar-card"
          data-control-question={control.slug}
        >
          <div class={"home-pillar-chip home-pillar-chip-#{control.accent}"}>
            <span class={"text-2xl leading-none text-accent-#{control.accent}"}>{control.icon}</span>
          </div>
          <h3 class="text-lg sm:text-xl font-bold mt-2 mb-3 leading-tight">{control.question}</h3>
          <p class="home-muted-copy text-[15px] leading-relaxed max-w-md mx-auto">{control.answer}</p>
        </article>
      </div>

      <div class="mt-16 max-w-2xl mx-auto">
        <p class="home-eyebrow-label text-[11px] font-semibold tracking-widest uppercase text-center mb-4">
          See the control in action
        </p>

        <article
          id="control-supervise-lifecycle"
          class="home-pillar-card px-6 py-6"
          data-control-card="supervise-lifecycle"
        >
          <div class="home-pillar-chip home-pillar-chip-red">
            <span class="text-2xl leading-none text-accent-red">↺</span>
          </div>
          <h3 class="text-lg sm:text-xl font-bold mt-2 mb-3 leading-tight">
            Supervise the lifecycle
          </h3>
          <p class="home-muted-copy text-[15px] leading-relaxed max-w-md mx-auto mb-5">
            Watch supervision contain a real crash. Run the failure drill to see a crashed AgentServer restart as a fresh process, then read how OTP supervision bounds each agent's lifecycle.
          </p>
          <div class="flex flex-col sm:flex-row items-center justify-center gap-3">
            <.link
              navigate="/features/agents-that-self-heal"
              class="home-pillar-link home-pillar-link-red"
              data-control-link="supervision"
              data-analytics-event="control_proof_viewed"
              data-analytics-source="home"
              data-analytics-channel="home_operational_control"
              data-analytics-section-id="supervision"
              data-analytics-target-url="/features/agents-that-self-heal"
            >
              Read how supervision works →
            </.link>
            <span class="home-muted-copy hidden sm:inline">·</span>
            <.link
              navigate="/examples/failure-drill-agent"
              class="home-pillar-link home-pillar-link-red"
              data-control-link="failure-boundary-proof"
              data-analytics-event="control_proof_viewed"
              data-analytics-source="home"
              data-analytics-channel="home_operational_control"
              data-analytics-section-id="failure-boundary-proof"
              data-analytics-target-url="/examples/failure-drill-agent"
            >
              Run the failure drill →
            </.link>
          </div>
        </article>

        <article
          id="control-constrain-capabilities"
          class="home-pillar-card px-6 py-6 mt-6"
          data-control-card="constrain-capabilities"
        >
          <div class="home-pillar-chip home-pillar-chip-yellow">
            <span class="text-2xl leading-none text-accent-yellow">▦</span>
          </div>
          <h3 class="text-lg sm:text-xl font-bold mt-2 mb-3 leading-tight">
            Constrain capabilities
          </h3>
          <p class="home-muted-copy text-[15px] leading-relaxed max-w-md mx-auto mb-5">
            Pin down what an agent may do before it runs. Follow each capability surface to where it is bounded — typed Actions, tool allowlists, policy hooks, effects, and quotas all reject work that exceeds what you explicitly allowed.
          </p>
          <div class="flex flex-wrap items-center justify-center gap-x-4 gap-y-2">
            <.link
              navigate="/docs/concepts/actions"
              class="home-pillar-link home-pillar-link-yellow"
              data-control-link="typed-actions"
              data-analytics-event="control_proof_viewed"
              data-analytics-source="home"
              data-analytics-channel="home_operational_control"
              data-analytics-section-id="typed-actions"
              data-analytics-target-url="/docs/concepts/actions"
            >
              Typed Actions →
            </.link>
            <.link
              navigate="/docs/operations/security-and-governance"
              class="home-pillar-link home-pillar-link-yellow"
              data-control-link="tool-allowlists"
              data-analytics-event="control_proof_viewed"
              data-analytics-source="home"
              data-analytics-channel="home_operational_control"
              data-analytics-section-id="tool-allowlists"
              data-analytics-target-url="/docs/operations/security-and-governance"
            >
              Tool allowlists →
            </.link>
            <.link
              navigate="/docs/operations/security-and-governance"
              class="home-pillar-link home-pillar-link-yellow"
              data-control-link="policy-hooks"
              data-analytics-event="control_proof_viewed"
              data-analytics-source="home"
              data-analytics-channel="home_operational_control"
              data-analytics-section-id="policy-hooks"
              data-analytics-target-url="/docs/operations/security-and-governance"
            >
              Policy hooks →
            </.link>
            <.link
              navigate="/docs/concepts/directives"
              class="home-pillar-link home-pillar-link-yellow"
              data-control-link="effects"
              data-analytics-event="control_proof_viewed"
              data-analytics-source="home"
              data-analytics-channel="home_operational_control"
              data-analytics-section-id="effects"
              data-analytics-target-url="/docs/concepts/directives"
            >
              Effects →
            </.link>
            <.link
              navigate="/docs/operations/security-and-governance"
              class="home-pillar-link home-pillar-link-yellow"
              data-control-link="quotas"
              data-analytics-event="control_proof_viewed"
              data-analytics-source="home"
              data-analytics-channel="home_operational_control"
              data-analytics-section-id="quotas"
              data-analytics-target-url="/docs/operations/security-and-governance"
            >
              Quotas →
            </.link>
          </div>
        </article>

        <article
          id="control-trace-what-happened"
          class="home-pillar-card px-6 py-6 mt-6"
          data-control-card="trace-what-happened"
        >
          <div class="home-pillar-chip home-pillar-chip-green">
            <span class="text-2xl leading-none text-accent-green">↳</span>
          </div>
          <h3 class="text-lg sm:text-xl font-bold mt-2 mb-3 leading-tight">
            Trace what happened
          </h3>
          <p class="home-muted-copy text-[15px] leading-relaxed max-w-md mx-auto mb-5">
            Reconstruct any piece of work after it runs. Follow the causal trail to where it is recorded — every Signal that entered, the durable Journal that keeps the history, and the correlated telemetry that joins the trace — so you can see exactly what ran and why.
          </p>
          <div class="flex flex-wrap items-center justify-center gap-x-4 gap-y-2">
            <.link
              navigate="/docs/concepts/signals"
              class="home-pillar-link home-pillar-link-green"
              data-control-link="causal-signals"
              data-analytics-event="control_proof_viewed"
              data-analytics-source="home"
              data-analytics-channel="home_operational_control"
              data-analytics-section-id="causal-signals"
              data-analytics-target-url="/docs/concepts/signals"
            >
              Causal Signals →
            </.link>
            <.link
              navigate="/docs/concepts/persistence"
              class="home-pillar-link home-pillar-link-green"
              data-control-link="journal-configuration"
              data-analytics-event="control_proof_viewed"
              data-analytics-source="home"
              data-analytics-channel="home_operational_control"
              data-analytics-section-id="journal-configuration"
              data-analytics-target-url="/docs/concepts/persistence"
            >
              Journal configuration →
            </.link>
            <.link
              navigate="/docs/reference/telemetry-and-observability"
              class="home-pillar-link home-pillar-link-green"
              data-control-link="correlated-telemetry"
              data-analytics-event="control_proof_viewed"
              data-analytics-source="home"
              data-analytics-channel="home_operational_control"
              data-analytics-section-id="correlated-telemetry"
              data-analytics-target-url="/docs/reference/telemetry-and-observability"
            >
              Correlated telemetry →
            </.link>
          </div>
        </article>

        <article
          id="control-integrate-your-control-system"
          class="home-pillar-card px-6 py-6 mt-6"
          data-control-card="integrate-your-control-system"
        >
          <div class="home-pillar-chip home-pillar-chip-cyan">
            <span class="text-2xl leading-none text-accent-cyan">⇄</span>
          </div>
          <h3 class="text-lg sm:text-xl font-bold mt-2 mb-3 leading-tight">
            Integrate your control system
          </h3>
          <p class="home-muted-copy text-[15px] leading-relaxed max-w-md mx-auto mb-5">
            Jido integrates with your existing systems; it does not replace them. Each boundary stays yours — the IAM and identity layer in front of Jido, Ash actor and tenant context carried through ash_jido, durable storage for the Journal, and your SIEM and OTel backends for export.
          </p>
          <div class="flex flex-wrap items-center justify-center gap-x-4 gap-y-2">
            <.link
              navigate="/docs/operations/security-and-governance"
              class="home-pillar-link home-pillar-link-cyan"
              data-control-link="iam-boundary"
              data-analytics-event="control_proof_viewed"
              data-analytics-source="home"
              data-analytics-channel="home_operational_control"
              data-analytics-section-id="iam-boundary"
              data-analytics-target-url="/docs/operations/security-and-governance"
            >
              IAM boundary →
            </.link>
            <.link
              navigate="/ecosystem/ash_jido"
              class="home-pillar-link home-pillar-link-cyan"
              data-control-link="ash-actor-tenant"
              data-analytics-event="control_proof_viewed"
              data-analytics-source="home"
              data-analytics-channel="home_operational_control"
              data-analytics-section-id="ash-actor-tenant"
              data-analytics-target-url="/ecosystem/ash_jido"
            >
              Ash actor/tenant →
            </.link>
            <.link
              navigate="/docs/concepts/persistence"
              class="home-pillar-link home-pillar-link-cyan"
              data-control-link="durable-storage"
              data-analytics-event="control_proof_viewed"
              data-analytics-source="home"
              data-analytics-channel="home_operational_control"
              data-analytics-section-id="durable-storage"
              data-analytics-target-url="/docs/concepts/persistence"
            >
              Durable storage →
            </.link>
            <.link
              navigate="/docs/operations/security-and-governance"
              class="home-pillar-link home-pillar-link-cyan"
              data-control-link="siem-integration"
              data-analytics-event="control_proof_viewed"
              data-analytics-source="home"
              data-analytics-channel="home_operational_control"
              data-analytics-section-id="siem-integration"
              data-analytics-target-url="/docs/operations/security-and-governance"
            >
              SIEM integration →
            </.link>
            <.link
              navigate="/docs/reference/telemetry-and-observability"
              class="home-pillar-link home-pillar-link-cyan"
              data-control-link="otel-export"
              data-analytics-event="control_proof_viewed"
              data-analytics-source="home"
              data-analytics-channel="home_operational_control"
              data-analytics-section-id="otel-export"
              data-analytics-target-url="/docs/reference/telemetry-and-observability"
            >
              OTel export →
            </.link>
          </div>
        </article>
      </div>

      <div
        id="telemetry-not-audit-note"
        class="mt-12 max-w-2xl mx-auto rounded-xl border border-primary/20 bg-primary/5 px-6 py-6 text-center"
        data-control-note="telemetry-not-audit"
      >
        <p class="home-eyebrow-label text-[11px] font-semibold tracking-widest uppercase mb-3">
          Telemetry is not an audit log
        </p>
        <p class="home-muted-copy text-[15px] leading-relaxed max-w-xl mx-auto">
          Telemetry — correlated spans, metrics, and logs — and its OpenTelemetry export show how your agents are running. That is operational signal, not tamper-evident evidence. A durable audit history is the Signal Journal you deliberately configure, and retention, access control, and tamper evidence remain your application's responsibility.
        </p>
        <div class="flex flex-wrap items-center justify-center gap-x-4 gap-y-2 mt-4">
          <.link
            navigate="/docs/reference/telemetry-and-observability"
            class="text-primary hover:underline text-[13px] font-semibold"
            data-note-link="telemetry-scope"
          >
            What telemetry covers →
          </.link>
          <span class="home-muted-copy">·</span>
          <.link
            navigate="/docs/concepts/persistence"
            class="text-primary hover:underline text-[13px] font-semibold"
            data-note-link="durable-journal"
          >
            Configure a durable Journal →
          </.link>
        </div>
      </div>

      <div
        id="identity-not-principal-note"
        class="mt-12 max-w-2xl mx-auto rounded-xl border border-primary/20 bg-primary/5 px-6 py-6 text-center"
        data-control-note="identity-not-principal"
      >
        <p class="home-eyebrow-label text-[11px] font-semibold tracking-widest uppercase mb-3">
          Agent IDs are not authenticated principals
        </p>
        <p class="home-muted-copy text-[15px] leading-relaxed max-w-xl mx-auto">
          Agent IDs — like Signal and trace IDs — are correlation metadata: handles for following one piece of work through your system, not proof of who started it. Jido does not authenticate callers. Verified human or service identity is established at the authentication and IAM boundary you put in front of Jido, and the principal it issues is what each incoming Signal carries.
        </p>
        <div class="flex flex-wrap items-center justify-center gap-x-4 gap-y-2 mt-4">
          <.link
            navigate="/docs/operations/security-and-governance"
            class="text-primary hover:underline text-[13px] font-semibold"
            data-note-link="identity-bounded"
          >
            What Jido calls identity →
          </.link>
        </div>
      </div>

      <article
        id="control-integrated-controlled-agent"
        class="home-pillar-card px-6 py-6 mt-12"
        data-control-card="integrated-controlled-agent"
      >
        <div class="home-pillar-chip home-pillar-chip-cyan">
          <span class="text-2xl leading-none text-accent-cyan">🛡</span>
        </div>
        <h3 class="text-lg sm:text-xl font-bold mt-2 mb-3 leading-tight">
          See one integrated controlled agent
        </h3>
        <p class="home-muted-copy text-[15px] leading-relaxed max-w-md mx-auto mb-5">
          The four controls above are not separate promises — they are one supervised agent. Run the integrated controlled-Agent example to watch an allowed principal run a protected Action, an unauthorized principal get denied before it runs, and supervision restart a crashed process. One run proves the complete control path: who initiated work, what was allowed, what happened, and how failure was handled.
        </p>
        <div class="flex flex-col sm:flex-row items-center justify-center gap-3">
          <.link
            navigate="/examples/controlled-agent"
            class="home-pillar-link home-pillar-link-cyan"
            data-control-link="controlled-agent-example"
            data-analytics-event="control_proof_viewed"
            data-analytics-source="home"
            data-analytics-channel="home_operational_control"
            data-analytics-section-id="controlled-agent-example"
            data-analytics-target-url="/examples/controlled-agent"
          >
            Run the integrated example →
          </.link>
        </div>
      </article>

      <div
        id="home-operational-control-evaluation-cta"
        class="mt-12 max-w-2xl mx-auto rounded-xl border border-primary/20 bg-primary/5 px-6 py-7 text-center"
        data-control-cta="operations-evaluation"
      >
        <span class="home-eyebrow-label text-[11px] font-semibold tracking-widest uppercase">
          For platform and SRE evaluators
        </span>
        <h3 class="text-2xl sm:text-3xl font-bold tracking-tight mt-3 mb-3">
          Evaluate the operational-control architecture
        </h3>
        <p class="home-muted-copy text-[15px] leading-relaxed max-w-xl mx-auto mb-6">
          If you are approving Jido for production, the Operations hub opens the full architecture and its proof. Follow the long-running agent path below — a worked example at each step — before you sign off.
        </p>

        <%!-- Short production-path index (jido-e07-t34). The site's main
             position must link to the full proof path: a compact, ordered index
             of the long-running agent path that mirrors the Operations hub
             (/docs/operations), so an evaluator scanning the home page can step
             through the production path and land on the one run that proves it. --%>
        <ol
          id="home-production-path-index"
          class="home-muted-copy text-[14px] leading-relaxed max-w-xl mx-auto text-left mb-6"
          data-control-index="production-path"
        >
          <li class="flex gap-3 mb-2">
            <span class="text-primary font-bold shrink-0">1.</span>
            <span>
              <.link
                navigate="/docs/operations/supervision-and-failure-boundaries"
                class="text-primary hover:underline font-semibold"
                data-control-link="production-path-recovery"
                data-analytics-event="control_proof_viewed"
                data-analytics-source="home"
                data-analytics-channel="home_operational_control"
                data-analytics-section-id="production-path-recovery"
                data-analytics-target-url="/docs/operations/supervision-and-failure-boundaries"
              >
                Define what recovery means
              </.link>
              — OTP supervision restarts a crashed AgentServer and bounds failure scope.
            </span>
          </li>
          <li class="flex gap-3 mb-2">
            <span class="text-primary font-bold shrink-0">2.</span>
            <span>
              <.link
                navigate="/docs/operations/deployment-restart"
                class="text-primary hover:underline font-semibold"
                data-control-link="production-path-state"
                data-analytics-event="control_proof_viewed"
                data-analytics-source="home"
                data-analytics-channel="home_operational_control"
                data-analytics-section-id="production-path-state"
                data-analytics-target-url="/docs/operations/deployment-restart"
              >
                Keep state across restart
              </.link>
              — decide what survives a process, application, and deployment restart, with a worked example.
            </span>
          </li>
          <li class="flex gap-3 mb-2">
            <span class="text-primary font-bold shrink-0">3.</span>
            <span>
              <.link
                navigate="/docs/operations/retries-timeouts-and-provider-failure"
                class="text-primary hover:underline font-semibold"
                data-control-link="production-path-failure"
                data-analytics-event="control_proof_viewed"
                data-analytics-source="home"
                data-analytics-channel="home_operational_control"
                data-analytics-section-id="production-path-failure"
                data-analytics-target-url="/docs/operations/retries-timeouts-and-provider-failure"
              >
                Handle failure modes
              </.link>
              — separate retry, timeout, and fallback for tool, HTTP, and model failures.
            </span>
          </li>
          <li class="flex gap-3 mb-2">
            <span class="text-primary font-bold shrink-0">4.</span>
            <span>
              <.link
                navigate="/docs/operations/telemetry-and-traces"
                class="text-primary hover:underline font-semibold"
                data-control-link="production-path-observe"
                data-analytics-event="control_proof_viewed"
                data-analytics-source="home"
                data-analytics-channel="home_operational_control"
                data-analytics-section-id="production-path-observe"
                data-analytics-target-url="/docs/operations/telemetry-and-traces"
              >
                Schedule and observe
              </.link>
              — add scheduling or event input, then telemetry and traces.
            </span>
          </li>
          <li class="flex gap-3">
            <span class="text-primary font-bold shrink-0">5.</span>
            <span>
              <.link
                navigate="/docs/operations/health-checks-and-readiness"
                class="text-primary hover:underline font-semibold"
                data-control-link="production-path-health"
                data-analytics-event="control_proof_viewed"
                data-analytics-source="home"
                data-analytics-channel="home_operational_control"
                data-analytics-section-id="production-path-health"
                data-analytics-target-url="/docs/operations/health-checks-and-readiness"
              >
                Check health and deploy
              </.link>
              — define process, dependency, and work health, and verify after every deploy.
            </span>
          </li>
        </ol>

        <p class="home-muted-copy text-[14px] leading-relaxed max-w-xl mx-auto mb-6">
          The whole path resolves to one run:
          <.link
            navigate="/examples/controlled-agent"
            class="text-primary hover:underline font-semibold"
            data-control-link="production-path-proof"
            data-analytics-event="control_proof_viewed"
            data-analytics-source="home"
            data-analytics-channel="home_operational_control"
            data-analytics-section-id="production-path-proof"
            data-analytics-target-url="/examples/controlled-agent"
          >
            run the Controlled Agent
          </.link>
          — one supervised agent proving the complete control path: who initiated work, what was allowed, what happened, and how failure was handled.
        </p>
        <div class="flex flex-col sm:flex-row items-center justify-center gap-3">
          <.link
            navigate="/docs/operations"
            class="bg-primary text-primary-foreground hover:bg-primary/90 text-[13px] font-bold px-7 py-4 rounded transition-colors"
            data-analytics-event="cta_clicked"
            data-analytics-source="home"
            data-analytics-channel="home_operational_control"
            data-analytics-section-id="operations-evaluation"
            data-analytics-target-url="/docs/operations"
          >
            Open the operational-control architecture →
          </.link>
          <span class="home-muted-copy hidden sm:inline">·</span>
          <.link
            navigate="/docs/operations/security-and-governance"
            class="text-primary hover:underline text-[13px] font-semibold"
          >
            See the full control model →
          </.link>
        </div>
      </div>
    </section>
    """
  end
end
