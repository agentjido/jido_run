defmodule AgentJidoWeb.PageLiveLongRunningPathTest do
  # async: false (like JidoExamplesLiveTest) so the connected LiveView's
  # analytics writes share the test's sandbox transaction and roll back,
  # instead of escaping to the shared test database.
  use AgentJidoWeb.ConnCase, async: false

  import Ecto.Query
  import Phoenix.LiveViewTest

  alias AgentJido.Analytics.AnalyticsEvent
  alias AgentJido.Repo

  describe "onboarding to Operate long-running path analytics (jido-e12-t27)" do
    # Each LiveView mount is assigned its own analytics session id. Reading it
    # back from the view and filtering the recorded event by it scopes the
    # assertion to this test's own visitor.

    test "the operations hub records a long_running_path_entered event keyed by the hub", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/docs/operations")
      session_id = analytics_identity(view).session_id

      [event] =
        Repo.all(
          from(e in AnalyticsEvent,
            where:
              e.event == "long_running_path_entered" and
                e.section_id == "operations" and
                e.session_id == ^session_id
          )
        )

      assert event.source == "operate"
      assert event.channel == "long_running_path"
      assert event.path == "/docs/operations"
      assert event.metadata["page"] == "operations"
      assert event.metadata["surface"] == "operations"
    end

    test "a deep operations page records the event keyed by its slug", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/docs/operations/telemetry-and-traces")
      session_id = analytics_identity(view).session_id

      [event] =
        Repo.all(
          from(e in AnalyticsEvent,
            where:
              e.event == "long_running_path_entered" and
                e.section_id == "telemetry-and-traces" and
                e.session_id == ^session_id
          )
        )

      assert event.path == "/docs/operations/telemetry-and-traces"
      assert event.metadata["page"] == "telemetry-and-traces"
    end

    test "a non-operations docs page records no long_running_path_entered event", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/docs/getting-started")
      session_id = analytics_identity(view).session_id

      assert Repo.aggregate(
               from(
                 e in AnalyticsEvent,
                 where:
                   e.event == "long_running_path_entered" and
                     e.session_id == ^session_id
               ),
               :count,
               :id
             ) == 0
    end
  end

  defp analytics_identity(view) do
    view.pid
    |> :sys.get_state()
    |> Map.fetch!(:socket)
    |> Map.fetch!(:assigns)
    |> Map.fetch!(:analytics_identity)
  end
end
