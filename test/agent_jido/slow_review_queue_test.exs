defmodule AgentJido.SlowReviewQueueTest do
  @moduledoc """
  180-day review queue for slow-changing content (jido-e12-t16).

  Acceptance condition: slow-changing pages still receive planned review.

  "Slow-changing" content is the conceptual foundation (`docs/concepts`) and
  the framework comparisons (the `:compare` category) — pages that describe
  stable ideas and competitive positioning rather than executable steps. They
  move less often than the onboarding ramp or the operations runbooks, so they
  rotate on a 180-day cadence (twice the 90-day critical window, jido-e12-t15)
  instead of never. The freshness+ownership publication gate (jido-e12-t14)
  enforces last_validated/tested_with/owner only on *executable* notebooks, so
  a plain-Markdown concept or comparison page can ship without a validation
  date and rot silently. The review queue makes that drift findable AND turns
  each stale page into assigned work attributed to its owner.

  `Pages.slow_review_queue/1` is the queue; `Pages.stale?/2` (shared with the
  critical queue) is the predicate, here evaluated against the 180-day window.
  """

  use ExUnit.Case, async: true

  alias AgentJido.Pages
  alias AgentJido.Pages.Page

  @today ~D[2026-07-27]
  @concept_path "/docs/concepts/agents"
  @comparison_path "/compare/langgraph"
  @critical_path "/docs/getting-started/installation"
  @non_slow_docs_path "/docs/learn"

  describe "slow_review_sections/0 and slow_review_categories/0 (jido-e12-t16)" do
    test "concepts is the slow-changing docs section" do
      assert Pages.slow_review_sections() == ["concepts"]
    end

    test "compare is the slow-changing comparison category" do
      assert Pages.slow_review_categories() == [:compare]
    end

    test "slow-changing scope is disjoint from the 90-day critical scope" do
      # Concepts and comparisons are deliberately NOT on the critical queue —
      # they get the slower 180-day cadence instead (jido-e12-t15).
      for section <- Pages.slow_review_sections() do
        refute section in Pages.critical_review_sections()
      end
    end
  end

  describe "default_slow_review_days/0 (jido-e12-t16)" do
    test "the slow-changing window is 180 days" do
      assert Pages.default_slow_review_days() == 180
    end

    test "the slow window is wider than the critical window" do
      assert Pages.default_slow_review_days() > Pages.default_critical_review_days()
    end
  end

  describe "slow_pages/0 (jido-e12-t16)" do
    test "returns concepts + comparisons only" do
      pages = Pages.slow_pages()

      assert pages != [], "expected concepts and comparison pages to exist"

      for page <- pages do
        assert in_slow_scope?(page),
               "#{page.path} is not in the concepts section or the compare category"
      end
    end

    test "includes a known concept page and a known comparison page" do
      paths = Enum.map(Pages.slow_pages(), & &1.path)

      assert @concept_path in paths
      assert @comparison_path in paths
    end

    test "excludes critical (onboarding/operations) pages" do
      paths = Enum.map(Pages.slow_pages(), & &1.path)

      refute @critical_path in paths,
             "onboarding/operations content stays on the 90-day critical queue (jido-e12-t15)"
    end

    test "excludes other docs sections and other categories" do
      paths = Enum.map(Pages.slow_pages(), & &1.path)

      refute @non_slow_docs_path in paths,
             "learn is not a slow-changing section"
    end

    test "every slow page is published" do
      draft_paths =
        Pages.all_pages_including_drafts()
        |> Enum.filter(& &1.draft)
        |> MapSet.new(& &1.path)

      for page <- Pages.slow_pages() do
        refute page.path in draft_paths, "#{page.path} is a draft but landed on the slow queue"
      end
    end

    test "concept and comparison pages are both represented (two-scope coverage)" do
      scopes = Pages.slow_pages() |> Enum.map(&slow_scope_label/1) |> MapSet.new()

      assert "concepts" in scopes
      assert "compare" in scopes
    end
  end

  describe "Pages.stale?/2 against the 180-day window (jido-e12-t16)" do
    setup do
      base = Pages.get_page_by_path!(@concept_path)
      {:ok, base: base}
    end

    test "a blank last_validated is stale", %{base: base} do
      assert Pages.stale?(%Page{base | last_validated: ""},
               stale_after_days: Pages.default_slow_review_days(),
               today: @today
             )
    end

    test "a malformed last_validated is stale", %{base: base} do
      assert Pages.stale?(%Page{base | last_validated: "last quarter"},
               stale_after_days: Pages.default_slow_review_days(),
               today: @today
             )
    end

    test "a page validated 180 days ago is still fresh (window is exclusive)", %{base: base} do
      edge = %Page{base | last_validated: Date.to_iso8601(Date.add(@today, -180))}

      refute Pages.stale?(edge,
               stale_after_days: Pages.default_slow_review_days(),
               today: @today
             )
    end

    test "a page validated 181 days ago is stale", %{base: base} do
      stale = %Page{base | last_validated: Date.to_iso8601(Date.add(@today, -181))}

      assert Pages.stale?(stale,
               stale_after_days: Pages.default_slow_review_days(),
               today: @today
             )
    end

    test "the stale_after_days opt moves the boundary", %{base: base} do
      recent = %Page{base | last_validated: Date.to_iso8601(Date.add(@today, -120))}

      # 120 days old is fresh under the 180-day window but stale under 90.
      refute Pages.stale?(recent,
               stale_after_days: Pages.default_slow_review_days(),
               today: @today
             )

      assert Pages.stale?(recent, stale_after_days: 90, today: @today)
    end
  end

  describe "Pages.slow_review_queue/1 (jido-e12-t16)" do
    test "every entry is a stale slow-changing page attributed to an owner (assigned work)" do
      queue = Pages.slow_review_queue(today: @today)

      assert queue != [], "expected stale slow-changing pages to create assigned work"

      for entry <- queue do
        # The five documented assigned-work keys.
        assert Map.keys(entry) |> Enum.sort() ==
                 [:days_since_validation, :last_validated, :owner, :page, :section]

        assert %Page{} = entry.page
        assert in_slow_scope?(entry.page), "#{entry.page.path} is not a slow-changing page"
        assert slow_scope_label(entry.page) == entry.section
        assert is_binary(entry.owner)
        assert is_binary(entry.section)
        assert is_nil(entry.last_validated) or is_binary(entry.last_validated)
        assert is_nil(entry.days_since_validation) or entry.days_since_validation >= 0

        # The entry is genuinely stale under the 180-day window and genuinely slow-changing.
        assert Pages.stale?(entry.page,
                 stale_after_days: Pages.default_slow_review_days(),
                 today: @today
               )

        assert entry.page in Pages.slow_pages()

        # Assigned work: the entry is attributed to its owner (empty owner is
        # still a recorded, pingeable field — executable pages always carry one).
        assert entry.owner == entry.page.owner
      end
    end

    test "is deterministic under a fixed :today" do
      one = Pages.slow_review_queue(today: @today)
      two = Pages.slow_review_queue(today: @today)

      assert Enum.map(one, & &1.page.path) == Enum.map(two, & &1.page.path)
    end

    test "every slow-changing page with no validation date joins the queue" do
      # Plain-Markdown concept/comparison pages (not covered by the E12-T14
      # executable gate) ship without last_validated, so they are always stale
      # and always create assigned work. This is the core acceptance: no
      # slow-changing page can rot silently once it lacks a validation date.
      unvalidated_paths =
        Pages.slow_pages()
        |> Enum.reject(&has_validation_date?/1)
        |> Enum.map(& &1.path)
        |> MapSet.new()

      queued_paths =
        Pages.slow_review_queue(today: @today)
        |> Enum.map(fn entry ->
          assert is_nil(entry.last_validated) or is_binary(entry.last_validated)
          entry.page.path
        end)
        |> MapSet.new()

      assert MapSet.subset?(unvalidated_paths, queued_paths)
    end

    test "the current concept set has unvalidated pages (planned review is real today)" do
      # Loud, current-state control: today the concept pages are plain Markdown
      # with no last_validated, so the queue is non-empty — slow-changing pages
      # are receiving planned review, not rotting unnoticed. If every concept
      # page later gains a validation date, update this (and the queue will then
      # track the 180-day window against those dates instead).
      unvalidated =
        Pages.slow_pages()
        |> Enum.filter(&(slow_scope_label(&1) == "concepts"))
        |> Enum.reject(&has_validation_date?/1)

      assert unvalidated != [],
             "expected at least one concept page with no last_validated to be on the queue"
    end

    test "a tighter window grows the queue; a wider window shrinks it" do
      default = Pages.slow_review_queue(today: @today)
      tighter = Pages.slow_review_queue(today: @today, stale_after_days: 90)
      wider = Pages.slow_review_queue(today: @today, stale_after_days: 10_000)

      assert length(tighter) >= length(default)
      assert length(wider) <= length(default)
    end

    test "executable slow-changing pages on the queue carry their owner" do
      # Executable notebooks enforce owner via the E12-T14 gate, so any
      # executable page that lands on the queue must carry a named owner.
      # (Today the slow-changing set is plain Markdown, so this is a
      # forward-compatible invariant rather than a live assertion.)
      executable_entries =
        Pages.slow_review_queue(today: @today)
        |> Enum.filter(& &1.page.is_livebook)

      for entry <- executable_entries do
        assert entry.owner != "",
               "executable page #{entry.page.path} on the queue must have an owner (jido-e12-t14)"
      end
    end
  end

  # --- helpers ---

  defp in_slow_scope?(%Page{} = page) do
    slow_scope_label(page) in ["concepts", "compare"]
  end

  defp slow_scope_label(%Page{category: :docs} = page), do: section_of(page)
  defp slow_scope_label(%Page{category: :compare}), do: "compare"
  defp slow_scope_label(%Page{category: category}), do: Atom.to_string(category)

  defp section_of(%Page{category: :docs} = page) do
    page.path
    |> String.trim_leading("/docs")
    |> String.trim_leading("/")
    |> String.split("/", trim: true)
    |> List.first()
  end

  defp has_validation_date?(%Page{last_validated: last_validated}) do
    case Date.from_iso8601(to_string(last_validated)) do
      {:ok, _date} -> true
      {:error, _} -> false
    end
  end
end
