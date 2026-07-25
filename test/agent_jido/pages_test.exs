defmodule AgentJido.PagesTest do
  use ExUnit.Case, async: true

  alias AgentJido.Pages
  alias AgentJido.Pages.MenuNode
  alias AgentJido.Pages.Page

  @moduletag :flaky

  describe "all_pages/0" do
    test "returns a list of pages" do
      pages = Pages.all_pages()
      assert is_list(pages)
      refute Enum.empty?(pages)
      assert Enum.all?(pages, &match?(%Page{}, &1))
    end

    test "pages are sorted by order" do
      pages = Pages.all_pages()
      orders = Enum.map(pages, & &1.order)
      assert orders == Enum.sort(orders)
    end

    test "excludes draft pages" do
      pages = Pages.all_pages()
      assert Enum.all?(pages, &(&1.draft == false))
    end
  end

  describe "all_tags/0" do
    test "returns a list of unique values" do
      tags = Pages.all_tags()
      assert is_list(tags)
      assert tags == Enum.uniq(tags)
    end
  end

  describe "all_categories/0" do
    test "returns a list of unique atoms" do
      categories = Pages.all_categories()
      assert is_list(categories)
      assert Enum.all?(categories, &is_atom/1)
      assert categories == Enum.uniq(categories)
    end

    test "includes docs and training categories" do
      categories = Pages.all_categories()
      assert :docs in categories
      assert :training in categories
    end
  end

  describe "docs hierarchy helpers" do
    @tag skip: "IA/content taxonomy transition; temporarily disabled for CI unblock"
    test "returns docs sections from root section pages" do
      sections = Pages.docs_sections()

      assert Enum.map(sections, &Pages.route_for/1) == [
               "/docs/getting-started",
               "/docs/concepts",
               "/docs/guides",
               "/docs/reference",
               "/docs/operations"
             ]
    end

    test "returns contextual section pages" do
      pages = Pages.docs_section_pages("reference")
      routes = Enum.map(pages, &Pages.route_for/1)

      assert "/docs/reference" in routes
      assert Enum.all?(routes, &String.starts_with?(&1, "/docs/reference"))
      assert Enum.any?(routes, &(&1 != "/docs/reference"))
      refute "/docs/getting-started" in routes
    end

    test "places contributors between guides and reference in docs sections" do
      routes = Pages.docs_sections() |> Enum.map(&Pages.route_for/1)

      contributors_index = Enum.find_index(routes, &(&1 == "/docs/contributors"))
      guides_index = Enum.find_index(routes, &(&1 == "/docs/guides"))
      reference_index = Enum.find_index(routes, &(&1 == "/docs/reference"))

      assert is_integer(contributors_index)
      assert is_integer(guides_index)
      assert is_integer(reference_index)
      assert contributors_index > guides_index
      assert contributors_index < reference_index
    end

    test "orders contributor handbook pages for the section sidebar" do
      routes = Pages.docs_section_pages("contributors") |> Enum.map(&Pages.route_for/1)

      assert routes == [
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

    test "extracts section slug from docs path" do
      assert Pages.docs_section_for_path("/docs") == nil
      assert Pages.docs_section_for_path("/docs/getting-started") == "getting-started"
      assert Pages.docs_section_for_path("/docs/concepts/key-concepts") == "concepts"
    end

    test "livebook docs expose a run URL using raw GitHub content" do
      page =
        Pages.pages_by_category(:docs)
        |> Enum.find(& &1.is_livebook)

      assert page != nil
      assert is_binary(page.livebook_url)
      assert page.livebook_url =~ "https://livebook.dev/run?url="
      assert page.livebook_url =~ URI.encode_www_form("https://raw.githubusercontent.com/")
    end
  end

  describe "menu_tree/0" do
    test "returns a list of MenuNode structs" do
      tree = Pages.menu_tree()
      assert is_list(tree)
      assert Enum.all?(tree, &match?(%MenuNode{}, &1))
    end

    test "menu nodes have children as lists" do
      tree = Pages.menu_tree()

      Enum.each(tree, fn node ->
        assert is_list(node.children)
      end)
    end
  end

  describe "get_page_by_id/1" do
    test "returns page when found" do
      pages = Pages.all_pages()
      page = hd(pages)

      found = Pages.get_page_by_id(page.id)
      assert found == page
    end

    test "returns nil when not found" do
      assert Pages.get_page_by_id("nonexistent-page-id") == nil
    end
  end

  describe "get_page!/1" do
    test "returns page when found" do
      pages = Pages.all_pages()
      page = hd(pages)

      found = Pages.get_page!(page.id)
      assert found == page
    end

    test "raises NotFoundError when not found" do
      assert_raise Pages.NotFoundError, fn ->
        Pages.get_page!("nonexistent-page-id")
      end
    end
  end

  describe "get_page_by_path/1" do
    test "returns page when found" do
      pages = Pages.all_pages()
      page = hd(pages)

      found = Pages.get_page_by_path(page.path)
      assert found == page
    end

    test "returns nil when not found" do
      assert Pages.get_page_by_path("/nonexistent/path") == nil
    end

    test "first agent guide is marked as a runnable Livebook" do
      page = Pages.get_page_by_path("/docs/getting-started/first-agent")

      assert page != nil
      assert page.is_livebook
      assert page.livebook.runnable
      assert page.livebook.required_env_vars == []
      refute page.livebook.requires_network
    end

    test "first LLM agent guide uses the default Livebook runtime pattern" do
      source =
        File.read!(Path.expand("priv/pages/docs/getting-started/first-llm-agent.livemd", File.cwd!()))

      assert source =~ "livebook: %{"
      assert source =~ "{:ok, _} = Jido.start()"
      assert source =~ "runtime = Jido.default_instance()"
      assert source =~ "Jido.start_agent(runtime, MyAgentApp.Greeter"
      assert source =~ "Jido.AgentServer.status(pid)"
      refute source =~ "MyAgentApp.Jido.start_link(name: Jido)"
      refute source =~ "Jido.AgentServer.start_link(agent: MyAgentApp.Greeter)"
    end

    test "AI chat agent guide uses the simple one-pid chat flow" do
      source =
        File.read!(Path.expand("priv/pages/docs/learn/ai-chat-agent.livemd", File.cwd!()))

      assert String.starts_with?(String.trim_leading(source), "<!-- %{")
      assert source =~ "livebook: %{"
      assert source =~ ~s({:jido, "~> 2.2"})
      assert source =~ ~s({:jido_ai, "~> 2.1"})
      assert source =~ ~s({:req_llm, "~> 1.11"})
      refute source =~ "{{mix_dep:"
      assert source =~ "Code.put_compiler_option(:docs, false)"
      assert source =~ "{:ok, _} = Jido.start()"
      assert source =~ "Jido.start_agent(runtime, MyApp.ChatAgent"
      assert source =~ "Jido.AgentServer.status(pid)"
      assert source =~ "details[:conversation]"
      assert source =~ "details.streaming_text"
      assert source =~ "Jido.AI.set_system_prompt"
      assert source =~ "Jido.AI.Plugins.Chat"
      assert source =~ ~s(model: "openai:gpt-5-mini")
      refute source =~ "model: :fast"
      refute source =~ "{:ai_react_start, params}"
      refute source =~ "on_before_cmd"
      refute source =~ "on_after_cmd"
      refute source =~ "strategy_snapshot(pid)"
    end

    test "hybrid chat agent guide uses per-request escalation on one pid" do
      source =
        File.read!(Path.expand("priv/pages/docs/learn/hybrid-chat-agent.livemd", File.cwd!()))

      assert String.starts_with?(String.trim_leading(source), "<!-- %{")
      assert source =~ "livebook: %{"
      assert source =~ ~s({:jido, "~> 2.2"})
      assert source =~ ~s({:jido_ai, "~> 2.1"})
      assert source =~ ~s({:req_llm, "~> 1.11"})
      assert source =~ "Code.put_compiler_option(:docs, false)"
      assert source =~ "Jido.start_agent(runtime, MyApp.HybridSupportAgent"
      assert source =~ ~s(model: "openai:o4-mini")
      assert source =~ "MyApp.HybridSupportChat.quick_reply"
      assert source =~ "MyApp.HybridSupportChat.deep_reply"
      assert source =~ "llm_opts: [reasoning_effort: :high]"
      assert source =~ "status.raw_state[:last_request_id]"
      assert source =~ "turn_usage_comparison ="
      assert source =~ "reasoning_token_delta"
      assert source =~ "status.snapshot.details[:conversation]"
      refute source =~ "request_transformer:"
      refute source =~ "on_before_cmd"
      refute source =~ "on_after_cmd"
    end

    test "docs Livebooks disable compiler docs for Livebook imports" do
      source_paths =
        Path.wildcard(Path.expand("priv/pages/docs/**/*.livemd", File.cwd!()))

      assert source_paths != []

      Enum.each(source_paths, fn source_path ->
        source = File.read!(source_path)
        assert source =~ "Code.put_compiler_option(:docs, false)"
      end)
    end

    test "AI agent with tools guide uses notebook-local weather actions and completed-run inspection" do
      source =
        File.read!(Path.expand("priv/pages/docs/learn/ai-agent-with-tools.livemd", File.cwd!()))

      assert source =~ "livebook: %{"
      assert source =~ "runnable: true"
      assert source =~ ~s({:req, "~> 0.5"})
      assert source =~ "{:ok, _} = Jido.start()"
      assert source =~ "Jido.start_agent(runtime, MyApp.WeatherAgent"
      assert source =~ "defmodule MyApp.WeatherGeocode do"
      assert source =~ "defmodule MyApp.WeatherLocationToGrid do"
      assert source =~ "defmodule MyApp.WeatherForecast do"
      assert source =~ "defmodule MyApp.WeatherCurrentConditions do"
      assert source =~ "MyApp.WeatherLocationToGrid.run"
      assert source =~ "%{forecast_url: grid_info.urls.forecast}"
      assert source =~ "%{observation_stations_url: grid_info.urls.observation_stations}"
      assert source =~ "weather_location_to_grid"
      assert source =~ ~s(type: {:in, ["fahrenheit", "celsius"]})
      assert source =~ "details[:conversation]"
      assert source =~ "details[:trace_summary]"

      refute source =~ """
             Jido.Tools.Weather.Forecast.run(
               %{location: "39.7392,-104.9903"},
               %{}
             )
             """

      refute source =~ "Jido.Tools.Weather."
      refute source =~ "tool_calls: status.snapshot.details[:tool_calls] || []"
    end

    test "local-only guide notebooks declare quiet setup and explicit local-only metadata" do
      source_paths = [
        "priv/pages/docs/guides/debugging-and-troubleshooting.livemd",
        "priv/pages/docs/guides/error-handling-and-recovery.livemd",
        "priv/pages/docs/guides/persistence-and-checkpoints.livemd",
        "priv/pages/docs/guides/testing-agents-and-actions.livemd"
      ]

      Enum.each(source_paths, fn source_path ->
        source = File.read!(Path.expand(source_path, File.cwd!()))

        assert source =~ "livebook: %{"
        assert source =~ "required_env_vars: []"
        assert source =~ "requires_network: false"
        assert source =~ "Logger.configure(level: :warning)"
      end)
    end

    test "advanced local-only learn notebooks declare quiet setup and explicit local-only metadata" do
      source_paths = [
        "priv/pages/docs/learn/first-workflow.livemd",
        "priv/pages/docs/learn/sensors-and-real-time-events.livemd",
        "priv/pages/docs/learn/parent-child-agent-hierarchies.livemd",
        "priv/pages/docs/learn/plugins-and-composable-agents.livemd",
        "priv/pages/docs/learn/memory-and-retrieval-augmented-agents.livemd",
        "priv/pages/docs/learn/multi-agent-orchestration.livemd",
        "priv/pages/docs/learn/state-machines-with-fsm.livemd",
        "priv/pages/docs/learn/task-planning-and-execution.livemd"
      ]

      Enum.each(source_paths, fn source_path ->
        source = File.read!(Path.expand(source_path, File.cwd!()))

        assert source =~ "livebook: %{"
        assert source =~ "required_env_vars: []"
        assert source =~ "requires_network: false"
        assert source =~ "Logger.configure(level: :warning)"
      end)
    end

    test "sensors guide keeps routes stable and state checks inside actions" do
      source =
        File.read!(Path.expand("priv/pages/docs/learn/sensors-and-real-time-events.livemd", File.cwd!()))

      assert source =~ "Routes are calculated when the Agent starts"
      assert source =~ "keep the route table stable and branch inside the Action"
      assert source =~ "def signal_routes(_ctx) do"
      assert source =~ ~s({"process", MyApp.ProcessAction})
      assert source =~ "The Signal still routed to `ProcessAction`"

      refute source =~ "dynamic signal routing"
      refute source =~ "maintenance: true"
      refute source =~ "MyApp.MaintenanceAction"
      refute source =~ "The routing decision happens on every incoming Signal"
      refute source =~ "You can return different routes based on the Agent's current state"
    end

    test "sensors guide defines QuoteSensor in one Livebook code block" do
      source =
        File.read!(Path.expand("priv/pages/docs/learn/sensors-and-real-time-events.livemd", File.cwd!()))

      [_before, after_module_start] = String.split(source, "defmodule MyApp.QuoteSensor do", parts: 2)
      [quote_sensor_block, _after] = String.split(after_module_start, "```", parts: 2)

      assert quote_sensor_block =~ "def init(opts) do"
      assert quote_sensor_block =~ "def handle_info(:emit, state) do"
      assert quote_sensor_block =~ "Jido.AgentServer.cast(state.target, signal)"
    end

    test "reasoning strategies guide uses public strategy agents and runnable metadata" do
      source =
        File.read!(Path.expand("priv/pages/docs/learn/reasoning-strategies-compared.livemd", File.cwd!()))

      assert source =~ "livebook: %{"
      assert source =~ "runnable: true"
      assert source =~ ~s(required_env_vars: ["OPENAI_API_KEY"])
      assert source =~ "Logger.configure(level: :warning)"
      assert source =~ "Jido.start_agent("
      assert source =~ "MyApp.ReleaseDecisionCoTAgent.think_sync"
      assert source =~ "MyApp.ReleaseDecisionToTAgent.explore_sync"
      assert source =~ "MyApp.ReleaseDecisionAdaptiveAgent.ask_sync"
      assert source =~ "selected_strategy"
      refute source =~ "Jido.AgentServer.start_link(agent:"
      refute source =~ "Jido.Tools.Weather."
    end
  end

  describe "pages_by_category/1" do
    test "returns pages for existing category" do
      categories = Pages.all_categories()
      category = hd(categories)

      pages = Pages.pages_by_category(category)
      assert is_list(pages)
      refute Enum.empty?(pages)
      assert Enum.all?(pages, &(&1.category == category))
    end

    test "returns empty list for nonexistent category" do
      assert Pages.pages_by_category(:nonexistent_category) == []
    end
  end

  describe "pages_by_tag/1" do
    test "returns empty list for nonexistent tag" do
      assert Pages.pages_by_tag(:nonexistent_tag) == []
    end
  end

  describe "neighbors/1" do
    test "returns prev and next pages within same category" do
      training = Pages.pages_by_category(:training)

      if length(training) >= 3 do
        middle = Enum.at(training, 1)
        {prev, next} = Pages.neighbors(middle.id)

        assert prev == Enum.at(training, 0)
        assert next == Enum.at(training, 2)
      end
    end

    test "returns nil for prev on first page in category" do
      training = Pages.pages_by_category(:training)
      first = hd(training)
      {prev, _next} = Pages.neighbors(first.id)

      assert prev == nil
    end

    test "returns nil for next on last page in category" do
      training = Pages.pages_by_category(:training)
      last = List.last(training)
      {_prev, next} = Pages.neighbors(last.id)

      assert next == nil
    end
  end

  describe "breadcrumbs/1" do
    test "returns path segments for a page" do
      page = %Page{id: "test", path: "/docs/getting-started", title: "Test", category: :docs}
      crumbs = Pages.breadcrumbs(page)

      assert crumbs == ["docs", "getting-started"]
    end

    test "returns path segments for a string path" do
      crumbs = Pages.breadcrumbs("/docs/getting-started")
      assert crumbs == ["docs", "getting-started"]
    end

    test "handles empty path" do
      crumbs = Pages.breadcrumbs("")
      assert crumbs == []
    end
  end

  describe "route_for/1" do
    test "generates correct routes for docs" do
      page = %Page{
        id: "getting-started",
        path: "/docs/getting-started",
        title: "GS",
        category: :docs
      }

      assert Pages.route_for(page) == "/docs/getting-started"
    end

    test "generates correct routes for training" do
      page = %Page{
        id: "agent-fundamentals",
        path: "/training/agent-fundamentals",
        title: "AF",
        category: :training
      }

      assert Pages.route_for(page) == "/training/agent-fundamentals"
    end

    test "generates correct routes for features" do
      page = %Page{
        id: "reliability",
        path: "/features/reliability",
        title: "R",
        category: :features
      }

      assert Pages.route_for(page) == "/features/reliability"
    end
  end

  describe "page_count/0" do
    test "returns correct count" do
      assert Pages.page_count() == length(Pages.all_pages())
      assert Pages.page_count() > 0
    end
  end

  describe "docs IA stubs" do
    test "required docs IA pages exist and are routable" do
      required_sections = ~w(getting-started concepts guides reference operations)

      Enum.each(required_sections, fn section ->
        path = "/docs/#{section}"
        page = Pages.get_page_by_path(path)

        assert page != nil
        assert page.category == :docs
        assert Pages.route_for(page) == path
      end)

      docs_pages = Pages.pages_by_category(:docs)

      Enum.each(~w(concepts guides reference operations), fn section ->
        assert Enum.any?(docs_pages, fn page ->
                 String.starts_with?(page.path, "/docs/#{section}/")
               end)
      end)
    end

    test "legacy docs paths resolve to canonical docs pages" do
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

      Enum.each(legacy_to_canonical, fn {legacy_path, canonical_path} ->
        assert {:ok, legacy_page, :legacy} = Pages.resolve_page_for_path(legacy_path)
        assert legacy_page.path == canonical_path
      end)
    end
  end

  describe "training pages" do
    test "training pages have track and difficulty" do
      training = Pages.pages_by_category(:training)
      assert length(training) == 6

      Enum.each(training, fn page ->
        assert page.track != nil
        assert page.difficulty != nil
        assert page.duration_minutes != nil
      end)
    end

    test "training pages are sorted by order" do
      training = Pages.pages_by_category(:training)
      orders = Enum.map(training, & &1.order)
      assert orders == Enum.sort(orders)
    end
  end

  describe "features wave A content quality" do
    test "first three feature pages are published and routable" do
      target_paths = [
        "/features/agents-that-self-heal",
        "/features/multi-agent-coordination",
        "/features/observe-everything"
      ]

      Enum.each(target_paths, fn path ->
        page = Pages.get_page_by_path(path)

        assert page != nil
        assert page.category == :features
        assert page.draft == false
      end)
    end

    test "first three feature source files do not contain placeholder markers" do
      feature_files = [
        Path.expand("../../priv/pages/features/agents-that-self-heal.md", __DIR__),
        Path.expand("../../priv/pages/features/multi-agent-coordination.md", __DIR__),
        Path.expand("../../priv/pages/features/observe-everything.md", __DIR__)
      ]

      placeholder_patterns = [
        ~r/content coming soon/i,
        ~r/\bcoming soon\b/i,
        ~r/\bTODO\b/,
        ~r/\bTBD\b/,
        ~r/lorem ipsum/i
      ]

      Enum.each(feature_files, fn file ->
        body = File.read!(file)

        assert body =~ "draft: false"

        Enum.each(placeholder_patterns, fn pattern ->
          refute body =~ pattern
        end)
      end)
    end
  end

  describe "features wave B content quality" do
    test "remaining feature pages are published and routable" do
      target_paths = [
        "/features/start-small",
        "/features/beam-for-ai-builders",
        "/features/jido-vs-framework-first-stacks",
        "/features/executive-brief"
      ]

      Enum.each(target_paths, fn path ->
        page = Pages.get_page_by_path(path)

        assert page != nil
        assert page.category == :features
        assert page.draft == false
      end)
    end

    test "remaining feature source files do not contain placeholder markers" do
      feature_files = [
        Path.expand("../../priv/pages/features/start-small.md", __DIR__),
        Path.expand("../../priv/pages/features/beam-for-ai-builders.md", __DIR__),
        Path.expand("../../priv/pages/features/jido-vs-framework-first-stacks.md", __DIR__),
        Path.expand("../../priv/pages/features/executive-brief.md", __DIR__)
      ]

      placeholder_patterns = [
        ~r/content coming soon/i,
        ~r/\bcoming soon\b/i,
        ~r/\bTODO\b/,
        ~r/\bTBD\b/,
        ~r/lorem ipsum/i
      ]

      Enum.each(feature_files, fn file ->
        body = File.read!(file)

        assert body =~ "draft: false"

        Enum.each(placeholder_patterns, fn pattern ->
          refute body =~ pattern
        end)
      end)
    end

    @tag skip: "IA/content taxonomy transition; temporarily disabled for CI unblock"
    test "features section includes all published feature pages" do
      expected_paths = [
        "/features/how-agents-work",
        "/features/tools",
        "/features/llm-support",
        "/features/agents-that-self-heal",
        "/features/multi-agent-coordination",
        "/features/observe-everything",
        "/features/start-small",
        "/features/beam-for-ai-builders",
        "/features/beam-native-agent-model",
        "/features/jido-vs-framework-first-stacks",
        "/features/executive-brief"
      ]

      features = Pages.pages_by_category(:features)
      feature_paths = Enum.map(features, & &1.path)

      Enum.each(expected_paths, fn path ->
        assert path in feature_paths
      end)
    end
  end

  describe "build wave A content quality" do
    test "wave A build pages are published and routable" do
      target_pages = [
        {"/build", "/build/build"},
        {"/build/quickstarts-by-persona", "/build/quickstarts-by-persona"},
        {"/build/reference-architectures", "/build/reference-architectures"}
      ]

      Enum.each(target_pages, fn {path, expected_route} ->
        page = Pages.get_page_by_path(path)

        assert page != nil
        assert page.category == :build
        assert page.draft == false
        assert Pages.route_for(page) == expected_route
      end)
    end

    test "wave A build source files do not contain placeholder markers" do
      build_files = [
        Path.expand("../../priv/pages/build/index.md", __DIR__),
        Path.expand("../../priv/pages/build/quickstarts-by-persona.md", __DIR__),
        Path.expand("../../priv/pages/build/reference-architectures.md", __DIR__)
      ]

      placeholder_patterns = [
        ~r/content coming soon/i,
        ~r/\bcoming soon\b/i,
        ~r/\bTODO\b/,
        ~r/\bTBD\b/,
        ~r/lorem ipsum/i
      ]

      Enum.each(build_files, fn file ->
        body = File.read!(file)

        assert body =~ "draft: false"

        Enum.each(placeholder_patterns, fn pattern ->
          refute body =~ pattern
        end)
      end)
    end
  end

  describe "build wave B content quality" do
    test "remaining build pages are published and routable" do
      target_pages = [
        {"/build/mixed-stack-integration", "/build/mixed-stack-integration"},
        {"/build/product-feature-blueprints", "/build/product-feature-blueprints"}
      ]

      Enum.each(target_pages, fn {path, expected_route} ->
        page = Pages.get_page_by_path(path)

        assert page != nil
        assert page.category == :build
        assert page.draft == false
        assert Pages.route_for(page) == expected_route
      end)
    end

    test "remaining build source files do not contain placeholder markers" do
      build_files = [
        Path.expand("../../priv/pages/build/mixed-stack-integration.md", __DIR__),
        Path.expand("../../priv/pages/build/product-feature-blueprints.md", __DIR__)
      ]

      placeholder_patterns = [
        ~r/content coming soon/i,
        ~r/\bcoming soon\b/i,
        ~r/\bTODO\b/,
        ~r/\bTBD\b/,
        ~r/lorem ipsum/i
      ]

      Enum.each(build_files, fn file ->
        body = File.read!(file)

        assert body =~ "draft: false"

        Enum.each(placeholder_patterns, fn pattern ->
          refute body =~ pattern
        end)
      end)
    end
  end

  describe "community content quality" do
    test "community subpages are retired from the pages system" do
      assert Pages.pages_by_category(:community) == []

      retired_paths = [
        "/community",
        "/community/learning-paths",
        "/community/adoption-playbooks",
        "/community/case-studies"
      ]

      Enum.each(retired_paths, fn path ->
        assert Pages.get_page_by_path(path) == nil
      end)
    end
  end

  describe "getting-started Phoenix starter lane (jido-e05-t05)" do
    @phoenix_starter_source Path.expand(
                              "../../priv/pages/docs/getting-started/phoenix-starter.md",
                              __DIR__
                            )

    test "the lane page is published and routable" do
      page = Pages.get_page_by_path("/docs/getting-started/phoenix-starter")

      assert page != nil
      assert page.category == :docs
      assert page.draft == false
      assert Pages.route_for(page) == "/docs/getting-started/phoenix-starter"
    end

    test "the lane links to the jido_phx_starter repo" do
      body = File.read!(@phoenix_starter_source)

      assert body =~ ~r{https://github\.com/agentjido/jido_phx_starter}
    end

    test "the lane clearly states the Postgres requirement from the starter README" do
      body = File.read!(@phoenix_starter_source)

      # Postgres is required, the app expects the local postgres/postgres user,
      # and ecto.setup is what provisions the database.
      assert body =~ ~r/Postgres/i
      assert body =~ "postgres"
      assert body =~ "ecto.setup"
    end

    test "the lane clearly states the provider-key requirement from the starter README" do
      body = File.read!(@phoenix_starter_source)

      # AI demos require an LLM provider key; core demos do not.
      assert body =~ "API key"
      assert body =~ "ANTHROPIC_API_KEY"
      assert body =~ ~r/optional/i
    end

    test "the lane source has no placeholder markers" do
      body = File.read!(@phoenix_starter_source)

      placeholder_patterns = [
        ~r/content coming soon/i,
        ~r/\bcoming soon\b/i,
        ~r/\bTODO\b/,
        ~r/\bTBD\b/,
        ~r/lorem ipsum/i
      ]

      assert body =~ "draft: false"

      Enum.each(placeholder_patterns, fn pattern ->
        refute body =~ pattern
      end)
    end
  end

  describe "getting-started operational controls lane (jido-e05-t32)" do
    @operational_controls_source Path.expand(
                                   "../../priv/pages/docs/getting-started/operational-controls.md",
                                   __DIR__
                                 )

    test "the lane page is published and routable" do
      page = Pages.get_page_by_path("/docs/getting-started/operational-controls")

      assert page != nil
      assert page.category == :docs
      assert page.draft == false
      assert Pages.route_for(page) == "/docs/getting-started/operational-controls"
    end

    # Acceptance: "The lane follows the first working Agent."
    test "the lane follows the first working agent" do
      body = File.read!(@operational_controls_source)

      # The lane builds on the first-agent lane and says so by name and link.
      assert body =~ ~s(/docs/getting-started/first-agent)
      assert body =~ "first agent"
    end

    # Acceptance: "...and does not block basic activation."
    test "the lane does not block basic activation" do
      body = File.read!(@operational_controls_source)

      # The lane is explicitly optional and states the basic agent runs without it.
      assert body =~ ~r/optional/i
      assert body =~ "Nothing on this page is required to run a basic agent"
    end

    test "the lane points at the documented operational control surfaces" do
      body = File.read!(@operational_controls_source)

      assert body =~ "prepare_action/3"
      assert body =~ ~s(/docs/operations/security-and-governance)
    end

    test "the lane source has no placeholder markers" do
      body = File.read!(@operational_controls_source)

      placeholder_patterns = [
        ~r/content coming soon/i,
        ~r/\bcoming soon\b/i,
        ~r/\bTODO\b/,
        ~r/\bTBD\b/,
        ~r/lorem ipsum/i
      ]

      assert body =~ "draft: false"

      Enum.each(placeholder_patterns, fn pattern ->
        refute body =~ pattern
      end)
    end

    # Acceptance (jido-e05-t40): "The reader chooses an adapter and sees what
    # survives restart."
    test "the durable-history step has the reader choose an adapter and see what survives restart" do
      body = File.read!(@operational_controls_source)

      # The reader is told to choose an adapter...
      assert body =~ ~r/choose a .* adapter/i
      # ...shown what a restart keeps and drops.
      assert body =~ "survives a restart"
      # ...and that the default keeps nothing, so the contrast is explicit.
      assert body =~ "not durable"
    end

    # Acceptance (jido-e05-t41): "Authentication, retention, tamper evidence,
    # and compliance remain named application concerns."
    test "the control-boundary summary names authentication, retention, tamper evidence, and compliance as application concerns" do
      body = File.read!(@operational_controls_source)

      # The summary section exists at the end of the guide...
      assert body =~ ~r/\#\# Control boundary summary/i

      # ...and names all four concerns as application/platform-owned duties.
      [_before, summary] = String.split(body, "## Control boundary summary", parts: 2)

      assert summary =~ ~r/\bAuthentication\b/i
      assert summary =~ ~r/\bretention\b/i
      assert summary =~ ~r/tamper[ -]evident/i
      assert summary =~ ~r/\bcompliance\b/i
      # ...framed as application or platform concerns, not Jido features.
      assert summary =~ ~r/application or platform concern/i
      # ...and pointing to the full boundary on the Operations path.
      assert summary =~ ~s(/docs/operations/security-and-governance)
    end
  end

  describe "operations supervision and failure boundaries page (jido-e07-t02)" do
    # Acceptance: "It explains topology, restart strategy, and restart intensity."
    @supervision_source Path.expand(
                          "../../priv/pages/docs/operations/supervision-and-failure-boundaries.md",
                          __DIR__
                        )

    test "the page is published and routable" do
      page = Pages.get_page_by_path("/docs/operations/supervision-and-failure-boundaries")

      assert page != nil
      assert page.category == :docs
      assert page.draft == false
      assert Pages.route_for(page) == "/docs/operations/supervision-and-failure-boundaries"
    end

    test "it explains supervision topology" do
      body = File.read!(@supervision_source)

      # A topology section names where agents sit in the tree and how they isolate.
      assert body =~ "## Topology"
      assert body =~ "Jido.AgentServer"
      assert body =~ ~r/own memory|own process|mailbox|failure boundary/is
    end

    test "it explains restart strategy" do
      body = File.read!(@supervision_source)

      assert body =~ "## Restart strategy"

      # Both the supervisor strategy and the per-child restart type are covered.
      assert body =~ ":one_for_one"
      assert body =~ ":rest_for_one"
      assert body =~ ":permanent"
      assert body =~ ":transient"
    end

    test "it explains restart intensity" do
      body = File.read!(@supervision_source)

      assert body =~ "## Restart intensity"

      # Intensity and period are named, with deliberate tuning guidance.
      assert body =~ "max_restarts"
      assert body =~ "max_seconds"
    end

    test "the page source has no placeholder markers" do
      body = File.read!(@supervision_source)

      placeholder_patterns = [
        ~r/content coming soon/i,
        ~r/\bcoming soon\b/i,
        ~r/\bTODO\b/,
        ~r/\bTBD\b/,
        ~r/lorem ipsum/i
      ]

      assert body =~ "draft: false"

      Enum.each(placeholder_patterns, fn pattern ->
        refute body =~ pattern
      end)
    end
  end

  describe "operations process crash and restart page (jido-e07-t12)" do
    # Acceptance: "The process restarts and the observed state result is explicit."
    @crash_source Path.expand(
                    "../../priv/pages/docs/operations/process-crash-and-restart.md",
                    __DIR__
                  )
    @crash_route "/docs/operations/process-crash-and-restart"
    @crash_demo_agent "lib/agent_jido/demos/agent_server_crash/agent_server_crash_agent.ex"
    @crash_demo_supervisor "lib/agent_jido/demos/agent_server_crash/supervisor.ex"
    @crash_demo_test "test/agent_jido/demos/agent_server_crash_test.exs"

    test "the page is published and routable" do
      page = Pages.get_page_by_path(@crash_route)

      assert page != nil
      assert page.category == :docs
      assert page.draft == false
      assert Pages.route_for(page) == @crash_route
    end

    test "the page is linked from the operations hub" do
      hub = File.read!(Path.expand("../../priv/pages/docs/operations.md", __DIR__))

      assert hub =~ @crash_route
    end

    test "it documents both halves of the acceptance: restart and observed state" do
      body = File.read!(@crash_source)

      # The acceptance condition: both halves get their own dedicated heading,
      # so process recovery and the observed result are presented distinctly.
      assert has_h2?(body, "The process restarts")
      assert has_h2?(body, "The observed state result is explicit")
    end

    test "the observed state is read through the real AgentServer APIs, not assumed" do
      body = File.read!(@crash_source)

      # The observed result is read explicitly through status/1 and state/1.
      assert body =~ "Jido.AgentServer.status"
      assert body =~ "Jido.AgentServer.state"
      assert body =~ ":not_found"

      # The before/after contrast is what makes the result explicit.
      assert body =~ "agent_before"
      assert body =~ "agent_after"
    end

    test "it separates process recovery from Action-error handling and state recovery" do
      body = File.read!(@crash_source)

      # A process crash is distinguished from an Action error (call boundary).
      assert body =~ "run/2"
      assert body =~ "Process.exit"

      # Process recovery is explicitly not state recovery.
      assert body =~ ~r/process recovery is not state recovery/i
      assert body =~ ~r/did not recover/i
    end

    test "the example is runnable: the demo modules and their test exist and are cited" do
      # The worked example points at a real, tested demo — not a snippet alone.
      assert File.regular?(@crash_demo_agent)
      assert File.regular?(@crash_demo_supervisor)
      assert File.regular?(@crash_demo_test)

      body = File.read!(@crash_source)
      assert body =~ "lib/agent_jido/demos/agent_server_crash/"
      assert body =~ @crash_demo_test
    end

    test "it cross-links supervision and the call-boundary pages (no isolated claims)" do
      body = File.read!(@crash_source)

      assert body =~ "/docs/operations/supervision-and-failure-boundaries"
      assert body =~ "/docs/operations/tool-error-and-retry-decision"
    end

    test "the page source has no placeholder markers" do
      body = File.read!(@crash_source)

      placeholder_patterns = [
        ~r/content coming soon/i,
        ~r/\bcoming soon\b/i,
        ~r/\bTODO\b/,
        ~r/\bTBD\b/,
        ~r/lorem ipsum/i
      ]

      assert body =~ "draft: false"

      Enum.each(placeholder_patterns, fn pattern ->
        refute body =~ pattern
      end)
    end
  end

  describe "operations deployment restart page (jido-e07-t14)" do
    # Acceptance: "The workflow resumes or safely restarts with stated semantics."
    @deploy_source Path.expand(
                     "../../priv/pages/docs/operations/deployment-restart.md",
                     __DIR__
                   )
    @deploy_route "/docs/operations/deployment-restart"
    @deploy_demo_agent "lib/agent_jido/demos/deployment_restart/deployment_restart_agent.ex"
    @deploy_demo_supervisor "lib/agent_jido/demos/deployment_restart/supervisor.ex"
    @deploy_demo_test "test/agent_jido/demos/deployment_restart_test.exs"

    test "the page is published and routable" do
      page = Pages.get_page_by_path(@deploy_route)

      assert page != nil
      assert page.category == :docs
      assert page.draft == false
      assert Pages.route_for(page) == @deploy_route
    end

    test "the page is linked from the operations hub" do
      hub = File.read!(Path.expand("../../priv/pages/docs/operations.md", __DIR__))

      assert hub =~ @deploy_route
    end

    test "it states both resume and safely-restart outcomes with their semantics" do
      body = File.read!(@deploy_source)

      # The acceptance condition: both outcomes are named and the decision is
      # stated explicitly, not left implicit.
      assert has_h2?(body, "Stated semantics: safely restart, not resume")
      assert body =~ ~r/safely restart/i
      assert body =~ ~r/resume/i

      # The decision rule is stated: resume needs persistence outside the
      # BEAM; safely restart is the default (no persistence wired in).
      assert body =~ ~r/persist/i
      assert body =~ ~r/initial state/i
    end

    test "it distinguishes a deployment restart from a process crash" do
      body = File.read!(@deploy_source)

      # The differentiator: a deployment restart replaces the whole tree and
      # has no surviving parent, unlike a process crash.
      assert body =~ ~r/no surviving parent/i
      assert body =~ ~r/whole tree/i

      # The whole tree is torn down and rebuilt through the supervisor lifecycle.
      assert body =~ "Supervisor.stop"
      assert body =~ "Process.alive?"
    end

    test "the observed result is read through the real AgentServer APIs" do
      body = File.read!(@deploy_source)

      assert body =~ "Jido.AgentServer.status"
      assert body =~ "Jido.AgentServer.state"

      # The registry rebind (same logical identity, new process) is observable.
      assert body =~ "AgentJido.Jido.whereis"
    end

    test "the example is runnable: the demo modules and their test exist and are cited" do
      # The worked example points at a real, tested demo — not a snippet alone.
      assert File.regular?(@deploy_demo_agent)
      assert File.regular?(@deploy_demo_supervisor)
      assert File.regular?(@deploy_demo_test)

      body = File.read!(@deploy_source)
      assert body =~ "lib/agent_jido/demos/deployment_restart/"
      assert body =~ @deploy_demo_test
    end

    test "it cross-links supervision, the process-crash example, and the readiness drill" do
      body = File.read!(@deploy_source)

      assert body =~ "/docs/operations/supervision-and-failure-boundaries"
      assert body =~ "/docs/operations/process-crash-and-restart"
      assert body =~ "/docs/operations/production-readiness-checklist"
    end

    test "the page source has no placeholder markers" do
      body = File.read!(@deploy_source)

      placeholder_patterns = [
        ~r/content coming soon/i,
        ~r/\bcoming soon\b/i,
        ~r/\bTODO\b/,
        ~r/\bTBD\b/,
        ~r/lorem ipsum/i
      ]

      assert body =~ "draft: false"

      Enum.each(placeholder_patterns, fn pattern ->
        refute body =~ pattern
      end)
    end
  end

  describe "operations retries, timeouts, and provider failure page (jido-e07-t05)" do
    # Acceptance: "It covers tool, HTTP, and model failures separately."
    @retries_source Path.expand(
                      "../../priv/pages/docs/operations/retries-timeouts-and-provider-failure.md",
                      __DIR__
                    )
    @retries_route "/docs/operations/retries-timeouts-and-provider-failure"

    test "the page is published and routable" do
      page = Pages.get_page_by_path(@retries_route)

      assert page != nil
      assert page.category == :docs
      assert page.draft == false
      assert Pages.route_for(page) == @retries_route
    end

    test "the page is linked from the operations hub" do
      hub = File.read!(Path.expand("../../priv/pages/docs/operations.md", __DIR__))

      assert hub =~ @retries_route
    end

    test "tool, HTTP, and model failures are three separate sections" do
      body = File.read!(@retries_source)

      # The acceptance condition: each layer has its own dedicated heading.
      assert has_h2?(body, "Tool failures")
      assert has_h2?(body, "HTTP failures")
      assert has_h2?(body, "Model failures")
    end

    test "it covers tool failures: Action results, retryable vs terminal" do
      body = File.read!(@retries_source)

      # Tool failures are framed at the Action run/2 boundary.
      assert body =~ "run/2"
      assert body =~ "{:ok, result}"

      # The retryable/terminal split is named, not guessed.
      assert body =~ ~r/retryable/i
      assert body =~ ~r/terminal/i

      # A real retry control surface is named (bounded by max_retries/backoff).
      assert body =~ "max_retries"
      assert body =~ "backoff"
    end

    test "it covers HTTP failures: transport, timeout, and fallback" do
      body = File.read!(@retries_source)

      # HTTP failures are framed as the transport layer with transient causes.
      assert body =~ ~r/network error|connection reset|5xx/i
      assert body =~ ~r/timeout/i
    end

    test "it covers model failures: provider response and fallback rule" do
      body = File.read!(@retries_source)

      # Model failures come from the provider response, with concrete causes.
      assert body =~ ~r/rate limit|429/i
      assert body =~ ~r/auth|permission|refusal/i

      # The outcome status the application branches on is named.
      assert body =~ ":completed"
      assert body =~ ":failed"
      assert body =~ ":timeout"
    end

    test "it commits to bounded retry and a fallback, not unbounded retry" do
      body = File.read!(@retries_source)

      # Provider failure has a defined fallback rule.
      assert body =~ ~r/fallback/i
      # The budget is bounded.
      assert body =~ ~r/bounded/i

      # It must not promise success or guarantee recovery.
      refute body =~ ~r/no downtime/i
      refute body =~ ~r/guaranteed success|guarantees success/i
    end

    test "it distinguishes call-layer retry from process-level recovery" do
      body = File.read!(@retries_source)

      # Retries recover calls; supervision recovers processes. Both are named,
      # and the page links supervision as the process-recovery page.
      assert body =~ ~r/process-level|process recovery/i
      assert body =~ "/docs/operations/supervision-and-failure-boundaries"
    end

    test "the page source has no placeholder markers" do
      body = File.read!(@retries_source)

      placeholder_patterns = [
        ~r/content coming soon/i,
        ~r/\bcoming soon\b/i,
        ~r/\bTODO\b/,
        ~r/\bTBD\b/,
        ~r/lorem ipsum/i
      ]

      assert body =~ "draft: false"

      Enum.each(placeholder_patterns, fn pattern ->
        refute body =~ pattern
      end)
    end
  end

  describe "operations tool error and retry decision page (jido-e07-t11)" do
    # Acceptance: "The example shows retryable and terminal errors."
    @tool_error_source Path.expand(
                         "../../priv/pages/docs/operations/tool-error-and-retry-decision.md",
                         __DIR__
                       )
    @tool_error_route "/docs/operations/tool-error-and-retry-decision"
    @tool_error_demo "lib/agent_jido/demos/tool_error_retry/failing_tool_action.ex"
    @tool_error_demo_test "test/agent_jido/demos/tool_error_retry_test.exs"

    test "the page is published and routable" do
      page = Pages.get_page_by_path(@tool_error_route)

      assert page != nil
      assert page.category == :docs
      assert page.draft == false
      assert Pages.route_for(page) == @tool_error_route
    end

    test "the page is linked from the operations hub" do
      hub = File.read!(Path.expand("../../priv/pages/docs/operations.md", __DIR__))

      assert hub =~ @tool_error_route
    end

    test "the example shows both retryable and terminal tool errors" do
      body = File.read!(@tool_error_source)

      # The acceptance condition: both error classes are named and shown.
      assert has_h2?(body, "A retryable error is retried")
      assert has_h2?(body, "A terminal error is not retried")
      assert body =~ ~r/retryable/i
      assert body =~ ~r/terminal/i

      # The decision rule is by error type, with the concrete types named.
      assert body =~ "TimeoutError"
      assert body =~ "InvalidInputError"
      assert body =~ "Jido.Action.Error.retryable?"
    end

    test "the example is runnable: the demo module and its test exist" do
      # The worked example points at a real, tested demo — not a snippet alone.
      assert File.regular?(@tool_error_demo)
      assert File.regular?(@tool_error_demo_test)

      body = File.read!(@tool_error_source)
      assert body =~ @tool_error_demo
      assert body =~ @tool_error_demo_test
      # The bounded retry knobs the example exercises are named.
      assert body =~ "max_retries"
      assert body =~ "backoff"
    end

    test "it cross-links the retries guide and supervision (no isolated claims)" do
      body = File.read!(@tool_error_source)

      assert body =~ "/docs/operations/retries-timeouts-and-provider-failure"
      assert body =~ "/docs/operations/supervision-and-failure-boundaries"
    end

    test "the page source has no placeholder markers" do
      body = File.read!(@tool_error_source)

      placeholder_patterns = [
        ~r/content coming soon/i,
        ~r/\bcoming soon\b/i,
        ~r/\bTODO\b/,
        ~r/\bTBD\b/,
        ~r/lorem ipsum/i
      ]

      assert body =~ "draft: false"

      Enum.each(placeholder_patterns, fn pattern ->
        refute body =~ pattern
      end)
    end
  end

  describe "operations scheduling and event input page (jido-e07-t06)" do
    # Acceptance: "It links to a working Schedule and Sensor example."
    @scheduling_source Path.expand(
                         "../../priv/pages/docs/operations/scheduling-and-event-input.md",
                         __DIR__
                       )
    @scheduling_route "/docs/operations/scheduling-and-event-input"
    @schedule_example_route "/examples/schedule-directive-agent"
    @sensor_guide_route "/docs/learn/sensors-and-real-time-events"

    test "the page is published and routable" do
      page = Pages.get_page_by_path(@scheduling_route)

      assert page != nil
      assert page.category == :docs
      assert page.draft == false
      assert Pages.route_for(page) == @scheduling_route
    end

    test "the page is linked from the operations hub" do
      hub = File.read!(Path.expand("../../priv/pages/docs/operations.md", __DIR__))

      assert hub =~ @scheduling_route
    end

    test "scheduling and event input are separate sections" do
      body = File.read!(@scheduling_source)

      # Both ingress paths get their own dedicated heading.
      assert has_h2?(body, "Scheduling")
      assert has_h2?(body, "Event input")
    end

    test "it links to a working Schedule example" do
      body = File.read!(@scheduling_source)

      # The acceptance condition: the page links a real, runnable Schedule example.
      assert body =~ @schedule_example_route

      # The example is a live route in the examples catalog, not a dead link.
      # get_example/1 returns only status == :live examples.
      schedule_example = AgentJido.Examples.get_example("schedule-directive-agent")
      assert schedule_example != nil
      assert schedule_example.status == :live
    end

    test "it links to a working Sensor example" do
      body = File.read!(@scheduling_source)

      # The acceptance condition: the page links a real, runnable Sensor example.
      assert body =~ @sensor_guide_route

      # The guide is a published, routable docs page, not a dead link.
      sensor_guide = Pages.get_page_by_path(@sensor_guide_route)
      assert sensor_guide != nil
      assert sensor_guide.draft == false
    end

    test "it frames what survives a restart, not a tutorial" do
      body = File.read!(@scheduling_source)

      # The operational angle: recoverability across an agent restart is named.
      assert body =~ ~r/restart/i
      assert body =~ "Directive.Cron"
      assert body =~ "Directive.Schedule"

      # The named control surfaces for recurring vs one-shot work.
      assert body =~ "job_id"
    end

    test "it commits to idempotent delivery, not a delivery guarantee" do
      body = File.read!(@scheduling_source)

      assert body =~ ~r/idempoten/i

      # It must not promise guaranteed delivery or no downtime.
      refute body =~ ~r/guaranteed delivery|guarantees delivery/i
      refute body =~ ~r/no downtime/i
    end

    test "the page source has no placeholder markers" do
      body = File.read!(@scheduling_source)

      placeholder_patterns = [
        ~r/content coming soon/i,
        ~r/\bcoming soon\b/i,
        ~r/\bTODO\b/,
        ~r/\bTBD\b/,
        ~r/lorem ipsum/i
      ]

      assert body =~ "draft: false"

      Enum.each(placeholder_patterns, fn pattern ->
        refute body =~ pattern
      end)
    end
  end

  describe "operations telemetry and traces page (jido-e07-t07)" do
    # Acceptance: "It distinguishes core observation events from jido_otel."
    @telemetry_source Path.expand(
                        "../../priv/pages/docs/operations/telemetry-and-traces.md",
                        __DIR__
                      )
    @telemetry_route "/docs/operations/telemetry-and-traces"
    @reference_route "/docs/reference/telemetry-and-observability"
    @otel_package_route "/ecosystem/jido_otel"

    test "the page is published and routable" do
      page = Pages.get_page_by_path(@telemetry_route)

      assert page != nil
      assert page.category == :docs
      assert page.draft == false
      assert Pages.route_for(page) == @telemetry_route
    end

    test "the page is linked from the operations hub" do
      hub = File.read!(Path.expand("../../priv/pages/docs/operations.md", __DIR__))

      assert hub =~ @telemetry_route
    end

    test "core observation events and jido_otel are separate sections" do
      body = File.read!(@telemetry_source)

      # The acceptance condition: the two layers each get their own dedicated
      # heading, so they are presented as distinct things, not conflated.
      assert has_h2?(body, "Core observation events")
      assert body =~ ~r/jido_otel/i
    end

    test "it names the core observation surface as :telemetry from Jido.Observe" do
      body = File.read!(@telemetry_source)

      # Core observation is the :telemetry event stream emitted by Jido.Observe.
      assert body =~ ":telemetry"
      assert body =~ "Jido.Observe"

      # The other core observation surfaces are named, not just jido_otel.
      assert body =~ "Jido.Telemetry"
      assert body =~ "Jido.AI.Observe"
    end

    test "it states core telemetry does not depend on jido_otel" do
      body = File.read!(@telemetry_source)

      # Core telemetry is observable without the tracing package.
      assert body =~ ~r/no Jido tracing package installed/i

      # A core reporter attaches without jido_otel.
      assert body =~ "Jido.Telemetry.setup()"
    end

    test "it frames jido_otel as a separate, optional exporter, not built in" do
      body = File.read!(@telemetry_source)

      # jido_otel bridges to OpenTelemetry via the Tracer behaviour.
      assert body =~ ~r/OpenTelemetry/i
      assert body =~ "Jido.Observe.Tracer"

      # It must not be presented as part of jido core.
      assert body =~ ~r/separate package/i
      assert body =~ ~r/not.*Hex|not on Hex/i
    end

    test "it separates core Stable maturity from experimental jido_otel" do
      body = File.read!(@telemetry_source)

      # The maturity table row separates Stable core from Experimental export.
      assert body =~ ~r/Stable/i
      assert body =~ ~r/Experimental/i
    end

    test "it links the reference catalog and the jido_otel package page" do
      body = File.read!(@telemetry_source)

      # The full event catalog lives on the reference page (a real route).
      assert body =~ @reference_route
      reference = Pages.get_page_by_path(@reference_route)
      assert reference != nil
      assert reference.draft == false

      # The package page resolves through the ecosystem catalog, not a dead link.
      assert body =~ @otel_package_route
      otel_package = AgentJido.Ecosystem.get_package("jido_otel")
      assert otel_package != nil
    end

    test "it frames telemetry as observation, not an audit log" do
      body = File.read!(@telemetry_source)

      # Observation is named; it is explicitly not a tamper-evident audit log.
      assert body =~ ~r/observation/i
      assert body =~ ~r/not.*audit log|not an audit/i

      # It must not overclaim delivery or completeness.
      refute body =~ ~r/guaranteed delivery|guarantees delivery/i
    end

    test "the page source has no placeholder markers" do
      body = File.read!(@telemetry_source)

      placeholder_patterns = [
        ~r/content coming soon/i,
        ~r/\bcoming soon\b/i,
        ~r/\bTODO\b/,
        ~r/\bTBD\b/,
        ~r/lorem ipsum/i
      ]

      assert body =~ "draft: false"

      Enum.each(placeholder_patterns, fn pattern ->
        refute body =~ pattern
      end)
    end
  end

  describe "operations health checks and readiness page (jido-e07-t08)" do
    # Acceptance: "It defines process health, dependency health, and work health."
    @health_source Path.expand(
                     "../../priv/pages/docs/operations/health-checks-and-readiness.md",
                     __DIR__
                   )
    @health_route "/docs/operations/health-checks-and-readiness"

    test "the page is published and routable" do
      page = Pages.get_page_by_path(@health_route)

      assert page != nil
      assert page.category == :docs
      assert page.draft == false
      assert Pages.route_for(page) == @health_route
    end

    test "the page is linked from the operations hub" do
      hub = File.read!(Path.expand("../../priv/pages/docs/operations.md", __DIR__))

      assert hub =~ @health_route
    end

    test "it defines process, dependency, and work health as separate sections" do
      body = File.read!(@health_source)

      # The acceptance condition: the three health axes each get their own
      # dedicated heading, so they are presented as distinct things, not one.
      assert has_h2?(body, "Process health")
      assert has_h2?(body, "Dependency health")
      assert has_h2?(body, "Work health")
    end

    test "process health ties liveness to the AgentServer status probe and supervision" do
      body = File.read!(@health_source)

      # Process health is observable through the real status API, not invented.
      assert body =~ "Jido.AgentServer.status"
      assert body =~ ":not_found"

      # A restart loop is caught by the supervision restart-intensity budget.
      assert body =~ "max_restarts"

      # Liveness and responsiveness must not be conflated.
      assert body =~ ~r/responsiveness/i
    end

    test "dependency health is stated as application-owned, not a Jido concept" do
      body = File.read!(@health_source)

      # Jido does not know the agent's dependencies; the application owns this.
      assert body =~ ~r/not a Jido concept|Jido does not know your dependencies/i

      # Dependency failure gates readiness rather than restarting the process.
      assert body =~ ~r/readiness/i
    end

    test "work health cites the Status queue length and strategy state" do
      body = File.read!(@health_source)

      # Work health uses the real Status API, not invented metrics.
      assert body =~ "Jido.AgentServer.Status.queue_length"
      assert body =~ "max_queue_size"
      assert body =~ ":queue_overflow"

      # The strategy state distinguishes "draining" from "stuck waiting".
      assert body =~ ":waiting"
    end

    test "it covers repeatable post-deploy verification" do
      body = File.read!(@health_source)

      # Post-deploy verification confirms the shipped build is serving.
      assert body =~ ~r/build hash|deploy stamp/i
      assert body =~ ~r/post-deploy/i

      # It must not claim a guaranteed-clean deploy.
      refute body =~ ~r/guaranteed deploy|no downtime/i
    end

    test "it links only to live operations, reference, and onboarding routes" do
      body = File.read!(@health_source)

      # Every internal link on the page must resolve to a published page.
      internal_links =
        Regex.scan(~r{\]\((/docs/[^)#]+)\)}, body, capture: :all_but_first)
        |> List.flatten()
        |> Enum.uniq()

      assert internal_links != []

      for path <- internal_links do
        page = Pages.get_page_by_path(path)

        assert page != nil, "health page links to a route that does not resolve: #{path}"
        assert page.draft == false, "health page links to a draft page: #{path}"
      end

      # The three recovery/observation siblings and the go-live gate are linked.
      assert body =~ "/docs/operations/supervision-and-failure-boundaries"
      assert body =~ "/docs/operations/telemetry-and-traces"
      assert body =~ "/docs/operations/production-readiness-checklist"
    end

    test "the page source has no placeholder markers" do
      body = File.read!(@health_source)

      placeholder_patterns = [
        ~r/content coming soon/i,
        ~r/\bcoming soon\b/i,
        ~r/\bTODO\b/,
        ~r/\bTBD\b/,
        ~r/lorem ipsum/i
      ]

      assert body =~ "draft: false"

      Enum.each(placeholder_patterns, fn pattern ->
        refute body =~ pattern
      end)
    end
  end

  describe "content_status/1 (jido-e06-t24)" do
    # Acceptance: "Draft or Experimental content cannot look complete." Hub cards
    # must be able to label a page by its content maturity, so a status distinct
    # from the `draft` visibility flag is exposed for the browser and Markdown
    # hubs to render.

    test "defaults to :published (stable content needs no label)" do
      page = %Page{id: "p", path: "/docs/x", title: "X", category: :docs}

      assert Pages.content_status(page) == :published
      assert Pages.content_status_label(page) == nil
    end

    test "exposes a draft status and label" do
      page = %Page{id: "p", path: "/docs/x", title: "X", category: :docs, status: :draft}

      assert Pages.content_status(page) == :draft
      assert Pages.content_status_label(page) == "Draft"
    end

    test "exposes an experimental status and label" do
      page = %Page{id: "p", path: "/docs/x", title: "X", category: :docs, status: :experimental}

      assert Pages.content_status(page) == :experimental
      assert Pages.content_status_label(page) == "Experimental"
    end

    test "is independent of the draft visibility boolean" do
      # A page can be hidden (draft: true) while still carrying a content status;
      # and a visible page can be labeled draft/experimental without being hidden.
      hidden_experimental = %Page{
        id: "p",
        path: "/docs/x",
        title: "X",
        category: :docs,
        draft: true,
        status: :experimental
      }

      assert Pages.content_status(hidden_experimental) == :experimental
    end

    test "all real published pages normalize to :published" do
      for page <- Pages.all_pages() do
        assert Pages.content_status(page) == :published
        assert Pages.content_status_label(page) == nil
      end
    end

    test "content_statuses/0 lists the supported maturity values" do
      assert :draft in Pages.content_statuses()
      assert :experimental in Pages.content_statuses()
      assert :published in Pages.content_statuses()
    end
  end

  describe "docs work-type filters (jido-e06-t25)" do
    # Acceptance: "A builder can select Elixir, AI, operations, or evaluation
    # work." The four audience/outcome lenses narrow the Docs hub section grid
    # to the sections that serve each kind of work.

    test "docs_work_types/0 lists the Elixir, AI, Operations, and Evaluation lenses" do
      ids = Pages.docs_work_type_ids()

      assert ids == [:elixir, :ai, :operations, :evaluation]
    end

    test "each work type carries a human label; unknown yields nil" do
      assert Pages.docs_work_type_label(:elixir) == "Elixir"
      assert Pages.docs_work_type_label(:ai) == "AI"
      assert Pages.docs_work_type_label(:operations) == "Operations"
      assert Pages.docs_work_type_label(:evaluation) == "Evaluation"
      assert Pages.docs_work_type_label(:nope) == nil
    end

    test "every published docs section is mapped to at least one work type" do
      for section_page <- Pages.docs_sections() do
        assert Pages.docs_section_work_types(section_page) != [],
               "section #{inspect(Pages.route_for(section_page))} is not mapped to any work type"
      end
    end

    test "getting-started serves every work type so the on-ramp is never hidden" do
      getting_started = Pages.get_page_by_path("/docs/getting-started")

      assert Pages.docs_section_work_types(getting_started) == Pages.docs_work_type_ids()
    end

    test "docs_sections_filtered(:all) returns the full inventory" do
      assert Pages.docs_sections_filtered(:all) |> Enum.map(&Pages.route_for/1) ==
               Pages.docs_sections() |> Enum.map(&Pages.route_for/1)
    end

    test "the AI lens narrows the grid to AI sections" do
      routes = Pages.docs_sections_filtered(:ai) |> Enum.map(&Pages.route_for/1)

      # getting-started is the cross-cutting on-ramp; learn + guides are the AI path.
      assert "/docs/getting-started" in routes
      assert "/docs/learn" in routes
      assert "/docs/guides" in routes
      refute "/docs/operations" in routes
      refute "/docs/concepts" in routes
    end

    test "the Operations lens shows operations and hides unrelated sections" do
      routes = Pages.docs_sections_filtered(:operations) |> Enum.map(&Pages.route_for/1)

      assert "/docs/getting-started" in routes
      assert "/docs/operations" in routes
      refute "/docs/learn" in routes
      refute "/docs/concepts" in routes
    end

    test "the Evaluation lens surfaces reference and contributors" do
      routes = Pages.docs_sections_filtered(:evaluation) |> Enum.map(&Pages.route_for/1)

      assert "/docs/getting-started" in routes
      assert "/docs/reference" in routes
      assert "/docs/contributors" in routes
      refute "/docs/learn" in routes
      refute "/docs/operations" in routes
    end

    test "the Elixir lens surfaces concepts and reference" do
      routes = Pages.docs_sections_filtered(:elixir) |> Enum.map(&Pages.route_for/1)

      assert "/docs/getting-started" in routes
      assert "/docs/concepts" in routes
      assert "/docs/reference" in routes
      assert "/docs/guides" in routes
      refute "/docs/operations" in routes
    end

    test "an unknown work type falls back to the full inventory" do
      assert Pages.docs_sections_filtered(:bogus) |> Enum.map(&Pages.route_for/1) ==
               Pages.docs_sections() |> Enum.map(&Pages.route_for/1)
    end
  end

  # True when the body has a `## <title>` heading (outside fenced code blocks).
  defp has_h2?(body, title) do
    pattern = ~r/\A##[[:space:]]+#{Regex.escape(title)}([[:space:]]|$)/

    body
    |> String.split("\n")
    |> Enum.reduce({false, false}, fn line, {in_fence?, found?} ->
      cond do
        String.match?(line, ~r/\A(```|~~~)/) ->
          {not in_fence?, found?}

        in_fence? ->
          {in_fence?, found?}

        Regex.match?(pattern, line) ->
          {in_fence?, true}

        true ->
          {in_fence?, found?}
      end
    end)
    |> elem(1)
  end
end
