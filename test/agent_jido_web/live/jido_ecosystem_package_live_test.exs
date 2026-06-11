defmodule AgentJidoWeb.JidoEcosystemPackageLiveTest do
  use AgentJidoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "private packages are not accessible from public ecosystem routes", %{conn: conn} do
    assert_raise AgentJido.Ecosystem.NotFoundError, fn ->
      live(conn, "/ecosystem/jido_memory_os")
    end
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
end
