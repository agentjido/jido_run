defmodule AgentJidoWeb.SitemapControllerTest do
  use AgentJidoWeb.ConnCase, async: true

  alias AgentJido.Blog
  alias AgentJido.Ecosystem
  alias AgentJido.Examples
  alias AgentJido.Pages

  test "returns raw xml sitemap payload", %{conn: conn} do
    conn = get(conn, "/sitemap.xml")
    body = response(conn, 200)

    assert body =~ ~s(<?xml version="1.0" encoding="UTF-8"?>)
    assert body =~ "<urlset"
    refute body =~ "&lt;urlset"
    refute body =~ "<html"
    assert get_resp_header(conn, "content-type") |> hd() =~ "application/xml"
  end

  test "includes ecosystem package pages", %{conn: conn} do
    conn = get(conn, "/sitemap.xml")

    assert response(conn, 200)

    body = response(conn, 200)
    assert body =~ "/ecosystem"

    for pkg <- Ecosystem.public_packages() do
      assert body =~ "/ecosystem/#{pkg.id}"
    end
  end

  test "includes public example detail pages", %{conn: conn} do
    body =
      conn
      |> get("/sitemap.xml")
      |> response(200)

    for example <- Examples.all_examples() do
      assert body =~ "/examples/#{example.slug}"
    end
  end

  test "includes page URLs from the Pages system", %{conn: conn} do
    body =
      conn
      |> get("/sitemap.xml")
      |> response(200)

    # Training pages are intentionally retired from public routing
    for page <- Pages.pages_by_category(:training) do
      refute body =~ Pages.route_for(page)
    end

    assert body =~ "/features"
    assert body =~ "/community/showcase"
    refute body =~ "/partners"
    refute body =~ "/benchmarks"
  end

  test "includes canonical blog URLs and excludes legacy underscore slugs", %{conn: conn} do
    body =
      conn
      |> get("/sitemap.xml")
      |> response(200)

    for post <- Blog.all_posts() do
      assert body =~ "/blog/#{post.id}"
    end

    refute body =~ "/blog/announcing-req_llm-1_0"
    refute body =~ "/blog/introducing-req_llm"
    refute body =~ "/blog/jido_signal"
  end

  test "includes public Build and Compare pages with accurate lastmod dates (E10-T22)", %{
    conn: conn
  } do
    body =
      conn
      |> get("/sitemap.xml")
      |> response(200)

    pages = Pages.pages_by_category(:build) ++ Pages.pages_by_category(:compare)

    for page <- pages do
      route = Pages.route_for(page)
      assert body =~ route, "missing sitemap entry for #{route}"

      modification_date = Pages.modification_date(page)
      assert modification_date != nil, "no modification date recorded for #{page.path}"

      block = url_block_for(body, route)

      assert block =~ "<lastmod>#{modification_date}</lastmod>",
             "expected <lastmod>#{modification_date}</lastmod> in sitemap block for #{route}"
    end
  end

  test "includes the canonical control overview and controlled-Agent example with accurate lastmod dates (E10-T33)",
       %{conn: conn} do
    body =
      conn
      |> get("/sitemap.xml")
      |> response(200)

    # The control overview is the canonical operational-control docs page — the
    # route the home control message, search aliases, and MCP all point at.
    overview = Pages.get_page_by_path!("/docs/operations/security-and-governance")

    overview_block = url_block_for(body, "/docs/operations/security-and-governance")
    refute overview_block == "", "control overview route missing from sitemap"

    assert overview_block =~ "<lastmod>#{Pages.modification_date(overview)}</lastmod>",
           "control overview must carry an accurate <lastmod> so search engines " <>
             "receive the route with a correct date"

    # The controlled-Agent example is the canonical operational-control proof
    # route — the single run that proves the complete control path.
    example = Examples.get_example!("controlled-agent")

    example_block = url_block_for(body, "/examples/controlled-agent")
    refute example_block == "", "controlled-Agent example route missing from sitemap"

    assert example_block =~ "<lastmod>#{Examples.modification_date(example)}</lastmod>",
           "controlled-Agent example must carry an accurate <lastmod> so search " <>
             "engines receive the route with a correct date"
  end

  defp url_block_for(sitemap, route) do
    case Regex.run(
           ~r{<url>\s*<loc>[^<]*#{Regex.escape(route)}</loc>.*?</url>}s,
           sitemap,
           capture: :first
         ) do
      [block] -> block
      nil -> ""
    end
  end
end
