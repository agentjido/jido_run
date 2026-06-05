defmodule AgentJido.Analytics.CompositeTest do
  use AgentJido.DataCase, async: false

  import AgentJido.AccountsFixtures

  alias AgentJido.Accounts.Scope
  alias AgentJido.Analytics
  alias AgentJido.Analytics.AnalyticsEvent
  alias AgentJido.Analytics.Composite
  alias AgentJido.QueryLogs
  alias AgentJido.Repo

  setup :set_posthog_shared

  setup do
    original_posthog_config = Application.get_env(:agent_jido, :posthog)

    on_exit(fn ->
      if original_posthog_config do
        Application.put_env(:agent_jido, :posthog, original_posthog_config)
      else
        Application.delete_env(:agent_jido, :posthog)
      end
    end)

    :ok
  end

  test "delegates first-party read APIs unchanged" do
    put_posthog_config(%{enabled: false, server_enabled: false})
    scope = Scope.for_user(user_fixture())
    admin_scope = Scope.for_user(admin_user_fixture())

    Analytics.track_feedback_safe(scope, %{
      event: "feedback_submitted",
      source: "docs",
      channel: "docs_sidebar",
      path: "/docs/concepts/agents",
      feedback_value: "not_helpful",
      feedback_note: "Needs more details about retries",
      visitor_id: "visitor-read-test",
      session_id: "session-read-test",
      metadata: %{surface: "docs_page", page_id: "agents"}
    })

    assert Composite.event_values() == Analytics.event_values()
    assert Composite.feedback_surfaces() == Analytics.feedback_surfaces()

    assert Composite.feedback_rows_for_export(admin_scope, 7, 10) ==
             Analytics.feedback_rows_for_export(admin_scope, 7, 10)

    assert Composite.search_activity_snapshot(admin_scope, 7, limit: 10) ==
             Analytics.search_activity_snapshot(admin_scope, 7, limit: 10)

    assert Composite.external_collection_snapshot(admin_scope, 7) ==
             Analytics.external_collection_snapshot(admin_scope, 7)
  end

  test "skips mirrored PostHog writes when server capture is disabled" do
    put_posthog_config(%{enabled: false, server_enabled: false})
    scope = Scope.for_user(user_fixture())
    before_count = length(PostHog.Test.all_captured())

    assert {:ok, %AnalyticsEvent{}} =
             Composite.track_event(scope, %{
               event: "content_assistant_submitted",
               source: "content_assistant",
               channel: "content_assistant_page",
               path: "/search",
               visitor_id: "visitor-disabled",
               session_id: "session-disabled",
               metadata: %{surface: "content_assistant_page", query: "agent retries"}
             })

    assert length(PostHog.Test.all_captured()) == before_count
  end

  test "skips mirrored PostHog writes for admin-scoped analytics" do
    put_posthog_config(%{})
    admin_scope = Scope.for_user(admin_user_fixture())
    before_count = length(PostHog.Test.all_captured())
    before_events = Repo.aggregate(AnalyticsEvent, :count, :id)

    assert {:ok, :excluded_admin} =
             Composite.track_event(admin_scope, %{
               event: "content_assistant_submitted",
               source: "content_assistant",
               channel: "content_assistant_page",
               path: "/search",
               visitor_id: "visitor-admin-posthog",
               session_id: "session-admin-posthog",
               metadata: %{surface: "content_assistant_page", query: "agent retries"}
             })

    assert Repo.aggregate(AnalyticsEvent, :count, :id) == before_events
    assert length(PostHog.Test.all_captured()) == before_count
  end

  test "sanitizes mirrored PostHog properties while preserving safe metadata" do
    put_posthog_config(%{})
    scope = Scope.for_user(user_fixture())
    feedback_note = "I wanted deeper retry examples"
    identity = %{visitor_id: "visitor-sanitize", session_id: "session-sanitize", path: "/search", referrer_host: "jido.run"}

    query_log =
      QueryLogs.track_query_safe(scope, identity, %{
        source: "content_assistant",
        channel: "content_assistant_page",
        query: "agent retries",
        status: "submitted",
        path: "/search",
        metadata: %{surface: "content_assistant_page"}
      })

    assert query_log
    query_log_id = query_log.id

    assert {:ok, %AnalyticsEvent{}} =
             Composite.track_event(scope, %{
               event: "content_assistant_submitted",
               source: "content_assistant",
               channel: "content_assistant_page",
               path: "/search",
               query_log_id: query_log_id,
               visitor_id: "visitor-sanitize",
               session_id: "session-sanitize",
               metadata: %{surface: "content_assistant_page", query: "agent retries", cache_hit: false}
             })

    Composite.track_feedback_safe(scope, %{
      event: "feedback_submitted",
      source: "content_assistant",
      channel: "content_assistant_page",
      path: "/search",
      feedback_value: "not_helpful",
      feedback_note: feedback_note,
      query_log_id: query_log_id,
      visitor_id: "visitor-sanitize",
      session_id: "session-sanitize",
      metadata: %{surface: "content_assistant", retrieval_status: :success}
    })

    submitted =
      PostHog.Test.all_captured()
      |> Enum.find(fn event ->
        event.event == "content_assistant_submitted" and event.distinct_id == "visitor-sanitize"
      end)

    assert submitted
    refute Map.has_key?(submitted.properties, "query")
    assert submitted.properties["query_length"] == String.length("agent retries")
    assert submitted.properties["query_log_id"] == query_log_id
    assert submitted.properties["surface"] == "content_assistant_page"
    assert submitted.properties["cache_hit"] == false

    feedback =
      PostHog.Test.all_captured()
      |> Enum.find(fn event ->
        event.event == "feedback_submitted" and event.distinct_id == "visitor-sanitize"
      end)

    assert feedback
    refute Map.has_key?(feedback.properties, "feedback_note")
    assert feedback.properties["feedback_note_length"] == String.length(feedback_note)
    assert feedback.properties["feedback_value"] == "not_helpful"
    assert feedback.properties["surface"] == "content_assistant"
    assert feedback.properties["retrieval_status"] == "success"
  end

  defp set_posthog_shared(_context) do
    PostHog.Test.set_posthog_shared()
    :ok
  end

  defp put_posthog_config(overrides) do
    Application.put_env(
      :agent_jido,
      :posthog,
      Map.merge(
        %{
          enabled: true,
          browser_enabled: false,
          server_enabled: true,
          autocapture_enabled: false,
          session_replay_enabled: false,
          session_replay_sample_rate: 0.25,
          api_key: "test-posthog-key",
          api_host: "https://us.i.posthog.com"
        },
        overrides
      )
    )
  end
end
