defmodule AgentJidoWeb.JidoEcosystemStackSelectionLiveTest do
  # async: false (like PageLiveLongRunningPathTest / JidoExamplesLiveTest) so the
  # connected LiveView's analytics writes share the test's sandbox transaction
  # and roll back, instead of escaping to the shared test database.
  use AgentJidoWeb.ConnCase, async: false

  import Ecto.Query
  import Phoenix.LiveViewTest

  alias AgentJido.Analytics.AnalyticsEvent
  alias AgentJido.Repo

  describe "ecosystem stack selection analytics (jido-e12-t28)" do
    # Acceptance condition: the team can compare recommended stacks with
    # full-catalog browsing. Expanding the dependency map is the "browse the full
    # catalog" half of that comparison; the recommended-stack package links are
    # the "recommended stacks" half. Each LiveView mount is assigned its own
    # analytics session id; reading it back from the view and filtering the
    # recorded event by it scopes the assertion to this test's own visitor.

    test "the recommended-stack package links carry the selection event for their stack", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/ecosystem")

      # Every recommended stack's package link fires the selection event keyed
      # by its stack, so the dashboard can attribute each follow to the stack a
      # visitor chose. The stack-compatibility section renders on the collapsed
      # first load (stacks come first), so these are present immediately.
      assert html =~ ~s(data-analytics-event="ecosystem_stack_selected")
      assert html =~ ~s(data-analytics-source="ecosystem")
      assert html =~ ~s(data-analytics-section-id="core")
      assert html =~ ~s(data-analytics-section-id="ai")
      assert html =~ ~s(data-analytics-section-id="operate")
    end

    test "the collapsed hub records no full-catalog selection", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/ecosystem")
      session_id = analytics_identity(view).session_id

      assert Repo.aggregate(
               from(e in AnalyticsEvent,
                 where:
                   e.event == "ecosystem_stack_selected" and
                     e.session_id == ^session_id
               ),
               :count,
               :id
             ) == 0
    end

    test "expanding the dependency map records a full-catalog selection; collapsing does not", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/ecosystem")
      session_id = analytics_identity(view).session_id

      view |> element("#toggle-dependency-map") |> render_click()

      [event] =
        Repo.all(
          from(e in AnalyticsEvent,
            where:
              e.event == "ecosystem_stack_selected" and
                e.session_id == ^session_id
          )
        )

      assert event.source == "ecosystem"
      assert event.channel == "dependency_map"
      assert event.section_id == "full_catalog"
      assert event.metadata["selection"] == "full_catalog"

      # Collapsing the catalog is not a new selection, so no second event is
      # recorded for this visitor.
      view |> element("#toggle-dependency-map") |> render_click()

      assert Repo.aggregate(
               from(e in AnalyticsEvent,
                 where:
                   e.event == "ecosystem_stack_selected" and
                     e.session_id == ^session_id
               ),
               :count,
               :id
             ) == 1
    end

    test "arriving on the ?map=open deep link records one full-catalog selection", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/ecosystem?map=open")
      session_id = analytics_identity(view).session_id

      [event] =
        Repo.all(
          from(e in AnalyticsEvent,
            where:
              e.event == "ecosystem_stack_selected" and
                e.session_id == ^session_id
          )
        )

      assert event.section_id == "full_catalog"
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
