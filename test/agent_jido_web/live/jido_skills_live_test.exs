defmodule AgentJidoWeb.JidoSkillsLiveTest do
  use AgentJidoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders the vendored upstream skills catalog page", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/skills")

    assert html =~ "Package skills for contributors and adopters"
    assert html =~ "one card per external package skill"
    assert html =~ "Router Skill"
    assert html =~ "jido-skill-router"
    assert html =~ "jido-action"
    assert html =~ "req-llm"
    assert html =~ ~s(href="https://github.com/arrowcircle/jido-skills")
    assert html =~ ~s(href="/examples/jido-ai-skills-runtime-foundations?tab=demo")
    assert html =~ ~s(href="/ecosystem/req_llm")
    assert html =~ ~s(href="/skills")
  end

  # jido-e10 E10-T24: each card must surface a package, task, maturity note,
  # and source so a user can choose a skill without opening every file.
  test "each package card renders package, task, maturity, and source detail", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/skills")

    # Row labels appear on every card.
    assert html =~ ~r(>Package</dt>)
    assert html =~ ~r(>Use for</dt>)
    assert html =~ ~r(>Triggers</dt>)
    assert html =~ ~r(>Maturity</dt>)
    assert html =~ ~r(>Source</dt>)

    # The req-llm card surfaces its upstream package and stable maturity.
    assert html =~ "req_llm"
    assert html =~ "provider transport and LLM request execution"
    assert html =~ "streaming"
    assert html =~ "Stable —"

    # Source links for the package (HexDocs / Hex) appear for published packages.
    assert html =~ ~s(href="https://hexdocs.pm/req_llm")
    assert html =~ ~s(href="https://hex.pm/packages/req_llm")

    # A beta package surfaces the distinct maturity label inline.
    assert html =~ "Beta —"

    # The router card also surfaces a task and maturity note.
    assert html =~ "Routes a task to the right package skill"
    assert html =~ "Generated meta-skill"
  end

  # jido-e10 E10-T26: the "use the router when unsure" guidance from the upstream
  # skills README must appear on the hub so users do not load the full skill
  # catalog by default.
  test "surfaces the 'use the router when unsure' guidance from the skills README", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/skills")

    assert html =~ "use the router when unsure which package to start with"
    assert html =~ "If you do not know which package skill to start with, use the router skill first"
    assert html =~ "avoid loading the entire ecosystem by default"
  end
end
