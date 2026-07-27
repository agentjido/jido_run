defmodule AgentJidoWeb.ContentAssistantLiveTest do
  use AgentJidoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Plug.Conn

  alias AgentJido.Analytics.AnalyticsEvent
  alias AgentJido.Analytics.Redactor
  alias AgentJido.ContentAssistant.Response
  alias AgentJido.ContentAssistant.Result
  alias AgentJido.QueryLogs.QueryLog
  alias AgentJido.Repo

  @endpoint AgentJidoWeb.Endpoint
  @query_issued_event [:agent_jido, :content_assistant, :query, :issued]
  @query_success_event [:agent_jido, :content_assistant, :query, :success]
  @query_failure_event [:agent_jido, :content_assistant, :query, :failure]

  defmodule ContentAssistantStub do
    @moduledoc false

    @spec respond(String.t(), keyword()) :: {:ok, Response.t()}
    def respond(query, _opts \\ [])

    def respond("arcana", _opts) do
      {:ok,
       %Response{
         query: "arcana",
         answer_markdown: "Arcana overview",
         answer_html: "<p>Arcana overview</p>",
         answer_mode: :deterministic,
         citations: [
           %Result{
             title: "Getting Started",
             snippet: "Kick off your first workflow.",
             url: "/docs/getting-started",
             source_type: :docs,
             score: 0.92
           },
           %Result{
             title: "Release Notes",
             snippet: "Highlights from this release.",
             url: "/blog/release-notes",
             source_type: :blog,
             score: 0.81
           },
           %Result{
             title: "Jido Core",
             snippet: "Main runtime package details.",
             url: "/ecosystem/jido-core",
             source_type: :ecosystem,
             score: 0.77
           }
         ],
         retrieval_status: :success,
         llm_attempted?: false,
         llm_enhanced?: false,
         enhancement_blocked_reason: nil,
         query_log_id: nil
       }}
    end

    def respond("slow", _opts) do
      Process.sleep(100)

      {:ok,
       %Response{
         query: "slow",
         answer_markdown: "",
         answer_html: "",
         answer_mode: :no_results,
         citations: [],
         retrieval_status: :success,
         llm_attempted?: false,
         llm_enhanced?: false,
         enhancement_blocked_reason: nil,
         query_log_id: nil
       }}
    end

    def respond("backend-down", _opts) do
      {:ok,
       %Response{
         query: "backend-down",
         answer_markdown: "",
         answer_html: "",
         answer_mode: :error,
         citations: [],
         retrieval_status: :failure,
         llm_attempted?: false,
         llm_enhanced?: false,
         enhancement_blocked_reason: nil,
         query_log_id: nil
       }}
    end

    def respond("fallback", _opts) do
      {:ok,
       %Response{
         query: "fallback",
         answer_markdown: "Fallback answer",
         answer_html: "<p>Fallback answer</p>",
         answer_mode: :deterministic,
         citations: [
           %Result{
             title: "Fallback docs",
             snippet: "Fallback still produced results.",
             url: "/docs/getting-started",
             source_type: :docs,
             score: 0.42
           }
         ],
         retrieval_status: :fallback,
         llm_attempted?: false,
         llm_enhanced?: false,
         enhancement_blocked_reason: nil,
         query_log_id: nil
       }}
    end

    def respond("hexdocs", _opts) do
      {:ok,
       %Response{
         query: "hexdocs",
         answer_markdown: "HexDocs answer",
         answer_html: "<p>HexDocs answer</p>",
         answer_mode: :deterministic,
         citations: [
           %Result{
             title: "Jido.Agent",
             snippet: "API reference for cmd/2.",
             url: "https://hexdocs.pm/jido/Jido.Agent.html",
             source_type: :ecosystem_docs,
             score: 0.93,
             external?: true,
             provider: :hexdocs,
             package_id: "jido",
             package_name: "jido",
             package_version: "2.1.0",
             page_kind: :module,
             secondary_url: "/ecosystem/jido"
           }
         ],
         retrieval_status: :success,
         llm_attempted?: false,
         llm_enhanced?: false,
         enhancement_blocked_reason: nil,
         query_log_id: nil
       }}
    end

    def respond("control", _opts) do
      # One citation per distinguishable content type, each carrying its
      # content-type and proof-level label (jido-e10-t28).
      {:ok,
       %Response{
         query: "control",
         answer_markdown: "Operational control overview",
         answer_html: "<p>Operational control overview</p>",
         answer_mode: :deterministic,
         citations: [
           %Result{
             title: "Agents concept",
             snippet: "Definition of an Agent.",
             url: "/docs/concepts/agents",
             source_type: :docs,
             content_type: :definition,
             proof_level: :design_intent,
             score: 0.95
           },
           %Result{
             title: "Error handling guide",
             snippet: "How to recover from failures.",
             url: "/docs/guides/error-handling-and-recovery",
             source_type: :docs,
             content_type: :guide,
             proof_level: :design_intent,
             score: 0.9
           },
           %Result{
             title: "Jido Core",
             snippet: "Main runtime package surface.",
             url: "/ecosystem/jido-core",
             source_type: :ecosystem,
             content_type: :package,
             proof_level: :tested_behavior,
             score: 0.86
           },
           %Result{
             title: "Controlled Agent example",
             snippet: "Runnable controlled-Agent demo.",
             url: "/examples/controlled-agent",
             source_type: :examples,
             content_type: :example,
             proof_level: :tested_behavior,
             score: 0.82
           },
           %Result{
             title: "Acme controlled-Agent case study",
             snippet: "Production controlled-Agent deployment.",
             url: "/blog/acme-controlled-agent",
             source_type: :blog,
             content_type: :case_study,
             proof_level: :production_evidence,
             score: 0.78
           }
         ],
         retrieval_status: :success,
         llm_attempted?: false,
         llm_enhanced?: false,
         enhancement_blocked_reason: nil,
         query_log_id: nil
       }}
    end

    def respond("skills", _opts) do
      {:ok,
       %Response{
         query: "skills",
         answer_markdown: "Skills overview",
         answer_html: "<p>Skills overview</p>",
         answer_mode: :deterministic,
         citations: [
           %Result{
             title: "Persistence skill",
             snippet: "A reusable persistence skill.",
             url: "/skills#skill-card-persistence",
             source_type: :skills,
             score: 0.8
           }
         ],
         retrieval_status: :success,
         llm_attempted?: false,
         llm_enhanced?: false,
         enhancement_blocked_reason: nil,
         query_log_id: nil
       }}
    end

    # A no-results query that carries a sensitive pattern (an email) and keeps
    # the submitted query on the response, so the no-result analytics test can
    # prove the query is recorded without leaking the raw email. Defined before
    # the catch-all so the specific clause is matched.
    def respond("contact me at leak@example.com please", _opts) do
      {:ok,
       %Response{
         query: "contact me at leak@example.com please",
         answer_markdown: "",
         answer_html: "",
         answer_mode: :no_results,
         citations: [],
         retrieval_status: :success,
         llm_attempted?: false,
         llm_enhanced?: false,
         enhancement_blocked_reason: nil,
         query_log_id: nil
       }}
    end

    def respond(_query, _opts) do
      {:ok,
       %Response{
         query: "",
         answer_markdown: "",
         answer_html: "",
         answer_mode: :no_results,
         citations: [],
         retrieval_status: :success,
         llm_attempted?: false,
         llm_enhanced?: false,
         enhancement_blocked_reason: nil,
         query_log_id: nil
       }}
    end
  end

  defmodule CountingContentAssistantStub do
    @moduledoc false

    @spec respond(String.t(), keyword()) :: {:ok, Response.t()}
    def respond(query, _opts \\ []) do
      if pid = :persistent_term.get({__MODULE__, :test_pid}, nil) do
        send(pid, {:counting_stub_called, query})
      end

      {:ok,
       %Response{
         query: query,
         answer_markdown: "Cached answer for #{query}",
         answer_html: "<p>Cached answer for #{query}</p>",
         answer_mode: :deterministic,
         citations: [
           %Result{
             title: "Cached docs",
             snippet: "Cached docs snippet.",
             url: "/docs/getting-started",
             source_type: :docs,
             score: 0.9
           }
         ],
         retrieval_status: :success,
         llm_attempted?: false,
         llm_enhanced?: false,
         enhancement_blocked_reason: nil,
         query_log_id: nil
       }}
    end
  end

  defmodule AssistantOptsCaptureStub do
    @moduledoc false

    @spec respond(String.t(), keyword()) :: {:ok, Response.t()}
    def respond(query, opts \\ []) do
      if pid = :persistent_term.get({__MODULE__, :test_pid}, nil) do
        send(pid, {:assistant_opts_capture, query, opts})
      end

      {:ok,
       %Response{
         query: query,
         answer_markdown: "Captured options for #{query}",
         answer_html: "<p>Captured options for #{query}</p>",
         answer_mode: :deterministic,
         citations: [],
         retrieval_status: :success,
         llm_attempted?: false,
         llm_enhanced?: false,
         enhancement_blocked_reason: nil,
         query_log_id: nil
       }}
    end
  end

  describe "ContentAssistantLive" do
    test "renders idle state by default", %{conn: conn} do
      {:ok, _view, html} = mount_live(conn)

      assert html =~ ">Search</h1>"
      assert html =~ ~s(id="content-assistant-idle-state")
    end

    test "renders loading state while a query is running", %{conn: conn} do
      conn = with_content_assistant_stub(conn)
      {:ok, view, _html} = mount_live(conn)

      loading_html =
        view
        |> form("#content-assistant-form", assistant: %{q: "slow"})
        |> render_submit()

      assert loading_html =~ ~s(id="content-assistant-loading-state")
      assert loading_html =~ "Working on"
      assert_state(view, ~s(id="content-assistant-no-results-state"))
    end

    test "renders answer with source labels and destination links", %{conn: conn} do
      conn = with_content_assistant_stub(conn)
      {:ok, view, _html} = mount_live(conn)

      view
      |> form("#content-assistant-form", assistant: %{q: "arcana"})
      |> render_submit()

      html = assert_state(view, ~s(id="content-assistant-answer-state"))

      assert html =~ "Getting Started"
      assert html =~ "Release Notes"
      assert html =~ "Jido Core"
      assert html =~ "Docs"
      assert html =~ "Blog"
      assert html =~ "Ecosystem"
      assert html =~ ~s(href="/docs/getting-started")
      assert html =~ ~s(href="/blog/release-notes")
      assert html =~ ~s(href="/ecosystem/jido-core")
    end

    test "renders HexDocs citations as external results with package handoff details", %{conn: conn} do
      conn = with_content_assistant_stub(conn)
      {:ok, view, _html} = mount_live(conn)

      view
      |> form("#content-assistant-form", assistant: %{q: "hexdocs"})
      |> render_submit()

      html = assert_state(view, ~s(id="content-assistant-answer-state"))

      assert html =~ "HexDocs"
      assert html =~ "Jido.Agent"
      assert html =~ "Opens in new tab"
      assert html =~ ~s(href="https://hexdocs.pm/jido/Jido.Agent.html")
      assert html =~ ~s(target="_blank")
      assert html =~ ~s(rel="noopener noreferrer")
      assert html =~ ~s(href="/ecosystem/jido")
      assert html =~ "About Package"
    end

    test "labels each result with a content type and proof level", %{conn: conn} do
      conn = with_content_assistant_stub(conn)
      {:ok, view, _html} = mount_live(conn)

      view
      |> form("#content-assistant-form", assistant: %{q: "control"})
      |> render_submit()

      html = assert_state(view, ~s(id="content-assistant-answer-state"))

      # A user can distinguish the five content types (jido-e10-t28).
      assert html =~ "Definition"
      assert html =~ "Guide"
      assert html =~ "Package"
      assert html =~ "Example"
      assert html =~ "Case study"

      # And see the proof level behind each result.
      assert html =~ "Design intent"
      assert html =~ "Tested behavior"
      assert html =~ "Production evidence"
    end

    test "submitting a query persists state in URL and reloads from params", %{conn: conn} do
      conn = with_content_assistant_stub(conn)
      {:ok, view, _html} = mount_live(conn)

      view
      |> form("#content-assistant-form", assistant: %{q: "arcana"})
      |> render_submit()

      assert_patch(view, "/search?q=arcana")
      assert_state(view, ~s(id="content-assistant-answer-state"))

      reload_conn = with_content_assistant_stub(build_conn())
      {:ok, reload_view, _html} = mount_live(reload_conn, "/search?q=arcana")

      html = assert_state(reload_view, ~s(id="content-assistant-answer-state"))
      assert html =~ ~s(value="arcana")
      assert html =~ "Arcana overview"
    end

    test "uses cached response on /search?q= reload without rerunning assistant", %{conn: conn} do
      :persistent_term.put({CountingContentAssistantStub, :test_pid}, self())

      on_exit(fn ->
        :persistent_term.erase({CountingContentAssistantStub, :test_pid})
      end)

      conn = with_content_assistant_module(conn, CountingContentAssistantStub)
      {:ok, view, _html} = mount_live(conn)

      view
      |> form("#content-assistant-form", assistant: %{q: "arcana"})
      |> render_submit()

      assert_patch(view, "/search?q=arcana")
      assert_receive {:counting_stub_called, "arcana"}, 1_000

      _ = assert_state(view, ~s(id="content-assistant-answer-state"))
      reload_conn = with_content_assistant_module(build_conn(), CountingContentAssistantStub)
      {:ok, reload_view, _html} = mount_live(reload_conn, "/search?q=arcana")
      html = assert_state(reload_view, ~s(id="content-assistant-answer-state"))

      assert html =~ "Cached answer for arcana"
      refute_receive {:counting_stub_called, "arcana"}, 200
    end

    test "uses fast defaults for global search execution", %{conn: conn} do
      :persistent_term.put({AssistantOptsCaptureStub, :test_pid}, self())

      on_exit(fn ->
        :persistent_term.erase({AssistantOptsCaptureStub, :test_pid})
      end)

      conn = with_content_assistant_module(conn, AssistantOptsCaptureStub)
      {:ok, view, _html} = mount_live(conn)

      view
      |> form("#content-assistant-form", assistant: %{q: "arcana"})
      |> render_submit()

      assert_receive {:assistant_opts_capture, "arcana", opts}, 1_000
      assert Keyword.get(opts, :llm) == nil
      assert Keyword.get(opts, :require_turnstile) == false
      assert opts |> Keyword.get(:retrieval_opts, []) |> Keyword.get(:mode) == :hybrid
      assert opts |> Keyword.get(:retrieval_opts, []) |> Keyword.get(:graph) == true
    end

    test "renders no-results state when query returns no matches", %{conn: conn} do
      conn = with_content_assistant_stub(conn)
      {:ok, view, _html} = mount_live(conn)

      view
      |> form("#content-assistant-form", assistant: %{q: "missing"})
      |> render_submit()

      html = assert_state(view, ~s(id="content-assistant-no-results-state"))
      assert html =~ "No relevant content found for"
    end

    test "renders answer when retrieval fallback still provides citations", %{conn: conn} do
      conn = with_content_assistant_stub(conn)
      {:ok, view, _html} = mount_live(conn)

      view
      |> form("#content-assistant-form", assistant: %{q: "fallback"})
      |> render_submit()

      html = assert_state(view, ~s(id="content-assistant-answer-state"))

      assert html =~ "Fallback answer"
      refute html =~ ~s(id="content-assistant-error-state")
    end

    test "renders failure state when assistant returns error mode", %{conn: conn} do
      conn = with_content_assistant_stub(conn)
      {:ok, view, _html} = mount_live(conn)

      view
      |> form("#content-assistant-form", assistant: %{q: "backend-down"})
      |> render_submit()

      html = assert_state(view, ~s(id="content-assistant-error-state"))

      assert html =~ "Content assistant is temporarily unavailable right now"
    end

    test "emits issued and success telemetry for successful flow", %{conn: conn} do
      attach_telemetry([@query_issued_event, @query_success_event])

      conn = with_content_assistant_stub(conn)
      {:ok, view, _html} = mount_live(conn)

      view
      |> form("#content-assistant-form", assistant: %{q: "arcana"})
      |> render_submit()

      assert_receive {:assistant_telemetry, @query_issued_event, %{count: 1}, issued_meta}, 1_000
      assert issued_meta.query_length == 6

      assert_receive {:assistant_telemetry, @query_success_event, success_measurements, success_meta}, 1_000
      assert success_measurements.count == 1
      assert is_integer(success_measurements.latency_ms)
      assert success_measurements.latency_ms >= 0
      assert success_meta.query_length == 6
      assert success_meta.results_count == 3
      refute_receive {:assistant_telemetry, @query_failure_event, _, _}, 50
    end

    test "emits issued and failure telemetry for failure flow", %{conn: conn} do
      attach_telemetry([@query_issued_event, @query_failure_event])

      conn = with_content_assistant_stub(conn)
      {:ok, view, _html} = mount_live(conn)

      view
      |> form("#content-assistant-form", assistant: %{q: "backend-down"})
      |> render_submit()

      assert_receive {:assistant_telemetry, @query_issued_event, %{count: 1}, issued_meta}, 1_000
      assert issued_meta.query_length == String.length("backend-down")

      assert_receive {:assistant_telemetry, @query_failure_event, failure_measurements, failure_meta}, 1_000
      assert failure_measurements.count == 1
      assert is_integer(failure_measurements.latency_ms)
      assert failure_measurements.latency_ms >= 0
      assert failure_meta.query_length == String.length("backend-down")
      refute_receive {:assistant_telemetry, @query_success_event, _, _}, 50
    end

    test "records a first-party no-result analytics event with query, filters, and route", %{conn: conn} do
      conn = with_content_assistant_stub(conn)
      {:ok, view, _html} = mount_live(conn)

      sensitive_query = "contact me at leak@example.com please"

      view
      |> form("#content-assistant-form", assistant: %{q: sensitive_query})
      |> render_submit()

      assert_state(view, ~s(id="content-assistant-no-results-state"))

      event =
        Repo.get_by(AnalyticsEvent,
          event: "content_assistant_query_no_results"
        )

      assert event, "expected a content_assistant_query_no_results analytics event"

      # Route is recorded.
      assert event.path == "/search"

      # Query is recorded through the redacted query log row, never as raw text.
      assert event.query_log_id

      query_log = Repo.get(QueryLog, event.query_log_id)
      assert query_log.query == Redactor.redact_query(sensitive_query)
      refute query_log.query =~ "leak@example.com"

      # Filters dimension and the outcome summary are recorded.
      assert event.metadata["filters"] == %{}
      assert event.metadata["results_count"] == 0
      assert event.metadata["query_length"] == String.length(sensitive_query)
      assert event.metadata["surface"] == "content_assistant_page"

      # No sensitive data is stored on the analytics event itself.
      refute Map.has_key?(event.metadata, "query")
      refute inspect(event.metadata) =~ "leak@example.com"
    end
  end

  describe "result-type filters (jido-e10-t07)" do
    # Acceptance: "Users can select Docs, Examples, Ecosystem, Blog, or Skills."

    test "the answer state offers a chip for each present result type plus All", %{conn: conn} do
      conn = with_content_assistant_stub(conn)
      {:ok, view, _html} = mount_live(conn)

      view
      |> form("#content-assistant-form", assistant: %{q: "control"})
      |> render_submit()

      html = assert_state(view, ~s(id="content-assistant-answer-state"))

      assert html =~ ~s(id="content-assistant-result-type-filter")
      assert html =~ ~s(phx-value-type="all")

      # The "control" stub returns docs, examples, ecosystem, and blog citations,
      # so each present type renders a selectable chip.
      for type <- ~w(docs examples ecosystem blog) do
        assert html =~ ~s(phx-value-type="#{type}"),
               "missing the #{type} result-type filter chip"
      end
    end

    test "a skills result offers and narrows to the Skills filter", %{conn: conn} do
      conn = with_content_assistant_stub(conn)
      {:ok, view, _html} = mount_live(conn)

      view
      |> form("#content-assistant-form", assistant: %{q: "skills"})
      |> render_submit()

      html = assert_state(view, ~s(id="content-assistant-answer-state"))
      assert html =~ ~s(phx-value-type="skills")

      html = render_click(view, "select_result_filter", %{"type" => "skills"})

      assert html =~ "Persistence skill"
      assert html =~ ~s(phx-value-type="skills" aria-pressed="true")
      assert html =~ ~s(phx-value-type="all" aria-pressed="false")
    end

    test "selecting Examples narrows references to example citations", %{conn: conn} do
      conn = with_content_assistant_stub(conn)
      {:ok, view, _html} = mount_live(conn)

      view
      |> form("#content-assistant-form", assistant: %{q: "control"})
      |> render_submit()

      assert_state(view, ~s(id="content-assistant-answer-state"))

      html = render_click(view, "select_result_filter", %{"type" => "examples"})

      # The example citation stays visible; non-example citations are hidden.
      assert html =~ "Controlled Agent example"
      refute html =~ "Agents concept"
      refute html =~ "Acme controlled-Agent case study"

      assert html =~ ~s(phx-value-type="examples" aria-pressed="true")
    end

    test "selecting All restores every citation", %{conn: conn} do
      conn = with_content_assistant_stub(conn)
      {:ok, view, _html} = mount_live(conn)

      view
      |> form("#content-assistant-form", assistant: %{q: "control"})
      |> render_submit()

      assert_state(view, ~s(id="content-assistant-answer-state"))

      render_click(view, "select_result_filter", %{"type" => "examples"})
      html = render_click(view, "select_result_filter", %{"type" => "all"})

      assert html =~ "Agents concept"
      assert html =~ "Controlled Agent example"
      assert html =~ ~s(phx-value-type="all" aria-pressed="true")
    end

    test "an unknown type clears the filter instead of emptying the list", %{conn: conn} do
      conn = with_content_assistant_stub(conn)
      {:ok, view, _html} = mount_live(conn)

      view
      |> form("#content-assistant-form", assistant: %{q: "control"})
      |> render_submit()

      assert_state(view, ~s(id="content-assistant-answer-state"))

      html = render_click(view, "select_result_filter", %{"type" => "bogus"})

      assert html =~ ~s(phx-value-type="all" aria-pressed="true")
      assert html =~ "Agents concept"
    end

    test "the no-result analytics records the active result-type filter", %{conn: conn} do
      conn = with_content_assistant_stub(conn)
      {:ok, view, _html} = mount_live(conn)

      # Get a result set, then narrow to Examples so the filter is active.
      view
      |> form("#content-assistant-form", assistant: %{q: "control"})
      |> render_submit()

      assert_state(view, ~s(id="content-assistant-answer-state"))
      render_click(view, "select_result_filter", %{"type" => "examples"})

      # A subsequent no-result query records the Examples filter that was
      # active when it ran.
      view
      |> form("#content-assistant-form", assistant: %{q: "missing"})
      |> render_submit()

      assert_state(view, ~s(id="content-assistant-no-results-state"))

      event =
        Repo.get_by(AnalyticsEvent,
          event: "content_assistant_query_no_results",
          path: "/search"
        )

      assert event
      assert event.metadata["filters"] == %{"type" => "examples"}
    end
  end

  describe "navigation entry points" do
    test "home header exposes unified content assistant trigger", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")
      assert html =~ ~s(id="primary-nav-content-assistant-trigger")
      assert html =~ "Cmd+K"
      refute html =~ ~s(id="primary-nav-search-trigger")
      refute html =~ "Ask AI"
      refute html =~ ~s(href="/search")
    end

    test "docs header exposes unified content assistant trigger", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/docs")
      assert html =~ ~s(id="primary-nav-content-assistant-trigger")
      assert html =~ "Cmd+K"
      refute html =~ ~s(id="primary-nav-search-trigger")
      refute html =~ "Ask AI"
      refute html =~ ~s(href="/search")
    end
  end

  setup_all do
    for app <- [:telemetry, :plug, :plug_crypto, :phoenix_pubsub] do
      {:ok, _started} = Application.ensure_all_started(app)
    end

    unless Process.whereis(AgentJido.PubSub) do
      start_supervised!({Phoenix.PubSub, name: AgentJido.PubSub})
    end

    unless Process.whereis(AgentJidoWeb.Endpoint) do
      start_supervised!(AgentJidoWeb.Endpoint)
    end

    :ok
  end

  setup do
    clear_response_cache()
    :ok
  end

  defp with_content_assistant_stub(conn) do
    with_content_assistant_module(conn, ContentAssistantStub)
  end

  defp with_content_assistant_module(conn, module) when is_atom(module) do
    conn
    |> init_test_session(%{})
    |> put_session(:content_assistant_module, module)
  end

  defp mount_live(conn, path \\ "/search") do
    live(conn, path)
  end

  defp clear_response_cache do
    table = :content_assistant_page_response_cache

    if :ets.whereis(table) != :undefined do
      :ets.delete_all_objects(table)
    end

    :ok
  end

  defp attach_telemetry(events) do
    handler_id = "content-assistant-live-test-#{System.unique_integer([:positive, :monotonic])}"
    pid = self()

    :ok =
      :telemetry.attach_many(
        handler_id,
        events,
        fn event, measurements, metadata, _config ->
          send(pid, {:assistant_telemetry, event, measurements, metadata})
        end,
        nil
      )

    on_exit(fn ->
      :telemetry.detach(handler_id)
    end)

    :ok
  end

  defp assert_state(view, state_id_fragment, attempts \\ 40)

  defp assert_state(_view, state_id_fragment, 0) do
    flunk("expected to render state #{state_id_fragment}")
  end

  defp assert_state(view, state_id_fragment, attempts) do
    html = render(view)

    if html =~ state_id_fragment do
      html
    else
      Process.sleep(10)
      assert_state(view, state_id_fragment, attempts - 1)
    end
  end
end
