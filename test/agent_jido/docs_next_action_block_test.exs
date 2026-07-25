defmodule AgentJido.DocsNextActionBlockTest do
  @moduledoc """
  E06-T14: no page ends without a next action.

  Every published docs page must end its body with a "What to do next" block —
  a Next steps / What to try next / What to do next / What's next section — so a
  reader always leaves with a concrete next action. This is the docs-template
  content-hygiene rule from the E06 backlog (see the E06 exit criteria: published
  pages have prerequisites, expected outcomes, versions, validation dates, and
  *next steps*).

  A next-action block is the page's LAST `##` section, matching the established
  convention across the docs (every getting-started, learn, and guide page
  already ends with `## Next steps`; the two chat-agent learn notebooks end with
  `## What to try next`). The accepted heading forms cover the variants already
  in use, so the rule does not force one phrasing on pages that already do the
  right thing under a different label.

  This test enumerates every published docs page and asserts its final `##`
  section is a next-action block, so no docs page can be added or edited without
  leaving the reader with a next action.
  """
  use ExUnit.Case, async: true

  alias AgentJido.Pages

  @docs_pages Pages.all_pages() |> Enum.filter(&(&1.category == :docs))

  # A `##` heading whose title tells the reader what to do next. Covers the
  # variants already in use across the docs:
  #   - "## Next steps" / "## Next Steps" (the canonical form)
  #   - "## What to try next" (the chat-agent learn notebooks)
  #   - "## What to do next"
  #   - "## What's next"
  @next_action_heading_re ~r/\A##[[:space:]]+(next[[:space:]]+steps?|what[[:space:]]+to[[:space:]]+(try|do)[[:space:]]+next|what's[[:space:]]+next)\b/i

  describe "every docs page ends with a next-action block (jido-e06-t14)" do
    test "there is at least one docs page to check" do
      assert length(@docs_pages) > 0,
             "expected at least one published docs page to be checked"
    end

    for page <- @docs_pages do
      test "#{page.path} ends with a Next steps / What to do next block" do
        page = unquote(Macro.escape(page))
        source = page.source_path
        body = File.read!(source)

        last_h2 = last_h2_heading(body)

        assert last_h2 != nil,
               "#{source} must contain at least one `##` section; the final " <>
                 "section should be a next-action block (e.g. `## Next steps`)"

        assert Regex.match?(@next_action_heading_re, last_h2),
               "#{source} must end with a next-action block " <>
                 "(e.g. `## Next steps`), but the last `##` section is: " <>
                 "#{inspect(String.trim(last_h2))}"
      end
    end
  end

  # The final `##`-level heading in the document body. Frontmatter is an Elixir
  # map (or an HTML-comment map for .livemd files) and never contains a `## `
  # line, so it is scanned safely. Lines inside fenced code blocks are skipped so
  # a `## ` inside example output cannot masquerade as a heading.
  defp last_h2_heading(body) do
    body
    |> String.split("\n")
    |> Enum.reduce({false, nil}, fn line, {in_fence?, last} ->
      cond do
        String.match?(line, ~r/\A(```|~~~)/) ->
          {not in_fence?, last}

        in_fence? ->
          {in_fence?, last}

        Regex.match?(~r/\A##[[:space:]]+/, line) ->
          {in_fence?, line}

        true ->
          {in_fence?, last}
      end
    end)
    |> elem(1)
  end
end
