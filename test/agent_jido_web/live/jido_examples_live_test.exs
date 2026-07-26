defmodule AgentJidoWeb.JidoExamplesLiveTest do
  use AgentJidoWeb.ConnCase, async: false

  import AgentJido.AccountsFixtures
  import Phoenix.LiveViewTest

  alias AgentJido.Examples

  @hidden_slug "budget-guardrail-agent"
  @visible_slug "counter-agent"
  @secondary_visible_slug "demand-tracker-agent"
  # coding-assistant was published as the home coding card's destination
  # (jido-e08-t24), so it is no longer the canonical draft. workflow-coordinator
  # stays a draft and is not in the t24-t29 use-case publish scope, which keeps
  # this draft-fixture stable.
  @draft_slug "workflow-coordinator"
  @pilot_live_slug "signal-routing-agent"
  @new_live_example_pages [
    {"signal-routing-agent", "Signal Routing Agent"},
    {"emit-directive-agent", "Emit Directive Agent"},
    {"state-ops-agent", "State Ops Agent"},
    {"plugin-basics-agent", "Plugin Basics Agent"},
    {"persistence-storage-agent", "Persistence Storage Agent"},
    {"schedule-directive-agent", "Schedule Directive Agent"},
    {"runic-ai-research-studio", "Runic AI Research Studio"},
    {"runic-ai-research-studio-step-mode", "Runic AI Research Studio Step Mode"},
    {"runic-adaptive-researcher", "Runic Adaptive Researcher"},
    {"runic-structured-llm-branching", "Runic Structured LLM Branching"},
    {"runic-delegating-orchestrator", "Runic Delegating Orchestrator"},
    {"jido-ai-actions-runtime-demos", "Jido.AI Actions Runtime Demos"},
    {"jido-ai-browser-web-workflow", "Jido Browser Docs Scout Agent"},
    {"jido-ai-weather-multi-turn-context", "Jido.AI Weather Multi-Turn Context"},
    {"jido-ai-task-execution-workflow", "Jido.AI Task Execution Workflow"},
    {"jido-ai-skills-runtime-foundations", "Jido.AI Skills Runtime Foundations"},
    {"jido-ai-skills-multi-agent-orchestration", "Jido.AI Skills Multi-Agent Orchestration"},
    {"jido-ai-weather-reasoning-strategy-suite", "Jido.AI Weather Reasoning Strategy Suite"},
    {"jido-ai-operational-agents-pack", "Jido.AI Operational Agents Pack"}
  ]

  test "draft examples are not listed on /examples", %{conn: conn} do
    hidden = Examples.get_example!(@hidden_slug, include_unpublished: true)
    {:ok, _view, html} = live(conn, "/examples")

    refute html =~ hidden.title
  end

  test "draft examples are not routable on /examples/:slug", %{conn: conn} do
    assert_raise AgentJido.Examples.NotFoundError, fn ->
      live(conn, "/examples/#{@hidden_slug}")
    end
  end

  test "examples index is simplified without browse filters", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/examples")

    refute html =~ "Browse by Taxonomy"
    refute html =~ "Wave"
    assert html =~ "Counter Agent"
    assert html =~ "Demand Tracker Agent"
    # The canonical draft (workflow-coordinator) stays hidden from public visitors.
    refute html =~ "Workflow Coordinator"
    refute html =~ "Hide Draft Examples"
  end

  test "selected live examples are listed", %{conn: conn} do
    visible = Examples.get_example!(@visible_slug)
    secondary_visible = Examples.get_example!(@secondary_visible_slug)
    {:ok, _view, html} = live(conn, "/examples")

    assert html =~ visible.title
    assert html =~ secondary_visible.title
    assert html =~ "Signal Routing Agent"
    # The canonical draft (workflow-coordinator) stays hidden from public visitors.
    refute html =~ "Workflow Coordinator"
  end

  test "admin users can see draft examples on /examples", %{conn: conn} do
    draft = Examples.get_example!(@draft_slug, include_unpublished: true)
    admin_conn = log_in_user(conn, admin_user_fixture())
    {:ok, _view, html} = live(admin_conn, "/examples")

    assert html =~ draft.title
    assert html =~ "Hide Draft Examples"
  end

  test "admin users can toggle draft visibility on /examples", %{conn: conn} do
    draft = Examples.get_example!(@draft_slug, include_unpublished: true)
    admin_conn = log_in_user(conn, admin_user_fixture())
    {:ok, view, html} = live(admin_conn, "/examples")

    assert html =~ draft.title
    assert html =~ "Hide Draft Examples"

    view
    |> element("#toggle-drafts-button")
    |> render_click()

    assert_patch(view, "/examples?hide_drafts=true")

    hidden_html = render(view)
    refute hidden_html =~ draft.title
    assert hidden_html =~ "Show Draft Examples"

    view
    |> element("#toggle-drafts-button")
    |> render_click()

    assert_patch(view, "/examples")

    shown_html = render(view)
    assert shown_html =~ draft.title
    assert shown_html =~ "Hide Draft Examples"
  end

  test "admin draft toggle state can be restored from query params", %{conn: conn} do
    draft = Examples.get_example!(@draft_slug, include_unpublished: true)
    admin_conn = log_in_user(conn, admin_user_fixture())

    {:ok, _view, hidden_html} = live(admin_conn, "/examples?hide_drafts=true")
    refute hidden_html =~ draft.title

    {:ok, _view, shown_html} = live(admin_conn, "/examples")
    assert shown_html =~ draft.title
  end

  test "admin users can open draft example routes", %{conn: conn} do
    admin_conn = log_in_user(conn, admin_user_fixture())
    {:ok, _view, html} = live(admin_conn, "/examples/#{@draft_slug}?tab=demo")

    assert html =~ Examples.get_example!(@draft_slug, include_unpublished: true).title
    assert html =~ "draft preview"
  end

  test "new published examples are routable for public visitors", %{conn: conn} do
    Enum.each(@new_live_example_pages, fn {slug, title} ->
      {:ok, _view, html} = live(conn, "/examples/#{slug}?tab=demo")
      assert html =~ title
      refute html =~ "draft preview"
    end)
  end

  test "admin users can open new published example routes", %{conn: conn} do
    admin_conn = log_in_user(conn, admin_user_fixture())

    Enum.each(@new_live_example_pages, fn {slug, title} ->
      {:ok, _view, html} = live(admin_conn, "/examples/#{slug}?tab=demo")
      assert html =~ title
      refute html =~ "draft preview"
    end)
  end

  test "admin users can run call and cast interactions on signal routing pilot", %{conn: conn} do
    admin_conn = log_in_user(conn, admin_user_fixture())
    {:ok, view, html} = live(admin_conn, "/examples/#{@pilot_live_slug}?tab=demo")

    assert html =~ "Signal Routing Agent"
    refute html =~ "draft preview"

    demo_view = find_live_child(view, "demo-#{@pilot_live_slug}")

    demo_view
    |> form("#signal-routing-increment-form", %{"amount" => "3"})
    |> render_submit()

    assert render(demo_view) =~ ~s(id="signal-routing-counter")
    assert render(demo_view) =~ ~r/id="signal-routing-counter"[^>]*>\s*3\s*</

    demo_view
    |> form("#signal-routing-name-form", %{"name" => "Router"})
    |> render_submit()

    assert render(demo_view) =~ ~s(id="signal-routing-name")
    assert render(demo_view) =~ ~r/id="signal-routing-name"[^>]*>\s*Router\s*</

    demo_view
    |> form("#signal-routing-cast-form", %{"count" => "2"})
    |> render_submit()

    assert render(demo_view) =~ "cast"
    assert render(demo_view) =~ ~r/id="signal-routing-counter"[^>]*>\s*5\s*</
  end

  test "emit directive demo runs create_order and process_payment interactions", %{conn: conn} do
    {:ok, view, html} = live(conn, "/examples/emit-directive-agent?tab=demo")

    assert html =~ "Emit Directive Agent"

    demo_view = find_live_child(view, "demo-emit-directive-agent")

    demo_view
    |> form("#emit-create-order-form", %{"total" => "1400"})
    |> render_submit()

    assert render(demo_view) =~ ~r/id="emit-orders-count"[^>]*>\s*1\s*</

    demo_view
    |> element("#emit-process-payment-btn")
    |> render_click()

    assert render(demo_view) =~ "process_payment"
    refute render(demo_view) =~ "Create an order first."
  end

  test "state ops demo applies state mutation operations", %{conn: conn} do
    {:ok, view, html} = live(conn, "/examples/state-ops-agent?tab=demo")

    assert html =~ "State Ops Agent"

    demo_view = find_live_child(view, "demo-state-ops-agent")

    demo_view
    |> element("#state-merge-btn")
    |> render_click()

    assert render(demo_view) =~ "SetState"
    assert render(demo_view) =~ "version: &quot;1.0&quot;"
  end

  test "plugin basics demo supports add and clear note flows", %{conn: conn} do
    {:ok, view, html} = live(conn, "/examples/plugin-basics-agent?tab=demo")

    assert html =~ "Plugin Basics Agent"

    demo_view = find_live_child(view, "demo-plugin-basics-agent")

    demo_view
    |> form("#plugin-add-note-form", %{"text" => "hello from test"})
    |> render_submit()

    assert render(demo_view) =~ ~r/id="plugin-notes-count"[^>]*>\s*1\s*</
    assert render(demo_view) =~ "hello from test"

    demo_view
    |> element("#plugin-clear-notes-btn")
    |> render_click()

    assert render(demo_view) =~ ~r/id="plugin-notes-count"[^>]*>\s*0\s*</
  end

  test "persistence storage demo supports increment and restore flow", %{conn: conn} do
    {:ok, view, html} = live(conn, "/examples/persistence-storage-agent?tab=demo")

    assert html =~ "Persistence Storage Agent"

    demo_view = find_live_child(view, "demo-persistence-storage-agent")

    demo_view
    |> element("#persist-inc-btn")
    |> render_click()

    assert render(demo_view) =~ ~r/id="persist-counter"[^>]*>\s*1\s*</

    demo_view
    |> element("#persist-hibernate-btn")
    |> render_click()

    demo_view
    |> element("#persist-inc-btn")
    |> render_click()

    assert render(demo_view) =~ ~r/id="persist-counter"[^>]*>\s*2\s*</

    demo_view
    |> element("#persist-thaw-btn")
    |> render_click()

    assert render(demo_view) =~ ~r/id="persist-counter"[^>]*>\s*1\s*</
  end

  test "schedule directive demo supports manual cron actions", %{conn: conn} do
    {:ok, view, html} = live(conn, "/examples/schedule-directive-agent?tab=demo")

    assert html =~ "Schedule Directive Agent"

    demo_view = find_live_child(view, "demo-schedule-directive-agent")

    demo_view
    |> element("#schedule-manual-cron-btn")
    |> render_click()

    assert render(demo_view) =~ ~r/id="schedule-cron-count"[^>]*>\s*1\s*</

    demo_view
    |> element("#schedule-manual-hourly-btn")
    |> render_click()

    assert render(demo_view) =~ ~r/id="schedule-cron-count"[^>]*>\s*2\s*</
  end

  test "examples content container matches primary nav width", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/examples")

    assert html =~ ~s(class="container max-w-[1000px] mx-auto px-6 py-12")
  end

  describe "use-case scoped index (E04-T21)" do
    test "?use_case=research scopes the list to research examples", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/examples?use_case=research")

      # The scoped hero names the use case.
      assert html =~ "Research and synthesis"
      # A public research example is listed.
      assert html =~ "Runic AI Research Studio"
      # A core example outside the research scope is hidden.
      refute html =~ "Counter Agent"
    end

    test "?use_case=coding lists the public coding example (jido-e08-t24)", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/examples?use_case=coding")

      # The scoped hero names the use case.
      assert html =~ "Coding agents"
      # A public coding example now exists, so the scoped destination lists it.
      assert html =~ "Coding Assistant"
      # The scoped empty state is gone now that a coding example is public.
      refute html =~ "No public examples for Coding agents yet"
      # An out-of-scope example stays hidden by the use-case scope.
      refute html =~ "Counter Agent"
    end

    test "an unknown use_case falls back to the unfiltered index", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/examples?use_case=not-a-real-use-case")

      assert html =~ "Learn by"
      assert html =~ "Counter Agent"
    end

    test "admin draft toggle preserves an active use_case scope", %{conn: conn} do
      admin_conn = log_in_user(conn, admin_user_fixture())
      {:ok, view, _html} = live(admin_conn, "/examples?use_case=research")

      view
      |> element("#toggle-drafts-button")
      |> render_click()

      # The scope survives the drafts toggle (param order is not significant).
      path = assert_patch(view)
      assert path =~ "use_case=research"
      assert path =~ "hide_drafts=true"
    end
  end
end
