defmodule AgentJido.ComparePageReviewSourcesTest do
  @moduledoc """
  Competitor-page review dates and sources (jido-e12-t19).

  Acceptance condition: "Old facts are visible and queued for review."

  The framework comparison pages (the `:compare` category) make specific
  factual claims about competitors — star counts, tool catalogs, provider
  support, failure handling. Two things keep those facts honest as competitors
  change:

    1. REVIEW DATE — every comparison carries a `last_validated` date naming
       when it was last checked. That date is what the rendered "Last reviewed"
       line shows a reader ("old facts ... visible") AND what the 180-day slow
       review queue (jido-e12-t16) measures against, so a stale comparison
       becomes assigned work instead of rotting unnoticed ("queued for review").
    2. SOURCES — every comparison names the external reference URLs (the
       competitor's repo and docs) its facts were checked against, rendered so a
       reader can re-verify any claim.

  A named reviewer (`owner`) attributes each comparison so a stale one has a
  person to ping when it lands on the queue — the same ownership model the
  executable gate (jido-e12-t14) uses for runnable notebooks, here applied to
  plain-Markdown comparisons the gate does not cover.

  This test locks all three (review date, reviewer, sources) on every competitor
  comparison page and proves a comparison whose review date goes stale lands on
  the slow review queue.
  """

  use ExUnit.Case, async: true

  alias AgentJido.Pages

  # Fixed "today" so the staleness window is deterministic. Mirrors the
  # slow_review_queue_test fixture (jido-e12-t16).
  @today ~D[2026-07-27]

  # The competitor comparison pages. The index hub (/compare) links to the
  # comparisons but makes no competitor claims of its own, so it is excluded:
  # the review-date + sources contract applies to pages that assert facts about
  # a competitor.
  @competitor_pages Pages.pages_by_category(:compare) |> Enum.reject(&(&1.path == "/compare"))

  describe "the competitor comparison set exists (jido-e12-t19)" do
    test "there is at least one competitor comparison page" do
      assert @competitor_pages != [],
             "expected published competitor comparison pages under :compare"
    end
  end

  describe "every competitor comparison page carries a review date (jido-e12-t19)" do
    for page <- @competitor_pages do
      test "#{page.path} carries a well-formed last_validated review date" do
        page = unquote(Macro.escape(page))

        assert {:ok, reviewed_on} = Date.from_iso8601(page.last_validated),
               "#{page.path} must carry an ISO last_validated date naming when the " <>
                 "comparison was last reviewed (jido-e12-t19)"

        # A review date is never in the future (fixed "today" mirrors @today).
        assert Date.compare(reviewed_on, ~D[2026-07-27]) != :gt,
               "#{page.path} last_validated (#{page.last_validated}) is in the future"
      end
    end
  end

  describe "every competitor comparison page names its reviewer (jido-e12-t19)" do
    for page <- @competitor_pages do
      test "#{page.path} names an accountable reviewer via owner" do
        page = unquote(Macro.escape(page))

        # owner defaults to "" (never nil), so a missing reviewer is the blank string.
        assert page.owner != "",
               "#{page.path} must name an accountable reviewer (owner) so a stale " <>
                 "comparison has someone to ping when it joins the queue (jido-e12-t19)"
      end
    end
  end

  describe "every competitor comparison page names openable sources (jido-e12-t19)" do
    for page <- @competitor_pages do
      test "#{page.path} carries at least one well-formed external source" do
        page = unquote(Macro.escape(page))

        sources = page.sources || []

        assert sources != [],
               "#{page.path} must name at least one external source backing its " <>
                 "competitor claims (jido-e12-t19)"

        for source <- sources do
          assert is_map(source),
                 "#{page.path} source is not a map: #{inspect(source)}"

          label = source_value(source, :label)
          url = source_value(source, :url)

          assert label not in [nil, ""],
                 "#{page.path} has a source with no label: #{inspect(source)}"

          assert url not in [nil, ""],
                 "#{page.path} source #{inspect(label)} has no url"

          assert String.starts_with?(to_string(url), ~w(http:// https://)),
                 "#{page.path} source #{inspect(label)} url must be http(s): #{inspect(url)}"
        end
      end
    end
  end

  describe "old facts are queued for review (jido-e12-t19)" do
    test "the compare category is on the slow review queue scope" do
      # The slow review queue (jido-e12-t16) is the mechanism that turns a stale
      # comparison into assigned work. Compare is one of its scopes.
      assert :compare in Pages.slow_review_categories()
    end

    test "every competitor page is a slow-changing page eligible for the queue" do
      slow_paths = Pages.slow_pages() |> Enum.map(& &1.path) |> MapSet.new()

      for page <- @competitor_pages do
        assert page.path in slow_paths,
               "#{page.path} must be in the slow-changing scope so its review date " <>
                 "can drive the queue (jido-e12-t16/jido-e12-t19)"
      end
    end

    test "a competitor page with no review date joins the slow review queue" do
      # A comparison whose review date is blank is always stale and always
      # becomes assigned work — old facts cannot rot unnoticed. Today every
      # comparison carries a review date, so this is the forward-compatible
      # invariant: no comparison that later loses its date slips off the queue.
      queued_paths =
        Pages.slow_review_queue(today: @today)
        |> Enum.map(& &1.page.path)
        |> MapSet.new()

      unvalidated_paths =
        @competitor_pages
        |> Enum.reject(&has_review_date?/1)
        |> Enum.map(& &1.path)
        |> MapSet.new()

      assert MapSet.subset?(unvalidated_paths, queued_paths)
    end

    test "a competitor page whose review date goes stale joins the slow review queue" do
      # The review date drives the queue: tighten the window past the
      # comparisons' current review dates and every comparison becomes assigned
      # work. This is the "queued for review" half of the acceptance.
      queued_paths =
        Pages.slow_review_queue(today: @today, stale_after_days: 1)
        |> Enum.map(& &1.page.path)
        |> MapSet.new()

      for page <- @competitor_pages do
        assert page.path in queued_paths,
               "#{page.path} should join the slow review queue once its review date is stale"
      end
    end
  end

  # --- helpers ---

  defp source_value(source, key) when is_atom(key) do
    Map.get(source, key) || Map.get(source, Atom.to_string(key))
  end

  defp has_review_date?(page) do
    case Date.from_iso8601(to_string(page.last_validated)) do
      {:ok, _date} -> true
      {:error, _} -> false
    end
  end
end
