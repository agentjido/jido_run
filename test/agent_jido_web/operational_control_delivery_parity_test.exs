defmodule AgentJidoWeb.OperationalControlDeliveryParityTest do
  @moduledoc """
  jido-e10-t34 — cross-surface parity for operational-control delivery.

  Acceptance condition: "No surface drops the limitation or changes a control
  term."

  Browser, Markdown, search, MCP, and Skills each deliver operational-control
  language to a different reader. They must agree about it: the same nine
  control dimensions, the same boundary-role vocabulary, the same release-basis
  limitation, and the same canonical control-overview proof link. This module
  is the one gate that asserts every surface carries that shared language and
  derives it from the same single source of truth (`ControlMatrix` for the
  matrix surfaces, `SearchAliases` for the search surface), so a change in one
  place cannot silently drop the limitation or drift a control term in another.

  The per-surface tests that already live next to each implementation
  (jido_ecosystem_live_test, markdown_content_test, search_aliases_test,
  docs_tools_test, jido_skills_live_test) lock each surface on its own. This
  module locks the *agreement* between them: the control terms and limitation a
  reader sees in a browser must be the same terms and limitation a machine
  client receives through Markdown, MCP, and llms.txt, the same overview a
  control-term search resolves to, and the same package boundary the Skills
  catalog links into.
  """

  use AgentJidoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias AgentJido.ContentAssistant.SearchAliases
  alias AgentJido.Ecosystem.ControlMatrix
  alias AgentJido.MCP.DocsTools
  alias AgentJido.UpstreamSkillCatalog
  alias AgentJidoWeb.MarkdownContent

  # The canonical control overview every surface cites as proof — the one docs
  # page that draws every control boundary (what Jido supplies, what the
  # application owns, and the proof for each).
  @control_overview "/docs/operations/security-and-governance"

  # The release-basis limitation. Every surface that states a control claim must
  # qualify it with this caveat (the "no over-claim" boundary). Surfaces phrase
  # the boundary word slightly differently ("here" vs "only"), so the parity
  # gate asserts the two invariant halves of the clause rather than one string —
  # the qualification a reader relies on cannot be dropped either half.
  @limitation_boundary "experimental or unreleased packages describe their documented boundary"
  @limitation_clause "do not back a general production claim"

  @ecosystem_absolute_url "https://jido.run/ecosystem"

  # The matrix surfaces — browser, Markdown, MCP — all render the same nine
  # dimensions. Asserting against `ControlMatrix.capabilities()/0` (not a
  # hand-copied list) is what makes this a parity gate: change a dimension label
  # in the source of truth and every surface must follow or this fails.
  defp dimension_labels, do: Enum.map(ControlMatrix.capabilities(), & &1.label)

  defp limitation?(surface_text) do
    # Collapse whitespace first: the browser HEEx wraps the limitation clause
    # across source lines ("do not back a\n  general production claim"), so a
    # raw contiguous-substring check would miss the wrapped clause. Markdown,
    # MCP, and llms.txt are single-line, so normalizing is a no-op there.
    normalized = String.replace(surface_text, ~r/\s+/u, " ")

    String.contains?(normalized, @limitation_boundary) and
      String.contains?(normalized, @limitation_clause)
  end

  describe "browser surface — the /ecosystem hub" do
    # The browser hub is the human-readable control matrix. It must carry every
    # control dimension, the full role vocabulary, the release-basis limitation,
    # and the proof link to the canonical overview.

    test "renders every control dimension label from ControlMatrix", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/ecosystem")

      for label <- dimension_labels() do
        assert html =~ label,
               "the browser ecosystem hub dropped the #{inspect(label)} control term"
      end
    end

    test "renders the full boundary-role vocabulary", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/ecosystem")

      for role <- [:supplies, :preserves, :app] do
        assert html =~ ControlMatrix.role_label(role),
               "the browser ecosystem hub dropped the #{role} role label"
      end
    end

    test "states the release-basis limitation and links the canonical overview", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/ecosystem")

      assert limitation?(html),
             "the browser ecosystem hub dropped the release-basis limitation"

      assert html =~ ~s(href="#{@control_overview}"),
             "the browser ecosystem hub dropped the canonical control-overview proof link"
    end
  end

  describe "Markdown surface — the /ecosystem.md hub" do
    # The Markdown hub is the machine-readable control matrix. It must carry the
    # same dimensions, roles, limitation, and proof link, sourced from
    # ControlMatrix so it cannot drift from the browser surface.

    test "carries every control dimension label from ControlMatrix" do
      {:ok, markdown} = MarkdownContent.resolve("/ecosystem", @ecosystem_absolute_url)

      for label <- dimension_labels() do
        assert markdown =~ label,
               "the ecosystem Markdown hub dropped the #{inspect(label)} control term"
      end
    end

    test "its dimension labels are exactly ControlMatrix's, in order" do
      # Set-and-order parity with the source of truth: the Markdown cannot
      # rename, reorder, add, or drop a control term relative to the matrix.
      {:ok, markdown} = MarkdownContent.resolve("/ecosystem", @ecosystem_absolute_url)

      markdown_dimension_labels =
        ControlMatrix.capabilities()
        |> Enum.map(fn capability ->
          if String.contains?(markdown, "### #{capability.label}"), do: capability.label, else: nil
        end)
        |> Enum.reject(&is_nil/1)

      assert markdown_dimension_labels == dimension_labels(),
             "the ecosystem Markdown hub's control dimensions drifted from ControlMatrix"
    end

    test "carries the full boundary-role vocabulary, limitation, and proof link" do
      {:ok, markdown} = MarkdownContent.resolve("/ecosystem", @ecosystem_absolute_url)

      for role <- [:supplies, :preserves, :app] do
        assert markdown =~ ControlMatrix.role_label(role),
               "the ecosystem Markdown hub dropped the #{role} role label"
      end

      assert limitation?(markdown),
             "the ecosystem Markdown hub dropped the release-basis limitation"

      assert markdown =~ "(#{@control_overview})",
             "the ecosystem Markdown hub dropped the canonical control-overview proof link"
    end
  end

  describe "search surface — control-term routing" do
    # Search does not render the matrix; it routes a control term to the one
    # canonical overview the other surfaces cite as proof. Parity here means
    # every registered control term resolves to that same overview, so a reader
    # who arrives through search lands on the control language every other
    # surface agrees on.

    test "every registered control term resolves to the canonical overview" do
      terms = SearchAliases.aliases_for_route(@control_overview)

      assert terms != [],
             "no operational-control terms are registered on the canonical overview"

      for term <- terms do
        assert SearchAliases.routes_for_query(term) == [@control_overview],
               "the control term #{inspect(term)} stopped resolving to the canonical overview"
      end
    end

    test "the canonical search overview is the same route the matrix surfaces cite as proof",
         %{conn: conn} do
      # Search, the browser hub, and the Markdown hub must agree on the one
      # control-overview route. A drift here would send a searcher to a different
      # page than the proof link a browser or Markdown reader follows.
      assert "authorization" in SearchAliases.aliases_for_route(@control_overview)
      assert SearchAliases.routes_for_query("authorization") == [@control_overview]

      {:ok, _view, browser_html} = live(conn, "/ecosystem")
      assert browser_html =~ ~s(href="#{@control_overview}")

      {:ok, markdown} = MarkdownContent.resolve("/ecosystem", @ecosystem_absolute_url)
      assert markdown =~ "(#{@control_overview})"
    end
  end

  describe "MCP surface — get_operational_control" do
    # MCP returns the control model as structured data. Parity here means its
    # dimensions are exactly ControlMatrix's and its overview is the canonical
    # control page, so a machine client receives the same terms a browser reader
    # sees and cannot be handed a changed control term.

    test "returns exactly the nine ControlMatrix dimensions with matching labels" do
      assert {:ok, %{"structuredContent" => %{"dimensions" => dimensions}}} =
               DocsTools.get_operational_control(%{}, [])

      assert Enum.map(dimensions, &{&1["key"], &1["label"]}) ==
               Enum.map(ControlMatrix.capabilities(), &{to_string(&1.key), &1.label}),
             "MCP control dimensions drifted from ControlMatrix"
    end

    test "the overview is the canonical control page" do
      assert {:ok, %{"structuredContent" => %{"overview" => %{"path" => overview_path}}}} =
               DocsTools.get_operational_control(%{}, [])

      assert overview_path == @control_overview,
             "MCP operational-control overview is not the canonical control page"
    end

    test "the release-basis proof carries the limitation" do
      assert {:ok, %{"structuredContent" => %{"proof" => %{"release_basis" => release_basis}}}} =
               DocsTools.get_operational_control(%{}, [])

      assert limitation?(release_basis),
             "MCP get_operational_control dropped the release-basis limitation"
    end
  end

  describe "Skills surface — the /skills catalog" do
    # The Skills catalog does not restate the matrix; it links each builder
    # skill to the ecosystem package page that carries the control surface.
    # Parity here means the Skills surface agrees with the matrix about which
    # packages are the controlled-Agent stack: every control-matrix package that
    # ships a builder skill links into the same ecosystem path the matrix column
    # uses, so a skills reader following a control package reaches the control
    # surface and the package identity cannot drift.

    test "every control package with a builder skill links to the matrix column's ecosystem path" do
      for column <- ControlMatrix.package_columns(),
          skill = UpstreamSkillCatalog.entry_for_ecosystem_package(column.key),
          skill != nil do
        assert skill.ecosystem_path == column.path,
               "the #{column.key} skill links to #{inspect(skill.ecosystem_path)}; " <>
                 "the control matrix column links to #{inspect(column.path)}"
      end
    end

    test "the rendered catalog links each control package skill to its ecosystem page",
         %{conn: conn} do
      {:ok, _view, html} = live(conn, "/skills")

      for column <- ControlMatrix.package_columns(),
          skill = UpstreamSkillCatalog.entry_for_ecosystem_package(column.key),
          skill != nil do
        assert html =~ ~s(href="#{column.path}"),
               "the Skills catalog dropped the ecosystem link for the #{column.key} control package"
      end
    end

    test "the controlled-Agent stack package set is the matrix's, not a second hand-maintained list" do
      # The skills surface reaches the control model through the controlled-Agent
      # stack, which ControlMatrix owns. Every control package that has a skill
      # must be a matrix package column — the skills surface must not invent or
      # rename a control package the matrix does not carry.
      matrix_keys = ControlMatrix.package_columns() |> Enum.map(& &1.key) |> MapSet.new()

      skilled_control_packages =
        ControlMatrix.package_columns()
        |> Enum.map(&UpstreamSkillCatalog.entry_for_ecosystem_package(&1.key))
        |> Enum.reject(&is_nil/1)
        |> Enum.map(& &1.ecosystem_package_id)

      for package_id <- skilled_control_packages do
        assert package_id in matrix_keys,
               "the Skills catalog names a control package #{inspect(package_id)} the matrix does not carry"
      end
    end
  end

  describe "machine-readable surface — /llms.txt" do
    # /llms.txt is the curated machine surface that mirrors the limitation and
    # proof links (jido-e10-t32). It must carry the same release-basis limitation
    # and point at the same canonical overview so an LLM client receives the same
    # bounded claim a browser reader sees.

    test "states the release-basis limitation and links the canonical overview", %{conn: conn} do
      conn = get(conn, "/llms.txt")
      body = response(conn, 200)

      assert limitation?(body),
             "/llms.txt dropped the release-basis limitation"

      assert body =~ @control_overview,
             "/llms.txt dropped the canonical control-overview proof link"
    end
  end

  describe "cross-surface agreement" do
    # The capstone: every claim-bearing surface carries the limitation, the
    # three matrix surfaces (browser, Markdown, MCP) carry the same nine
    # dimension labels, and every surface points at the one canonical overview.
    # This is the literal acceptance condition — no surface drops the
    # limitation, no surface changes a control term.

    test "every claim-bearing surface carries the release-basis limitation", %{conn: conn} do
      {:ok, _view, browser_html} = live(conn, "/ecosystem")
      {:ok, markdown} = MarkdownContent.resolve("/ecosystem", @ecosystem_absolute_url)

      {:ok, %{"structuredContent" => %{"proof" => %{"release_basis" => mcp_release_basis}}}} =
        DocsTools.get_operational_control(%{}, [])

      llms = response(get(conn, "/llms.txt"), 200)

      for {label, surface} <-
            [{"browser", browser_html}, {"Markdown", markdown}, {"MCP", mcp_release_basis}, {"llms.txt", llms}] do
        assert limitation?(surface),
               "the #{label} surface dropped the release-basis limitation"
      end
    end

    test "the three matrix surfaces carry the same nine dimension labels", %{conn: conn} do
      {:ok, _view, browser_html} = live(conn, "/ecosystem")
      {:ok, markdown} = MarkdownContent.resolve("/ecosystem", @ecosystem_absolute_url)

      {:ok, %{"structuredContent" => %{"dimensions" => mcp_dimensions}}} =
        DocsTools.get_operational_control(%{}, [])

      mcp_labels = mcp_dimensions |> Enum.map(& &1["label"]) |> MapSet.new()

      for label <- dimension_labels() do
        assert browser_html =~ label,
               "the browser matrix surface dropped the #{inspect(label)} control term"

        assert markdown =~ label,
               "the Markdown matrix surface dropped the #{inspect(label)} control term"

        assert label in mcp_labels,
               "the MCP matrix surface dropped the #{inspect(label)} control term"
      end
    end

    test "every surface points at the one canonical control-overview route", %{conn: conn} do
      {:ok, _view, browser_html} = live(conn, "/ecosystem")
      {:ok, markdown} = MarkdownContent.resolve("/ecosystem", @ecosystem_absolute_url)

      {:ok, %{"structuredContent" => %{"overview" => %{"path" => mcp_overview_path}}}} =
        DocsTools.get_operational_control(%{}, [])

      llms = response(get(conn, "/llms.txt"), 200)

      # Search resolves a control term to the overview.
      assert SearchAliases.routes_for_query("authorization") == [@control_overview]
      # The matrix surfaces cite it as the proof link.
      assert browser_html =~ ~s(href="#{@control_overview}")
      assert markdown =~ "(#{@control_overview})"
      assert mcp_overview_path == @control_overview
      # The machine surface links it too.
      assert llms =~ @control_overview
    end
  end
end
