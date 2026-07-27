defmodule AgentJido.MCP.DocsToolsTest do
  use ExUnit.Case, async: true

  alias AgentJido.ContentAssistant.Result
  alias AgentJido.Ecosystem.Stacks
  alias AgentJido.Examples
  alias AgentJido.MCP
  alias AgentJido.MCP.DocsTools
  alias AgentJido.Pages
  alias AgentJidoWeb.MarkdownContent

  defmodule RetrievalStub do
    def query_with_status(_query, _opts) do
      {:ok,
       [
         %Result{
           title: "Plugins and composable agents",
           snippet: "Compose runtime plugins safely.",
           url: "/docs/learn/plugins-and-composable-agents",
           source_type: :docs,
           score: 0.9
         },
         %Result{
           title: "Jido Skill",
           snippet: "Package listing",
           url: "/ecosystem/jido_skill",
           source_type: :ecosystem,
           score: 0.7
         }
       ], :success}
    end
  end

  test "search_docs returns only docs routes with section metadata" do
    assert {:ok, result} =
             DocsTools.search_docs(
               %{"query" => "plugins"},
               retrieval_module: RetrievalStub
             )

    assert result["structuredContent"]["retrieval_status"] == "success"

    assert [
             %{
               "path" => "/docs/learn/plugins-and-composable-agents",
               "section" => "learn",
               "canonical_url" => canonical_url
             }
           ] = result["structuredContent"]["results"]

    assert canonical_url =~ "/docs/learn/plugins-and-composable-agents"
  end

  test "search_docs rejects blank queries" do
    assert {:error, %{"code" => "invalid_arguments"}} =
             DocsTools.search_docs(%{"query" => "   "}, retrieval_module: RetrievalStub)
  end

  test "tool descriptions state the v1 docs-only scope" do
    # Product copy and tool scope must agree (jido-e10-t17): every public tool
    # description must keep examples/skills/ecosystem out of the promised scope.
    by_name = Map.new(DocsTools.tools(), &{&1["name"], &1["description"]})

    search_description = by_name["search_docs"]
    assert search_description =~ "/docs/**"
    assert search_description =~ "docs only"
    assert search_description =~ "examples"

    for name <- ~w(get_doc list_sections) do
      description = by_name[name]
      assert description =~ "documentation", "expected #{name} to stay docs-scoped"
    end
  end

  test "get_doc resolves legacy docs routes to canonical markdown" do
    assert {:ok, result} = DocsTools.get_doc(%{"path" => "/docs/chat-response"}, [])

    structured = result["structuredContent"]

    assert structured["path"] == "/docs/guides/cookbook/chat-response"
    assert structured["section"] == "guides"
    assert structured["legacy_resolution"]["requested_path"] == "/docs/chat-response"
    assert structured["markdown"] =~ "#"
  end

  test "list_sections returns section roots and visible child pages" do
    assert {:ok, result} = DocsTools.list_sections(%{}, [])

    sections = result["structuredContent"]["sections"]
    learn_section = Enum.find(sections, &(&1["section"] == "learn"))

    assert is_map(learn_section)
    assert learn_section["path"] == "/docs/learn"
    assert learn_section["page_count"] > 1
    assert Enum.any?(learn_section["pages"], &(&1["path"] == "/docs/learn/ai-chat-agent"))
  end

  describe "operational-control query path (jido-e10-t30)" do
    # Acceptance: "A client can retrieve the canonical control overview and its
    # proof without a broad text guess." get_operational_control is a
    # deterministic, no-argument path: it returns the canonical Security and
    # governance overview, the nine control dimensions, and the proof pointers
    # (the docs pages that ground each claim and the package columns whose
    # package pages carry release version/support/proof). A client calls it by
    # name instead of guessing an operational-control term in search_docs.

    test "get_operational_control returns the canonical overview, dimensions, and proof with no arguments" do
      assert {:ok, result} = DocsTools.get_operational_control(%{}, [])

      structured = result["structuredContent"]

      # The canonical control overview is the Security and governance guide.
      overview = structured["overview"]
      assert overview["title"] == "Security and governance"
      assert overview["path"] == "/docs/operations/security-and-governance"
      assert overview["canonical_url"] =~ "/docs/operations/security-and-governance"
      assert overview["section"] == "operations"
      assert overview["markdown"] =~ "#"

      # The nine operational-control dimensions come straight from ControlMatrix.
      dimensions = structured["dimensions"]
      dimension_keys = Enum.map(dimensions, & &1["key"])
      assert "context" in dimension_keys
      assert "approval" in dimension_keys
      assert "integration_duties" in dimension_keys
      assert length(dimensions) == 9

      # Proof: the docs pages that ground each claim plus the package columns
      # whose package pages carry release version/support/proof.
      proof = structured["proof"]

      related_paths = Enum.map(proof["related_pages"], & &1["path"])
      assert "/docs/operations/rate-limits-and-cost-budgets" in related_paths
      assert "/docs/operations/production-readiness-checklist" in related_paths
      assert Enum.all?(proof["related_pages"], &(&1["title"] != nil))
      assert Enum.all?(proof["related_pages"], &(&1["canonical_url"] =~ &1["path"]))

      assert Enum.any?(proof["matrix_packages"], &(&1["label"] == "jido"))
      assert Enum.all?(proof["matrix_packages"], &(&1["canonical_url"] =~ &1["path"]))

      assert proof["release_basis"] =~ "Security and governance"
    end

    test "get_operational_control is deterministic and takes no query argument" do
      # A client does not guess a control term; any argument is rejected so the
      # path cannot silently become a text search.
      assert {:error, %{"code" => "invalid_arguments"}} =
               DocsTools.get_operational_control(%{"query" => "authorization"}, [])
    end

    test "the tool catalog advertises get_operational_control with docs-scoped copy" do
      # Product copy and tool scope must agree (jido-e10-t17): the description
      # must stay docs-scoped and point a client here instead of search_docs.
      by_name = Map.new(DocsTools.tools(), &{&1["name"], &1["description"]})

      control = by_name["get_operational_control"]
      assert control =~ "Security and governance"
      assert control =~ "documentation"
      assert control =~ "search_docs"
    end

    test "get_operational_control overview markdown is byte-identical to the public Markdown endpoint" do
      # The overview a client retrieves through MCP must match the public .md
      # surface so the two cannot drift (jido-e10-t20 parity discipline).
      assert {:ok, %{"structuredContent" => %{"overview" => %{"markdown" => mcp_markdown}}}} =
               DocsTools.get_operational_control(%{}, [])

      assert {:ok, public_markdown} =
               MarkdownContent.resolve(
                 "/docs/operations/security-and-governance",
                 MCP.canonical_url("/docs/operations/security-and-governance")
               )

      assert mcp_markdown == public_markdown
    end
  end

  describe "example retrieval (jido-e10-t18)" do
    # Acceptance: "It returns the canonical example Markdown and metadata."
    # get_example is the first scope expansion beyond the docs-only surface: a
    # client retrieves one published interactive example by path or slug and
    # receives the canonical example Markdown (byte-identical to the public
    # /examples/<slug>.md endpoint, because both flow through
    # MarkdownContent.resolve/2) plus the example's proof and content metadata.

    test "get_example returns the canonical markdown and metadata by slug" do
      assert {:ok, result} = DocsTools.get_example(%{"path" => "counter-agent"}, [])

      structured = result["structuredContent"]

      assert structured["title"] == "Counter Agent"
      assert structured["path"] == "/examples/counter-agent"
      assert structured["canonical_url"] =~ "/examples/counter-agent"
      assert structured["category"] == "core"
      assert structured["markdown"] =~ "#"

      metadata = structured["metadata"]
      assert metadata["content_type"] == "Example"
      assert metadata["status"] == "Beta"
      assert metadata["packages"] == ["jido"]
      assert metadata["package_maturity"] == "Beta"
      assert metadata["difficulty"] == "beginner"
      assert metadata["outcome"] =~ "supervised Jido agent"
    end

    test "get_example accepts /examples/<slug>, the .md suffix, and a same-site URL" do
      for path <- [
            "/examples/counter-agent",
            "/examples/counter-agent.md",
            "counter-agent.md"
          ] do
        assert {:ok, %{"structuredContent" => %{"path" => "/examples/counter-agent"}}} =
                 DocsTools.get_example(%{"path" => path}, []),
               "expected #{inspect(path)} to resolve to the counter-agent example"
      end
    end

    test "get_example rejects a blank or missing path" do
      assert {:error, %{"code" => "invalid_arguments"}} =
               DocsTools.get_example(%{"path" => "   "}, [])

      assert {:error, %{"code" => "invalid_arguments"}} =
               DocsTools.get_example(%{}, [])
    end

    test "get_example returns not_found for an unknown slug" do
      assert {:error, %{"code" => "not_found"}} =
               DocsTools.get_example(%{"path" => "no-such-example"}, [])
    end

    test "get_example does not serve a non-example route" do
      # A docs path must not resolve through the example tool.
      assert {:error, %{"code" => "not_found"}} =
               DocsTools.get_example(%{"path" => "/docs/getting-started/first-agent"}, [])
    end

    test "the structured metadata agrees with the markdown content-metadata block" do
      # The structured metadata status/version/last_validated must match the
      # `## Content metadata` block appended to the returned markdown, so the two
      # cannot drift (controlled-agent carries a last_validated date).
      assert {:ok, %{"structuredContent" => structured}} =
               DocsTools.get_example(%{"path" => "controlled-agent"}, [])

      metadata = structured["metadata"]
      markdown = structured["markdown"]

      assert metadata["content_type"] == "Example"
      assert markdown =~ "Content type: Example"
      assert markdown =~ "Status: #{metadata["status"]}"
      assert markdown =~ "Last validated: #{metadata["last_validated"]}"
    end

    test "get_example markdown is byte-identical to the public Markdown endpoint for every live example" do
      # jido-e10-t20 parity discipline extended to examples: the markdown an MCP
      # client retrieves must match the public /examples/<slug>.md surface.
      example_routes =
        Examples.all_examples()
        |> Enum.map(&"/examples/#{&1.slug}")
        |> Enum.uniq()

      assert example_routes != [], "no live examples to assert MCP/Markdown parity against"

      for path <- example_routes do
        assert {:ok, %{"structuredContent" => %{"markdown" => mcp_markdown}}} =
                 DocsTools.get_example(%{"path" => path}, []),
               "MCP get_example could not serve example #{path}"

        assert {:ok, public_markdown} = MarkdownContent.resolve(path, MCP.canonical_url(path)),
               "public Markdown endpoint could not serve example #{path}"

        assert mcp_markdown == public_markdown,
               "MCP get_example markdown drifted from the public Markdown endpoint for #{inspect(path)}"
      end
    end

    test "the tool catalog advertises get_example with example-scoped copy" do
      by_name = Map.new(DocsTools.tools(), &{&1["name"], &1["description"]})

      example = by_name["get_example"]
      assert example =~ "/examples/<slug>"
      assert example =~ "Markdown"
      assert example =~ "metadata"
      assert example =~ "search_docs"
    end
  end

  describe "ecosystem stack retrieval (jido-e10-t19)" do
    # Acceptance: "A client can ask for a recommended package set."
    # get_recommended_stack is the ecosystem expansion beyond the docs/example
    # surface: a client asks for a recommended starting package set (an ecosystem
    # stack — core, ai, or operate) and receives the packages with their explicit
    # supported ranges, source, support level, package-page links, and a copyable
    # mix.exs deps/0 block. The package set is derived from
    # AgentJido.Ecosystem.Stacks (the single source of truth for the home
    # dependency blocks and the Ecosystem compatibility matrix), so it can never
    # drift from install or the /ecosystem markdown hub.

    test "get_recommended_stack returns all three recommended stacks when no key is given" do
      assert {:ok, result} = DocsTools.get_recommended_stack(%{}, [])

      stacks = result["structuredContent"]["stacks"]

      assert Enum.map(stacks, & &1["key"]) == ~w(core ai operate)
      assert Enum.map(stacks, & &1["name"]) == ~w(Core AI Operate)
      assert Enum.all?(stacks, &(&1["purpose"] != ""))

      # Each recommended package set carries packages, an explicit range per
      # package, package-page links, and a copyable deps block.
      for stack <- stacks do
        assert stack["packages"] != [], "expected the #{stack["key"]} stack to list packages"
        assert stack["dependency_block"] =~ "defp deps do"
        assert String.ends_with?(stack["dependency_block"], "end")

        for pkg <- stack["packages"] do
          assert is_binary(pkg["name"]) and pkg["name"] != ""
          assert is_binary(pkg["role"]) and pkg["role"] != ""
          assert is_binary(pkg["range"]) and pkg["range"] != "", "expected a range for #{pkg["name"]}"
          assert pkg["path"] == "/ecosystem/#{pkg["name"]}"
          assert pkg["canonical_url"] =~ pkg["path"]
          assert pkg["source"] in ["hex", "github", "unknown"]
          assert pkg["support_level"] in ["stable", "beta", "experimental"]
        end
      end
    end

    test "get_recommended_stack returns a single recommended package set by key" do
      for {key, name} <- [{"core", "Core"}, {"ai", "AI"}, {"operate", "Operate"}] do
        assert {:ok, %{"structuredContent" => %{"stacks" => [stack]}}} =
                 DocsTools.get_recommended_stack(%{"stack" => key}, []),
               "expected to resolve the #{key} stack"

        assert stack["key"] == key
        assert stack["name"] == name

        # The copyable deps block lists exactly this stack's packages.
        for pkg <- stack["packages"] do
          assert stack["dependency_block"] =~ "{:#{pkg["name"]},"
        end
      end
    end

    test "get_recommended_stack accepts the stack key case-insensitively" do
      # A client passing the display name's casing still resolves the package set.
      assert {:ok, %{"structuredContent" => %{"stacks" => [stack]}}} =
               DocsTools.get_recommended_stack(%{"stack" => "AI"}, [])

      assert stack["key"] == "ai"
    end

    test "get_recommended_stack returns not_found for an unknown stack key" do
      assert {:error, %{"code" => "not_found", "message" => message}} =
               DocsTools.get_recommended_stack(%{"stack" => "no-such-stack"}, [])

      assert message =~ "core"
      assert message =~ "ai"
      assert message =~ "operate"
    end

    test "get_recommended_stack rejects a blank stack argument" do
      # The schema declares minLength: 1, so a blank key is a client bug, not a
      # request for all stacks.
      assert {:error, %{"code" => "invalid_arguments"}} =
               DocsTools.get_recommended_stack(%{"stack" => "   "}, [])

      assert {:error, %{"code" => "invalid_arguments"}} =
               DocsTools.get_recommended_stack(%{"stack" => 1}, [])
    end

    test "the recommended package set never drifts from the authoritative Stacks registry" do
      # Parity discipline (jido-e10-t20) extended to the ecosystem surface: the
      # ranges, sources, and copyable deps block the tool returns must equal
      # AgentJido.Ecosystem.Stacks — the same module the home dependency blocks
      # and the public /ecosystem markdown hub render from — so the machine and
      # browser surfaces cannot disagree.
      assert {:ok, %{"structuredContent" => %{"stacks" => stacks}}} =
               DocsTools.get_recommended_stack(%{}, [])

      for stack <- stacks do
        declared = Stacks.get_stack!(stack["key"])

        assert Enum.map(stack["packages"], & &1["name"]) ==
                 Enum.map(declared.packages, & &1.name)

        for pkg <- stack["packages"] do
          assert pkg["range"] == Stacks.supported_range(pkg["name"])
          assert pkg["source"] == Stacks.source(pkg["name"]) |> to_string()
          assert pkg["source_label"] == Stacks.source_label(Stacks.source(pkg["name"]))
        end

        # The copyable block matches the registry's generated deps/0 function.
        assert stack["dependency_block"] == Stacks.dependency_block(declared.packages)
      end
    end

    test "the tool catalog advertises get_recommended_stack with package-set copy" do
      # Product copy and tool scope must agree (jido-e10-t17): the description
      # must name the recommended stacks and point a client here for package
      # selection instead of search_docs.
      by_name = Map.new(DocsTools.tools(), &{&1["name"], &1["description"]})

      stack = by_name["get_recommended_stack"]
      assert stack =~ "recommended"
      assert stack =~ "core"
      assert stack =~ "ai"
      assert stack =~ "operate"
      assert stack =~ "mix.exs"
      assert stack =~ "search_docs"
    end
  end

  describe "MCP markdown parity with public Markdown (jido-e10-t20)" do
    # Acceptance: "MCP returns the same expanded code as public Markdown." MCP
    # get_doc delegates to MarkdownContent.resolve/2 (the same resolver the public
    # .md endpoint / LLMResponse plug serves), so the two surfaces must agree
    # byte-for-byte on every docs page. This is locked here so the parity cannot
    # drift silently — e.g. if get_doc ever stopped expanding {{mix_dep:*}}
    # tokens, the public `.md` payload (which expands them) would diverge.

    test "get_doc returns byte-identical markdown to the public Markdown endpoint for every docs page" do
      docs_routes =
        Pages.pages_by_category(:docs)
        |> Enum.map(&Pages.route_for/1)
        |> Enum.uniq()

      assert docs_routes != [], "no docs routes to assert MCP/Markdown parity against"

      for path <- docs_routes do
        assert {:ok, %{"structuredContent" => %{"markdown" => mcp_markdown}}} =
                 DocsTools.get_doc(%{"path" => path}, []),
               "MCP get_doc could not serve docs page #{path}"

        assert {:ok, public_markdown} =
                 MarkdownContent.resolve(path, MCP.canonical_url(path)),
               "public Markdown endpoint could not serve docs page #{path}"

        assert mcp_markdown == public_markdown,
               "MCP get_doc markdown drifted from the public Markdown endpoint for #{inspect(path)}"
      end
    end

    test "the canonical placeholder page carries expanded code, not raw tokens, on both surfaces" do
      # The first-LLM-agent page source carries {{mix_dep:jido}}, {{mix_dep:jido_ai}},
      # and {{mix_dep:req_llm}} tokens. Both MCP get_doc and the public Markdown
      # endpoint must return the EXPANDED dependency tuples, never the raw tokens.
      path = "/docs/getting-started/first-llm-agent"

      assert {:ok, %{"structuredContent" => %{"markdown" => mcp_markdown}}} =
               DocsTools.get_doc(%{"path" => path}, [])

      {:ok, public_markdown} = MarkdownContent.resolve(path, MCP.canonical_url(path))

      # The two surfaces agree byte-for-byte.
      assert mcp_markdown == public_markdown,
             "MCP get_doc markdown drifted from the public Markdown endpoint for #{inspect(path)}"

      # And that shared payload is the expanded code, not the raw {{...}} tokens.
      refute mcp_markdown =~ ~r/\{\{/,
             "MCP markdown carries unresolved {{...}} placeholders"

      assert mcp_markdown =~ "{:jido,"
      assert mcp_markdown =~ "{:jido_ai,"
    end
  end
end
