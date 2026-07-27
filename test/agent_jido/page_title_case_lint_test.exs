defmodule AgentJido.PageTitleCaseLintTest do
  @moduledoc """
  Page title capitalization gate (jido-e06-t19).

  Every public page title must follow sentence case and the term rules in
  `specs/style-voice.md` (Terminology and Capitalization; Headings): only the
  first word, proper nouns, acronyms, and Jido-specific terms may be
  capitalized — every other word is lowercase. This gate turns a Title Case
  regression (e.g. "Health Checks and Readiness") into a blocking failure so
  capitalization drift cannot ship.

  Scope: every page loaded by the Pages system (`priv/pages/**`), including
  drafts. Ecosystem package display names and Example agent names live in their
  own content systems and are out of scope here.
  """
  use ExUnit.Case, async: true

  alias AgentJido.Pages

  # Proper nouns, brands, and product names that stay capitalized anywhere they
  # appear. Sourced from the term rules in specs/style-voice.md plus the brands
  # named on the public compare/features pages. When a new title introduces a
  # legitimate proper noun, add it here rather than lowercasing a real name.
  @proper_nouns MapSet.new(~w(
    Jido Jidoka Elixir Phoenix LiveView Livebook GenServer HexDocs
    ReqLLM LLMDB Ash Runic
    CrewAI AutoGen LangGraph LlamaIndex Mastra PydanticAI Pi Mono Semantic Kernel
    January February March April May June July August September October November December
  ))

  # Documented Jido-specific concepts (specs/style-voice.md, "Jido-Specific
  # Terms") that stay capitalized when they name the concept, even mid-title.
  @jido_terms MapSet.new(~w(
    Action Actions Agent Agents Signal Signals Directive Directives
    Sensor Sensors Plugin Plugins Strategy
  ))

  describe "page titles follow sentence case and term rules" do
    test "no page title capitalizes a word that should be lowercase" do
      offenders =
        for page <- Pages.all_pages_including_drafts(),
            offender <- title_case_offenders(page.title),
            do: {page.path, page.title, offender}

      assert offenders == [],
             "page titles must use sentence case (specs/style-voice.md): only the " <>
               "first word, proper nouns, acronyms, and Jido terms may be capitalized. " <>
               "Offenders: #{inspect(offenders, pretty: true)}"
    end

    # Positive control (jido-e06-t19): proves NEW Title Case drift trips the gate.
    test "newly introduced Title Case is flagged" do
      assert title_case_offenders("Health Checks and Readiness") != [],
             "the gate must block newly introduced Title Case titles"
    end

    # Negative control: legitimate sentence-case titles — including proper nouns,
    # acronyms, and Jido terms capitalized mid-title — must not be flagged.
    test "legitimate sentence-case titles are not flagged" do
      legit = [
        "Health checks and readiness",
        "Build with Jido",
        "How Jido agents work",
        "Agent fundamentals on the BEAM",
        "LiveView + Jido integration patterns",
        "Signals, routing, and agent communication",
        "Why not just a GenServer?",
        "Data storage and pgvector",
        "Jido ecosystem digest: January 2026",
        "Jido vs Semantic Kernel",
        "Your first LLM agent"
      ]

      for title <- legit do
        assert title_case_offenders(title) == [],
               "false positive on legitimate sentence-case title: #{inspect(title)}"
      end
    end
  end

  # A title offends when a word is capitalized that should not be: any word that
  # is not the first word of the title, not a proper noun, not an all-caps
  # acronym, and not a documented Jido-specific term. Hyphenated compounds are
  # checked segment by segment so "Mixed-Stack" regressions are caught.
  defp title_case_offenders(title) do
    title
    |> String.split(~r/\s+/, trim: true)
    |> Enum.with_index()
    |> Enum.flat_map(fn {token, token_idx} ->
      token
      |> String.split("-", trim: true)
      |> Enum.with_index()
      |> Enum.flat_map(fn {raw_segment, segment_idx} ->
        segment = clean_segment(raw_segment)

        cond do
          segment == "" ->
            []

          not String.match?(segment, ~r/^[A-Za-z]/) ->
            []

          token_idx == 0 and segment_idx == 0 ->
            []

          proper_noun?(segment) ->
            []

          acronym?(segment) ->
            []

          jido_term?(segment) ->
            []

          String.match?(segment, ~r/^[A-Z]/) ->
            ["#{segment} should be lowercase (or add to allowlist if it is a proper noun/acronym/Jido term)"]

          true ->
            []
        end
      end)
    end)
  end

  # Strip leading/trailing non-alphanumeric characters (punctuation such as the
  # trailing "?" in "Why not just a GenServer?" or the trailing comma after
  # "Signals,") while preserving internal characters like the period in "Jido.AI".
  defp clean_segment(segment) do
    segment
    |> String.replace(~r/^[^A-Za-z0-9]+/, "")
    |> String.replace(~r/[^A-Za-z0-9]+$/, "")
  end

  defp proper_noun?(segment), do: MapSet.member?(@proper_nouns, segment)
  defp jido_term?(segment), do: MapSet.member?(@jido_terms, segment)

  defp acronym?(segment) do
    byte_size(segment) >= 2 and String.match?(segment, ~r/^[A-Z][A-Z0-9]+$/)
  end
end
