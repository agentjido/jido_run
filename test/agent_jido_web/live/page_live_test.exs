defmodule AgentJidoWeb.PageLiveTest do
  use AgentJidoWeb.ConnCase, async: true

  import Ecto.Query
  import Phoenix.LiveViewTest

  alias AgentJido.Analytics
  alias AgentJido.Analytics.AnalyticsEvent
  alias AgentJido.Ecosystem
  alias AgentJido.Ecosystem.Layering
  alias AgentJido.Pages
  alias AgentJido.Repo
  alias AgentJidoWeb.Jido.Nav

  @moduletag :flaky

  describe "home auth navigation" do
    test "does not render login link on the home page", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      refute html =~ ~s(href="/users/log-in")
    end

    test "does not render login link on non-home public pages", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/docs")

      refute html =~ ~s(href="/users/log-in")
    end
  end

  describe "home ecosystem section" do
    test "renders ecosystem header, summary, and explore CTA", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ ~s(id="home-ecosystem-section")
      assert html =~ "Ecosystem"
      assert html =~ "composable by design · ground up"
      assert html =~ "Explore the full ecosystem"
      assert html =~ ~s(href="/ecosystem")
    end

    test "renders rows in app, ai, foundation order and includes core anchor row", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      expected_layers =
        [:app, :ai, :foundation]
        |> Enum.filter(fn layer ->
          Ecosystem.public_packages()
          |> Enum.any?(&(Layering.layer_for(&1) == layer))
        end)

      positions =
        Enum.map(expected_layers, fn layer ->
          row_id = ~s(id="home-ecosystem-row-#{layer}")
          assert html =~ row_id

          case :binary.match(html, row_id) do
            {index, _length} -> index
            :nomatch -> flunk("expected #{row_id} to exist in home ecosystem section")
          end
        end)

      assert positions == Enum.sort(positions)
      assert html =~ ~s(id="home-ecosystem-core-anchor")
    end

    test "renders package links for all public ecosystem packages", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      for pkg <- Ecosystem.public_packages() do
        assert html =~ ~s(id="home-ecosystem-package-#{pkg.id}")
        assert html =~ ~s(href="/ecosystem/#{pkg.id}")
      end
    end
  end

  describe "getting-started hub lanes (jido-e05-t05)" do
    test "renders all three choose-your-path lanes", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/docs/getting-started")

      assert html =~ ~s(href="/docs/getting-started/new-to-elixir")
      assert html =~ ~s(href="/docs/getting-started/elixir-developers")
      assert html =~ ~s(href="/docs/getting-started/phoenix-starter")
      assert html =~ "Use the Phoenix starter"
    end

    test "the Phoenix starter lane route renders its requirements", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/docs/getting-started/phoenix-starter")

      assert html =~ "Use the Phoenix starter"
      assert html =~ "https://github.com/agentjido/jido_phx_starter"
      assert html =~ "Postgres"
      assert html =~ "ecto.setup"
      assert html =~ "API key"
    end
  end

  describe "getting-started operational controls lane (jido-e05-t32)" do
    test "the hub renders the operational controls lane as an optional next path", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/docs/getting-started")

      assert html =~ ~s(href="/docs/getting-started/operational-controls")
      assert html =~ "Add operational controls"
    end

    test "the operational controls lane route renders", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/docs/getting-started/operational-controls")

      assert html =~ "Add operational controls"
      # The lane follows the first working agent and links back to it.
      assert html =~ ~s(href="/docs/getting-started/first-agent")
      # The lane does not block basic activation.
      assert html =~ "Nothing on this page is required to run a basic agent"
    end
  end

  describe "onboarding version metadata (jido-e05-t28)" do
    test "the first-agent lane renders last validation date and tested versions", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/docs/getting-started/first-agent")

      assert html =~ "Last validated"
      assert html =~ "Tested with"
      # 2.3.2 only appears via the tested_with metadata; the body uses build tokens.
      assert html =~ "2.3.2"
    end

    test "the first-LLM lane renders the full tested-with package set", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/docs/getting-started/first-llm-agent")

      assert html =~ "Last validated"
      assert html =~ "Tested with"
      assert html =~ "jido_ai"
      assert html =~ "req_llm"
      assert html =~ "2.2.0"
    end

    test "the Phoenix starter lane renders last validation date and tested versions", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/docs/getting-started/phoenix-starter")

      assert html =~ "Last validated"
      assert html =~ "Tested with"
    end
  end

  describe "guide related packages (jido-e06-t26)" do
    # Acceptance: "Package roles and maturity appear near instructions." Each
    # guide's related_packages render next to the instructions (above the body),
    # with each package's role and its current maturity.
    test "the weather-agent guide renders package roles and maturity next to the instructions",
         %{conn: conn} do
      {:ok, _view, html} = live(conn, "/docs/guides/building-a-weather-agent")

      # The block heading and a guide-specific role appear...
      assert html =~ "Related packages"
      assert html =~ "The tool-calling loop that drives the agent"

      # ...each package links to its ecosystem page...
      assert html =~ ~s(href="/ecosystem/jido")
      assert html =~ ~s(href="/ecosystem/jido_ai")
      assert html =~ ~s(href="/ecosystem/req_llm")

      # ...and the resolved maturity renders alongside the role.
      assert html =~ "stable"

      # Placement: the related-packages block sits above the instruction body,
      # not after it.
      {related_pos, _} = :binary.match(html, "Related packages")
      {body_pos, _} = :binary.match(html, ~s(id="docs-content"))

      assert related_pos < body_pos,
             "Related packages must render before the instruction body (near instructions)"
    end

    test "the debugging guide renders its single related package with maturity", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/docs/guides/debugging-and-troubleshooting")

      assert html =~ "Related packages"
      assert html =~ "Debug modes, the event buffer, and status/state inspection"
      assert html =~ ~s(href="/ecosystem/jido")
      assert html =~ "stable"
    end
  end

  describe "home quick start and cta sections" do
    test "renders elixir onboarding guide links", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ ~s(href="/docs/getting-started/new-to-elixir")
      assert html =~ ~s(id="home-elixir-expert-guide-link")
      assert html =~ ~s(href="/docs/getting-started/elixir-developers")
    end

    test "renders quick start section with define and terminal blocks", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ ~s(id="quick-start")
      assert html =~ "Quick start"
      assert html =~ "Define an agent, start it supervised, ask it questions."
      assert html =~ "lib/my_app/weather_agent.ex"
      assert html =~ "iex -S mix"
      assert html =~ "View full example"
      assert html =~ ~s(href="/training/agent-fundamentals")
    end

    test "renders why elixir section with expected feature links", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ ~s(id="why-elixir-otp")
      assert html =~ "Why Elixir/OTP"
      assert html =~ "Process isolation"
      assert html =~ "OTP supervision"
      assert html =~ "Fault-tolerant concurrency"
      assert html =~ ~s(href="/features/beam-native-agent-model")
      assert html =~ ~s(href="/features/beam-for-ai-builders")
    end

    test "renders reusable build your first agent cta", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ ~s(id="cta")
      assert html =~ ~s(id="home-build-agent-cta")
      assert html =~ "Build your first agent"
      assert html =~ "GET BUILDING"
      assert html =~ "START TRAINING"
      assert html =~ ~s(href="/docs/getting-started")
      assert html =~ ~s(href="/training")
    end
  end

  describe "footer metadata" do
    test "marketing footer reflects legal and ecosystem updates", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/features")
      jido_version = Nav.jido_version()
      current_year = Date.utc_today().year

      assert html =~ "Apache License 2.0"
      assert html =~ "Copyright © 2025-#{current_year}"
      assert html =~ "Mike Hostetler"
      assert html =~ ~s(href="https://mike-hostetler.com")
      assert html =~ "Jido #{jido_version}"

      assert html =~ ~s(href="/ecosystem")
      assert html =~ ~s(href="https://llmdb.xyz")
      assert html =~ ~s(href="https://jido.run/discord")
      refute html =~ ~s(href="https://discord.gg/jido")
      assert html =~ ~s(id="primary-nav-content-assistant-trigger")

      assert html =~ "jido"
      assert html =~ "jido_ai"
      assert html =~ "req_llm"
      refute html =~ "HexDocs"
      refute html =~ "LinkedIn"
      refute html =~ "YouTube"
      refute html =~ ~s(href="/training")
      refute html =~ ~s(href="/search")
    end

    test "docs footer includes legal/version row and edit link", %{conn: conn} do
      page =
        Pages.pages_by_category(:docs)
        |> Enum.find(fn doc ->
          not is_nil(doc.github_url) and
            doc.path != "/docs" and
            not String.ends_with?(doc.path, "/getting-started")
        end)

      assert page != nil

      {:ok, _view, html} = live(conn, Pages.route_for(page))
      jido_version = Nav.jido_version()
      current_year = Date.utc_today().year

      assert html =~ "Edit this page"
      assert html =~ "https://github.com/agentjido/agentjido_xyz/"
      assert html =~ "Apache License 2.0"
      assert html =~ "Copyright © 2025-#{current_year}"
      assert html =~ "Mike Hostetler"
      assert html =~ ~s(href="https://mike-hostetler.com")
      assert html =~ "Jido #{jido_version}"
    end
  end

  describe "about page" do
    test "renders placeholder about page", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/about")

      assert html =~ "About"
    end
  end

  describe "docs" do
    test "renders docs index page", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/docs")

      assert html =~ "Jido Documentation"
      assert html =~ "Get Started"
      assert html =~ ~s(href="/docs/contributors")
      assert html =~ ~s(href="https://jido.run/discord")
    end

    test "renders docs show page", %{conn: conn} do
      page = Pages.pages_by_category(:docs) |> hd()
      route = Pages.route_for(page)
      {:ok, _view, html} = live(conn, route)

      assert html =~ page.title
    end

    test "renders the package support levels contributors page", %{conn: conn} do
      page = Pages.get_page_by_path("/docs/contributors/package-support-levels")
      assert page != nil

      {:ok, _view, html} = live(conn, page.path)

      assert html =~ "Package support levels"
      assert html =~ "Stable"
      assert html =~ "Beta"
      assert html =~ "Experimental"
      assert html =~ "Every public ecosystem package should carry one public"
    end

    test "renders the new contributor handbook pages", %{conn: conn} do
      for {path, title} <- [
            {"/docs/contributors/ecosystem-atlas", "Ecosystem atlas"},
            {"/docs/contributors/observability-and-error-reporting-standards", "Observability and error reporting standards"},
            {"/docs/contributors/livebook-authoring-standards", "Livebook authoring standards"},
            {"/docs/contributors/roadmap", "Roadmap"},
            {"/docs/contributors/contributing", "Contributing"},
            {"/docs/contributors/governance-and-team", "Governance and team structure"}
          ] do
        page = Pages.get_page_by_path(path)
        assert page != nil

        {:ok, _view, html} = live(conn, path)

        assert html =~ title
      end
    end

    test "contributors sidebar lists handbook pages in atlas-first order" do
      [%{title: title, items: items}] = AgentJidoWeb.PageLive.sidebar_nav("/docs/contributors")

      assert title == "Contributors"

      assert Enum.map(items, & &1.href) == [
               "/docs/contributors",
               "/docs/contributors/ecosystem-atlas",
               "/docs/contributors/package-support-levels",
               "/docs/contributors/package-quality-standards",
               "/docs/contributors/observability-and-error-reporting-standards",
               "/docs/contributors/livebook-authoring-standards",
               "/docs/contributors/roadmap",
               "/docs/contributors/contributing",
               "/docs/contributors/governance-and-team"
             ]
    end

    test "ecosystem atlas renders public package links, owner handles, and excludes private packages", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/docs/contributors/ecosystem-atlas")

      assert html =~ "Core"
      assert html =~ "Integrations"
      assert html =~ "Chat"
      assert html =~ "Provider Adapters"
      assert html =~ ~s(href="/ecosystem/jido")
      assert html =~ ~s(href="/ecosystem/jido_code")
      assert html =~ "@mikehostetler"
      assert html =~ "@pcharbon70"
      refute html =~ "Integration / Framework"
      refute html =~ ~s(href="/ecosystem/agent_jido")
      refute html =~ ~s(href="/ecosystem/jido_memory_os")
      refute html =~ ~s(href="/ecosystem/jido_flame")
    end

    test "docs right rail includes Livebook run link for livebook-backed docs pages", %{conn: conn} do
      page = Pages.get_page_by_path("/docs/concepts/agents")
      assert page != nil
      assert page.is_livebook
      assert is_binary(page.livebook_url)

      {:ok, _view, html} = live(conn, "/docs/concepts/agents")

      assert html =~ "Run this in Livebook"
      assert html =~ page.livebook_url
      assert html =~ ~s(id="what-this-solves")
    end

    test "AI chat agent page links to a published chat response cookbook page", %{conn: conn} do
      recipe_page = Pages.get_page_by_path("/docs/guides/cookbook/chat-response")
      assert recipe_page != nil

      {:ok, _view, ai_chat_html} = live(conn, "/docs/learn/ai-chat-agent")
      assert ai_chat_html =~ ~s(href="/docs/guides/cookbook/chat-response")

      {:ok, _view, recipe_html} = live(conn, "/docs/guides/cookbook/chat-response")
      assert recipe_html =~ "Cookbook: chat response"
    end

    test "AI agent with tools page documents the LocationToGrid weather flow", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/docs/learn/ai-agent-with-tools")

      assert html =~ "weather_location_to_grid"
      assert html =~ "forecast URL"
      assert html =~ "observation stations URL"
    end

    test "docs right rail quick links include For Agents entry", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/docs/concepts/agents")

      assert html =~ "For Agents"
      assert html =~ ~s(href="/docs/concepts/agents.md")
    end

    test "docs table of contents uses the right-rail breakpoint from lg upward", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/docs/concepts/agents")

      assert html =~ ~s(class="lg:hidden")
      assert html =~ ~s(class="docs-column-height hidden lg:flex)
    end

    test "docs code blocks preserve syntax highlighter whitespace tokens", %{conn: conn} do
      conn = get(conn, "/docs/concepts/agents")
      html = response(conn, 200)

      assert html =~ ~s(<pre><code class="makeup elixir">)
      refute html =~ ~s(<span class="w"></span>)
    end

    test "docs helpful feedback gives visible confirmation and records once", %{conn: conn} do
      path = "/docs/concepts/agents"
      session_id = Ecto.UUID.generate()

      conn =
        init_test_session(conn, %{
          analytics_session_id: session_id
        })

      {:ok, view, _html} = live(conn, path)

      assert has_element?(view, "#docs-page-feedback button[title='Helpful']")

      render_click(view, "docs_feedback_select", %{"value" => "helpful"})

      assert render(view) =~ "Thanks for the feedback."

      assert docs_feedback_count(path, "helpful", session_id) == 1

      render_click(view, "docs_feedback_select", %{"value" => "helpful"})

      assert docs_feedback_count(path, "helpful", session_id) == 1
    end

    test "docs feedback remains locked on revisit for the same visitor session", %{conn: conn} do
      path = "/docs/concepts/agents"
      session_id = Ecto.UUID.generate()

      conn =
        init_test_session(conn, %{
          analytics_session_id: session_id
        })

      {:ok, view, _html} = live(conn, path)

      render_click(view, "docs_feedback_select", %{"value" => "helpful"})

      assert docs_feedback_count(path, "helpful", session_id) == 1
      assert analytics_identity(view).session_id == session_id
      assert docs_feedback_assign(view).submitted
      assert Analytics.latest_feedback_for_identity(nil, session_id, path, surface: "docs_page")

      {:ok, revisit_view, _revisit_html} = live(conn, path)

      assert analytics_identity(revisit_view).session_id == session_id
      assert docs_feedback_assign(revisit_view).submitted
      assert has_element?(revisit_view, "#docs-page-feedback button[title='Helpful'][disabled]")

      render_click(revisit_view, "docs_feedback_select", %{"value" => "helpful"})

      assert docs_feedback_count(path, "helpful", session_id) == 1
    end

    test "smoke routes for required docs IA stubs", %{conn: conn} do
      sections = ~w(getting-started concepts guides contributors reference operations)

      Enum.each(sections, fn section ->
        path = "/docs/#{section}"
        page = Pages.get_page_by_path(path)
        assert page != nil

        {:ok, _view, html} = live(conn, path)
        assert html =~ page.title
      end)

      docs_pages = Pages.pages_by_category(:docs)

      Enum.each(~w(concepts guides contributors reference operations), fn section ->
        child =
          docs_pages
          |> Enum.filter(&String.starts_with?(&1.path, "/docs/#{section}/"))
          |> Enum.sort_by(&{&1.order, &1.path})
          |> List.first()

        assert child != nil

        child_path = Pages.route_for(child)
        {:ok, _view, html} = live(conn, child_path)
        assert html =~ child.title
      end)
    end

    test "legacy docs routes redirect permanently to canonical section routes", %{conn: conn} do
      legacy_to_canonical = %{
        "/docs/cookbook-index" => "/docs/guides/cookbook",
        "/docs/core-concepts" => "/docs/concepts",
        "/docs/getting-started/core-concepts" => "/docs/concepts",
        "/docs/getting-started/guides" => "/docs/guides",
        "/docs/chat-response" => "/docs/guides/cookbook/chat-response",
        "/docs/tool-response" => "/docs/guides/cookbook/tool-response",
        "/docs/weather-tool-response" => "/docs/guides/cookbook/weather-tool-response",
        "/docs/architecture" => "/docs/reference/architecture",
        "/docs/configuration" => "/docs/reference/configuration",
        "/docs/glossary" => "/docs/reference/glossary",
        "/docs/production-readiness-checklist" => "/docs/operations/production-readiness-checklist",
        "/docs/reference/production-readiness-checklist" => "/docs/operations/production-readiness-checklist",
        "/docs/security-and-governance" => "/docs/operations/security-and-governance",
        "/docs/reference/security-and-governance" => "/docs/operations/security-and-governance",
        "/docs/incident-playbooks" => "/docs/operations/incident-playbooks",
        "/docs/reference/incident-playbooks" => "/docs/operations/incident-playbooks"
      }

      Enum.each(legacy_to_canonical, fn {legacy, canonical} ->
        redirected_conn = get(recycle(conn), legacy)
        assert redirected_to(redirected_conn, 301) == canonical
      end)

      Enum.each(legacy_to_canonical, fn {legacy, canonical} ->
        redirected_conn = get(recycle(conn), legacy <> ".md")
        assert redirected_to(redirected_conn, 301) == canonical <> ".md"
      end)
    end

    test "first workflow next steps link points to the published actions doc", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/docs/learn/first-workflow")

      assert html =~ ~s(href="/docs/concepts/actions")
      refute html =~ ~s(href="/docs/learn/actions-validation")
    end
  end

  defp docs_feedback_count(path, feedback_value, session_id) do
    from(e in AnalyticsEvent,
      where:
        e.event == "feedback_submitted" and
          e.path == ^path and
          e.session_id == ^session_id and
          e.feedback_value == ^feedback_value and
          fragment("?->>'surface' = ?", e.metadata, "docs_page")
    )
    |> Repo.aggregate(:count, :id)
  end

  defp analytics_identity(view) do
    view.pid
    |> :sys.get_state()
    |> Map.fetch!(:socket)
    |> Map.fetch!(:assigns)
    |> Map.fetch!(:analytics_identity)
  end

  defp docs_feedback_assign(view) do
    view.pid
    |> :sys.get_state()
    |> Map.fetch!(:socket)
    |> Map.fetch!(:assigns)
    |> Map.fetch!(:docs_feedback)
  end

  describe "hub card status labels (jido-e06-t24)" do
    # Acceptance: "Draft or Experimental content cannot look complete." Hub cards
    # render a status badge when a page's content status is draft or
    # experimental; published content renders no badge.

    test "status_badge_class/1 returns a distinct caution style per status" do
      assert AgentJidoWeb.PageLive.status_badge_class(:draft) =~ "text-accent-yellow"
      assert AgentJidoWeb.PageLive.status_badge_class(:experimental) =~ "text-accent-cyan"
      # The fallback is neutral so it never reads as a status by itself.
      refute AgentJidoWeb.PageLive.status_badge_class(:published) =~ "text-accent-"
    end

    test "published build pages carry no status label, so the hub renders no badges", %{conn: conn} do
      for page <- Pages.pages_by_category(:build) do
        assert Pages.content_status(page) == :published
        assert Pages.content_status_label(page) == nil
      end

      # The hub still renders its cards (regression for the template edit), and
      # because every build page is published the status-badge spans never
      # render — the badge class is only emitted by status_badge_class/1 and
      # only when a non-published status is present.
      {:ok, _view, html} = live(conn, "/build")

      assert html =~ "Build with Jido"
      refute html =~ ~s(uppercase tracking-wide bg-accent-yellow/10 border border-accent-yellow/30)
      refute html =~ ~s(uppercase tracking-wide bg-accent-cyan/10 border border-accent-cyan/30)
    end

    test "published docs section roots carry no status label" do
      for section_page <- Pages.docs_sections() do
        assert Pages.content_status(section_page) == :published
        assert Pages.content_status_label(section_page) == nil
      end
    end
  end

  describe "docs hub audience/outcome filters (jido-e06-t25)" do
    # Acceptance: "A builder can select Elixir, AI, operations, or evaluation
    # work." The Docs index renders a filter bar; selecting a lens narrows the
    # Documentation section grid to the sections that serve that work.

    @section_slugs ~w(getting-started concepts learn guides contributors reference operations)

    test "the docs index renders a filter chip for each work type plus All", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/docs")

      assert html =~ ~s(id="docs-work-filter")
      assert html =~ ~s(phx-value-work-type="all")
      assert html =~ ~s(phx-value-work-type="elixir")
      assert html =~ ~s(phx-value-work-type="ai")
      assert html =~ ~s(phx-value-work-type="operations")
      assert html =~ ~s(phx-value-work-type="evaluation")
    end

    test "the default view shows every section card", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/docs")

      for slug <- @section_slugs do
        assert has_element?(view, "#docs-section-card-#{slug}"),
               "expected section card for #{slug} in the default grid"
      end
    end

    test "selecting the AI lens narrows the grid and marks the chip active", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/docs")

      render_click(view, "select_docs_filter", %{"work_type" => "ai"})

      assert has_element?(view, "#docs-section-card-learn")
      assert has_element?(view, "#docs-section-card-guides")
      refute has_element?(view, "#docs-section-card-operations")
      refute has_element?(view, "#docs-section-card-concepts")

      html = render(view)

      # The AI chip is the active affordance; All is no longer pressed.
      assert html =~ ~s(phx-value-work-type="ai" aria-pressed="true")
      assert html =~ ~s(phx-value-work-type="all" aria-pressed="false")
    end

    test "selecting the Operations lens shows operations and hides AI sections", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/docs")

      render_click(view, "select_docs_filter", %{"work_type" => "operations"})

      assert has_element?(view, "#docs-section-card-operations")
      refute has_element?(view, "#docs-section-card-learn")
      refute has_element?(view, "#docs-section-card-concepts")
    end

    test "selecting the Evaluation lens surfaces reference and contributors", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/docs")

      render_click(view, "select_docs_filter", %{"work_type" => "evaluation"})

      assert has_element?(view, "#docs-section-card-reference")
      assert has_element?(view, "#docs-section-card-contributors")
      refute has_element?(view, "#docs-section-card-learn")
    end

    test "selecting All restores the full grid", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/docs")

      render_click(view, "select_docs_filter", %{"work_type" => "ai"})
      refute has_element?(view, "#docs-section-card-operations")

      render_click(view, "select_docs_filter", %{"work_type" => "all"})

      for slug <- @section_slugs do
        assert has_element?(view, "#docs-section-card-#{slug}")
      end
    end

    test "an unknown work type falls back to the full grid", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/docs")

      render_click(view, "select_docs_filter", %{"work_type" => "ai"})
      refute has_element?(view, "#docs-section-card-operations")

      # "bogus" is not an existing atom, so it normalizes to :all.
      render_click(view, "select_docs_filter", %{"work_type" => "bogus"})

      assert has_element?(view, "#docs-section-card-operations")
      assert has_element?(view, "#docs-section-card-learn")
    end
  end

  describe "disabled public routes" do
    test "training index route returns 404", %{conn: conn} do
      conn = get(conn, "/training")
      assert response(conn, 404)
    end

    test "training detail routes return 404", %{conn: conn} do
      training_page = Pages.pages_by_category(:training) |> hd()
      training_path = Pages.route_for(training_page)

      conn = get(conn, training_path)
      assert response(conn, 404)
    end

    test "search route renders search page", %{conn: conn} do
      conn = get(conn, "/search")
      body = response(conn, 200)
      assert body =~ "Search and chat"
    end
  end

  describe "features wave A pages" do
    test "smoke routes for first three feature pages", %{conn: conn} do
      target_routes = [
        {"/features/agents-that-self-heal", "OTP supervision"},
        {"/features/multi-agent-coordination", "coordination"},
        {"/features/observe-everything", "telemetry"}
      ]

      Enum.each(target_routes, fn {path, expected_copy} ->
        page = Pages.get_page_by_path(path)
        assert page != nil

        {:ok, _view, html} = live(conn, path)

        assert html =~ expected_copy
        assert html =~ "Get Building"
        refute html =~ "Content coming soon."
      end)
    end
  end

  describe "features wave B pages" do
    test "smoke routes for remaining four feature pages", %{conn: conn} do
      target_routes = [
        {"/features/start-small", "Add one agent"},
        {"/features/beam-for-ai-builders", "If your team is evaluating Jido from Python or TypeScript"},
        {"/features/jido-vs-framework-first-stacks", "This comparison is about operating model fit, not vendor ranking"},
        {"/features/executive-brief", "This page is for engineering managers, CTOs, and architecture leads evaluating"}
      ]

      Enum.each(target_routes, fn {path, expected_copy} ->
        page = Pages.get_page_by_path(path)
        assert page != nil

        {:ok, _view, html} = live(conn, path)

        assert html =~ expected_copy
        assert html =~ "Get Building"
        refute html =~ "Content coming soon."
      end)
    end
  end

  describe "build wave A pages" do
    test "renders /build index with wave A cards and no placeholder copy", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/build")

      assert html =~ "Build"
      assert html =~ "Build with Jido"
      assert html =~ "Quickstarts by persona"
      assert html =~ "Reference architectures"
      refute html =~ "Content coming soon."
    end

    test "smoke routes for wave A build pages", %{conn: conn} do
      target_pages = [
        {"/build", "Build is where you convert Jido concepts"},
        {"/build/quickstarts-by-persona", "Use this page as a routing layer"},
        {"/build/reference-architectures", "Reference architectures let you choose runtime boundaries"}
      ]

      Enum.each(target_pages, fn {path, expected_copy} ->
        page = Pages.get_page_by_path(path)
        assert page != nil

        {:ok, _view, html} = live(conn, Pages.route_for(page))

        assert html =~ expected_copy
        assert html =~ "Get Building"
        refute html =~ "Content coming soon."
      end)
    end
  end

  describe "build wave B pages" do
    test "smoke routes for remaining build pages", %{conn: conn} do
      target_pages = [
        {"/build/mixed-stack-integration", "Mixed-stack integration works when Jido owns orchestration"},
        {"/build/product-feature-blueprints", "Product feature blueprints convert fuzzy requirements into shippable milestones"}
      ]

      Enum.each(target_pages, fn {path, expected_copy} ->
        page = Pages.get_page_by_path(path)
        assert page != nil

        {:ok, _view, html} = live(conn, path)

        assert html =~ expected_copy
        assert html =~ "Get Building"
        refute html =~ "Content coming soon."
      end)
    end
  end

  describe "community pages" do
    test "renders /community community hub route", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/community")

      assert html =~ "COMMUNITY"
      assert html =~ "Build agents with us"
      assert html =~ "Ways To Participate"
      assert html =~ "Join Discord"
      assert html =~ ~s(href="https://jido.run/discord")
      assert html =~ "Collaborate on GitHub"
      assert html =~ "Work together on GitHub"
    end

    test "renders /community/showcase route", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/community/showcase")

      assert html =~ "Built with Jido"
      assert html =~ "Community Showcase"
      assert html =~ "Loomkin"
      assert html =~ "ScreenTour"
      assert html =~ "Submit Project"
      assert html =~ ~s(id="showcase-project-loomkin")
      refute html =~ "Agent Jido Workbench"
      refute html =~ ~s(id="showcase-project-agent-jido-workbench")
      assert html =~ "SUBMIT YOUR PROJECT"
    end

    test "community subpages are no longer routable", %{conn: conn} do
      retired_paths = [
        "/community/learning-paths",
        "/community/adoption-playbooks",
        "/community/case-studies"
      ]

      Enum.each(retired_paths, fn path ->
        html =
          conn
          |> get(path)
          |> html_response(404)

        assert html =~ "Page not found"
      end)
    end
  end
end
