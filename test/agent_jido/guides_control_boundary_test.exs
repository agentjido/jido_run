defmodule AgentJido.GuidesControlBoundaryTest do
  @moduledoc """
  E06-T31: every guide draws the control boundary.

  The E06 backlog requires each guide to state, in one place, what Jido
  supplies, what an application must supply, and what evidence remains after
  execution — the same three-part boundary the [Security and governance]
  page draws in full. A guide that omits any of the three leaves an evaluator
  unable to tell where Jido ends and their application begins (E06 exit
  criteria: operational-control pages state Jido controls, application duties,
  limits, and proof).

  A control-boundary block is a `## Control boundary` section whose body
  carries all three statements. This test enumerates every published guide —
  docs pages of `doc_type: :guide` in the `/docs/guides/` section — and
  asserts each one carries all three statements inside that block, so no guide
  can be added or edited without drawing the boundary. Cookbooks are a distinct
  `doc_type` and are excluded. The authoring guide template is checked too, so
  new guides cannot be written or generated without the block.
  """
  use ExUnit.Case, async: true

  alias AgentJido.Pages

  @template_path Path.expand("../../specs/templates/build-guide.md", __DIR__)

  @guides Pages.all_pages()
          |> Enum.filter(&(&1.category == :docs and &1.doc_type == :guide))
          |> Enum.filter(fn page -> String.starts_with?(page.path, "/docs/guides/") end)

  # The three parts of the control boundary, matched loosely so authors can
  # phrase the surrounding sentence naturally while the structure is enforced.
  # Each maps to one clause of the E06-T31 acceptance condition.
  @boundary_parts [
    {"What Jido supplies", ~r/What Jido supplies/i},
    {"what an application must supply", ~r/application must supply/i},
    {"what evidence remains after execution", ~r/evidence remains after execution/i}
  ]

  # A `## Control boundary` section: the heading and its body up to the next
  # `##` heading (or end of document). Lines inside fenced code blocks are not
  # excluded because the boundary block is prose, but `##` inside a fence would
  # still start a new section per Markdown rendering, so stopping at the next
  # `^## ` is the correct boundary either way.
  @boundary_section_re ~r/^##[[:space:]]+Control boundary\b.*?(?=^##[[:space:]]|\z)/ims

  describe "the guide template carries a control-boundary block (jido-e06-t31)" do
    test "the authoring template states all three boundary parts" do
      template = File.read!(@template_path)
      section = control_boundary_section(template)

      assert section != nil,
             "specs/templates/build-guide.md must include a `## Control boundary` block"

      for {label, re} <- @boundary_parts do
        assert Regex.match?(re, section),
               "the guide template's Control boundary block must state #{label}, " <>
                 "matching #{inspect(re.source)}"
      end
    end
  end

  describe "every guide draws the control boundary (jido-e06-t31)" do
    test "there is at least one guide to check" do
      assert length(@guides) > 0,
             "expected at least one published guide (doc_type :guide under /docs/guides/) " <>
               "to be checked"
    end

    for page <- @guides do
      test "#{page.path} states what Jido supplies, what an application must supply, and what evidence remains" do
        page = unquote(Macro.escape(page))
        body = File.read!(page.source_path)

        section = control_boundary_section(body)

        assert section != nil,
               "#{page.source_path} must contain a `## Control boundary` block " <>
                 "stating what Jido supplies, what an application must supply, " <>
                 "and what evidence remains after execution"

        for {label, re} <- @boundary_parts do
          assert Regex.match?(re, section),
                 "#{page.source_path} Control boundary block must state #{label} " <>
                   "(matching #{inspect(re.source)})"
        end
      end
    end
  end

  defp control_boundary_section(body) do
    case Regex.run(@boundary_section_re, body) do
      [section | _] -> section
      nil -> nil
    end
  end
end
