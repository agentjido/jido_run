defmodule AgentJidoWeb.JidoEcosystemPackageLiveTest do
  use AgentJidoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "deprecated memory package redirects to its replacement", %{conn: conn} do
    conn = get(conn, "/ecosystem/jido_memory_os")

    assert redirected_to(conn, 301) == "/ecosystem/jido_memory"
  end

  test "renders jido as a curated landing page", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/ecosystem/jido")

    assert html =~ "Jido"
    assert html =~ "long-running, autonomous, multi-agent systems on OTP and the BEAM"
    assert html =~ "WHEN TO USE Jido"
    assert html =~ "Use This When"
    assert html =~ "Not The Right Fit When"
    assert html =~ "START HERE"
    assert html =~ "Start Here"
    assert html =~ "Guides"
    assert html =~ "Examples"
    assert html =~ "Reference"
    assert html =~ ~s(href="/docs/getting-started/first-agent")
    assert html =~ ~s(href="/examples/counter-agent")
    assert html =~ "KEY MODULES"
    assert html =~ "Jido.Discovery"
    assert html =~ ~s(href="https://hexdocs.pm/jido/Jido.Discovery.html")
    assert html =~ "RELATED PACKAGES"
    assert html =~ "Builds on"
    assert html =~ "Works with"
    assert html =~ "Add next"
    assert html =~ ~s(href="/ecosystem/jido_action")
    assert html =~ "AT A GLANCE"
    assert html =~ "FAQ"
    assert html =~ "Do I need jido_ai to use Jido?"
    assert html =~ "DEEP DIVE"
    assert html =~ "Add to mix.exs"
    assert html =~ "defp deps do"
    assert html =~ "~&gt; 2.2.0"
    assert html =~ "View package metadata source"
    refute html =~ "Ecosystem Fit"
    refute html =~ "IMPORTANT PACKAGES"
  end

  test "falls back cleanly for a package without curated landing metadata", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/ecosystem/jido_chat")

    assert html =~ "Jido Chat"
    assert html =~ "SDK-first chat core for typed message flows and adapter contracts"
    assert html =~ "AT A GLANCE"
    assert html =~ "DEEP DIVE"
    assert html =~ ~s(href="https://github.com/agentjido/jido_chat")
    refute html =~ "WHEN TO USE Jido Chat"
    refute html =~ "START HERE"
    refute html =~ "KEY MODULES"
    refute html =~ "RELATED PACKAGES"
    refute html =~ ">FAQ</"
    refute html =~ "Add to mix.exs"
    refute html =~ "Ecosystem Fit"
  end

  test "renders mattermost adapter details with websocket-first positioning", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/ecosystem/jido_chat_mattermost")

    assert html =~ "Jido Chat Mattermost"
    assert html =~ "Mattermost adapter package implementing the Jido Chat adapter contract"
    assert html =~ "AT A GLANCE"
    assert html =~ "DEEP DIVE"
    assert html =~ "Uses a websocket-only ingress model and does not include webhook ingestion support."
    assert html =~ "Provides standalone transport implementation without external adapter dependencies"
    assert html =~ ~s(href="https://github.com/www-zaq-ai/jido_chat_mattermost")
    refute html =~ "WHEN TO USE Jido Chat Mattermost"
    refute html =~ "START HERE"
    refute html =~ "KEY MODULES"
    refute html =~ "FAQ"
    refute html =~ "Add to mix.exs"
  end

  test "renders curated seo metadata and structured data for package pages", %{conn: conn} do
    html =
      conn
      |> get("/ecosystem/jido")
      |> html_response(200)

    assert html =~ "Jido Elixir agent framework for autonomous multi-agent systems"
    assert html =~ "Jido: Elixir agent framework on OTP"
    assert html =~ "Build long-running, multi-agent Elixir systems with a deterministic runtime, explicit directives, and BEAM-native supervision."

    assert html =~
             ~s(<meta name="keywords" content="jido, elixir agent framework, otp agents, multi-agent systems, beam agent runtime, Jido.Agent, Jido.AgentServer")

    assert html =~ ~s(<link rel="canonical" href="http://localhost:4002/ecosystem/jido")
    assert html =~ ~s("SoftwareSourceCode")
    assert html =~ ~s("BreadcrumbList")
    assert html =~ ~s("FAQPage")
  end

  test "renders ReqLLM metadata in the initial response without a duplicate brand suffix", %{conn: conn} do
    conn = get(conn, "/ecosystem/req_llm")
    document = conn |> html_response(200) |> Floki.parse_document!()
    title = "ReqLLM: Elixir LLM Client with Streaming and Tools"

    description =
      "Use ReqLLM to call LLM providers from Elixir through one API. Explore streaming, tool calling, structured output, and links to docs and examples."

    assert [title_node] = Floki.find(document, "head title")
    assert Floki.text(title_node) == title <> " · Agent Jido"

    for selector <- [
          ~s(meta[name="description"]),
          ~s(meta[property="og:description"]),
          ~s(meta[name="twitter:description"])
        ] do
      assert [node] = Floki.find(document, selector)
      assert Floki.attribute(node, "content") == [description]
    end

    for selector <- [~s(meta[property="og:title"]), ~s(meta[name="twitter:title"])] do
      assert [node] = Floki.find(document, selector)
      assert Floki.attribute(node, "content") == [title]
    end

    assert [canonical] = Floki.find(document, ~s(link[rel="canonical"]))
    assert Floki.attribute(canonical, "href") == [AgentJidoWeb.Endpoint.url() <> "/ecosystem/req_llm"]

    for node <- Floki.find(document, ~s(meta[name="robots"], meta[name="googlebot"])),
        value <- Floki.attribute(node, "content") do
      refute String.contains?(String.downcase(value), ["noindex", "none"])
    end

    for value <- get_resp_header(conn, "x-robots-tag") do
      refute String.contains?(String.downcase(value), ["noindex", "none"])
    end
  end
end
