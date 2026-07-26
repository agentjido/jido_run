defmodule AgentJidoWeb.MarkdownContentTest do
  use ExUnit.Case, async: true

  alias AgentJidoWeb.MarkdownContent

  describe "release placeholder expansion in markdown delivery (E01-T08, E01-T11)" do
    test "the first-LLM agent markdown payload has no unresolved placeholders" do
      {:ok, markdown} =
        MarkdownContent.resolve(
          "/docs/getting-started/first-llm-agent",
          "https://jido.run/docs/getting-started/first-llm-agent"
        )

      refute markdown =~ ~r/\{\{/,
             "public markdown must not contain unresolved {{...}} placeholders"

      # The expanded payload carries real dependency requirements, not tokens.
      assert markdown =~ "{:jido,"
      assert markdown =~ "{:jido_ai,"
    end
  end

  describe "compare markdown delivery (E10-T10)" do
    test "compare detail pages and the hub resolve to markdown" do
      assert {:ok, _} =
               MarkdownContent.resolve(
                 "/compare/semantic-kernel",
                 "https://jido.run/compare/semantic-kernel"
               )

      assert {:ok, _} =
               MarkdownContent.resolve("/compare", "https://jido.run/compare")
    end
  end

  describe "skills markdown delivery (E10-T09)" do
    test "the skills hub resolves to markdown (the .md route promised by llms.txt)" do
      assert {:ok, markdown} =
               MarkdownContent.resolve("/skills", "https://jido.run/skills")

      assert markdown =~ "Skills"
    end
  end

  describe "build and compare hub markdown equivalents (E06-T23)" do
    # The Build and Compare hubs must serve a full Markdown equivalent
    # generated from the same content records as the rendered browser hub —
    # not the raw index.md source (which leaked its `%{...}` frontmatter) and
    # not a short fallback stub.
    @hub_categories [:build, :compare]

    test "the build and compare hubs resolve to generated markdown, not fallbacks" do
      for category <- @hub_categories do
        path = "/#{category}"

        assert {:ok, markdown} = MarkdownContent.resolve(path, "https://jido.run#{path}")

        # Generated from content records, not a rendered-route fallback.
        refute String.contains?(
                 markdown,
                 "generated from the rendered route when direct source markdown is not available"
               ),
               "#{path} markdown is a fallback stub"

        assert String.contains?(
                 markdown,
                 "generated from the same content records as the rendered"
               ),
               "#{path} markdown is not generated from content records"
      end
    end

    test "the build and compare hub markdown does not leak source frontmatter" do
      for category <- @hub_categories do
        path = "/#{category}"
        {:ok, markdown} = MarkdownContent.resolve(path, "https://jido.run#{path}")

        refute String.starts_with?(markdown, "%{"),
               "#{path} markdown leaks the Elixir frontmatter map"
      end
    end

    test "the build and compare hub markdown lists every leaf page in the category" do
      for category <- @hub_categories do
        path = "/#{category}"
        {:ok, markdown} = MarkdownContent.resolve(path, "https://jido.run#{path}")

        leaf_pages =
          AgentJido.Pages.pages_by_category(category)
          |> Enum.reject(&(&1.path == path))

        assert leaf_pages != [], "#{path} category has no leaf pages to assert against"

        for page <- leaf_pages do
          route = AgentJido.Pages.route_for(page)

          assert String.contains?(markdown, "[#{page.title}](#{route})"),
                 "#{path} markdown is missing leaf page: #{inspect("[#{page.title}](#{route})")}"
        end
      end
    end
  end

  describe "docs hub markdown inventory (E06-T22)" do
    # The browser hub (`/docs`) and the Markdown hub (`/docs.md`) must list the
    # same inventory, both generated from the Pages content records.
    test "the docs hub markdown is generated from the same content records as the browser hub" do
      assert {:ok, markdown} = MarkdownContent.resolve("/docs", "https://jido.run/docs")

      # Generated payload, not a fallback stub and not the hand-written index body.
      refute String.contains?(
               markdown,
               "generated from the rendered route when direct source markdown is not available"
             )

      assert String.contains?(markdown, "generated from the same content records as the rendered Docs hub")

      for section_page <- AgentJido.Pages.docs_sections() do
        section = AgentJido.Pages.docs_section_for_path(AgentJido.Pages.route_for(section_page))

        section_pages =
          if section,
            do:
              section
              |> AgentJido.Pages.docs_section_pages()
              |> Enum.reject(&(&1.path == section_page.path)),
            else: []

        count = length(section_pages)
        label = Map.get(section_page, :menu_label) || section_page.title
        route = AgentJido.Pages.route_for(section_page)

        # The section header agrees with the browser card: same label, route,
        # and page count.
        expected_header =
          "**[#{label}](#{route})**" <>
            if(count > 0, do: " (#{count} pages)", else: "")

        assert String.contains?(markdown, expected_header),
               "docs hub markdown is missing section header: #{inspect(expected_header)}"

        # Every in-menu leaf page in the section is listed in the inventory.
        for page <- section_pages do
          page_label = Map.get(page, :menu_label) || page.title
          page_route = AgentJido.Pages.route_for(page)

          assert String.contains?(markdown, "[#{page_label}](#{page_route})"),
                 "docs hub markdown is missing leaf page: #{inspect("[#{page_label}](#{page_route})")}"
        end
      end
    end

    test "the docs hub markdown lists exactly the same section routes as the browser hub" do
      assert {:ok, markdown} = MarkdownContent.resolve("/docs", "https://jido.run/docs")

      markdown_section_routes =
        Regex.scan(~r"\*\*\[[^\]]+\]\((/docs/[^)]+)\)\*\*", markdown)
        |> Enum.map(fn [_, route] -> route end)
        |> Enum.uniq()
        |> Enum.sort()

      browser_section_routes =
        AgentJido.Pages.docs_sections()
        |> Enum.map(&AgentJido.Pages.route_for/1)
        |> Enum.uniq()
        |> Enum.sort()

      assert markdown_section_routes == browser_section_routes
    end
  end

  describe "docs hub markdown section order (jido-e10-t13)" do
    # The browser Docs hub (`/docs`) renders its section grid by iterating
    # Pages.docs_sections_filtered(:all) == Pages.docs_sections()/0 in list order
    # (page_live.ex assigns docs_sections). The Markdown hub maps the same
    # Pages.docs_sections()/0 in list order, so a machine reader and a browser
    # reader walk the Docs hub in the SAME section ORDER — not merely the same
    # set of sections.
    #
    # The backlog's literal six-section order (Start, Build, Operate, Reference,
    # Ecosystem, Contribute) is the E06-T01 IA restructure, deferred for this
    # iteration by an explicit product decision (current doc structure, URLs, and
    # paths kept unchanged). So "same section order" here means the current
    # docs_sections()/0 order shared by both surfaces. The E06-T22 test above
    # asserts set parity (sorted); this test asserts in-order parity so the order
    # cannot drift silently.

    test "the markdown hub lists docs sections in the same order as the browser hub" do
      assert {:ok, markdown} = MarkdownContent.resolve("/docs", "https://jido.run/docs")

      # Section headers are the only `**[label](route)**` lines; child links are
      # plain `[label](route)`, so this scan captures the section sequence in
      # document order (not sorted).
      markdown_section_routes =
        Regex.scan(~r"\*\*\[[^\]]+\]\((/docs/[^)]+)\)\*\*", markdown)
        |> Enum.map(fn [_, route] -> route end)
        |> Enum.uniq()

      browser_section_routes =
        AgentJido.Pages.docs_sections()
        |> Enum.map(&AgentJido.Pages.route_for/1)

      assert markdown_section_routes == browser_section_routes,
             "docs hub markdown section order drifted from the browser hub"
    end

    test "the markdown hub follows docs_sections()/0 adoption order, not alphabetical" do
      # Guard against a regression that sorts the inventory alphabetically (which
      # would still pass the set-parity test above but break the in-order
      # agreement with the browser hub). The current docs_sections()/0 order is
      # adoption order, which is not alphabetical.
      assert {:ok, markdown} = MarkdownContent.resolve("/docs", "https://jido.run/docs")

      markdown_section_routes =
        Regex.scan(~r"\*\*\[[^\]]+\]\((/docs/[^)]+)\)\*\*", markdown)
        |> Enum.map(fn [_, route] -> route end)
        |> Enum.uniq()

      refute markdown_section_routes == Enum.sort(markdown_section_routes),
             "docs hub markdown sections are alphabetical; " <>
               "they must follow docs_sections()/0 adoption order to match the browser hub"
    end
  end

  describe "hub status labels (jido-e06-t24)" do
    # Acceptance: "Draft or Experimental content cannot look complete." A status
    # tag must only appear when a page is draft or experimental. Today every
    # public page is published, so the generated hubs must carry no false tags —
    # the positive (Draft)/(Experimental) tagging path is covered by the shared
    # Pages.content_status_label/1 unit tests, which both the browser and
    # Markdown hubs call.

    @status_tag ~r/\((Draft|Experimental)\)/

    test "the docs hub markdown adds no status tags for published content" do
      {:ok, markdown} = MarkdownContent.resolve("/docs", "https://jido.run/docs")

      refute Regex.match?(@status_tag, markdown),
             "published docs hub content must not carry a draft/experimental tag"
    end

    test "the build and compare hub markdown add no status tags for published content" do
      for path <- ["/build", "/compare"] do
        {:ok, markdown} = MarkdownContent.resolve(path, "https://jido.run#{path}")

        refute Regex.match?(@status_tag, markdown),
               "published #{path} hub content must not carry a draft/experimental tag"
      end
    end

    # Contract for the shared helper both hubs call: draft/experimental content
    # must yield a visible label (so it cannot look complete); published yields
    # none. Kept here (non-flaky) so the positive path runs in the default suite.
    test "Pages.content_status_label/1 labels draft and experimental content" do
      alias AgentJido.Pages.Page

      draft = %Page{id: "d", path: "/docs/d", title: "D", category: :docs, status: :draft}
      experimental = %Page{id: "e", path: "/docs/e", title: "E", category: :docs, status: :experimental}
      published = %Page{id: "p", path: "/docs/p", title: "P", category: :docs}

      assert AgentJido.Pages.content_status_label(draft) == "Draft"
      assert AgentJido.Pages.content_status_label(experimental) == "Experimental"
      assert AgentJido.Pages.content_status_label(published) == nil
    end
  end

  describe "examples hub markdown inventory (jido-e10-t11)" do
    # The browser hub (`/examples`) and the Markdown hub (`/examples.md`) must
    # list the same inventory, both generated from the live Example records, and
    # every entry must carry the task, outcome, packages, maturity, and URL the
    # machine-readable delivery needs.
    @absolute_url "https://jido.run/examples"

    test "the examples hub markdown is generated, not a fallback stub" do
      assert {:ok, markdown} = MarkdownContent.resolve("/examples", @absolute_url)

      refute String.contains?(
               markdown,
               "generated from the rendered route when direct source markdown is not available"
             ),
             "examples hub markdown is a fallback stub"

      assert String.contains?(
               markdown,
               "generated from the same content records as the rendered Examples hub"
             )
    end

    test "every live example appears with its route and absolute URL" do
      assert {:ok, markdown} = MarkdownContent.resolve("/examples", @absolute_url)

      for example <- AgentJido.Examples.all_examples() do
        route = "/examples/#{example.slug}"
        url = "https://jido.run/examples/#{example.slug}"

        assert String.contains?(markdown, "(#{route})"),
               "examples hub markdown is missing link for #{inspect(example.slug)}"

        assert String.contains?(markdown, "URL: #{url}"),
               "examples hub markdown is missing absolute URL for #{inspect(example.slug)}"
      end
    end

    test "each entry includes task, outcome, packages, maturity, and URL labels" do
      assert {:ok, markdown} = MarkdownContent.resolve("/examples", @absolute_url)

      # The five required inventory fields are explicitly labeled per entry.
      for label <- ~w(Task Outcome Packages Maturity URL) do
        assert String.contains?(markdown, "#{label}:"),
               "examples hub markdown is missing the #{label} field label"
      end

      # Spot-check one canonical entry carries all five fields together.
      counter_block = """
        - Task: #{AgentJido.Examples.get_example!("counter-agent").description}
        - Outcome: #{AgentJido.Examples.get_example!("counter-agent").outcome}
        - Packages: jido
        - Maturity: Beta
        - URL: https://jido.run/examples/counter-agent\
      """

      assert String.contains?(markdown, counter_block),
             "examples hub markdown counter-agent entry is missing required fields"
    end

    test "the markdown inventory matches the browser hub's live example set" do
      assert {:ok, markdown} = MarkdownContent.resolve("/examples", @absolute_url)

      markdown_routes =
        Regex.scan(~r"\(/examples/([a-z0-9-]+)\)", markdown)
        |> Enum.map(fn [_, slug] -> slug end)
        |> Enum.uniq()
        |> Enum.sort()

      browser_slugs =
        AgentJido.Examples.all_examples() |> Enum.map(& &1.slug) |> Enum.uniq() |> Enum.sort()

      assert markdown_routes == browser_slugs,
             "examples hub markdown inventory drifted from the browser hub's live examples"
    end
  end

  describe "ecosystem hub markdown inventory (jido-e10-t12)" do
    # The browser hub (`/ecosystem`) and the Markdown hub (`/ecosystem.md`) must
    # agree, both generated from the public package registry. The Markdown hub
    # must carry the recommended starting stacks (with each package's explicit
    # supported range, source, and support level) and a full package inventory
    # with each package's external links.
    @absolute_url "https://jido.run/ecosystem"

    test "the ecosystem hub markdown is generated, not a fallback stub" do
      assert {:ok, markdown} = MarkdownContent.resolve("/ecosystem", @absolute_url)

      refute String.contains?(
               markdown,
               "generated from the rendered route when direct source markdown is not available"
             ),
             "ecosystem hub markdown is a fallback stub"

      assert String.contains?(
               markdown,
               "generated from the same content records as the rendered Ecosystem hub"
             )
    end

    test "the recommended stacks list every stack package with its range, source, and support level" do
      assert {:ok, markdown} = MarkdownContent.resolve("/ecosystem", @absolute_url)

      for heading <- ["### Core", "### AI", "### Operate"] do
        assert String.contains?(markdown, heading),
               "ecosystem markdown is missing recommended-stack heading #{heading}"
      end

      for stack <- AgentJido.Ecosystem.Stacks.matrix(), pkg <- stack.packages do
        assert String.contains?(markdown, "[#{pkg.name}](#{pkg.path})"),
               "ecosystem markdown is missing recommended-stack link for #{pkg.name}"

        expected_range = if pkg.range in [nil, ""], do: "Not specified", else: pkg.range

        assert String.contains?(markdown, "Range: #{expected_range}"),
               "ecosystem markdown is missing supported range for #{pkg.name}"

        assert String.contains?(markdown, "Source: #{pkg.source_label}"),
               "ecosystem markdown is missing source for #{pkg.name}"
      end
    end

    test "every public package appears with its route, absolute URL, and full link set" do
      assert {:ok, markdown} = MarkdownContent.resolve("/ecosystem", @absolute_url)

      for pkg <- AgentJido.Ecosystem.public_packages() do
        route = "/ecosystem/#{pkg.id}"
        url = "https://jido.run/ecosystem/#{pkg.id}"

        assert String.contains?(markdown, "(#{route})"),
               "ecosystem markdown is missing link for #{inspect(pkg.id)}"

        assert String.contains?(markdown, "URL: #{url}"),
               "ecosystem markdown is missing absolute URL for #{inspect(pkg.id)}"

        # Each external link the package carries must appear in full — these are
        # the "full package links" the machine-readable delivery needs.
        for {label, value} <-
              [{"HexDocs", pkg.hexdocs_url}, {"Hex.pm", pkg.hex_url}, {"GitHub", pkg.github_url}],
            value not in [nil, ""] do
          assert String.contains?(markdown, "#{label}: #{value}"),
                 "ecosystem markdown is missing #{label} link for #{inspect(pkg.id)}"
        end
      end
    end

    test "the markdown inventory matches the browser hub's public package set" do
      assert {:ok, markdown} = MarkdownContent.resolve("/ecosystem", @absolute_url)

      markdown_ids =
        Regex.scan(~r"\(/ecosystem/([^)]+)\)", markdown)
        |> Enum.map(fn [_, id] -> id end)
        |> Enum.uniq()
        |> Enum.sort()

      browser_ids =
        AgentJido.Ecosystem.public_packages() |> Enum.map(& &1.id) |> Enum.uniq() |> Enum.sort()

      assert markdown_ids == browser_ids,
             "ecosystem hub markdown inventory drifted from the browser hub's public packages"
    end
  end

  describe "ecosystem hub markdown operational-control matrix (jido-e10-t29)" do
    # Acceptance: "Machine clients receive the same qualified control claims as
    # browser clients." The browser Ecosystem hub renders an OPERATIONAL CONTROL
    # matrix — nine capabilities x control packages + host, each cell carrying a
    # boundary role and a grounding clause, a legend, and a release-basis proof
    # link. The Markdown hub must carry the same control types, boundaries,
    # limitations, and proof links so the machine surface agrees with the
    # browser surface.
    alias AgentJido.Ecosystem.ControlMatrix
    @absolute_url "https://jido.run/ecosystem"

    test "the ecosystem hub markdown carries the operational-control section" do
      assert {:ok, markdown} = MarkdownContent.resolve("/ecosystem", @absolute_url)

      assert String.contains?(markdown, "## Operational control"),
             "ecosystem markdown is missing the Operational control section"
    end

    test "every control capability and its description appears" do
      assert {:ok, markdown} = MarkdownContent.resolve("/ecosystem", @absolute_url)

      for capability <- ControlMatrix.capabilities() do
        assert String.contains?(markdown, "### #{capability.label}"),
               "ecosystem markdown is missing the #{capability.key} capability heading"

        assert String.contains?(markdown, capability.description),
               "ecosystem markdown is missing the #{capability.key} capability description"
      end
    end

    test "every matrix cell carries its boundary role and grounding clause" do
      assert {:ok, markdown} = MarkdownContent.resolve("/ecosystem", @absolute_url)
      matrix = ControlMatrix.matrix()
      columns = ControlMatrix.columns()

      for row <- matrix, column <- columns do
        cell = Map.fetch!(row.cells, column.key)
        role_label = ControlMatrix.role_label(cell.role)

        # The boundary role label and the grounding clause both appear, so a
        # machine reader sees the same qualified claim the browser cell draws.
        assert String.contains?(markdown, "#{role_label}:"),
               "ecosystem markdown is missing the #{role_label} role for #{row.key}/#{column.key}"

        assert String.contains?(markdown, cell.text),
               "ecosystem markdown is missing the #{row.key}/#{column.key} cell clause"
      end
    end

    test "package columns link to their package page; the host column carries no link" do
      assert {:ok, markdown} = MarkdownContent.resolve("/ecosystem", @absolute_url)

      for column <- ControlMatrix.columns(), column.kind == :package do
        assert String.contains?(markdown, "[#{column.label}](#{column.path})"),
               "ecosystem markdown is missing the #{column.key} control column link"
      end

      # The host column is synthetic — it must appear as a plain bold label, not
      # a link, mirroring the browser table.
      refute String.contains?(markdown, "[Host application](/ecosystem/host)")
    end

    test "the legend and the release-basis proof link are present" do
      assert {:ok, markdown} = MarkdownContent.resolve("/ecosystem", @absolute_url)

      for role <- [:supplies, :preserves, :app] do
        label = ControlMatrix.role_label(role)

        assert String.contains?(markdown, "- **#{label}** —"),
               "ecosystem markdown is missing the #{label} legend line"
      end

      assert String.contains?(
               markdown,
               "[Security and governance](/docs/operations/security-and-governance)"
             ),
             "ecosystem markdown is missing the Security and governance proof link"
    end
  end
end
