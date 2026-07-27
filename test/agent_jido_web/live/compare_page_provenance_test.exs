defmodule AgentJidoWeb.ComparePageProvenanceTest do
  @moduledoc """
  Renders competitor-page review dates and sources (jido-e12-t19).

  Acceptance condition: "Old facts are visible and queued for review."

  The data invariants (review date, reviewer, sources on every comparison) are
  locked in ComparePageReviewSourcesTest. This test locks the *visibility* half:
  a visitor reading a comparison page actually sees when it was last reviewed,
  who reviewed it, and the external sources its competitor facts came from, so
  old facts cannot hide behind unattributed prose. The provenance block is
  scoped to the `:compare` category.
  """

  use AgentJidoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  # One comparison page is enough to prove the block renders; the data test
  # covers the full set.
  @compare_path "/compare/crewai"

  test "a comparison page shows its review date, reviewer, and sources", %{conn: conn} do
    {:ok, _view, html} = live(conn, @compare_path)

    # The provenance block is present.
    assert html =~ ~s(data-compare-provenance),
           "the comparison page must render its provenance block (jido-e12-t19)"

    # The review date is visible.
    assert html =~ "Last reviewed",
           "the comparison page must show when it was last reviewed"

    # The reviewer is visible (accountability).
    assert html =~ "Reviewed by",
           "the comparison page must name its reviewer"

    # The sources section is visible and lists the competitor's repo + docs.
    assert html =~ "Sources",
           "the comparison page must list its external sources"

    assert html =~ "https://github.com/crewAIInc/crewAI",
           "the CrewAI comparison must link the competitor repo as a source"

    assert html =~ "https://docs.crewai.com",
           "the CrewAI comparison must link the competitor docs as a source"
  end

  test "a non-compare marketing page does not render the provenance block", %{conn: conn} do
    # The provenance block is scoped to :compare; a features page (also rendered
    # through the marketing shell) must not carry it.
    {:ok, _view, html} = live(conn, "/features/start-small")

    refute html =~ ~s(data-compare-provenance),
           "the compare provenance block must not render on a non-compare page"
  end
end
