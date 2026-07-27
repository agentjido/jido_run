defmodule AgentJidoWeb.JidoFeaturesProofLinksTest do
  @moduledoc """
  Proof-link gate for the Features marketing page (jido-e11-t20).

  Acceptance: "A visitor can open the supporting example, benchmark, or case
  study."

  Every feature card on /features makes a production claim (supervision,
  coordination, observability, ...). This test locks that each card carries a
  "Proof" link to exactly one runnable example, that the linked example is
  public (`status: :live` in `AgentJido.Examples`), and that the two residual
  timing claims with no benchmark ("restarts it in milliseconds",
  "under ten minutes") were restated as tested behavior per
  `specs/benchmark-methodology.md` (E11-T18/T19) rather than left beside a link
  they cannot back.
  """

  use AgentJidoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias AgentJido.Examples

  # {card slug, proof example path} — one runnable example per production claim.
  # Each path's slug must resolve to a live example, so a card whose proof points
  # at a missing or draft example fails the build.
  @proof_links [
    {"how-agents-work", "/examples/counter-agent"},
    {"tools", "/examples/coding-assistant"},
    {"llm-support", "/examples/jido-ai-weather-multi-turn-context"},
    {"agents-that-self-heal", "/examples/failure-drill-agent"},
    {"multi-agent-coordination", "/examples/signal-routing-agent"},
    {"observe-everything", "/examples/operations-agent"},
    {"start-small", "/examples/data-pipeline-agent"}
  ]

  test "every feature card links a proof example the visitor can open", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/features")

    assert html =~ "Proof",
           "the Features page must label each production claim with a Proof affordance"

    for {card_slug, proof_path} <- @proof_links do
      example_slug = String.trim_leading(proof_path, "/examples/")

      assert html =~ ~s(href="#{proof_path}"),
             "the #{card_slug} card must link its proof example at #{proof_path}"

      assert html =~ ~s(data-feature-proof="#{card_slug}"),
             "the #{card_slug} card must tag its proof link with data-feature-proof"

      assert Examples.get_example(example_slug) != nil,
             "the proof example #{example_slug} (#{card_slug}) must be a live example"
    end
  end

  test "unbenchmarked timing claims are restated, not left beside a proof link", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/features")

    # specs/benchmark-methodology.md: a restart duration (E11-T18) or an
    # onboarding duration (E11-T19) needs a measured benchmark before it can
    # carry a number. Neither exists, so neither number may appear.
    refute html =~ "in milliseconds",
           "the restart claim must state tested behavior, not an unbenchmarked duration"

    refute html =~ "under ten minutes",
           "the getting-started claim must state tested behavior, not an unbenchmarked duration"
  end
end
