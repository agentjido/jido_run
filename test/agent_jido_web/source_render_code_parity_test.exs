defmodule AgentJidoWeb.SourceRenderCodeParityTest do
  @moduledoc """
  jido-e12-t10 — source/render code parity for dependency code blocks.

  Acceptance condition: "HTML, Markdown, copied source, and Livebook code agree."

  A runnable docs page hands the same dependency declaration to four surfaces:
  the rendered HTML page, the public `.md` payload, the "Copy Markdown"
  clipboard text, and the `.livemd` source a reader opens in Livebook. The
  dependency tuples (`{:jido, "~> x.y"}`, …) must be identical across every one
  of them, and must equal what the single source of truth —
  `AgentJido.ReleaseCatalog` — declares. If a dependency or requirement changes
  in the registry, every surface follows or this gate fails; if one surface
  silently drops, renames, or hard-codes a dependency the others do not, this
  gate fails.

  The four surfaces reach the code through three independent code paths, which
  is exactly where drift hides:

    * HTML  — the `.livemd` source is expanded at compile time
      (`Pages.LivebookParser` → `Pages.ContentExpander` →
      `ReleaseCatalog.expand_placeholders/1`) and rendered to syntax-highlighted
      HTML by NimblePublisher + Makeup.
    * Markdown — `MarkdownContent` reads the same `.livemd` source at request
      time and expands it again with `ReleaseCatalog.expand_placeholders/1`.
    * Copied source — the "Copy Markdown" button's `data-copy-source-url` points
      at the `.md` route, so the clipboard text IS the Markdown payload above.
    * Livebook — the "Run in Livebook" link points at the page's `.livemd`
      source, the shared origin the other three render from.

  Expected tuples are derived from `ReleaseCatalog` (not hand-copied versions),
  so this gate tracks a registry bump instead of going stale beside it.

  Pairs with jido-e01-t09 (expanded-Livebook delivery): the served Livebook URL
  currently hands Livebook the raw `.livemd`, which still carries the
  `{{mix_dep:…}}` tokens unexpanded. The Livebook assertion here therefore
  locks the shared *origin* — the `.livemd` source, expanded with the same
  `ReleaseCatalog` the HTML and Markdown paths use, carries the identical
  tuples. Making the raw served URL expand before hand-off is the deferred
  jido-e01-t09 delivery change; this test is the gate that proves the source the
  other three surfaces agree on.
  """

  use AgentJidoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias AgentJido.Pages
  alias AgentJido.ReleaseCatalog
  alias AgentJidoWeb.MarkdownContent

  # A runnable onboarding page whose Mix.install block declares the three core
  # onboarding dependencies via `{{mix_dep:…}}` tokens, exposes a Copy Markdown
  # button (docs category), and links a Run-in-Livebook source.
  @page_route "/docs/getting-started/first-llm-agent"
  @page_source "priv/pages/docs/getting-started/first-llm-agent.livemd"
  @absolute_url "https://jido.run#{@page_route}"

  # The dependency package ids this page declares. These are stable content
  # identifiers (package names), not versions — the versions are read from the
  # registry so a bump cannot silently pass this gate.
  @declared_packages [:jido, :jido_ai, :req_llm]

  # Matches a Mix dependency tuple `{:pkg, "~> x.y"}` and captures the package id
  # and requirement. The `\s*` tolerates Makeup's whitespace handling after tag
  # stripping, and the required quoted string avoids matching unrelated tuples
  # like `{:ok, result}` or `{:error, reason}`.
  @dep_tuple_pattern ~r/\{:([a-z0-9_]+),\s*"([^"]+)"\}/

  # The declared package ids as binaries — ReleaseCatalog keys on strings.
  defp declared_package_ids, do: Enum.map(@declared_packages, &Atom.to_string/1)

  # The dependency tuples every surface must carry, straight from the registry.
  defp expected_tuples do
    MapSet.new(declared_package_ids(), fn id -> {id, ReleaseCatalog.requirement(id)} end)
  end

  # Recovers the plain code text from a rendered HTML page: concatenate every
  # `<pre><code>` block, strip the Makeup `<span>` highlighting, and unescape
  # HTML entities so `&quot;`/`&gt;` round-trip back to the source characters.
  defp html_code_text(html) do
    html
    |> extract_pre_blocks()
    |> Enum.map_join("\n", &strip_tags/1)
    |> unescape_entities()
  end

  defp extract_pre_blocks(html) do
    Regex.scan(~r/<pre[^>]*>(.*?)<\/pre>/s, html, capture: :all_but_first)
    |> List.flatten()
  end

  defp strip_tags(text), do: Regex.replace(~r/<[^>]+>/, text, "")

  defp unescape_entities(text) do
    text
    |> String.replace("&quot;", "\"")
    |> String.replace("&gt;", ">")
    |> String.replace("&lt;", "<")
    |> String.replace("&amp;", "&")
  end

  # Extracts every dependency tuple a surface carries, as a MapSet of
  # `{package_id, requirement}` (string keys, matching ReleaseCatalog).
  defp dependency_tuples(text) do
    @dep_tuple_pattern
    |> Regex.scan(text, capture: :all_but_first)
    |> Enum.map(fn [id, req] -> {id, req} end)
    |> MapSet.new()
  end

  # The dependency tuples a surface carries, restricted to this page's declared
  # packages — the meaningful comparison ("the declared dependencies agree").
  defp declared_tuples(text) do
    text
    |> dependency_tuples()
    |> MapSet.filter(fn {id, _req} -> id in declared_package_ids() end)
  end

  defp page do
    {:ok, page, _resolution} = Pages.resolve_page_for_path(@page_route)
    page
  end

  defp expanded_livebook_source do
    @page_source
    |> File.read!()
    # The same expansion the HTML and Markdown paths apply to this source.
    |> ReleaseCatalog.expand_placeholders()
  end

  describe "HTML surface — the rendered page" do
    # The browser page must show the same dependency tuples the registry
    # declares, expanded (no raw tokens leak into the rendered HTML).

    test "every declared dependency tuple appears in the rendered code blocks", %{conn: conn} do
      {:ok, _view, html} = live(conn, @page_route)
      code_text = html_code_text(html)
      tuples = dependency_tuples(code_text)

      # Whitespace-tolerant: Makeup collapses the space after the comma
      # (`{:jido,"~> x.y"}`), so compare the extracted {id, requirement} pairs
      # rather than a literal substring.
      for {id, req} <- expected_tuples() do
        assert {id, req} in tuples,
               "the rendered HTML dropped the #{id} dependency tuple " <>
                 "(expected #{inspect({id, req})})"
      end
    end

    test "the rendered HTML carries no unexpanded release tokens", %{conn: conn} do
      {:ok, _view, html} = live(conn, @page_route)

      refute html =~ "{{",
             "the rendered HTML leaked an unexpanded {{…}} release token"
    end
  end

  describe "Markdown surface — the .md payload" do
    # The public Markdown must carry the same expanded dependency tuples the
    # HTML shows, sourced from the registry.

    test "every declared dependency tuple appears in the markdown payload" do
      {:ok, markdown} = MarkdownContent.resolve(@page_route, @absolute_url)
      tuples = dependency_tuples(markdown)

      for {id, req} <- expected_tuples() do
        assert {id, req} in tuples,
               "the markdown payload dropped the #{id} dependency tuple " <>
                 "(expected #{inspect({id, req})})"
      end
    end

    test "the markdown payload carries no unexpanded release tokens" do
      {:ok, markdown} = MarkdownContent.resolve(@page_route, @absolute_url)

      refute markdown =~ "{{",
             "the markdown payload leaked an unexpanded {{…}} release token"
    end
  end

  describe "copied-source surface — the Copy Markdown button" do
    # "Copy Markdown" copies whatever the `data-copy-source-url` route returns.
    # Parity here means the button points at the page's own `.md` route, so the
    # clipboard text is the same expanded Markdown payload the Markdown surface
    # serves — the dependency tuples the reader copies match the page and the
    # Livebook. A drift to any other URL (or its removal) would let copied code
    # disagree with the page.

    test "the Copy Markdown button sources the page's own .md route", %{conn: conn} do
      {:ok, _view, html} = live(conn, @page_route)

      assert html =~ ~s(data-copy-source-url="#{@page_route}.md"),
             "the Copy Markdown button does not source the page's .md route, " <>
               "so copied source could drift from the rendered page"
    end

    test "the page exposes a Copy Markdown control", %{conn: conn} do
      {:ok, _view, html} = live(conn, @page_route)

      assert html =~ "Copy Markdown",
             "the docs page dropped the Copy Markdown control"
    end
  end

  describe "Livebook surface — the Run-in-Livebook source" do
    # The Run-in-Livebook link points at the page's `.livemd` source — the
    # single origin the HTML and Markdown surfaces render from. Parity here
    # means that source, expanded with the same `ReleaseCatalog` the other
    # surfaces use, carries the identical dependency tuples. (The raw served URL
    # does not expand tokens before hand-off yet — that delivery change is the
    # deferred jido-e01-t09; this gate locks the shared origin so the source
    # itself cannot drift from the rendered surfaces.)

    test "the Run-in-Livebook link points at the page's .livemd source", %{conn: conn} do
      {:ok, _view, html} = live(conn, @page_route)

      assert html =~ "Run in Livebook",
             "the docs page dropped the Run in Livebook link"

      livebook_url = Map.fetch!(page(), :livebook_url)

      assert livebook_url =~ "livebook.dev/run?url=",
             "the Run-in-Livebook URL is not a livebook.dev run link"

      assert String.ends_with?(URI.decode(livebook_url), @page_source),
             "the Run-in-Livebook URL does not point at the page's .livemd source"
    end

    test "the expanded .livemd source carries every declared dependency tuple" do
      source = expanded_livebook_source()
      tuples = dependency_tuples(source)

      for {id, req} <- expected_tuples() do
        assert {id, req} in tuples,
               "the expanded Livebook source dropped the #{id} dependency tuple " <>
                 "(expected #{inspect({id, req})})"
      end

      refute source =~ "{{",
             "the Livebook source expansion left an unresolved {{…}} token"
    end
  end

  describe "cross-surface code agreement" do
    # The capstone: the literal acceptance condition. The dependency tuples a
    # reader sees in the browser HTML, receives through Markdown (and therefore
    # through Copy Markdown), and runs in the Livebook source are the same set,
    # and that set is exactly what ReleaseCatalog declares. No surface can add,
    # drop, rename, or re-version a dependency without the others following.

    test "HTML, Markdown, and Livebook source carry the same declared dependency tuples",
         %{conn: conn} do
      {:ok, _view, html} = live(conn, @page_route)
      {:ok, markdown} = MarkdownContent.resolve(@page_route, @absolute_url)
      livebook_source = expanded_livebook_source()

      html_tuples = html |> html_code_text() |> declared_tuples()
      markdown_tuples = declared_tuples(markdown)
      livebook_tuples = declared_tuples(livebook_source)

      assert html_tuples == expected_tuples(),
             "the HTML dependency tuples drifted from ReleaseCatalog: " <>
               "#{inspect(MapSet.to_list(html_tuples))}"

      assert markdown_tuples == expected_tuples(),
             "the Markdown dependency tuples drifted from ReleaseCatalog: " <>
               "#{inspect(MapSet.to_list(markdown_tuples))}"

      assert livebook_tuples == expected_tuples(),
             "the Livebook source dependency tuples drifted from ReleaseCatalog: " <>
               "#{inspect(MapSet.to_list(livebook_tuples))}"

      # The three render surfaces agree with each other — copied source agrees
      # with Markdown by the Copy Markdown → .md contract locked above.
      assert html_tuples == markdown_tuples,
             "the HTML and Markdown dependency tuples disagree"

      assert markdown_tuples == livebook_tuples,
             "the Markdown and Livebook source dependency tuples disagree"
    end
  end
end
