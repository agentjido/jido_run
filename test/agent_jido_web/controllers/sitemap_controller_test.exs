defmodule AgentJidoWeb.SitemapControllerTest do
  use AgentJidoWeb.ConnCase, async: true

  alias AgentJido.Blog
  alias AgentJido.Ecosystem
  alias AgentJido.Examples

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

  test "includes page URLs from the Pages system", %{conn: conn} do
    body =
      conn
      |> get("/sitemap.xml")
      |> response(200)

    assert body =~ "/docs/learn/agent-fundamentals"
    assert body =~ "/docs/learn/production-readiness"
    refute body =~ "/training/agent-fundamentals"

    assert body =~ "/features"
    assert body =~ "/community/showcase"
    refute body =~ "/partners"
    refute body =~ "/benchmarks"
  end

  test "includes only canonical live example URLs", %{conn: conn} do
    body =
      conn
      |> get("/sitemap.xml")
      |> response(200)

    for example <- Examples.all_examples() do
      assert body =~ "<loc>#{AgentJidoWeb.Endpoint.url()}/examples/#{example.slug}</loc>"
    end

    refute body =~ ~r{<loc>[^<]+/examples/[^<]+\?}
    refute body =~ "/examples/incident-triage"
    refute body =~ "/examples/workflow-coordinator"
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
    assert body =~ "/blog/jido-assembly-slack-clone"
    refute body =~ "/blog/jido-assembly<"
  end

  test "includes indexable build and compare hubs once and excludes aliases", %{conn: conn} do
    body = conn |> get("/sitemap.xml") |> response(200)
    urls = Regex.scan(~r/<loc>([^<]+)<\/loc>/, body, capture: :all_but_first) |> List.flatten()
    assert length(urls) == length(Enum.uniq(urls))

    for path <- ["/build", "/compare"] do
      url = AgentJidoWeb.Endpoint.url() <> path
      assert Enum.count(urls, &(&1 == url)) == 1
      response = build_conn() |> get(path) |> html_response(200) |> Floki.parse_document!()
      assert Floki.find(response, ~s(link[rel="canonical"])) |> Floki.attribute("href") == [url]
      refute response |> Floki.find(~s(meta[name="robots"])) |> Floki.attribute("content") |> Enum.any?(&String.contains?(&1, "noindex"))
    end

    for source <- Map.keys(AgentJidoWeb.LegacyRedirects.all()) do
      refute (AgentJidoWeb.Endpoint.url() <> source) in urls
    end

    for package <- Ecosystem.all_packages(), package.visibility == :private do
      refute (AgentJidoWeb.Endpoint.url() <> "/ecosystem/" <> package.id) in urls
    end
  end
end
