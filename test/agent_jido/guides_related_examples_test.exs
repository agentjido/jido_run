defmodule AgentJido.GuidesRelatedExamplesTest do
  @moduledoc """
  E06-T27: every guide names its related examples so each guide has runnable
  proof next to the instructions.

  A guide teaches a pattern; an interactive example proves the pattern runs.
  The E06 backlog requires each guide to surface the published examples that
  prove it, with the role each plays in the guide and the example's one-line
  outcome, placed next to the instructions rather than at the end of the page.
  The Page schema (`lib/agent_jido/pages/page.ex`) exposes `related_examples`
  — a list of `%{id, role}` maps — and the docs shell resolves each `id` to its
  published interactive example so the role and the proof render together
  (E06-T27 acceptance: "Every major guide has runnable proof").

  This test enumerates every published guide — docs pages of
  `doc_type: :guide` in the `/docs/guides/` section — and asserts each one
  ships with a non-empty, well-formed `related_examples` whose ids resolve to
  real published examples, so no guide can be added without pointing at proof
  and no guide can name an example that is missing or still a draft.
  """
  use ExUnit.Case, async: true

  alias AgentJido.Examples
  alias AgentJido.Pages

  # A published guide is a docs page of doc_type :guide whose path lives under
  # /docs/guides/. Cookbooks are a distinct doc_type and are excluded.
  @guides Pages.all_pages()
          |> Enum.filter(fn page ->
            page.category == :docs and page.doc_type == :guide and
              String.starts_with?(page.path, "/docs/guides/")
          end)

  describe "every guide declares related examples (jido-e06-t27)" do
    test "there is at least one guide to check" do
      refute Enum.empty?(@guides),
             "expected at least one published guide (doc_type :guide under /docs/guides/) " <>
               "to be checked"
    end

    for page <- @guides do
      test "#{page.path} frontmatter carries a related_examples list" do
        source = unquote(Macro.escape(page)).source_path
        body = File.read!(source)

        assert body =~ ~r/related_examples:\s*\[/,
               "#{source} must declare a related_examples list of %{id, role} maps"
      end

      test "#{page.path} Page struct exposes a non-empty related_examples" do
        page = unquote(Macro.escape(page))
        examples = page.related_examples

        assert is_list(examples),
               "#{page.path} related_examples must be a list, got: #{inspect(examples)}"

        refute Enum.empty?(examples),
               "#{page.path} related_examples must be a non-empty list, " <>
                 "got: #{inspect(examples)}"

        for entry <- examples do
          assert is_map(entry),
                 "#{page.path} each related_examples entry must be a map, got: #{inspect(entry)}"

          id = entry[:id]
          role = entry[:role]

          assert is_binary(id) and id != "",
                 "#{page.path} each related_examples entry needs a non-empty :id, " <>
                   "got: #{inspect(entry)}"

          assert is_binary(role) and String.trim(role) != "",
                 "#{page.path} related_examples[#{id}] needs a non-empty :role describing " <>
                   "what the example proves in this guide, got: #{inspect(role)}"
        end
      end

      test "#{page.path} related_examples ids resolve to published examples" do
        page = unquote(Macro.escape(page))

        for entry <- page.related_examples do
          example = Examples.get_example(entry[:id])

          assert example != nil,
                 "#{page.path} related_examples[#{entry[:id]}] must be a published example slug " <>
                   "(a priv/examples/*.md file with status: :live); drafts and missing slugs do not resolve"

          # The outcome is the one-line "what this example proves" the docs shell
          # surfaces next to the instructions; an example with no outcome would
          # render a bare link with no proof, which fails the acceptance condition.
          assert is_binary(example.outcome) and String.trim(example.outcome) != "",
                 "#{page.path} related_examples[#{entry[:id]}] must resolve to an example with a " <>
                   "non-empty outcome so its proof renders next to the role"
        end
      end
    end
  end
end
