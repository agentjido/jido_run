defmodule AgentJidoWeb.JidoExampleLiveTest do
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias AgentJido.Examples

  @endpoint AgentJidoWeb.Endpoint
  setup_all do
    ensure_started(:telemetry)
    ensure_started(:phoenix_pubsub)
    ensure_started(:phoenix)
    ensure_started(:phoenix_live_view)
    ensure_started(:jido_action)
    ensure_started(:jido_browser)

    if Process.whereis(AgentJido.PubSub) == nil do
      start_supervised!({Phoenix.PubSub, name: AgentJido.PubSub})
    end

    if Process.whereis(AgentJidoWeb.Endpoint) == nil do
      start_supervised!(AgentJidoWeb.Endpoint)
    end

    :ok
  end

  setup do
    {:ok, conn: build_conn()}
  end

  defp ensure_started(app) do
    case Application.ensure_all_started(app) do
      {:ok, _apps} -> :ok
      {:error, {:already_started, _app}} -> :ok
      {:error, reason} -> raise "failed to start #{inspect(app)}: #{inspect(reason)}"
    end
  end

  describe "/examples/address-normalization-agent" do
    test "renders explanation tab", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/examples/address-normalization-agent?tab=explanation")

      assert html =~ "Address Normalization Agent"
      assert html =~ "Action contracts and validation"
      assert html =~ "Story Link"
    end

    test "renders source tab", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/examples/address-normalization-agent?tab=source")

      assert html =~ "address_normalization_agent.ex"
      assert html =~ "execute_action.ex"
      assert html =~ "reset_action.ex"
      assert html =~ "address_normalization_agent_live.ex"
      refute html =~ "file="
    end

    test "source tab uses clean indexed URL params", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/address-normalization-agent?tab=source")

      view
      |> element("a", "execute_action.ex")
      |> render_click()

      patched = assert_patch(view)
      assert URI.parse(patched).path == "/examples/address-normalization-agent"
      assert URI.parse(patched).query |> URI.decode_query() == %{"source" => "2", "tab" => "source"}

      html = render(view)
      assert html =~ "tab=source"
      assert html =~ "source=2"
      refute html =~ "file="
    end

    test "renders demo tab and validates interaction flow", %{conn: conn} do
      {:ok, view, html} = live(conn, "/examples/address-normalization-agent?tab=demo")

      assert html =~ "Address Normalization Agent"
      assert html =~ "Action Contract"

      demo_view = find_live_child(view, "demo-address-normalization-agent")

      html =
        demo_view
        |> element("#address-normalization-demo button[phx-click='run_valid_sample']")
        |> render_click()

      assert html =~ "123 Main St, San Francisco, CA 94105, US"
      assert html =~ "successful runs: 1"

      html =
        demo_view
        |> element("#address-normalization-demo button[phx-click='run_invalid_sample']")
        |> render_click()

      assert html =~ "Action contract rejected the payload."
    end

    test "example registry metadata resolves source files", %{conn: _conn} do
      example = Examples.get_example!("address-normalization-agent")

      assert example.title == "Address Normalization Agent"
      assert example.live_view_module == "AgentJidoWeb.Examples.AddressNormalizationAgentLive"

      assert example.source_files == [
               "lib/agent_jido/demos/address_normalization/address_normalization_agent.ex",
               "lib/agent_jido/demos/address_normalization/actions/execute_action.ex",
               "lib/agent_jido/demos/address_normalization/actions/reset_action.ex",
               "lib/agent_jido_web/examples/address_normalization_agent_live.ex"
             ]

      assert Enum.map(example.sources, & &1.path) == example.source_files
    end
  end

  describe "/examples/counter-agent" do
    test "renders related guides and livebooks", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/examples/counter-agent?tab=explanation")

      assert html =~ "Related guides and notebooks"
      assert html =~ "/docs/getting-started/first-agent"
      assert html =~ "/docs/concepts/actions"
      assert html =~ "/docs/learn/first-workflow"
      assert html =~ "livebook.dev/run?url="
    end

    test "the companion Livebook link fires the first-open activation event (jido-e12-t22)",
         %{conn: conn} do
      {:ok, _view, html} = live(conn, "/examples/counter-agent?tab=explanation")

      # The global click handler in app.js fires `livebook_run_clicked` for any
      # [data-livebook-run='true'] anchor, so the companion notebook opened
      # from an example page counts as a distinct activation surface ("example")
      # alongside the docs "Run in Livebook" CTA. This locks the datasets the
      # handler reads; only the Livebook resource carries them.
      livebook_link =
        html
        |> Floki.parse_document!()
        |> Floki.find("a[data-livebook-run='true']")
        |> List.first()

      assert livebook_link != nil,
             "expected the companion Livebook resource to be instrumented for first-open analytics"

      href = Floki.attribute(livebook_link, "href") |> hd()
      assert href =~ "livebook.dev/run?url="
      assert Floki.attribute(livebook_link, "data-analytics-source") |> hd() == "example"
      assert Floki.attribute(livebook_link, "data-analytics-channel") |> hd() == "related_livebook"
      assert Floki.attribute(livebook_link, "data-analytics-target-url") |> hd() == href
    end

    test "tabs patch cleanly for history navigation", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/counter-agent?tab=explanation")

      view
      |> element("a", "Interactive Demo")
      |> render_click()

      assert_patch(view, "/examples/counter-agent?tab=demo")

      view
      |> element("a", "Source Code")
      |> render_click()

      patched = assert_patch(view)
      assert URI.parse(patched).path == "/examples/counter-agent"
      assert URI.parse(patched).query |> URI.decode_query() == %{"source" => "1", "tab" => "source"}
    end

    test "a successful action pushes the first core Agent success signal (jido-e12-t23)",
         %{conn: conn} do
      {:ok, view, html} = live(conn, "/examples/counter-agent?tab=demo")

      demo_view = find_live_child(view, "demo-counter-agent")

      # The demo root carries the CoreAgentRun hook that forwards the success
      # signal to first-party analytics.
      root =
        html
        |> Floki.parse_document!()
        |> Floki.find("#counter-agent-demo")
        |> List.first()

      assert root != nil, "expected the counter-agent demo root to be instrumented"
      assert Floki.attribute(root, "phx-hook") |> hd() == "CoreAgentRun"

      # A successful Jido.Agent.cmd/2 (the increment action) is the explicit
      # success the demo can prove — it must push agent-run-succeeded so the
      # CoreAgentRun hook forwards it as `agent_run_succeeded`, not a page view.
      demo_view
      |> element("#counter-agent-demo button[phx-click='increment']")
      |> render_click()

      assert_push_event(demo_view, "agent-run-succeeded", %{example: "counter-agent"})
    end
  end

  describe "/examples/runic-ai-research-studio" do
    test "renders explanation tab with real workflow guidance", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/examples/runic-ai-research-studio?tab=explanation")

      assert html =~ "Runic AI Research Studio"
      assert html =~ "Jido.Runic.Strategy"
      assert html =~ "PlanQueries"
      assert html =~ "No LLM provider, browser session, or remote network call is required"
    end

    test "renders source tab for the dedicated Runic auto-mode example", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/examples/runic-ai-research-studio?tab=source")

      assert html =~ "fixtures.ex"
      assert html =~ "actions.ex"
      assert html =~ "orchestrator_agent.ex"
      assert html =~ "runtime_demo.ex"
      assert html =~ "runic_research_studio_live.ex"
      refute html =~ "simulated_showcase_live.ex"
    end

    test "demo tab runs the deterministic auto pipeline", %{conn: conn} do
      {:ok, view, html} = live(conn, "/examples/runic-ai-research-studio?tab=demo")

      assert html =~ "Runic AI Research Studio"
      refute html =~ "Simulated demo"

      demo_view = find_live_child(view, "demo-runic-ai-research-studio")

      html =
        demo_view
        |> element("#runic-research-studio-demo button[phx-click='run_pipeline']")
        |> render_click()

      assert html =~ "plan_queries"
      assert html =~ "edit_and_assemble"
      assert html =~ "Concurrency pays off when isolation, supervision, and observability are designed together."
      assert html =~ "Research Sources"
      assert has_element?(demo_view, "#runic-auto-mode", "auto")
    end

    test "example registry metadata resolves new runic auto-mode source files", %{conn: _conn} do
      example = Examples.get_example!("runic-ai-research-studio")

      assert example.title == "Runic AI Research Studio"
      assert example.live_view_module == "AgentJidoWeb.Examples.RunicResearchStudioLive"

      assert example.source_files == [
               "lib/agent_jido/demos/runic_research_studio/fixtures.ex",
               "lib/agent_jido/demos/runic_research_studio/actions.ex",
               "lib/agent_jido/demos/runic_research_studio/orchestrator_agent.ex",
               "lib/agent_jido/demos/runic_research_studio/runtime_demo.ex",
               "lib/agent_jido_web/examples/runic_research_studio_live.ex"
             ]

      assert Enum.map(example.sources, & &1.path) == example.source_files
    end
  end

  describe "/examples/runic-ai-research-studio-step-mode" do
    test "renders explanation tab with real step-mode guidance", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/examples/runic-ai-research-studio-step-mode?tab=explanation")

      assert html =~ "Runic AI Research Studio Step Mode"
      assert html =~ "runic.step"
      assert html =~ "runic.resume"
      assert html =~ "real strategy transitions"
    end

    test "renders source tab for the dedicated Runic step-mode example", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/examples/runic-ai-research-studio-step-mode?tab=source")

      assert html =~ "fixtures.ex"
      assert html =~ "actions.ex"
      assert html =~ "orchestrator_agent.ex"
      assert html =~ "runtime_demo.ex"
      assert html =~ "runic_research_studio_step_mode_live.ex"
      refute html =~ "simulated_showcase_live.ex"
    end

    test "demo tab prepares, steps, and resumes the deterministic workflow", %{conn: conn} do
      {:ok, view, html} = live(conn, "/examples/runic-ai-research-studio-step-mode?tab=demo")

      assert html =~ "Runic AI Research Studio Step Mode"
      refute html =~ "Simulated demo"

      demo_view = find_live_child(view, "demo-runic-ai-research-studio-step-mode")

      html =
        demo_view
        |> element("#runic-research-studio-step-demo button[phx-click='prepare_step']")
        |> render_click()

      assert html =~ "paused"
      assert has_element?(demo_view, "#runic-step-held-count", "1")
      assert html =~ "plan_queries"

      html =
        demo_view
        |> element("#runic-research-studio-step-demo button[phx-click='step_once']")
        |> render_click()

      assert has_element?(demo_view, "#runic-step-history-count", "1")
      assert html =~ "outline_seed"
      assert html =~ "simulate_search"

      html =
        demo_view
        |> element("#runic-research-studio-step-demo button[phx-click='resume_demo']")
        |> render_click()

      assert has_element?(demo_view, "#runic-step-mode", "auto")
      assert html =~ "Research Sources"
      assert html =~ "Concurrency pays off when isolation, supervision, and observability are designed together."
    end

    test "example registry metadata resolves new runic step-mode source files", %{conn: _conn} do
      example = Examples.get_example!("runic-ai-research-studio-step-mode")

      assert example.title == "Runic AI Research Studio Step Mode"
      assert example.live_view_module == "AgentJidoWeb.Examples.RunicResearchStudioStepModeLive"

      assert example.source_files == [
               "lib/agent_jido/demos/runic_research_studio/fixtures.ex",
               "lib/agent_jido/demos/runic_research_studio/actions.ex",
               "lib/agent_jido/demos/runic_research_studio/orchestrator_agent.ex",
               "lib/agent_jido/demos/runic_research_studio/runtime_demo.ex",
               "lib/agent_jido_web/examples/runic_research_studio_step_mode_live.ex"
             ]

      assert Enum.map(example.sources, & &1.path) == example.source_files
    end
  end

  describe "/examples/runic-structured-llm-branching" do
    test "renders explanation tab with real branching guidance", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/examples/runic-structured-llm-branching?tab=explanation")

      assert html =~ "Runic Structured LLM Branching"
      assert html =~ "runic.set_workflow"
      assert html =~ "DirectAnswer"
      assert html =~ "SafeResponse"
      assert html =~ "No LLM provider, browser session, or remote network call is required"
    end

    test "renders source tab for the dedicated branching example", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/examples/runic-structured-llm-branching?tab=source")

      assert html =~ "fixtures.ex"
      assert html =~ "actions.ex"
      assert html =~ "orchestrator_agent.ex"
      assert html =~ "runtime_demo.ex"
      assert html =~ "runic_structured_branching_live.ex"
      refute html =~ "simulated_showcase_live.ex"
    end

    test "demo tab runs the deterministic branching workflow", %{conn: conn} do
      {:ok, view, html} = live(conn, "/examples/runic-structured-llm-branching?tab=demo")

      assert html =~ "Runic Structured LLM Branching"
      refute html =~ "Simulated demo"

      demo_view = find_live_child(view, "demo-runic-structured-llm-branching")

      html =
        demo_view
        |> element("#runic-structured-branching-demo button[phx-click='run_workflow']")
        |> render_click()

      assert has_element?(demo_view, "#runic-branching-selected-branch", "analysis")
      assert has_element?(demo_view, "#runic-branching-selected-workflow", "phase_2_analysis")
      assert html =~ "analysis_plan"
      assert html =~ "analysis_answer"
      assert html =~ "gather more evidence first"
    end

    test "example registry metadata resolves new branching source files", %{conn: _conn} do
      example = Examples.get_example!("runic-structured-llm-branching")

      assert example.title == "Runic Structured LLM Branching"
      assert example.live_view_module == "AgentJidoWeb.Examples.RunicStructuredBranchingLive"

      assert example.source_files == [
               "lib/agent_jido/demos/runic_structured_branching/fixtures.ex",
               "lib/agent_jido/demos/runic_structured_branching/actions.ex",
               "lib/agent_jido/demos/runic_structured_branching/orchestrator_agent.ex",
               "lib/agent_jido/demos/runic_structured_branching/runtime_demo.ex",
               "lib/agent_jido_web/examples/runic_structured_branching_live.ex"
             ]

      assert Enum.map(example.sources, & &1.path) == example.source_files
    end
  end

  describe "/examples/runic-adaptive-researcher" do
    test "renders explanation tab with real adaptive workflow guidance", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/examples/runic-adaptive-researcher?tab=explanation")

      assert html =~ "Runic Adaptive Researcher"
      assert html =~ "runic.set_workflow"
      assert html =~ "full and slim"
      assert html =~ "real local Runic workflow"
    end

    test "renders source tab for the dedicated adaptive example", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/examples/runic-adaptive-researcher?tab=source")

      assert html =~ "fixtures.ex"
      assert html =~ "actions.ex"
      assert html =~ "orchestrator_agent.ex"
      assert html =~ "runtime_demo.ex"
      assert html =~ "runic_adaptive_researcher_live.ex"
      refute html =~ "simulated_showcase_live.ex"
    end

    test "demo tab runs the deterministic adaptive workflow", %{conn: conn} do
      {:ok, view, html} = live(conn, "/examples/runic-adaptive-researcher?tab=demo")

      assert html =~ "Runic Adaptive Researcher"
      refute html =~ "Simulated demo"

      demo_view = find_live_child(view, "demo-runic-adaptive-researcher")

      html =
        demo_view
        |> element("#runic-adaptive-researcher-demo button[phx-click='run_workflow']")
        |> render_click()

      assert has_element?(demo_view, "#runic-adaptive-selected-phase", "full")
      assert has_element?(demo_view, "#runic-adaptive-selected-workflow", "phase_2_full")
      assert html =~ "build_outline"
      assert html =~ "edit_and_assemble"
      assert html =~ "## Research Sources"

      html =
        demo_view
        |> element("button[phx-click='select_topic'][phx-value-topic='release-brief-slim']")
        |> render_click()

      assert html =~ "Release Brief Digest"

      html =
        demo_view
        |> element("#runic-adaptive-researcher-demo button[phx-click='run_workflow']")
        |> render_click()

      assert has_element?(demo_view, "#runic-adaptive-selected-phase", "slim")
      assert has_element?(demo_view, "#runic-adaptive-selected-workflow", "phase_2_slim")
      assert html =~ "Thin research results can skip the outline stage"
    end

    test "example registry metadata resolves new adaptive source files", %{conn: _conn} do
      example = Examples.get_example!("runic-adaptive-researcher")

      assert example.title == "Runic Adaptive Researcher"
      assert example.live_view_module == "AgentJidoWeb.Examples.RunicAdaptiveResearcherLive"

      assert example.source_files == [
               "lib/agent_jido/demos/runic_adaptive_researcher/fixtures.ex",
               "lib/agent_jido/demos/runic_adaptive_researcher/actions.ex",
               "lib/agent_jido/demos/runic_adaptive_researcher/orchestrator_agent.ex",
               "lib/agent_jido/demos/runic_adaptive_researcher/runtime_demo.ex",
               "lib/agent_jido_web/examples/runic_adaptive_researcher_live.ex"
             ]

      assert Enum.map(example.sources, & &1.path) == example.source_files
    end
  end

  describe "/examples/runic-delegating-orchestrator" do
    test "renders explanation tab with real delegation guidance", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/examples/runic-delegating-orchestrator?tab=explanation")

      assert html =~ "Runic Delegating Orchestrator"
      assert html =~ "executor: {:child, tag}"
      assert html =~ "child-worker handoff strategy path"
      assert html =~ "real Runic delegation strategy path locally"
    end

    test "renders source tab for the dedicated delegating example", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/examples/runic-delegating-orchestrator?tab=source")

      assert html =~ "fixtures.ex"
      assert html =~ "actions.ex"
      assert html =~ "orchestrator_agent.ex"
      assert html =~ "runtime_demo.ex"
      assert html =~ "runic_delegating_orchestrator_live.ex"
      refute html =~ "simulated_showcase_live.ex"
    end

    test "demo tab runs the deterministic delegating workflow", %{conn: conn} do
      {:ok, view, html} = live(conn, "/examples/runic-delegating-orchestrator?tab=demo")

      assert html =~ "Runic Delegating Orchestrator"
      refute html =~ "Simulated demo"

      demo_view = find_live_child(view, "demo-runic-delegating-orchestrator")

      html =
        demo_view
        |> element("#runic-delegating-orchestrator-demo button[phx-click='run_workflow']")
        |> render_click()

      assert has_element?(demo_view, "#runic-delegating-local-count", "3")
      assert has_element?(demo_view, "#runic-delegating-delegated-count", "2")
      assert html =~ "child:drafter"
      assert html =~ "child:editor"
      assert html =~ "## Research Sources"
    end

    test "example registry metadata resolves new delegating source files", %{conn: _conn} do
      example = Examples.get_example!("runic-delegating-orchestrator")

      assert example.title == "Runic Delegating Orchestrator"
      assert example.live_view_module == "AgentJidoWeb.Examples.RunicDelegatingOrchestratorLive"

      assert example.source_files == [
               "lib/agent_jido/demos/runic_research_studio/fixtures.ex",
               "lib/agent_jido/demos/runic_research_studio/actions.ex",
               "lib/agent_jido/demos/runic_delegating_orchestrator/orchestrator_agent.ex",
               "lib/agent_jido/demos/runic_delegating_orchestrator/runtime_demo.ex",
               "lib/agent_jido_web/examples/runic_delegating_orchestrator_live.ex"
             ]

      assert Enum.map(example.sources, & &1.path) == example.source_files
    end
  end

  describe "/examples/jido-ai-weather-multi-turn-context" do
    test "renders explanation tab with real local weather-tool guidance", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/examples/jido-ai-weather-multi-turn-context?tab=explanation")

      assert html =~ "Jido.AI Weather Multi-Turn Context"
      assert html =~ "real local weather assistant workflow"
      assert html =~ "context carryover"
      assert html =~ "retry/backoff"
    end

    test "renders source tab for the dedicated weather example", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/examples/jido-ai-weather-multi-turn-context?tab=source")

      assert html =~ "fixtures.ex"
      assert html =~ "forecast_action.ex"
      assert html =~ "weather_assistant.ex"
      assert html =~ "runtime_demo.ex"
      assert html =~ "weather_multi_turn_context_live.ex"
      refute html =~ "simulated_showcase_live.ex"
    end

    test "demo tab preserves context and records the deterministic retry", %{conn: conn} do
      {:ok, view, html} = live(conn, "/examples/jido-ai-weather-multi-turn-context?tab=demo")

      assert html =~ "Jido.AI Weather Multi-Turn Context"
      refute html =~ "Simulated demo"

      demo_view = find_live_child(view, "demo-jido-ai-weather-multi-turn-context")

      html =
        demo_view
        |> element("#weather-multi-turn-context-demo button[phx-click='run_all']")
        |> render_click()

      assert has_element?(demo_view, "#weather-context-city", "Seattle")
      assert has_element?(demo_view, "#weather-turn-count", "3")
      assert has_element?(demo_view, "#weather-retry-count", "1")
      assert html =~ "Should I bring an umbrella?"
      assert html =~ "Seattle"
      assert html =~ "outdoor"
      assert html =~ "indoor"
    end

    test "example registry metadata resolves new weather source files", %{conn: _conn} do
      example = Examples.get_example!("jido-ai-weather-multi-turn-context")

      assert example.title == "Jido.AI Weather Multi-Turn Context"
      assert example.live_view_module == "AgentJidoWeb.Examples.WeatherMultiTurnContextLive"

      assert example.source_files == [
               "lib/agent_jido/demos/weather_multi_turn_context/fixtures.ex",
               "lib/agent_jido/demos/weather_multi_turn_context/forecast_action.ex",
               "lib/agent_jido/demos/weather_multi_turn_context/weather_assistant.ex",
               "lib/agent_jido/demos/weather_multi_turn_context/runtime_demo.ex",
               "lib/agent_jido_web/examples/weather_multi_turn_context_live.ex"
             ]

      assert Enum.map(example.sources, & &1.path) == example.source_files
    end
  end

  describe "/examples/jido-ai-browser-web-workflow" do
    test "renders explanation tab with live-browser requirements and fallback guidance", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/examples/jido-ai-browser-web-workflow?tab=explanation")

      assert html =~ "Jido Browser Docs Scout Agent"
      assert html =~ "agentjido/jido_browser"
      assert html =~ "Jido.Browser.Plugin"
      assert html =~ "jido_browser.install --if-missing"
      assert html =~ "No API keys or browser binaries are required for this site demo."
      assert html =~ "without refetching the URL"
      assert html =~ "keep the simulated adapter wired in dev/test"
    end

    test "renders source tab for the dedicated browser example", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/examples/jido-ai-browser-web-workflow?tab=source")

      assert html =~ "browser_docs_scout_agent.ex"
      assert html =~ "browser_actions.ex"
      assert html =~ "simulated_adapter.ex"
      assert html =~ "browser_docs_scout_agent_live.ex"
    end

    test "demo tab runs the deterministic browser flow", %{conn: conn} do
      {:ok, view, html} = live(conn, "/examples/jido-ai-browser-web-workflow?tab=demo")

      assert html =~ "Jido Browser Docs Scout Agent"
      assert html =~ "Simulated demo"

      demo_view = find_live_child(view, "demo-jido-ai-browser-web-workflow")

      html =
        demo_view
        |> element("#browser-docs-scout-demo button[phx-click='open_intro']")
        |> render_click()

      assert html =~ "Jido Browser Plugin Guide"
      assert html =~ "session:"

      html =
        demo_view
        |> element("#browser-docs-scout-demo button[phx-click='extract_article']")
        |> render_click()

      assert html =~ "chars"
      assert html =~ "Jido.Browser.Plugin"

      html =
        demo_view
        |> element("#browser-docs-scout-demo button[phx-click='follow_link']")
        |> render_click()

      assert html =~ "Testing Browser Agents"
      assert html =~ "3 step(s)"

      html =
        demo_view
        |> element("#browser-docs-scout-demo button[phx-click='capture_screenshot']")
        |> render_click()

      assert html =~ "data:image/png;base64,"

      html =
        demo_view
        |> element("#browser-docs-scout-demo button[phx-click='reset_demo']")
        |> render_click()

      assert html =~ "No docs page opened yet"
      assert html =~ "session: idle"
    end

    test "demo panel carries a clear simulated-mode label (jido-e08-t16)", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/jido-ai-browser-web-workflow?tab=demo")

      demo_view = find_live_child(view, "demo-jido-ai-browser-web-workflow")
      panel_html = render(demo_view)

      # The browser panel self-labels its simulated output so the deterministic
      # fixture trace is never read as a live provider/browser result.
      assert panel_html =~ ~s(id="browser-demo-simulated-label")
      assert panel_html =~ "simulated"
    end

    test "example registry metadata resolves new browser source files", %{conn: _conn} do
      example = Examples.get_example!("jido-ai-browser-web-workflow")

      assert example.title == "Jido Browser Docs Scout Agent"
      assert example.live_view_module == "AgentJidoWeb.Examples.BrowserDocsScoutAgentLive"

      assert example.source_files == [
               "lib/agent_jido/demos/browser_docs_scout/browser_docs_scout_agent.ex",
               "lib/agent_jido/demos/browser_docs_scout/browser_actions.ex",
               "lib/agent_jido/demos/browser_docs_scout/simulated_adapter.ex",
               "lib/agent_jido_web/examples/browser_docs_scout_agent_live.ex"
             ]

      assert Enum.map(example.sources, & &1.path) == example.source_files
    end
  end

  describe "simulated-mode labeling (jido-e08-t16)" do
    test "every live simulated example labels its demo so output is never read as a live provider result",
         %{conn: conn} do
      # Only public (live) examples can present output to a visitor, so the
      # contract is enforced over Examples.all_examples/0, which is already
      # filtered to status == :live.
      live_simulated =
        Examples.all_examples()
        |> Enum.filter(&(&1.demo_mode == :simulated))

      assert live_simulated != [],
             "expected at least one live simulated example to exercise the simulated-mode label"

      for example <- live_simulated do
        {:ok, _view, html} = live(conn, "/examples/#{example.slug}?tab=demo")

        assert html =~ "Simulated demo",
               "live simulated example #{inspect(example.slug)} must label its demo as simulated"
      end
    end
  end

  describe "/examples/jido-ai-actions-runtime-demos" do
    test "renders explanation tab with real runtime and fixture guidance", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/examples/jido-ai-actions-runtime-demos?tab=explanation")

      assert html =~ "Jido.AI Actions Runtime Demos"
      assert html =~ "Jido.Exec.run/3"
      assert html =~ "Retrieval and quota use the shipped"
      assert html =~ "fixture-backed families"
    end

    test "renders source tab for the dedicated actions runtime example", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/examples/jido-ai-actions-runtime-demos?tab=source")

      assert html =~ "runtime_demo.ex"
      assert html =~ "fixture_actions.ex"
      assert html =~ "convert_temperature_action.ex"
      assert html =~ "actions_runtime_demo_live.ex"
    end

    test "demo tab runs deterministic runtime families", %{conn: conn} do
      {:ok, view, html} = live(conn, "/examples/jido-ai-actions-runtime-demos?tab=demo")

      assert html =~ "Jido.AI Actions Runtime Demos"
      refute html =~ "Simulated demo"

      demo_view = find_live_child(view, "demo-jido-ai-actions-runtime-demos")

      html =
        demo_view
        |> element("#actions-runtime-demo button[phx-value-family='llm']")
        |> render_click()

      assert html =~ "LLM envelopes"
      assert html =~ "FixtureChatAction"
      assert html =~ "fixture:haiku"

      html =
        demo_view
        |> element("#actions-runtime-demo button[phx-value-family='tool_calling']")
        |> render_click()

      assert html =~ "convert_temperature"
      assert html =~ "22.2"

      html =
        demo_view
        |> element("#actions-runtime-demo button[phx-click='run_all']")
        |> render_click()

      assert html =~ "6 / 6 families completed"
      assert html =~ "Quota usage and reset"
      assert html =~ "GetStatus After Reset"
    end

    test "example registry metadata resolves new runtime source files", %{conn: _conn} do
      example = Examples.get_example!("jido-ai-actions-runtime-demos")

      assert example.title == "Jido.AI Actions Runtime Demos"
      assert example.live_view_module == "AgentJidoWeb.Examples.ActionsRuntimeDemoLive"

      assert example.source_files == [
               "lib/agent_jido/demos/actions_runtime/runtime_demo.ex",
               "lib/agent_jido/demos/actions_runtime/fixture_actions.ex",
               "lib/agent_jido/demos/actions_runtime/convert_temperature_action.ex",
               "lib/agent_jido_web/examples/actions_runtime_demo_live.ex"
             ]

      assert Enum.map(example.sources, & &1.path) == example.source_files
    end
  end

  describe "/examples/jido-ai-task-execution-workflow" do
    test "renders explanation tab with real tasklist lifecycle guidance", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/examples/jido-ai-task-execution-workflow?tab=explanation")

      assert html =~ "Jido.AI Task Execution Workflow"
      assert html =~ "Jido.Exec.run/3"
      assert html =~ "tasklist_add_tasks"
      assert html =~ "tasklist_complete_task"
      assert html =~ "No external providers, API keys, or network access are required for this demo."
    end

    test "renders source tab for the dedicated task workflow example", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/examples/jido-ai-task-execution-workflow?tab=source")

      assert html =~ "workflow.ex"
      assert html =~ "task_execution_workflow_live.ex"
      refute html =~ "simulated_showcase_live.ex"
    end

    test "demo tab runs deterministic task lifecycle transitions", %{conn: conn} do
      {:ok, view, html} = live(conn, "/examples/jido-ai-task-execution-workflow?tab=demo")

      assert html =~ "Jido.AI Task Execution Workflow"
      refute html =~ "Simulated demo"

      demo_view = find_live_child(view, "demo-jido-ai-task-execution-workflow")

      html =
        demo_view
        |> element("#task-execution-demo button[phx-click='seed_tasks']")
        |> render_click()

      assert html =~ "Validate release metadata"
      assert html =~ "3 total task(s)"

      html =
        demo_view
        |> element("#task-execution-demo button[phx-click='start_next']")
        |> render_click()

      assert html =~ "Started task: Validate release metadata"
      assert html =~ "in_progress"

      html =
        demo_view
        |> element("#task-execution-demo button[phx-click='complete_active']")
        |> render_click()

      assert html =~ "Completed task: Validate release metadata"
      assert html =~ "Completed workflow step 1 for Validate release metadata."

      html =
        demo_view
        |> element("#task-execution-demo button[phx-click='run_full_workflow']")
        |> render_click()

      assert html =~ "Workflow reached all_complete."
      assert html =~ "All 3 tasks are complete!"
      assert has_element?(demo_view, "#task-all-complete", "yes")
    end

    test "example registry metadata resolves new task workflow source files", %{conn: _conn} do
      example = Examples.get_example!("jido-ai-task-execution-workflow")

      assert example.title == "Jido.AI Task Execution Workflow"
      assert example.live_view_module == "AgentJidoWeb.Examples.TaskExecutionWorkflowLive"

      assert example.source_files == [
               "lib/agent_jido/demos/task_execution/workflow.ex",
               "lib/agent_jido_web/examples/task_execution_workflow_live.ex"
             ]

      assert Enum.map(example.sources, & &1.path) == example.source_files
    end
  end

  describe "/examples/jido-ai-skills-runtime-foundations" do
    test "renders explanation tab with real skills runtime guidance", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/examples/jido-ai-skills-runtime-foundations?tab=explanation")

      assert html =~ "Jido.AI Skills Runtime Foundations"
      assert html =~ "Jido.AI.Skill.Loader.load/1"
      assert html =~ "Jido.AI.Skill.Registry.load_from_paths/1"
      assert html =~ "Jido.AI.Skill.Prompt.render/2"
      assert html =~ "priv/skills/builder-*/SKILL.md"
      assert html =~ "jido_skill"
      assert html =~ "No API keys, LLM providers, or network access are required for this example."
    end

    test "renders source tab for the dedicated skills runtime example", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/examples/jido-ai-skills-runtime-foundations?tab=source")

      assert html =~ "calculator_skill.ex"
      assert html =~ "runtime_demo.ex"
      assert html =~ "skills_runtime_foundations_live.ex"
      assert html =~ "jido_skill.md"
      assert html =~ "SKILL.md"
      refute html =~ "simulated_showcase_live.ex"
    end

    test "demo tab runs the deterministic skills runtime and builder workflow flows", %{conn: conn} do
      {:ok, view, html} = live(conn, "/examples/jido-ai-skills-runtime-foundations?tab=demo")

      assert html =~ "Jido.AI Skills Runtime Foundations"
      refute html =~ "Simulated demo"

      demo_view = find_live_child(view, "demo-jido-ai-skills-runtime-foundations")

      html =
        demo_view
        |> element("#skills-runtime-foundations-demo button[phx-click='load_file_manifest']")
        |> render_click()

      assert html =~ "demo-code-review"
      assert html =~ "git_diff"

      html =
        demo_view
        |> element("#skills-runtime-foundations-demo button[phx-click='register_module_skill']")
        |> render_click()

      assert html =~ "demo-runtime-calculator"
      assert html =~ "Registered demo-runtime-calculator"

      html =
        demo_view
        |> element("#skills-runtime-foundations-demo button[phx-click='load_runtime_skills']")
        |> render_click()

      assert html =~ "Loaded 2 SKILL.md file(s)"
      assert html =~ "demo-release-notes"
      assert html =~ "3 skill(s)"

      html =
        demo_view
        |> element("#skills-runtime-foundations-demo button[phx-click='render_prompt']")
        |> render_click()

      assert html =~ "You have access to the following skills:"
      assert html =~ "demo-runtime-calculator"
      assert html =~ "demo-code-review"
      assert html =~ "format_release_notes"

      html =
        demo_view
        |> element("#skills-runtime-foundations-demo button[phx-click='load_builder_catalog']")
        |> render_click()

      assert html =~ "Loaded 7 builder SKILL.md file(s)"
      assert html =~ "builder-action-scaffold"
      assert html =~ "builder-package-review"

      html =
        demo_view
        |> element("#skills-runtime-foundations-demo button[phx-click='run_builder_workflow']")
        |> render_click()

      assert html =~ "Refresh Jido Skill package coverage"
      assert html =~ "priv/ecosystem/jido_skill.md"
      assert html =~ "builder-ecosystem-page-author"
      assert html =~ "Builder Ecosystem Page Author"
      assert html =~ "Jido.AI, jido_skill, Codex"
    end

    test "example registry metadata resolves new skills runtime source files", %{conn: _conn} do
      example = Examples.get_example!("jido-ai-skills-runtime-foundations")

      assert example.title == "Jido.AI Skills Runtime Foundations"
      assert example.live_view_module == "AgentJidoWeb.Examples.SkillsRuntimeFoundationsLive"

      assert example.source_files == [
               "lib/agent_jido/demos/skills_runtime_foundations/calculator_skill.ex",
               "lib/agent_jido/demos/skills_runtime_foundations/runtime_demo.ex",
               "lib/agent_jido_web/examples/skills_runtime_foundations_live.ex",
               "priv/ecosystem/jido_skill.md",
               "priv/skills/builder-action-scaffold/SKILL.md",
               "priv/skills/builder-agent-scaffold/SKILL.md",
               "priv/skills/builder-plugin-scaffold/SKILL.md",
               "priv/skills/builder-adapter-package/SKILL.md",
               "priv/skills/builder-ecosystem-page-author/SKILL.md",
               "priv/skills/builder-example-tutorial-author/SKILL.md",
               "priv/skills/builder-package-review/SKILL.md",
               "priv/skills/skills-runtime-foundations/demo-code-review/SKILL.md",
               "priv/skills/skills-runtime-foundations/demo-release-notes/SKILL.md"
             ]

      assert Enum.map(example.sources, & &1.path) == example.source_files
    end
  end

  describe "/examples/jido-ai-skills-multi-agent-orchestration" do
    test "renders explanation tab with real orchestration guidance", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/examples/jido-ai-skills-multi-agent-orchestration?tab=explanation")

      assert html =~ "Jido.AI Skills Multi-Agent Orchestration"
      assert html =~ "Jido.AI.Skill.Registry.load_from_paths/1"
      assert html =~ "Jido.AI.Skill.Prompt.render/2"
      assert html =~ "No API keys, LLM providers, or network access are required for this example."
    end

    test "renders source tab for the dedicated orchestration example", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/examples/jido-ai-skills-multi-agent-orchestration?tab=source")

      assert html =~ "arithmetic_skill.ex"
      assert html =~ "conversion_specialist.ex"
      assert html =~ "endurance_planner_skill.ex"
      assert html =~ "orchestrator.ex"
      assert html =~ "skills_multi_agent_orchestration_live.ex"
      assert html =~ "SKILL.md"
      refute html =~ "simulated_showcase_live.ex"
    end

    test "demo tab runs deterministic routing across the three fixed scenarios", %{conn: conn} do
      {:ok, view, html} = live(conn, "/examples/jido-ai-skills-multi-agent-orchestration?tab=demo")

      assert html =~ "Jido.AI Skills Multi-Agent Orchestration"
      refute html =~ "Simulated demo"
      assert html =~ "registry: 3 skill(s)"

      demo_view = find_live_child(view, "demo-jido-ai-skills-multi-agent-orchestration")

      html =
        demo_view
        |> element("#skills-multi-agent-orchestration-demo button[phx-click='run_arithmetic']")
        |> render_click()

      assert html =~ "42 * 17 + 100"
      assert html =~ "demo-orchestrator-arithmetic"
      assert html =~ "multiply"
      assert html =~ "814"

      html =
        demo_view
        |> element("#skills-multi-agent-orchestration-demo button[phx-click='run_conversion']")
        |> render_click()

      assert html =~ "98.6 degrees Fahrenheit"
      assert html =~ "demo-unit-converter"
      assert html =~ "convert_temperature"
      assert html =~ "37.0"

      html =
        demo_view
        |> element("#skills-multi-agent-orchestration-demo button[phx-click='run_combined']")
        |> render_click()

      assert html =~ "5 kilometers"
      assert html =~ "demo-endurance-planner"
      assert html =~ "convert_distance"
      assert html =~ "estimate_calories"
      assert html =~ "3.11 miles"
      assert html =~ "311 calories"
    end

    test "example registry metadata resolves new orchestration source files", %{conn: _conn} do
      example = Examples.get_example!("jido-ai-skills-multi-agent-orchestration")

      assert example.title == "Jido.AI Skills Multi-Agent Orchestration"
      assert example.live_view_module == "AgentJidoWeb.Examples.SkillsMultiAgentOrchestrationLive"

      assert example.source_files == [
               "lib/agent_jido/demos/skills_multi_agent_orchestration/arithmetic_skill.ex",
               "lib/agent_jido/demos/skills_multi_agent_orchestration/conversion_specialist.ex",
               "lib/agent_jido/demos/skills_multi_agent_orchestration/endurance_planner_skill.ex",
               "lib/agent_jido/demos/skills_multi_agent_orchestration/orchestrator.ex",
               "lib/agent_jido_web/examples/skills_multi_agent_orchestration_live.ex",
               "priv/skills/skills-multi-agent-orchestration/demo-unit-converter/SKILL.md"
             ]

      assert Enum.map(example.sources, & &1.path) == example.source_files
    end
  end

  describe "/examples/jido-ai-weather-reasoning-strategy-suite" do
    test "renders explanation tab with explicit comparison framing", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/examples/jido-ai-weather-reasoning-strategy-suite?tab=explanation")

      assert html =~ "Jido.AI Weather Reasoning Strategy Suite"
      assert html =~ "deterministic comparison lab"
      assert html =~ "not one copy-pasteable weather agent implementation"
      assert html =~ "The source tab shows the actual comparison harness"
    end

    test "renders source tab for the dedicated comparison harness", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/examples/jido-ai-weather-reasoning-strategy-suite?tab=source")

      assert html =~ "fixtures.ex"
      assert html =~ "comparison_lab.ex"
      assert html =~ "weather_reasoning_strategy_suite_live.ex"
      refute html =~ "simulated_showcase_live.ex"
    end

    test "demo tab switches presets and strategy details without simulated framing", %{conn: conn} do
      {:ok, view, html} = live(conn, "/examples/jido-ai-weather-reasoning-strategy-suite?tab=demo")

      assert html =~ "Jido.AI Weather Reasoning Strategy Suite"
      refute html =~ "Simulated demo"
      assert html =~ "reference"
      assert html =~ "Commuter Decision"
      assert has_element?(view, "#weather-reasoning-recommended-strategy", "CoT")

      demo_view = find_live_child(view, "demo-jido-ai-weather-reasoning-strategy-suite")

      html =
        demo_view
        |> element("#weather-reasoning-strategy-suite-demo button[phx-value-preset='weekend-trip']")
        |> render_click()

      assert html =~ "Weekend Trip Planning"
      assert html =~ "ToT"

      html =
        demo_view
        |> element("#weather-reasoning-strategy-suite-demo button[phx-value-strategy='adaptive']")
        |> render_click()

      assert html =~ ~s(id="weather-reasoning-selected-strategy")
      assert html =~ "Adaptive"
      assert html =~ "route to ToT or GoT automatically"
    end

    test "example registry metadata resolves comparison source files", %{conn: _conn} do
      example = Examples.get_example!("jido-ai-weather-reasoning-strategy-suite")

      assert example.title == "Jido.AI Weather Reasoning Strategy Suite"
      assert example.live_view_module == "AgentJidoWeb.Examples.WeatherReasoningStrategySuiteLive"
      assert example.evidence_surface == :docs_reference
      assert example.demo_mode == :real

      assert example.source_files == [
               "lib/agent_jido/demos/weather_reasoning_strategy_suite/fixtures.ex",
               "lib/agent_jido/demos/weather_reasoning_strategy_suite/comparison_lab.ex",
               "lib/agent_jido_web/examples/weather_reasoning_strategy_suite_live.ex"
             ]

      assert Enum.map(example.sources, & &1.path) == example.source_files
    end
  end

  describe "/examples/jido-ai-operational-agents-pack" do
    test "renders explanation tab with explicit overview framing", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/examples/jido-ai-operational-agents-pack?tab=explanation")

      assert html =~ "Jido.AI Operational Agents Pack"
      assert html =~ "This page is an overview/index."
      assert html =~ "not one runnable"
      assert html =~ "Use those linked pages when you want runnable proof"
    end

    test "renders source tab for the dedicated operational index modules", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/examples/jido-ai-operational-agents-pack?tab=source")

      assert html =~ "catalog.ex"
      assert html =~ "operational_agents_pack_live.ex"
      refute html =~ "simulated_showcase_live.ex"
    end

    test "demo tab selects deterministic local example cards and exposes real routes", %{conn: conn} do
      {:ok, view, html} = live(conn, "/examples/jido-ai-operational-agents-pack?tab=demo")

      assert html =~ "Jido.AI Operational Agents Pack"
      refute html =~ "Simulated demo"
      assert html =~ "overview"
      assert html =~ "Jido.AI Task Execution Workflow"
      assert has_element?(view, "#operational-selected-route", "/examples/jido-ai-task-execution-workflow")

      demo_view = find_live_child(view, "demo-jido-ai-operational-agents-pack")

      html =
        demo_view
        |> element("#operational-agents-pack-demo button[phx-value-entry='schedule-directive']")
        |> render_click()

      assert html =~ "Schedule Directive Agent"
      assert html =~ "/examples/schedule-directive-agent"
      assert html =~ "schedule directives"

      html =
        demo_view
        |> element("#operational-agents-pack-demo button[phx-value-entry='persistence-storage']")
        |> render_click()

      assert html =~ "Persistence Storage Agent"
      assert html =~ "/examples/persistence-storage-agent"
      assert html =~ "durable storage"
      assert html =~ "API Smoke Test Agent"
      assert html =~ "Issue Triage Agent"
      assert html =~ "Release Notes Agent"
    end

    test "example registry metadata resolves operational index source files", %{conn: _conn} do
      example = Examples.get_example!("jido-ai-operational-agents-pack")

      assert example.title == "Jido.AI Operational Agents Pack"
      assert example.live_view_module == "AgentJidoWeb.Examples.OperationalAgentsPackLive"
      assert example.evidence_surface == :docs_reference
      assert example.demo_mode == :real

      assert example.source_files == [
               "lib/agent_jido/demos/operational_agents_pack/catalog.ex",
               "lib/agent_jido_web/examples/operational_agents_pack_live.ex"
             ]

      assert Enum.map(example.sources, & &1.path) == example.source_files
    end
  end

  describe "/examples/coding-assistant (jido-e08-t24)" do
    # Acceptance condition: "The home coding card has a direct destination."
    # The coding card now routes to a real, runnable coding example.

    test "is registered as a live runnable example with a real demo module" do
      example = Examples.get_example!("coding-assistant")

      assert example.status == :live
      assert example.demo_mode == :real
      assert example.live_view_module == "AgentJidoWeb.Examples.CodingAssistantLive"
      # The shared simulated showcase surface is reserved for drafts; this
      # published example runs on its own real-runtime module instead.
      refute example.live_view_module == "AgentJidoWeb.Examples.SimulatedShowcaseLive"
      assert Enum.map(example.sources, & &1.path) == example.source_files
      assert Enum.all?(example.source_files, &File.exists?/1)
    end

    test "is routable for public visitors and renders its demo", %{conn: conn} do
      {:ok, view, html} = live(conn, "/examples/coding-assistant?tab=demo")

      assert html =~ "Coding Assistant"
      refute html =~ "draft preview"

      demo_view = find_live_child(view, "demo-coding-assistant")
      demo_html = render(demo_view)

      # The dedicated demo module renders the real-runtime coding workflow.
      assert demo_html =~ "Coding Assistant Agent"
      assert demo_html =~ "Read fixture"
      assert demo_html =~ "Analyze code"
      assert demo_html =~ "Propose patch"
    end
  end

  describe "/examples/document-processor (jido-e08-t26)" do
    # Acceptance condition: "The home documents card has a direct destination."
    # The documents card now routes to a real, runnable document-processing example.

    test "is registered as a live runnable example with a real demo module" do
      example = Examples.get_example!("document-processor")

      assert example.status == :live
      assert example.demo_mode == :real
      assert example.live_view_module == "AgentJidoWeb.Examples.DocumentProcessorLive"
      # The shared simulated showcase surface is reserved for drafts; this
      # published example runs on its own real-runtime module instead.
      refute example.live_view_module == "AgentJidoWeb.Examples.SimulatedShowcaseLive"
      assert Enum.map(example.sources, & &1.path) == example.source_files
      assert Enum.all?(example.source_files, &File.exists?/1)
    end

    test "is routable for public visitors and renders its demo", %{conn: conn} do
      {:ok, view, html} = live(conn, "/examples/document-processor?tab=demo")

      assert html =~ "Document Processor"
      refute html =~ "draft preview"

      demo_view = find_live_child(view, "demo-document-processor")
      demo_html = render(demo_view)

      # The dedicated demo module renders the real-runtime document pipeline.
      assert demo_html =~ "Document Processor Agent"
      assert demo_html =~ "Load invoice"
      assert demo_html =~ "Classify"
      assert demo_html =~ "Route"
    end

    test "the demo runs the real classify step on a loaded document", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/document-processor?tab=demo")

      demo_view = find_live_child(view, "demo-document-processor")

      # Load an invoice, then classify it on the real runtime.
      render_click(demo_view, "load_invoice")
      render_click(demo_view, "classify")

      demo_html = render(demo_view)

      # The real keyword-scored classification appears, not a canned label.
      assert demo_html =~ "type: invoice"
    end
  end

  describe "/examples/support-triage-agent (jido-e08-t27)" do
    # Acceptance condition: "The home support card has a direct destination."
    # The support card now routes to a real, runnable support-triage example.

    test "is registered as a live runnable example with a real demo module" do
      example = Examples.get_example!("support-triage-agent")

      assert example.status == :live
      assert example.demo_mode == :real
      assert example.live_view_module == "AgentJidoWeb.Examples.SupportTriageAgentLive"
      # The shared simulated showcase surface is reserved for drafts; this
      # published example runs on its own real-runtime module instead.
      refute example.live_view_module == "AgentJidoWeb.Examples.SimulatedShowcaseLive"
      assert Enum.map(example.sources, & &1.path) == example.source_files
      assert Enum.all?(example.source_files, &File.exists?/1)
    end

    test "is routable for public visitors and renders its demo", %{conn: conn} do
      {:ok, view, html} = live(conn, "/examples/support-triage-agent?tab=demo")

      assert html =~ "Support Triage Agent"
      refute html =~ "draft preview"

      demo_view = find_live_child(view, "demo-support-triage-agent")
      demo_html = render(demo_view)

      # The dedicated demo module renders the real-runtime support triage.
      assert demo_html =~ "Support Triage Agent"
      assert demo_html =~ "Load billing"
      assert demo_html =~ "Classify"
      assert demo_html =~ "Respond"
    end

    test "the demo runs the real classify step on a loaded message", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/support-triage-agent?tab=demo")

      demo_view = find_live_child(view, "demo-support-triage-agent")

      # Load a billing message, then classify it on the real runtime.
      render_click(demo_view, "load_billing")
      render_click(demo_view, "classify")

      demo_html = render(demo_view)

      # The real keyword-scored intent appears, not a canned label.
      assert demo_html =~ "intent: billing"
    end
  end

  describe "/examples/operations-agent (jido-e08-t28)" do
    # Acceptance condition: "The home operations card links to a scoped, safe
    # workflow." The operations (devops) card's scoped destination now lands on a
    # real, runnable, safe operations-remediation workflow.

    test "is registered as a live runnable example with a real demo module" do
      example = Examples.get_example!("operations-agent")

      assert example.status == :live
      assert example.demo_mode == :real
      assert example.live_view_module == "AgentJidoWeb.Examples.OpsRemediationAgentLive"
      # The shared simulated showcase surface is reserved for drafts; this
      # published example runs on its own real-runtime module instead.
      refute example.live_view_module == "AgentJidoWeb.Examples.SimulatedShowcaseLive"
      assert Enum.map(example.sources, & &1.path) == example.source_files
      assert Enum.all?(example.source_files, &File.exists?/1)
    end

    test "is routable for public visitors and renders its demo", %{conn: conn} do
      {:ok, view, html} = live(conn, "/examples/operations-agent?tab=demo")

      assert html =~ "Operations Remediation Agent"
      refute html =~ "draft preview"

      demo_view = find_live_child(view, "demo-operations-agent")
      demo_html = render(demo_view)

      # The dedicated demo module renders the real-runtime operations workflow.
      assert demo_html =~ "Operations Remediation Agent"
      assert demo_html =~ "Load latency spike"
      assert demo_html =~ "Detect"
      assert demo_html =~ "Remediate"
      assert demo_html =~ "Verify"
    end

    test "the demo runs the real detect step on a loaded snapshot", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/operations-agent?tab=demo")

      demo_view = find_live_child(view, "demo-operations-agent")

      # Load a latency spike, then detect it on the real runtime.
      render_click(demo_view, "load_latency")
      render_click(demo_view, "detect")

      demo_html = render(demo_view)

      # The real threshold-breached status appears, not a canned label.
      assert demo_html =~ "status: degraded"
    end
  end

  describe "/examples/data-pipeline-agent (jido-e08-t29)" do
    # Acceptance condition: "The home data card has a direct destination." The
    # data-pipelines card's scoped destination now lands on a real, runnable
    # collect -> validate -> transform -> load -> summarize pipeline.

    test "is registered as a live runnable example with a real demo module" do
      example = Examples.get_example!("data-pipeline-agent")

      assert example.status == :live
      assert example.demo_mode == :real
      assert example.live_view_module == "AgentJidoWeb.Examples.DataPipelineAgentLive"
      # The shared simulated showcase surface is reserved for drafts; this
      # published example runs on its own real-runtime module instead.
      refute example.live_view_module == "AgentJidoWeb.Examples.SimulatedShowcaseLive"
      assert Enum.map(example.sources, & &1.path) == example.source_files
      assert Enum.all?(example.source_files, &File.exists?/1)
    end

    test "is routable for public visitors and renders its demo", %{conn: conn} do
      {:ok, view, html} = live(conn, "/examples/data-pipeline-agent?tab=demo")

      assert html =~ "Data Pipeline Agent"
      refute html =~ "draft preview"

      demo_view = find_live_child(view, "demo-data-pipeline-agent")
      demo_html = render(demo_view)

      # The dedicated demo module renders the real-runtime ETL workflow.
      assert demo_html =~ "Data Pipeline Agent"
      assert demo_html =~ "Collect all sources"
      assert demo_html =~ "Validate"
      assert demo_html =~ "Transform"
      assert demo_html =~ "Load"
      assert demo_html =~ "Summarize"
    end

    test "the demo runs the real validate step on a collected batch", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/data-pipeline-agent?tab=demo")

      demo_view = find_live_child(view, "demo-data-pipeline-agent")

      # Collect all sources, then validate on the real runtime.
      render_click(demo_view, "ingest_all")
      render_click(demo_view, "validate")

      demo_html = render(demo_view)

      # The real schema check rejects the malformed records, not a canned label.
      assert demo_html =~ "reject: orders record missing customer"
    end
  end

  describe "/examples/failure-drill-agent" do
    test "renders explanation tab", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/examples/failure-drill-agent?tab=explanation")

      assert html =~ "Failure Drill Agent"
      assert html =~ "AgentServer"
      assert html =~ "supervisor"
    end

    test "renders source tab with the drill implementation", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/examples/failure-drill-agent?tab=source")

      assert html =~ "failure_drill_agent.ex"
      assert html =~ "tick_action.ex"
      assert html =~ "supervisor.ex"
      assert html =~ "failure_drill_agent_live.ex"
    end

    test "is registered as a live runnable example with a real demo module", _conn do
      example = Examples.get_example!("failure-drill-agent")

      assert example.status == :live
      assert example.demo_mode == :real
      assert example.live_view_module == "AgentJidoWeb.Examples.FailureDrillAgentLive"
      assert Enum.map(example.sources, & &1.path) == example.source_files
      assert Enum.all?(example.source_files, &File.exists?/1)
    end

    test "demo tab ticks the counter, then crashes with a supervised restart", %{conn: conn} do
      {:ok, view, html} = live(conn, "/examples/failure-drill-agent?tab=demo")

      assert html =~ "Failure Drill Agent"
      refute html =~ "Simulated demo"

      demo_view = find_live_child(view, "demo-failure-drill-agent")

      Enum.each(1..3, fn _ ->
        demo_view
        |> element("#failure-drill-tick-btn")
        |> render_click()
      end)

      # Three ticks land in the supervised agent's in-memory state.
      assert element_cell(demo_view, "failure-drill-ticks") =~ ~r/>\s*3\s*</

      crash_html =
        demo_view
        |> element("#failure-drill-crash-btn")
        |> render_click()

      assert crash_html =~ "restart"
      # OTP restarted the process; the in-memory counter is gone.
      assert render(demo_view) =~ "ticks reset to 0"
      assert element_cell(demo_view, "failure-drill-ticks") =~ ~r/>\s*0\s*</
      assert element_cell(demo_view, "failure-drill-restarts") =~ ~r/>\s*1\s*</
    end
  end

  defp element_cell(view, id) do
    view
    |> element("##{id}")
    |> render()
  end

  describe "/examples/controlled-agent (jido-e04-t41)" do
    # The integrated controlled-Agent example: one supervised run proves the
    # complete control path — who initiated work, what was allowed, what
    # happened, and how failure was handled.

    test "renders explanation tab mapping the example to the complete control path", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/examples/controlled-agent?tab=explanation")

      assert html =~ "Controlled Agent"
      assert html =~ "AgentServer"

      # The destination must prove the complete control path, so the explanation
      # names each control question.
      for term <- ~w(Who initiated What was allowed What happened How failure) do
        assert html =~ term,
               "expected the controlled-agent explanation to name the '#{term}' control"
      end
    end

    test "renders source tab with the controlled-agent implementation", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/examples/controlled-agent?tab=source")

      assert html =~ "controlled_agent.ex"
      assert html =~ "approve_action.ex"
      assert html =~ "authorization_plugin.ex"
      assert html =~ "supervisor.ex"
      assert html =~ "controlled_agent_live.ex"
    end

    test "is registered as a live runnable example with a real demo module", _conn do
      example = Examples.get_example!("controlled-agent")

      assert example.status == :live
      assert example.demo_mode == :real
      assert example.live_view_module == "AgentJidoWeb.Examples.ControlledAgentLive"
      assert Enum.map(example.sources, & &1.path) == example.source_files
      assert Enum.all?(example.source_files, &File.exists?/1)
    end

    test "demo tab runs the allowed path, denies the unauthorized path, and restarts on crash",
         %{conn: conn} do
      {:ok, view, html} = live(conn, "/examples/controlled-agent?tab=demo")

      assert html =~ "Controlled Agent"
      refute html =~ "Simulated demo"

      demo_view = find_live_child(view, "demo-controlled-agent")

      # Allowed path: an authorized principal runs the protected Action.
      allowed_html =
        demo_view
        |> element("#controlled-agent-approve-allowed")
        |> render_click()

      assert allowed_html =~ "allowed"
      assert element_cell(demo_view, "controlled-agent-approved") =~ ~r/>\s*1\s*</

      # Denied path: an unauthorized principal is rejected before the Action runs.
      denied_html =
        demo_view
        |> element("#controlled-agent-approve-denied")
        |> render_click()

      assert denied_html =~ "denied"
      assert denied_html =~ ":unauthorized"
      # The counter did not move.
      assert element_cell(demo_view, "controlled-agent-approved") =~ ~r/>\s*1\s*</

      # How failure was handled: crashing the process triggers a supervised restart,
      # and the in-memory approved counter resets.
      crash_html =
        demo_view
        |> element("#controlled-agent-crash")
        |> render_click()

      assert crash_html =~ "restart"
      assert render(demo_view) =~ "approved work reset to 0"
      assert element_cell(demo_view, "controlled-agent-approved") =~ ~r/>\s*0\s*</
      assert element_cell(demo_view, "controlled-agent-restarts") =~ ~r/>\s*1\s*</
    end
  end
end
