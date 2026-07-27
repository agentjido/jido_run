defmodule AgentJido.AtAGlanceOrderLintTest do
  @moduledoc """
  `At a glance` row-order gate (jido-e06-t20).

  Every Feature and Docs page that carries an `## At a glance` table must list
  its rows in the same order so a reader scanning the hub sees the same shape on
  every page:

      Best for → packages → maturity → proof → next action

  This is the content-hygiene rule from the E06 backlog ("Best for, packages,
  maturity, proof, and next action use the same order"). The gate parses each
  `At a glance` table, maps each recognized row label to one of the five slots
  above, and asserts the recognized rows appear in non-decreasing slot order.
  Rows whose labels are not part of the standard vocabulary (a leadership brief
  that frames the page differently, for example) are ignored, so the rule never
  forces a page to invent a row it does not need — it only forbids reordering
  the standard rows relative to each other.

  Scope: every page loaded by the Pages system under `:features` and `:docs`
  (including drafts) whose body contains an `## At a glance` table. Ecosystem
  package pages render their own `AT A GLANCE` cliff-notes block from a
  LiveView and are out of scope here.
  """
  use ExUnit.Case, async: true

  alias AgentJido.Pages

  @target_pages Pages.all_pages_including_drafts() |> Enum.filter(&(&1.category in [:features, :docs]))

  # Canonical slot order. A row is mapped to the FIRST slot whose accepted
  # labels match it, so a row can only belong to one slot. Labels are matched
  # case-insensitively after collapsing internal whitespace. Each accepted label
  # is a literal string (multi-word labels cannot use the `~w` sigil, which
  # splits on whitespace).
  @slots [
    {:best_for, ["best for"]},
    {:packages, ["core packages", "core runtime packages", "optional intelligence layer", "strategy add-ons", "supported providers"]},
    {:maturity, ["package status"]},
    {:proof, ["first proof path"]},
    {:next_action, ["key idea", "adoption stance"]}
  ]

  describe "every At a glance table lists standard rows in canonical order (jido-e06-t20)" do
    test "there is at least one feature or docs page to check" do
      assert length(@target_pages) > 0,
             "expected at least one feature or docs page to be checked"
    end

    for page <- @target_pages do
      test "#{page.path} At a glance rows follow Best for -> packages -> maturity -> proof -> next action" do
        page = unquote(Macro.escape(page))
        body = File.read!(page.source_path)

        rows = at_a_glance_rows(body)

        # Pages without an "At a glance" table are out of scope.
        slots =
          rows
          |> Enum.map(fn {label, _value} -> {label, slot_index(label)} end)
          |> Enum.reject(fn {_label, slot} -> is_nil(slot) end)

        indices = Enum.map(slots, fn {_label, slot} -> slot end)

        assert indices == Enum.sort(indices),
               "#{page.source_path} `At a glance` rows must follow the canonical order " <>
                 "Best for -> packages -> maturity -> proof -> next action " <>
                 "(jido-e06-t20), but the recognized rows are out of order: " <>
                 "#{format_slots(slots)}"
      end
    end

    # Positive control (jido-e06-t20): proves NEW ordering drift trips the gate.
    test "a packages row after a maturity row is flagged" do
      body = """
      ## At a glance

      | Item | Summary |
      |---|---|
      | Best for | Anyone |
      | Package status | `jido` (Beta) |
      | Core packages | [jido](/ecosystem/jido) |
      | First proof path | Run the example |
      | Key idea | Deterministic core |
      """

      slots =
        body
        |> at_a_glance_rows()
        |> Enum.map(fn {label, _} -> {label, slot_index(label)} end)
        |> Enum.reject(fn {_, slot} -> is_nil(slot) end)

      indices = Enum.map(slots, fn {_, slot} -> slot end)

      assert indices != Enum.sort(indices),
             "the gate must flag a packages row that appears after a maturity row"
    end

    # Negative control: the canonical order — including multiple consecutive
    # packages rows — must pass, and non-standard labels must not interfere.
    test "canonical order with grouped packages rows is not flagged" do
      body = """
      ## At a glance

      | Item | Summary |
      |---|---|
      | Best for | Anyone |
      | Core runtime packages | [jido](/ecosystem/jido) |
      | Optional intelligence layer | [jido_ai](/ecosystem/jido_ai) |
      | Package status | Core packages are Beta |
      | First proof path | Run the example |
      | Adoption stance | Start with one workflow |

      ## Body
      """

      slots =
        body
        |> at_a_glance_rows()
        |> Enum.map(fn {label, _} -> {label, slot_index(label)} end)
        |> Enum.reject(fn {_, slot} -> is_nil(slot) end)

      indices = Enum.map(slots, fn {_, slot} -> slot end)

      assert indices == Enum.sort(indices),
             "the gate must not flag a correctly ordered table: #{format_slots(slots)}"
    end
  end

  # The rows of the first `## At a glance` table as `{label, value}` tuples.
  # Returns `[]` when the page has no such table. Lines inside fenced code
  # blocks are skipped so a table-shaped block inside an example cannot
  # masquerade as the page's At a glance table.
  defp at_a_glance_rows(body) do
    body
    |> String.split("\n")
    |> annotate_fences()
    |> find_heading_index()
    |> case do
      nil -> []
      index -> collect_table(body |> String.split("\n") |> annotate_fences(), index)
    end
  end

  defp annotate_fences(lines) do
    lines
    |> Enum.reduce({false, []}, fn line, {in_fence?, acc} ->
      if String.match?(line, ~r/\A(```|~~~)/) do
        {not in_fence?, acc ++ [{line, not in_fence?}]}
      else
        {in_fence?, acc ++ [{line, in_fence?}]}
      end
    end)
    |> elem(1)
  end

  defp find_heading_index(annotated) do
    Enum.find_index(annotated, fn {line, in_fence?} ->
      not in_fence? and Regex.match?(~r/\A##[[:space:]]+at[[:space:]]+a[[:space:]]+glance\b/i, line)
    end)
  end

  # From the heading, scan forward to the first table (a line starting with
  # `|` outside a fence) and collect its contiguous `|`-prefixed rows.
  defp collect_table(annotated, heading_index) do
    annotated
    |> Enum.drop(heading_index + 1)
    |> Enum.reduce_while({:seeking, []}, fn
      {_line, true}, state ->
        # Inside a code fence — never part of the table.
        {:cont, state}

      {line, false}, {:seeking, rows} ->
        if table_row?(line) do
          {:cont, {:collecting, rows ++ [line]}}
        else
          {:cont, {:seeking, rows}}
        end

      {line, false}, {:collecting, rows} ->
        if table_row?(line) do
          {:cont, {:collecting, rows ++ [line]}}
        else
          {:halt, {:done, rows}}
        end
    end)
    |> finish_table()
  end

  defp finish_table({:done, rows}), do: parse_rows(rows)
  defp finish_table({:collecting, rows}), do: parse_rows(rows)
  defp finish_table({:seeking, _rows}), do: []

  defp table_row?(line), do: String.match?(line, ~r/\A\|/)

  defp parse_rows(lines) do
    lines
    |> Enum.map(&parse_row/1)
    |> Enum.reject(&match?({:skip, _}, &1))
    |> Enum.map(fn {:row, label, value} -> {label, value} end)
  end

  defp parse_row(line) do
    cells =
      line
      |> String.trim()
      |> String.trim("|")
      |> String.split("|", parts: 2)

    case cells do
      [label, value] ->
        normalized_label = normalize_label(label)

        cond do
          separator_row?(normalized_label) -> {:skip, :separator}
          normalized_label in ~w(item) -> {:skip, :header}
          true -> {:row, String.trim(label), String.trim(value)}
        end

      _other ->
        {:skip, :malformed}
    end
  end

  # A markdown table separator row (`|---|---|`) normalizes to dashes/colons.
  defp separator_row?(normalized), do: String.match?(normalized, ~r/\A:?-+:?\z/)

  defp normalize_label(label) do
    label |> String.downcase() |> String.replace(~r/\s+/, " ") |> String.trim()
  end

  defp slot_index(label) do
    normalized = normalize_label(label)

    @slots
    |> Enum.with_index(1)
    |> Enum.find_value(fn {{_name, accepted_labels}, idx} ->
      if normalized in accepted_labels, do: idx
    end)
  end

  defp format_slots(slots) do
    slots
    |> Enum.map(fn {label, idx} -> "#{label}(slot #{idx})" end)
    |> Enum.join(" -> ")
  end
end
