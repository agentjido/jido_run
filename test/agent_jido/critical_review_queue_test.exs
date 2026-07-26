defmodule AgentJido.CriticalReviewQueueTest do
  @moduledoc """
  90-day review queue for onboarding and operations content (jido-e12-t15).

  Acceptance condition: stale critical pages create assigned work.

  "Critical" content is the onboarding ramp (docs/getting-started) and the
  operations runbook set (docs/operations) — the pages a new builder or an
  on-call operator must trust. The freshness+ownership publication gate
  (jido-e12-t14) enforces last_validated/tested_with/owner only on *executable*
  notebooks, so a plain-Markdown critical page can ship without a validation
  date and rot silently. The review queue makes that drift findable AND turns
  each stale page into assigned work attributed to its owner.

  `Pages.critical_review_queue/1` is the queue; `Pages.stale?/2` is the
  predicate. The default window (90 days) mirrors the Example staleness query
  (jido-e08-t15) and the quarterly operational-control proof audit (E12-T49).
  """

  use ExUnit.Case, async: true

  alias AgentJido.Pages
  alias AgentJido.Pages.Page

  @today ~D[2026-07-26]
  @onboarding_path "/docs/getting-started/installation"
  @operations_path "/docs/operations/deployment-restart"
  @non_critical_path "/docs/concepts"

  describe "critical_review_sections/0 (jido-e12-t15)" do
    test "returns onboarding + operations" do
      assert Pages.critical_review_sections() == ["getting-started", "operations"]
    end
  end

  describe "critical_pages/0 (jido-e12-t15)" do
    test "returns only onboarding + operations pages" do
      pages = Pages.critical_pages()

      assert pages != [], "expected onboarding + operations pages to exist"

      assert Enum.all?(pages, &(&1.category == :docs)),
             "critical pages must all be docs"

      assert Enum.all?(pages, &(section_of(&1) in Pages.critical_review_sections())),
             "critical pages must all be in onboarding or operations"
    end

    test "includes a known onboarding and a known operations page" do
      paths = Enum.map(Pages.critical_pages(), & &1.path)

      assert @onboarding_path in paths
      assert @operations_path in paths
    end

    test "excludes non-critical sections" do
      paths = Enum.map(Pages.critical_pages(), & &1.path)

      refute @non_critical_path in paths,
             "concepts is slow-changing (E12-T16), not on the 90-day critical queue"
    end
  end

  describe "Pages.stale?/2 (jido-e12-t15)" do
    setup do
      base = Pages.get_page_by_path!(@onboarding_path)
      {:ok, base: base}
    end

    test "a blank last_validated is stale", %{base: base} do
      assert Pages.stale?(%Page{base | last_validated: ""}, today: @today)
    end

    test "a malformed last_validated is stale", %{base: base} do
      assert Pages.stale?(%Page{base | last_validated: "last tuesday"}, today: @today)
    end

    test "a freshly validated page is not stale", %{base: base} do
      fresh = %Page{base | last_validated: Date.to_iso8601(@today)}
      refute Pages.stale?(fresh, today: @today)
    end

    test "a page validated 90 days ago is still fresh (window is exclusive)", %{base: base} do
      edge = %Page{base | last_validated: Date.to_iso8601(Date.add(@today, -90))}
      refute Pages.stale?(edge, today: @today)
    end

    test "a page validated 91 days ago is stale", %{base: base} do
      stale = %Page{base | last_validated: Date.to_iso8601(Date.add(@today, -91))}
      assert Pages.stale?(stale, today: @today)
    end

    test "the stale_after_days opt moves the boundary", %{base: base} do
      recent = %Page{base | last_validated: Date.to_iso8601(Date.add(@today, -40))}

      # 40 days old is fresh under the default 90-day window but stale under 30.
      refute Pages.stale?(recent, today: @today)
      assert Pages.stale?(recent, today: @today, stale_after_days: 30)
    end

    test "defaults to Date.utc_today/0 when :today is omitted", %{base: base} do
      fresh_today = %Page{base | last_validated: Date.to_iso8601(Date.utc_today())}
      refute Pages.stale?(fresh_today)
    end
  end

  describe "Pages.critical_review_queue/1 (jido-e12-t15)" do
    test "every entry is a stale critical page attributed to an owner (assigned work)" do
      queue = Pages.critical_review_queue(today: @today)

      assert queue != [], "expected stale critical pages to create assigned work"

      for entry <- queue do
        # The five documented assigned-work keys.
        assert Map.keys(entry) |> Enum.sort() ==
                 [:days_since_validation, :last_validated, :owner, :page, :section]

        assert %Page{} = entry.page
        assert entry.section in Pages.critical_review_sections()
        assert is_binary(entry.owner)
        assert is_nil(entry.last_validated) or is_binary(entry.last_validated)
        assert is_nil(entry.days_since_validation) or entry.days_since_validation >= 0

        # The entry is genuinely stale and genuinely critical.
        assert Pages.stale?(entry.page, today: @today)
        assert entry.page in Pages.critical_pages()

        # Assigned work: the entry is attributed to its owner (empty owner is
        # still a recorded, pingeable field — executable pages always carry one).
        assert entry.owner == entry.page.owner
      end
    end

    test "is deterministic under a fixed :today" do
      one = Pages.critical_review_queue(today: @today)
      two = Pages.critical_review_queue(today: @today)

      assert Enum.map(one, & &1.page.path) == Enum.map(two, & &1.page.path)
    end

    test "every critical page with no validation date joins the queue" do
      # Plain-Markdown critical pages (not covered by the E12-T14 executable
      # gate) ship without last_validated, so they are always stale and always
      # create assigned work. This is the core acceptance: no critical page can
      # rot silently once it lacks a validation date.
      unvalidated_paths =
        Pages.critical_pages()
        |> Enum.reject(&has_validation_date?/1)
        |> Enum.map(& &1.path)
        |> MapSet.new()

      queued_paths =
        Pages.critical_review_queue(today: @today)
        |> Enum.map(fn entry ->
          assert is_nil(entry.last_validated) or is_binary(entry.last_validated)
          entry.page.path
        end)
        |> MapSet.new()

      assert MapSet.subset?(unvalidated_paths, queued_paths)
    end

    test "the current onboarding/operations set has unvalidated pages" do
      # Loud, current-state control: today the operations runbooks are
      # plain Markdown with no last_validated, so the queue is non-empty.
      # If every critical page later gains a validation date, update this (and
      # the queue will then track the 90-day window instead).
      unvalidated =
        Pages.critical_pages()
        |> Enum.reject(&has_validation_date?/1)

      assert unvalidated != [],
             "expected at least one critical page with no last_validated to be on the queue"
    end

    test "a tighter window grows the queue; a wider window shrinks it" do
      default = Pages.critical_review_queue(today: @today)
      tighter = Pages.critical_review_queue(today: @today, stale_after_days: 30)
      wider = Pages.critical_review_queue(today: @today, stale_after_days: 10_000)

      assert length(tighter) >= length(default)
      assert length(wider) <= length(default)
    end

    test "executable pages on the queue carry their owner" do
      # Executable notebooks enforce owner via the E12-T14 gate, so any
      # executable page that lands on the queue must carry a named owner.
      executable_entries =
        Pages.critical_review_queue(today: @today)
        |> Enum.filter(& &1.page.is_livebook)

      for entry <- executable_entries do
        assert entry.owner != "",
               "executable page #{entry.page.path} on the queue must have an owner (jido-e12-t14)"
      end
    end
  end

  # --- helpers ---

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
