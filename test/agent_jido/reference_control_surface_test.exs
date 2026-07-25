defmodule AgentJido.ReferenceControlSurfaceTest do
  @moduledoc """
  E06-T32: every relevant reference page carries a control-surface table.

  The E06 backlog requires each reference page for a control-bearing primitive
  to name, in one table, the control points it supplies. The acceptance
  condition is exact: *each table names the hook, input, decision, output,
  failure behavior, and evidence* (source: Jido Site Improvement Backlog
  2026-07-23.md, row E06-T32). A reference page that omits any of the six
  columns leaves an evaluator unable to see where Jido supplies a control point,
  what it decides, how it fails, and what evidence remains — the same
  operational-control lens the [Security and governance] page and the
  control-surface inventory (`specs/audits/control-inventory-2026-07-23.md`)
  draw in full.

  The six targets are the primitives named in the task: Agent, Action, Signal,
  Plugin, AI, and Observe. Their canonical reference pages are enumerated below;
  this test asserts each one carries a `## Control surface` section whose table
  header row names all six columns, so no target page can be added or edited
  without drawing the table. The authoring templates are checked too, so new
  concept and reference pages cannot be written or generated without the block.
  """

  use ExUnit.Case, async: true

  # The six control-bearing primitives and their canonical reference pages.
  # Each entry is {label, path relative to the repo root}.
  @target_pages [
    {"Agent", "priv/pages/docs/concepts/agents.md"},
    {"Action", "priv/pages/docs/concepts/actions.md"},
    {"Signal", "priv/pages/docs/concepts/signals.md"},
    {"Plugin", "priv/pages/docs/concepts/plugins.md"},
    {"AI", "priv/pages/docs/reference/req-llm-and-llmdb.md"},
    {"Observe", "priv/pages/docs/reference/telemetry-and-observability.md"}
  ]

  # The authoring templates that carry the block, so generated/hand-written
  # pages inherit it. Paths relative to the repo root.
  @templates [
    "specs/templates/docs-concept.md",
    "specs/templates/docs-reference.md",
    "priv/prompts/content_gen/templates/docs-concept.md",
    "priv/prompts/content_gen/templates/docs-reference.md"
  ]

  # The six columns the acceptance condition requires, matched on the table
  # header row. Case-insensitive so authors can phrase casing naturally while
  # the structure is enforced.
  @columns [
    {"hook", ~r/\bhook\b/i},
    {"input", ~r/\binput\b/i},
    {"decision", ~r/\bdecision\b/i},
    {"output", ~r/\boutput\b/i},
    {"failure behavior", ~r/failure[[:space:]]+behavior/i},
    {"evidence", ~r/\bevidence\b/i}
  ]

  # A `## Control surface` section: the heading and its body up to the next
  # `##` heading (or end of document).
  @section_re ~r/^##[[:space:]]+Control surface\b.*?(?=^##[[:space:]]|\z)/ims

  describe "the authoring templates carry a control-surface table (jido-e06-t32)" do
    for path <- @templates do
      test "#{path} names all six columns" do
        path = unquote(path)
        body = File.read!(repo_path(path))
        section = section(body)

        assert section != nil,
               "#{path} must include a `## Control surface` block"

        header = table_header(section)

        assert header != nil,
               "#{path} Control surface block must contain a Markdown table " <>
                 "with a header row"

        for {name, re} <- @columns do
          assert Regex.match?(re, header),
                 "#{path} Control surface table header must name #{name} " <>
                   "(matching #{inspect(re.source)})"
        end
      end
    end
  end

  describe "every target reference page carries a control-surface table (jido-e06-t32)" do
    test "there is a target page for each of the six primitives" do
      labels = Enum.map(@target_pages, fn {label, _} -> label end) |> Enum.uniq()

      assert labels == ["Agent", "Action", "Signal", "Plugin", "AI", "Observe"],
             "expected the six named targets (Agent, Action, Signal, Plugin, AI, Observe)"
    end

    for {label, path} <- @target_pages do
      test "#{label} reference (#{path}) names hook, input, decision, output, failure behavior, and evidence" do
        {label, path} = unquote({label, path})
        body = File.read!(repo_path(path))
        section = section(body)

        assert section != nil,
               "#{path} must contain a `## Control surface` block naming the " <>
                 "hook, input, decision, output, failure behavior, and evidence"

        header = table_header(section)

        assert header != nil,
               "#{path} Control surface block must contain a Markdown table " <>
                 "with a header row"

        for {name, re} <- @columns do
          assert Regex.match?(re, header),
                 "#{path} (#{label}) Control surface table header must name #{name} " <>
                   "(matching #{inspect(re.source)})"
        end

        # A table with only a header is not a control surface. Require at least
        # one data row so the table actually names a control point.
        assert data_row_count(section) >= 1,
               "#{path} (#{label}) Control surface table must list at least one control point"
      end
    end
  end

  defp repo_path(relative) do
    Path.expand("../../" <> relative, __DIR__)
  end

  defp section(body) do
    case Regex.run(@section_re, body) do
      [section | _] -> section
      nil -> nil
    end
  end

  # The header row of the first Markdown table in the section: a `|`-row whose
  # next non-blank line is a separator row (`| --- | --- |`).
  defp table_header(section) do
    lines = String.split(section, "\n")

    lines
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.find_value(fn [row, next] ->
      if table_row?(row) and separator_row?(next), do: row, else: nil
    end)
  end

  defp data_row_count(section) do
    # Count the `|`-rows that follow the first separator row of the table. A
    # control-surface table with only a header names no control point, so at
    # least one data row is required.
    lines = String.split(section, "\n")

    {count, _} =
      Enum.reduce(lines, {0, false}, fn line, {count, past_sep?} ->
        cond do
          not past_sep? and separator_row?(line) -> {count, true}
          past_sep? and table_row?(line) -> {count + 1, true}
          past_sep? -> {count, false}
          true -> {count, past_sep?}
        end
      end)

    count
  end

  defp table_row?(line) do
    String.match?(line, ~r/^\s*\|/)
  end

  defp separator_row?(line) do
    String.match?(line, ~r/^\s*\|/) and
      String.match?(line, ~r/^[\s|:-]+$/) and
      String.match?(line, ~r/-/)
  end
end
