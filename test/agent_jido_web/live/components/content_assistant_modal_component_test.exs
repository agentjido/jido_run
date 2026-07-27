defmodule AgentJidoWeb.ContentAssistantModalComponentTest do
  use AgentJidoWeb.ConnCase, async: false

  import Ecto.Query
  import Phoenix.LiveViewTest

  alias AgentJido.Analytics.AnalyticsEvent
  alias AgentJido.ContentAssistant.Response
  alias AgentJido.ContentAssistant.Result
  alias AgentJido.QueryLogs
  alias AgentJido.QueryLogs.QueryLog

  defmodule ContentAssistantStub do
    def respond("agents", _opts) do
      {:ok,
       %Response{
         query: "agents",
         answer_markdown: "Agent overview",
         answer_html: "<p>Agent overview</p>",
         answer_mode: :deterministic,
         citations: [
           %Result{
             title: "Agents",
             snippet: "Agents model state and command boundaries.",
             url: "/docs/concepts/agents",
             source_type: :docs,
             score: 0.95
           }
         ],
         retrieval_status: :success,
         llm_attempted?: false,
         llm_enhanced?: false,
         enhancement_blocked_reason: nil,
         query_log_id: nil
       }}
    end

    def respond("none", _opts) do
      {:ok,
       %Response{
         query: "none",
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

    def respond("jido", _opts) do
      {:ok,
       %Response{
         query: "jido",
         answer_markdown: "Jido docs result",
         answer_html: "<p>Jido docs result</p>",
         answer_mode: :deterministic,
         citations: [
           %Result{
             title: "Jido Runtime",
             snippet: "How Jido runtime handles directives.",
             url: "/docs/concepts/agent-runtime",
             source_type: :docs,
             score: 0.91
           }
         ],
         retrieval_status: :success,
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
         answer_markdown: "HexDocs result",
         answer_html: "<p>HexDocs result</p>",
         answer_mode: :deterministic,
         citations: [
           %Result{
             title: "Jido.Agent",
             snippet: "API reference for cmd/2.",
             url: "https://hexdocs.pm/jido/Jido.Agent.html",
             source_type: :ecosystem_docs,
             score: 0.9,
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

    def respond("mixed", _opts) do
      {:ok,
       %Response{
         query: "mixed",
         answer_markdown: "Mixed overview",
         answer_html: "<p>Mixed overview</p>",
         answer_mode: :deterministic,
         citations: [
           %Result{
             title: "Runtime concept",
             snippet: "A docs concept.",
             url: "/docs/concepts/runtime",
             source_type: :docs,
             score: 0.9
           },
           %Result{
             title: "Persistence example",
             snippet: "A runnable example.",
             url: "/examples/persistence",
             source_type: :examples,
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

    def respond(_query, _opts) do
      {:ok,
       %Response{
         query: "",
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
  end

  defmodule AssistantOptsCaptureStub do
    @moduledoc false

    @spec respond(String.t(), keyword()) :: {:ok, Response.t()}
    def respond(query, opts \\ []) do
      if pid = :persistent_term.get({__MODULE__, :test_pid}, nil) do
        send(pid, {:modal_opts_capture, query, opts})
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

  defmodule ModalHarnessLive do
    use AgentJidoWeb, :live_view

    @impl true
    def render(assigns) do
      ~H"""
      <.live_component
        module={AgentJidoWeb.ContentAssistantModalComponent}
        id="primary-nav-content-assistant-modal"
        analytics_identity={
          %{
            visitor_id: "content-assistant-test-visitor",
            session_id: "content-assistant-test-session",
            path: "/docs/concepts/agents",
            referrer_host: "jido.run"
          }
        }
      />
      """
    end
  end

  setup do
    original_module = Application.get_env(:agent_jido, :content_assistant_module)
    original_content_assistant_config = Application.get_env(:agent_jido, AgentJido.ContentAssistant)
    Application.put_env(:agent_jido, :content_assistant_module, ContentAssistantStub)

    on_exit(fn ->
      if original_module do
        Application.put_env(:agent_jido, :content_assistant_module, original_module)
      else
        Application.delete_env(:agent_jido, :content_assistant_module)
      end

      if original_content_assistant_config do
        Application.put_env(:agent_jido, AgentJido.ContentAssistant, original_content_assistant_config)
      else
        Application.delete_env(:agent_jido, AgentJido.ContentAssistant)
      end
    end)

    :ok
  end

  test "tracks reference click events", %{conn: conn} do
    {:ok, view, _html} = live_isolated(conn, ModalHarnessLive)

    view
    |> form("form[phx-submit='submit']", assistant: %{q: "agents"})
    |> render_submit()

    assert_eventually(fn ->
      html = render(view)
      html =~ ~s(id="primary-nav-content-assistant-modal-answer")
    end)

    view
    |> element("a[href='/docs/concepts/agents']")
    |> render_click()

    assert_eventually(fn ->
      AgentJido.Repo.exists?(
        from(e in AnalyticsEvent,
          where: e.event == "content_assistant_reference_clicked" and e.source == "content_assistant"
        )
      )
    end)

    assert_eventually(fn ->
      query_log = latest_query_log("agents")
      query_log && query_log.source == "content_assistant" && query_log.status == "success"
    end)
  end

  test "tracks no-results feedback events", %{conn: conn} do
    {:ok, view, _html} = live_isolated(conn, ModalHarnessLive)

    view
    |> form("form[phx-submit='submit']", assistant: %{q: "none"})
    |> render_submit()

    assert_eventually(fn ->
      html = render(view)
      html =~ ~s(id="primary-nav-content-assistant-modal-empty")
    end)

    assert has_element?(view, "#primary-nav-content-assistant-modal-no-results-feedback button[title='Not helpful']")

    view
    |> form("#primary-nav-content-assistant-modal-no-results-feedback-form", feedback: %{note: "Need agent docs"})
    |> render_submit()

    assert_eventually(fn ->
      AgentJido.Repo.exists?(
        from(e in AnalyticsEvent,
          where:
            e.event == "feedback_submitted" and e.source == "content_assistant" and
              e.channel == "content_assistant_no_results"
        )
      )
    end)

    assert_eventually(fn ->
      query_log = latest_query_log("none")
      query_log && query_log.source == "content_assistant" && query_log.status == "no_results"
    end)
  end

  test "uses fast defaults for modal search execution", %{conn: conn} do
    :persistent_term.put({AssistantOptsCaptureStub, :test_pid}, self())
    original_module = Application.get_env(:agent_jido, :content_assistant_module)
    Application.put_env(:agent_jido, :content_assistant_module, AssistantOptsCaptureStub)

    on_exit(fn ->
      :persistent_term.erase({AssistantOptsCaptureStub, :test_pid})

      if original_module do
        Application.put_env(:agent_jido, :content_assistant_module, original_module)
      else
        Application.delete_env(:agent_jido, :content_assistant_module)
      end
    end)

    {:ok, view, _html} = live_isolated(conn, ModalHarnessLive)

    view
    |> form("form[phx-submit='submit']", assistant: %{q: "agents"})
    |> render_submit()

    assert_receive {:modal_opts_capture, "agents", opts}, 1_000
    assert Keyword.get(opts, :llm) == nil
    assert Keyword.get(opts, :require_turnstile) == false
    assert opts |> Keyword.get(:retrieval_opts, []) |> Keyword.get(:mode) == :hybrid
    assert opts |> Keyword.get(:retrieval_opts, []) |> Keyword.get(:graph) == true
  end

  test "renders HexDocs citations with external handoff details", %{conn: conn} do
    {:ok, view, _html} = live_isolated(conn, ModalHarnessLive)

    view
    |> form("form[phx-submit='submit']", assistant: %{q: "hexdocs"})
    |> render_submit()

    assert_eventually(fn ->
      html = render(view)

      html =~ "HexDocs" and
        html =~ "Jido.Agent" and
        html =~ "Opens in new tab" and
        html =~ ~s(href="https://hexdocs.pm/jido/Jido.Agent.html") and
        html =~ ~s(target="_blank") and
        html =~ ~s(href="/ecosystem/jido")
    end)
  end

  test "result-type filter narrows citations (jido-e10-t07)", %{conn: conn} do
    # Acceptance: "Users can select Docs, Examples, Ecosystem, Blog, or Skills."
    {:ok, view, _html} = live_isolated(conn, ModalHarnessLive)

    view
    |> form("form[phx-submit='submit']", assistant: %{q: "mixed"})
    |> render_submit()

    assert_eventually(fn ->
      html = render(view)
      html =~ ~s(id="primary-nav-content-assistant-modal-answer") and html =~ "Persistence example"
    end)

    # Narrow to Examples — the example citation stays, the docs citation hides.
    view
    |> element("button[phx-value-type='examples']")
    |> render_click()

    assert_eventually(fn ->
      html = render(view)
      html =~ "Persistence example" and not String.contains?(html, "Runtime concept")
    end)

    # All restores the docs citation.
    view
    |> element("button[phx-value-type='all']")
    |> render_click()

    assert_eventually(fn ->
      html = render(view)
      html =~ "Runtime concept"
    end)
  end

  test "renders lazy turnstile metadata for the modal when verification is enabled", %{conn: conn} do
    Application.put_env(
      :agent_jido,
      AgentJido.ContentAssistant,
      search_response_mode: :enhanced,
      require_turnstile: true,
      turnstile_site_key: "site-key"
    )

    {:ok, _view, html} = live_isolated(conn, ModalHarnessLive)

    assert html =~ ~s(id="primary-nav-content-assistant-modal-turnstile")
    assert html =~ ~s(data-load-trigger="modal-open")
    assert html =~ ~s(data-modal-id="primary-nav-content-assistant-modal")
    assert html =~ ~s(data-submit-id="primary-nav-content-assistant-modal-submit")
    assert html =~ ~s(id="primary-nav-content-assistant-modal-turnstile-status")
    assert html =~ ~s(id="primary-nav-content-assistant-modal-turnstile-retry")
  end

  test "hydrates recent thread from persisted query logs and limits to last three entries", %{conn: conn} do
    identity = %{
      visitor_id: "content-assistant-test-visitor",
      session_id: "content-assistant-test-session"
    }

    base_time = ~N[2026-01-01 00:00:00]

    seed_query_log(identity, "alpha", "success", 2, NaiveDateTime.add(base_time, 1, :second))
    seed_query_log(identity, "beta", "no_results", 0, NaiveDateTime.add(base_time, 2, :second))
    seed_query_log(identity, "gamma", "success", 5, NaiveDateTime.add(base_time, 3, :second))
    seed_query_log(identity, "delta", "success", 1, NaiveDateTime.add(base_time, 4, :second))

    {:ok, view, _html} = live_isolated(conn, ModalHarnessLive)

    assert_eventually(fn ->
      html = render(view)

      html =~ "Recent thread" and
        html =~ "delta" and
        html =~ "gamma" and
        html =~ "beta" and
        not String.contains?(html, "alpha")
    end)
  end

  test "recent thread items are clickable and rerun that query", %{conn: conn} do
    {:ok, view, _html} = live_isolated(conn, ModalHarnessLive)

    view
    |> form("form[phx-submit='submit']", assistant: %{q: "agents"})
    |> render_submit()

    assert_eventually(fn ->
      html = render(view)
      html =~ "Agent overview" and html =~ "agents"
    end)

    view
    |> form("form[phx-submit='submit']", assistant: %{q: "jido"})
    |> render_submit()

    assert_eventually(fn ->
      html = render(view)
      html =~ "Jido docs result" and html =~ "jido"
    end)

    view
    |> element("button[phx-value-q='agents']")
    |> render_click()

    assert_eventually(fn ->
      html = render(view)
      html =~ "Agent overview" and html =~ ~s(value="agents")
    end)
  end

  defp latest_query_log(query) when is_binary(query) do
    # Scope to the submitted query so this assertion is stable across files.
    AgentJido.Repo.one(
      from(q in QueryLog,
        where: q.source == "content_assistant" and q.query == ^query,
        order_by: [desc: q.inserted_at],
        limit: 1
      )
    )
  end

  defp seed_query_log(identity, query, status, results_count, inserted_at) do
    {:ok, query_log} =
      QueryLogs.create_query_log(nil, identity, %{
        source: "content_assistant",
        channel: "content_assistant_modal",
        query: query,
        status: status,
        results_count: results_count
      })

    AgentJido.Repo.update_all(
      from(q in QueryLog, where: q.id == ^query_log.id),
      set: [inserted_at: inserted_at, updated_at: inserted_at]
    )
  end

  defp assert_eventually(fun, attempts \\ 60)

  defp assert_eventually(fun, attempts) when attempts > 0 do
    if fun.() do
      :ok
    else
      Process.sleep(25)
      assert_eventually(fun, attempts - 1)
    end
  end

  defp assert_eventually(_fun, 0), do: flunk("expected condition to become true")
end
