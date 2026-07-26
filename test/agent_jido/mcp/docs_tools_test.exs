defmodule AgentJido.MCP.DocsToolsTest do
  use ExUnit.Case, async: true

  alias AgentJido.ContentAssistant.Result
  alias AgentJido.MCP.DocsTools

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
end
