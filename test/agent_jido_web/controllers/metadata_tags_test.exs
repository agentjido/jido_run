defmodule AgentJidoWeb.MetadataTagsTest do
  use AgentJidoWeb.ConnCase, async: true

  alias AgentJido.Blog
  alias AgentJido.Pages
  import Phoenix.LiveViewTest

  test "GET / renders release metadata with canonical and social images", %{conn: conn} do
    conn = get(conn, "/")
    body = response(conn, 200)

    assert body =~ "Build AI Agents That Run in Production · Agent Jido"

    assert_meta_content(
      body,
      "description",
      "Jido is an open-source agent framework for Elixir. Build supervised AI agents with fault tolerance, tool calling, and multi-agent coordination built in."
    )

    assert body =~ ~r/<link rel="canonical" href="#{Regex.escape(AgentJidoWeb.Endpoint.url() <> "/")}"\s*\/?>/

    assert body =~
             ~r/<meta property="og:image" content="#{Regex.escape(AgentJidoWeb.Endpoint.url() <> "/og/render/home")}"\s*\/?>/

    assert body =~
             ~r/<meta name="twitter:image" content="#{Regex.escape(AgentJidoWeb.Endpoint.url() <> "/og/render/home")}"\s*\/?>/

    assert length(Regex.scan(~r/<meta name="twitter:card"/, body)) == 1
  end

  test "GET /features uses route-specific title and description", %{conn: conn} do
    conn = get(conn, "/features")
    body = response(conn, 200)

    assert body =~ "How Jido Works · Agent Jido"

    assert_meta_content(
      body,
      "description",
      "The architecture behind agents that stay up, recover from crashes, and coordinate under real load."
    )

    assert body =~
             ~r/<meta property="og:image" content="#{Regex.escape(AgentJidoWeb.Endpoint.url() <> "/og/render/features")}"\s*\/?>/

    refute body =~ "<title>Agent Jido</title>"
  end

  test "GET /blog/:slug uses post title and post description metadata", %{conn: conn} do
    post =
      Blog.all_posts()
      |> Enum.find(fn entry -> String.trim(to_string(entry.description)) != "" end)
      |> Kernel.||(Blog.all_posts() |> hd())

    conn = get(conn, "/blog/#{post.id}")
    body = response(conn, 200)

    assert body =~ "#{post.title} · Agent Jido"

    if String.trim(to_string(post.description)) != "" do
      assert_meta_content(body, "description", String.trim(post.description))
    else
      assert body =~ ~r/<meta name="description" content=".+?"\s*\/?>/
    end

    expected_og =
      Map.get(post.seo || %{}, :og_image) || Map.get(post.seo || %{}, "og_image") ||
        AgentJidoWeb.Endpoint.url() <> "/og/render/blog/#{post.id}"

    assert body =~
             ~r/<meta property="og:image" content="#{Regex.escape(expected_og)}"\s*\/?>/
  end

  test "query-string views point to the clean canonical URL", %{conn: conn} do
    path = "/examples/runic-structured-llm-branching"

    body =
      conn
      |> get(path <> "?source=2&tab=source")
      |> response(200)

    assert body =~
             ~r/<link rel="canonical" href="#{Regex.escape(AgentJidoWeb.Endpoint.url() <> path)}"\s*\/?>/

    refute body =~ ~r/<link rel="canonical" href="[^"]+\?/
  end

  test "GET /docs uses section-specific metadata", %{conn: conn} do
    conn = get(conn, "/docs")
    body = response(conn, 200)

    assert body =~ "Jido Documentation · Agent Jido"

    assert_meta_content(
      body,
      "description",
      "Reference docs and implementation guides for building reliable multi-agent systems with Jido."
    )

    assert body =~
             ~r/<meta property="og:image" content="#{Regex.escape(AgentJidoWeb.Endpoint.url() <> "/og/render/docs")}"\s*\/?>/
  end

  test "docs detail route emits dynamic og:image path", %{conn: conn} do
    docs_path =
      Pages.pages_by_category(:docs)
      |> Enum.map(&Pages.route_for/1)
      |> Enum.find(&(&1 != "/docs"))
      |> Kernel.||("/docs")

    conn = get(conn, docs_path)
    body = response(conn, 200)

    assert body =~
             ~r/<meta property="og:image" content="#{Regex.escape(AgentJidoWeb.Endpoint.url() <> "/og/render" <> docs_path)}"\s*\/?>/
  end

  test "missing routes emit noindex robots, no canonical, and a single twitter card", %{conn: conn} do
    conn = get(conn, "/totally-missing-route")
    body = response(conn, 404)

    assert body =~ ~r/<meta name="robots" content="noindex,\s*nofollow"\s*\/?>/
    refute body =~ ~r/<link rel="canonical"/
    assert length(Regex.scan(~r/<meta name="twitter:card"/, body)) == 1
  end

  test "explicit og_image assign overrides dynamic default mapping" do
    conn = build_conn(:get, "/features")

    html =
      render_component(&AgentJidoWeb.Layouts.root/1,
        conn: conn,
        inner_content: "",
        page_title: "Test Page",
        meta_description: "Test description",
        og_image: "https://cdn.example.com/custom-og.png"
      )

    assert html =~ ~s(<meta property="og:image" content="https://cdn.example.com/custom-og.png")
    assert html =~ ~s(<meta name="twitter:image" content="https://cdn.example.com/custom-og.png")
  end

  defp assert_meta_content(body, name, content) do
    escaped_name = Regex.escape(name)
    escaped_content = Regex.escape(content)

    assert body =~ ~r/<meta name="#{escaped_name}" content="#{escaped_content}"\s*\/?>/
  end
end
