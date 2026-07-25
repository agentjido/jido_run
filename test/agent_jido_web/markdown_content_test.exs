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
end
