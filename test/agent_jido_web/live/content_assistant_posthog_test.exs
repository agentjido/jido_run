defmodule AgentJidoWeb.ContentAssistantPostHogTest do
  use AgentJidoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias AgentJido.ContentAssistant.Response
  alias AgentJido.ContentAssistant.Result

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
            session_id: "0195798a-89c2-78f4-8b5e-5a8ef0f37e73",
            path: "/docs/concepts/agents",
            referrer_host: "jido.run"
          }
        }
      />
      """
    end
  end

  setup :set_posthog_shared

  setup do
    original_module = Application.get_env(:agent_jido, :content_assistant_module)
    original_posthog_config = Application.get_env(:agent_jido, :posthog)

    Application.put_env(:agent_jido, :content_assistant_module, ContentAssistantStub)

    on_exit(fn ->
      if original_module do
        Application.put_env(:agent_jido, :content_assistant_module, original_module)
      else
        Application.delete_env(:agent_jido, :content_assistant_module)
      end

      if original_posthog_config do
        Application.put_env(:agent_jido, :posthog, original_posthog_config)
      else
        Application.delete_env(:agent_jido, :posthog)
      end
    end)

    :ok
  end

  test "captures modal lifecycle events without raw query text", %{conn: conn} do
    enable_posthog_server()
    {:ok, view, html} = live_isolated(conn, ModalHarnessLive)

    assert html =~ "ph-no-capture ph-sensitive"

    view
    |> form("form[phx-submit='submit']", assistant: %{q: "agents"})
    |> render_submit()

    assert_eventually(fn ->
      updated_html = render(view)
      updated_html =~ ~s(id="primary-nav-content-assistant-modal-answer") and updated_html =~ "ph-mask"
    end)

    assert_eventually(fn ->
      submitted =
        lifecycle_event("content_assistant_query_submitted", "content-assistant-test-visitor")

      completed =
        lifecycle_event("content_assistant_query_completed", "content-assistant-test-visitor")

      submitted && completed
    end)

    submitted = lifecycle_event("content_assistant_query_submitted", "content-assistant-test-visitor")
    completed = lifecycle_event("content_assistant_query_completed", "content-assistant-test-visitor")

    assert submitted.properties["query_length"] == 6
    refute Map.has_key?(submitted.properties, "query")
    assert submitted.properties["surface"] == "content_assistant_modal"

    assert completed.properties["results_count"] == 1
    assert completed.properties["query_length"] == 6
    assert completed.properties["surface"] == "content_assistant_modal"
  end

  test "captures the categorized first LLM request outcome (jido-e12-t24)", %{conn: conn} do
    enable_posthog_server()
    {:ok, view, _html} = live_isolated(conn, ModalHarnessLive)

    view
    |> form("form[phx-submit='submit']", assistant: %{q: "agents"})
    |> render_submit()

    assert_eventually(fn ->
      updated_html = render(view)
      updated_html =~ ~s(id="primary-nav-content-assistant-modal-answer")
    end)

    assert_eventually(fn ->
      lifecycle_event("llm_request_outcome", "content-assistant-test-visitor")
    end)

    # A deterministic success (the "agents" stub) categorizes as a succeeded
    # first LLM request — proving the modal tracks the categorized outcome.
    outcome = lifecycle_event("llm_request_outcome", "content-assistant-test-visitor")

    assert outcome.properties["outcome"] == "succeeded"
    assert outcome.properties["reason"] == "succeeded"
    assert outcome.properties["surface"] == "content_assistant_modal"
  end

  test "captures no-results lifecycle events for modal searches", %{conn: conn} do
    enable_posthog_server()
    {:ok, view, _html} = live_isolated(conn, ModalHarnessLive)

    view
    |> form("form[phx-submit='submit']", assistant: %{q: "none"})
    |> render_submit()

    assert_eventually(fn ->
      updated_html = render(view)
      updated_html =~ ~s(id="primary-nav-content-assistant-modal-empty") and updated_html =~ "ph-mask"
    end)

    assert_eventually(fn ->
      lifecycle_event("content_assistant_query_no_results", "content-assistant-test-visitor")
    end)

    no_results = lifecycle_event("content_assistant_query_no_results", "content-assistant-test-visitor")

    assert no_results.properties["query_length"] == 4
    assert no_results.properties["results_count"] == 0
    assert no_results.properties["surface"] == "content_assistant_modal"

    # First-party no-result analytics event (jido-e10-t06) records the query
    # (via query_log_id + query_length), filters, and route without sensitive
    # data, mirroring the PostHog lifecycle event.
    assert_eventually(fn ->
      AgentJido.Repo.get_by(AgentJido.Analytics.AnalyticsEvent,
        event: "content_assistant_query_no_results"
      )
    end)

    first_party =
      AgentJido.Repo.get_by(AgentJido.Analytics.AnalyticsEvent,
        event: "content_assistant_query_no_results"
      )

    assert first_party.path == "/docs/concepts/agents"
    assert first_party.query_log_id
    assert first_party.metadata["surface"] == "content_assistant_modal"
    assert first_party.metadata["filters"] == %{}
    assert first_party.metadata["results_count"] == 0
    assert first_party.metadata["query_length"] == 4
    refute Map.has_key?(first_party.metadata, "query")
  end

  defp set_posthog_shared(_context) do
    PostHog.Test.set_posthog_shared()
    :ok
  end

  defp enable_posthog_server do
    Application.put_env(:agent_jido, :posthog, %{
      enabled: true,
      browser_enabled: false,
      server_enabled: true,
      autocapture_enabled: false,
      session_replay_enabled: false,
      session_replay_sample_rate: 0.25,
      api_key: "test-posthog-key",
      api_host: "https://us.i.posthog.com"
    })
  end

  defp lifecycle_event(event_name, distinct_id) do
    PostHog.Test.all_captured()
    |> Enum.find(fn event ->
      event.event == event_name and event.distinct_id == distinct_id
    end)
  end

  defp assert_eventually(fun, attempts \\ 25)

  defp assert_eventually(fun, attempts) when attempts > 0 do
    if fun.() do
      assert true
    else
      Process.sleep(40)
      assert_eventually(fun, attempts - 1)
    end
  end

  defp assert_eventually(_fun, 0), do: flunk("condition not met in time")
end
