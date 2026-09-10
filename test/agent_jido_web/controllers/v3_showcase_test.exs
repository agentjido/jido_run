defmodule AgentJidoWeb.V3ShowcaseTest do
  use AgentJidoWeb.ConnCase, async: true

  alias AgentJidoWeb.Showcase.V3

  test "renders a read-only V3 showcase with highlighted Elixir", %{conn: conn} do
    conn = get(conn, "/v3")
    html = html_response(conn, 200)

    assert html =~ "JIDO V3"
    assert html =~ "COMING SOON"
    assert html =~ "Build large-scale Actor and Agent systems"
    assert html =~ "Jido.Flow"
    assert html =~ "Jido.Topology"
    assert html =~ "https://hex.pm/packages/jido_action"
    assert html =~ "agentic backpressure"
    assert html =~ "versioned JSON documents"
    refute html =~ "rebuilds the framework"
    refute html =~ "shaped like Elixir"
    refute html =~ "BROWSE V3 EXAMPLES"
    refute html =~ "github.com/agentjido/jido/tree/v3-spike/examples"
    assert html =~ ~s(class="highlight marketing-highlight language-elixir")
    assert html =~ ~s(name="robots" content="noindex, nofollow")

    {:ok, document} = Floki.parse_document(html)
    assert V3.snippets().flow =~ ~s(map "priced")
    assert V3.snippets().flow =~ ~s(reduce "summary")
    assert V3.snippets().ai =~ "reasoning(:react)"

    assert Floki.find(document, "#jido-v3-showcase [phx-click]") == []
    assert Floki.find(document, "#jido-v3-showcase form") == []
    refute html =~ "Run example"
  end

  test "keeps the showcase out of public content listings", %{conn: conn} do
    blog_html = conn |> get("/blog") |> html_response(200)
    sitemap_xml = conn |> recycle() |> get("/sitemap.xml") |> response(200)

    refute blog_html =~ "A First Look at Jido V3"
    refute sitemap_xml =~ "/v3"
  end

  test "all displayed samples are valid Elixir syntax" do
    for {name, source} <- V3.snippets() do
      assert {:ok, _ast} = Code.string_to_quoted(source), "invalid #{name} sample"
    end
  end
end
