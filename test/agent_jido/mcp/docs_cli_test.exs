defmodule AgentJido.MCP.DocsCLITest do
  use ExUnit.Case, async: true

  alias AgentJido.MCP.DocsCLI

  defmodule ClientStub do
    def initialize(_endpoint, _opts), do: {:ok, %{"protocolVersion" => "2025-11-25"}}

    def search_docs(_endpoint, "plugins", _limit, _opts) do
      {:ok,
       %{
         "structuredContent" => %{
           "retrieval_status" => "success",
           "results" => [
             %{
               "title" => "Plugins and composable agents",
               "path" => "/docs/learn/plugins-and-composable-agents",
               "section" => "learn",
               "snippet" => "Compose runtime plugins safely.",
               "score" => 0.92
             }
           ]
         }
       }}
    end

    def get_doc(_endpoint, "/docs/learn/plugins-and-composable-agents", _opts) do
      {:ok,
       %{
         "structuredContent" => %{
           "title" => "Plugins and composable agents",
           "path" => "/docs/learn/plugins-and-composable-agents",
           "section" => "learn",
           "canonical_url" => "http://localhost:4001/docs/learn/plugins-and-composable-agents",
           "markdown" => "# Plugins and composable agents\n\nCompose runtime plugins safely."
         }
       }}
    end

    def get_doc(_endpoint, path, _opts) do
      {:ok,
       %{
         "structuredContent" => %{
           "title" => "Fetched doc",
           "path" => path,
           "section" => "guides",
           "canonical_url" => "http://localhost:4001#{path}",
           "markdown" => "# Fetched doc\n\nDirect fetch works."
         }
       }}
    end

    def list_sections(_endpoint, _opts) do
      {:ok,
       %{
         "structuredContent" => %{
           "sections" => [
             %{
               "title" => "Learn",
               "path" => "/docs/learn",
               "section" => "learn",
               "page_count" => 2,
               "pages" => [
                 %{"title" => "AI Chat Agent", "path" => "/docs/learn/ai-chat-agent"}
               ]
             }
           ]
         }
       }}
    end

    def get_operational_control(_endpoint, _opts) do
      {:ok,
       %{
         "structuredContent" => %{
           "overview" => %{
             "title" => "Security and Governance",
             "path" => "/docs/operations/security-and-governance",
             "canonical_url" => "http://localhost:4001/docs/operations/security-and-governance",
             "markdown" => "# Security and Governance\n\nControl boundaries."
           },
           "dimensions" => [
             %{"key" => "context", "label" => "Context", "description" => "Principal and trace context."},
             %{"key" => "approval", "label" => "Approval", "description" => "A sign-off before work proceeds."}
           ],
           "proof" => %{
             "related_pages" => [
               %{"title" => "Production Readiness Checklist", "path" => "/docs/operations/production-readiness-checklist"}
             ],
             "matrix_packages" => [
               %{"label" => "jido", "path" => "/ecosystem/jido"}
             ],
             "release_basis" => "Each package's release version and proof live on its package page."
           }
         }
       }}
    end
  end

  test "run/2 renders search results and previews" do
    assert {:ok, output} = DocsCLI.run(["plugins"], client_module: ClientStub)

    assert output =~ "Question: plugins"
    assert output =~ "Top matches:"
    assert output =~ "/docs/learn/plugins-and-composable-agents"
    assert output =~ "Top doc previews:"
  end

  test "run/2 ignores a leading separator argument" do
    assert {:ok, output} = DocsCLI.run(["--", "--sections"], client_module: ClientStub)
    assert output =~ "Documentation sections: 1"
  end

  test "run/2 supports direct doc fetch mode" do
    assert {:ok, output} =
             DocsCLI.run(["--get", "/docs/guides/cookbook/chat-response"], client_module: ClientStub)

    assert output =~ "Title: Fetched doc"
    assert output =~ "Preview:"
  end

  test "run/2 supports section listing mode" do
    assert {:ok, output} = DocsCLI.run(["--sections"], client_module: ClientStub)

    assert output =~ "Documentation sections: 1"
    assert output =~ "Learn (learn)"
    assert output =~ "/docs/learn/ai-chat-agent"
  end

  test "run/2 supports the operational-control query path (--control)" do
    # jido-e10-t30: a client retrieves the canonical control overview and proof
    # by name, without a broad text guess.
    assert {:ok, output} = DocsCLI.run(["--control"], client_module: ClientStub)

    assert output =~ "Operational control overview: Security and Governance"
    assert output =~ "/docs/operations/security-and-governance"
    assert output =~ "Control dimensions: 2"
    assert output =~ "Context: Principal and trace context."
    assert output =~ "Proof pages:"
    assert output =~ "Production Readiness Checklist"
    assert output =~ "Package proof:"
    assert output =~ "Release basis:"
  end

  test "run/2 rejects --control combined with a query" do
    assert {:error, output} = DocsCLI.run(["--control", "authorization"], client_module: ClientStub)
    assert output =~ "--control cannot be combined"
  end

  test "run/2 returns usage when no command is provided" do
    assert {:error, output} = DocsCLI.run([], client_module: ClientStub)
    assert output =~ "Usage:"
  end
end
