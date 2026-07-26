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

  test "renders registry freshness — tested version and last-sync date (jido-e09-t18)", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/ecosystem/jido")

    # Tested version is visible and falls back to the package version when not
    # set in frontmatter (jido's registry version is enforced to the installed
    # release by the version-freshness gate).
    assert html =~ "tested 2.3.2"

    # Last-sync date is visible and well-formed, falling back to the
    # registry-wide reconciliation date.
    assert html =~ ~r/synced \d{4}-\d{2}-\d{2}/
    assert html =~ "synced #{AgentJido.Ecosystem.registry_last_synced()}"
  end

  test "renders registry freshness for packages without curated metadata", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/ecosystem/jido_chat")

    # Freshness is visible on every package page, not just curated ones.
    assert html =~ ~r/tested \S/
    assert html =~ ~r/synced \d{4}-\d{2}-\d{2}/
  end

  test "renders one best example — curated proof for jido (jido-e09-t19)", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/ecosystem/jido")

    # Every package page surfaces a single best example section.
    assert html =~ "ONE BEST EXAMPLE"

    # jido has curated its best example to the canonical counter-agent.
    assert html =~ "proof curated"
    assert html =~ "Counter Agent example"
    assert html =~ ~s(href="/examples/counter-agent")
  end

  test "auto-resolves one best example from the examples registry", %{conn: conn} do
    # jido_signal has no curated best example, so the page auto-resolves the
    # single published example that declares it (signal-routing-agent).
    {:ok, _view, html} = live(conn, "/ecosystem/jido_signal")

    assert html =~ "ONE BEST EXAMPLE"
    assert html =~ "proof auto-resolved"
    assert html =~ ~s(href="/examples/signal-routing-agent")
  end

  test "states proof is missing when no example exercises the package", %{conn: conn} do
    # jido_chat is not exercised by any example, so the page must be explicit
    # that proof is missing rather than silent.
    {:ok, _view, html} = live(conn, "/ecosystem/jido_chat")

    assert html =~ "ONE BEST EXAMPLE"
    assert html =~ "proof missing"
    refute html =~ "proof curated"
    refute html =~ "proof auto-resolved"
  end

  # Direct expression of the E09-T19 contract: every public package page either
  # points to proof (a /examples/... link) or explicitly states proof is missing.
  # Uses a disconnected GET render (still runs mount + render) so all public
  # packages can be checked without the connected-LiveView overhead.
  @tag timeout: 120_000
  test "every public package points to proof or states proof is missing (jido-e09-t19)", %{conn: conn} do
    for package <- AgentJido.Ecosystem.public_packages() do
      html = conn |> get("/ecosystem/#{package.id}") |> html_response(200)

      assert html =~ "ONE BEST EXAMPLE",
             "package #{package.id} is missing the ONE BEST EXAMPLE section"

      has_proof_link = html =~ ~s(href="/examples/)
      states_missing = html =~ "proof missing"

      assert has_proof_link != states_missing,
             "package #{package.id} must either link proof or state proof is missing " <>
               "(proof_link=#{has_proof_link}, missing=#{states_missing})"
    end
  end

  test "renders one best guide — curated learning path for jido (jido-e09-t20)", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/ecosystem/jido")

    # Every package page surfaces a single best guide section.
    assert html =~ "ONE BEST GUIDE"

    # jido has curated its best guide to the canonical first learning path.
    assert html =~ "guide curated"
    assert html =~ "Your first agent"
    assert html =~ ~s(href="/docs/getting-started/first-agent")
  end

  test "auto-resolves one best guide from the docs guides registry", %{conn: conn} do
    # jido_ai has no curated best guide, so the page auto-resolves the
    # lowest-order published guide whose tested_with declares it
    # (testing-agents-and-actions, order 170).
    {:ok, _view, html} = live(conn, "/ecosystem/jido_ai")

    assert html =~ "ONE BEST GUIDE"
    assert html =~ "guide auto-resolved"
    assert html =~ ~s(href="/docs/guides/testing-agents-and-actions")
  end

  test "states a guide is missing when no guide covers the package", %{conn: conn} do
    # jido_chat is not covered by any guide, so the page must be explicit that
    # no learning path exists rather than silent.
    {:ok, _view, html} = live(conn, "/ecosystem/jido_chat")

    assert html =~ "ONE BEST GUIDE"
    assert html =~ "guide missing"
    refute html =~ "guide curated"
    refute html =~ "guide auto-resolved"
  end

  # Direct expression of the E09-T20 contract: every public package page either
  # links a maintained learning path (a /docs/... guide link) or explicitly
  # states that a guide is missing. Uses a disconnected GET render (still runs
  # mount + render) so all public packages can be checked.
  @tag timeout: 120_000
  test "every public package links a guide or states a guide is missing (jido-e09-t20)", %{conn: conn} do
    for package <- AgentJido.Ecosystem.public_packages() do
      html = conn |> get("/ecosystem/#{package.id}") |> html_response(200)

      assert html =~ "ONE BEST GUIDE",
             "package #{package.id} is missing the ONE BEST GUIDE section"

      has_guide = html =~ "guide curated" or html =~ "guide auto-resolved"
      states_missing = html =~ "guide missing"

      assert has_guide != states_missing,
             "package #{package.id} must either link a guide or state a guide is missing " <>
               "(guide=#{has_guide}, missing=#{states_missing})"
    end
  end

  test "renders the control surface jido supplies and the result it does not supply (jido-e09-t41)", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/ecosystem/jido")

    # Every package page surfaces the operational-control section.
    assert html =~ "OPERATIONAL CONTROL"

    # The control surface jido supplies is stated explicitly.
    assert html =~ "Control surface it supplies"
    assert html =~ "prepare_action/3 is the fail-closed authorization point"

    # The control result jido does not supply is stated explicitly.
    assert html =~ "Control result it does not supply"
    assert html =~ "Does not authenticate principals"
  end

  # Direct expression of the E09-T42 contract: the jido package page states the
  # current meaning of core Agent identity. An Agent's ID is Agent lifecycle or
  # profile state (correlation metadata), and the page must say so in those
  # terms rather than implying it is an authenticated principal identity. The
  # authoritative phrasing lives on the Security and governance identity guide;
  # this asserts the package page carries the same meaning.
  test "states core Agent identity as lifecycle or profile state, not authenticated principal identity (jido-e09-t42)", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/ecosystem/jido")

    # Positive meaning: the page names the Agent ID as lifecycle or profile state.
    assert html =~ "Agent lifecycle or profile state",
           "the jido package page must state that an Agent's core identity is " <>
             "Agent lifecycle or profile state, not authenticated principal identity"

    # Boundary: the page must distinguish that meaning from authenticated
    # principal identity so an Agent ID cannot be mistaken for a verified caller.
    assert html =~ "not authenticated principal identity",
           "the jido package page must state core Agent identity is not " <>
             "authenticated principal identity"
  end

  test "states the control surface is not documented when neither field is set (jido-e09-t41)", %{conn: conn} do
    # jido_chat has no documented control surface, so the page must be explicit
    # about the gap rather than silent.
    {:ok, _view, html} = live(conn, "/ecosystem/jido_chat")

    assert html =~ "OPERATIONAL CONTROL"
    assert html =~ "control surface not documented"
    refute html =~ "Control surface it supplies"
    refute html =~ "Control result it does not supply"
  end

  # Direct expression of the E09-T41 contract: every public package page renders
  # the OPERATIONAL CONTROL section and either states the control surface it
  # supplies / the result it does not supply, or is explicit that the control
  # surface is not documented yet. Uses a disconnected GET render (still runs
  # mount + render) so all public packages can be checked.
  @tag timeout: 120_000
  test "every public package states its control surface or flags it undocumented (jido-e09-t41)", %{conn: conn} do
    for package <- AgentJido.Ecosystem.public_packages() do
      html = conn |> get("/ecosystem/#{package.id}") |> html_response(200)

      assert html =~ "OPERATIONAL CONTROL",
             "package #{package.id} is missing the OPERATIONAL CONTROL section"

      states_documented = html =~ "Control surface it supplies" or html =~ "Control result it does not supply"
      states_undocumented = html =~ "control surface not documented"

      assert states_documented != states_undocumented,
             "package #{package.id} must either state its control surface/result or flag it undocumented " <>
               "(documented=#{states_documented}, undocumented=#{states_undocumented})"
    end
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
