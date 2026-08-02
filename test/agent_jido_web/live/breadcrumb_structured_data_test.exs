defmodule AgentJidoWeb.BreadcrumbStructuredDataTest do
  use AgentJidoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias AgentJido.Blog
  alias AgentJido.Examples

  test "documentation pages render their semantic hierarchy", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/docs/learn/agent-fundamentals")

    assert breadcrumb_names(html) == [
             "Jido",
             "Documentation",
             "Learn",
             "Agent Fundamentals on the BEAM"
           ]
  end

  test "blog posts render blog breadcrumbs", %{conn: conn} do
    post = Blog.get_published_post_by_slug!("jido-assembly-slack-clone")
    {:ok, _view, html} = live(conn, "/blog/#{post.id}")

    assert breadcrumb_names(html) == ["Jido", "Blog", post.title]
  end

  test "examples render example breadcrumbs", %{conn: conn} do
    example = Examples.get_example!("counter-agent")
    {:ok, _view, html} = live(conn, "/examples/#{example.slug}")

    assert breadcrumb_names(html) == ["Jido", "Examples", example.title]
  end

  test "feature pages render feature breadcrumbs", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/features/how-agents-work")

    assert breadcrumb_names(html) == ["Jido", "How Jido Works", "How Jido agents work"]
  end

  test "ecosystem package pages keep their accepted breadcrumb format", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/ecosystem/jido_mcp")

    assert breadcrumb_names(html) == ["Jido", "Ecosystem", "Jido MCP"]
  end

  defp breadcrumb_names(html) do
    ~r{<script[^>]*\btype="application/ld\+json"[^>]*>\s*(.*?)\s*</script>}s
    |> Regex.scan(html, capture: :all_but_first)
    |> Enum.map(fn [json] -> Jason.decode!(json) end)
    |> Enum.find(&(&1["@type"] == "BreadcrumbList"))
    |> Map.fetch!("itemListElement")
    |> Enum.map(&Map.fetch!(&1, "name"))
  end
end
