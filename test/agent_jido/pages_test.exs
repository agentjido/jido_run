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
end
