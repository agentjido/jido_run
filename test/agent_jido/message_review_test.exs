defmodule AgentJido.MessageReviewTest do
  @moduledoc """
  Quarterly message review (jido-e12-t36).

  Acceptance condition: *Position, package roles, proof, and audience are
  reviewed together* — each quarter.

  The site's message is the agreement of four independent sources, each owned
  and refreshed on its own cadence: **position** (`specs/positioning.md`),
  **package roles** (the ecosystem registry, `priv/ecosystem/*.md`),
  **proof** (`specs/proof.md`), and **audience** (`specs/persona-journeys.md`).
  `AgentJido.MessageReview` brings them into one review: it reads each source's
  positioning anchor and last-reviewed date, confirms the anchor-bearing
  dimensions still agree (coherent) and every public package still carries a
  role (present), and returns the dimensions due this quarter.

  This contract locks:
    * the four named dimensions (`dimensions/0`);
    * the per-dimension verification (`verification/1`) — with negative controls
      proving coherence and presence fail independently;
    * the quarterly freshness predicate (`stale?/2`);
    * the review queue and `reviewed_together?/1` — deterministic.
  """

  use ExUnit.Case, async: true

  alias AgentJido.Ecosystem
  alias AgentJido.MessageReview, as: Review

  @today ~D[2026-07-27]

  # --- dimensions -----------------------------------------------------------

  describe "dimensions/0 (jido-e12-t36)" do
    test "enumerates position, package roles, proof, and audience — together" do
      dims = Review.dimensions() |> Enum.map(& &1.dimension)

      assert dims == [:position, :package_roles, :proof, :audience],
             "the four messaging dimensions must be reviewed together"
    end

    test "every dimension records its source and presence" do
      for state <- Review.dimensions() do
        assert Map.has_key?(state, :source)

        assert String.trim(state.source) != "",
               "#{inspect(state.dimension)} must name its source"

        assert Map.has_key?(state, :present)
      end
    end

    test "position is the canonical anchor source" do
      [position] = for s <- Review.dimensions(), s.dimension == :position, do: s

      assert position.source =~ "positioning.md"
      # The canonical anchor is a real sentence, not a heading slug.
      assert position.anchor =~ "Jido is the Elixir framework"

      assert position.last_reviewed != nil,
             "positioning.md must record a Last updated date"
    end

    test "package_roles draws from the ecosystem registry" do
      [roles] = for s <- Review.dimensions(), s.dimension == :package_roles, do: s

      assert roles.source =~ "registry"
      assert roles.source =~ "public packages"
      # The registry records no single review date; its freshness gate is presence.
      assert roles.last_reviewed == nil
      assert roles.anchor == nil
    end

    test "proof and audience record the positioning anchor and a review date" do
      for dim <- [:proof, :audience] do
        [state] = for s <- Review.dimensions(), s.dimension == dim, do: s

        assert state.anchor =~ "Jido is the Elixir framework",
               "#{dim} must record the positioning anchor"

        assert state.last_reviewed != nil,
               "#{dim} must record a Last updated date"
      end
    end
  end

  # --- verification: coherent + present ------------------------------------

  describe "verification/1 (jido-e12-t36: coherent + present)" do
    test "every recorded dimension is currently present and coherent" do
      # Loud, current-state control: today the four messaging dimensions agree on
      # one positioning anchor and every public package carries a role, so a
      # reviewer holding the quarterly review finds nothing to fix.
      for state <- Review.dimensions() do
        v = Review.verification(state)

        assert v.present,
               "#{inspect(state.dimension)} is not present"

        assert v.coherent,
               "#{inspect(state.dimension)} anchor diverges from the canonical anchor"
      end

      assert Review.coherent?()
    end

    test "coherence fails when an anchor-bearing source records a different anchor" do
      divergent =
        good_state(:audience, anchor: "A runtime for reliable, multi-agent systems.")

      v = Review.verification(divergent)
      refute v.coherent, "a divergent anchor is exactly what the review must catch"
      # Presence is unaffected — only the message disagrees.
      assert v.present
    end

    test "a dimension that records no anchor is trivially coherent" do
      roles =
        good_state(:package_roles)
        |> Map.put(:anchor, nil)

      assert Review.verification(roles).coherent
    end

    test "package_roles presence fails when a public package lacks a role" do
      good_pkg = %{id: "jido", visibility: :public, tagline: "core agent framework"}
      no_role = %{id: "ghost", visibility: :public, tagline: ""}

      [roles] =
        for s <- Review.dimensions(packages: [good_pkg, no_role]), s.dimension == :package_roles, do: s

      refute roles.present, "a public package without a tagline is a message gap"
    end

    test "a non-public package without a role does not fail package_roles" do
      # Only packages the site presents (visibility: :public) are part of the
      # message; a private/unreleased package without a tagline is not a gap.
      good_pkg = %{id: "jido", visibility: :public, tagline: "core agent framework"}
      private_no_role = %{id: "secret", visibility: :internal, tagline: ""}

      [roles] =
        for s <- Review.dimensions(packages: [good_pkg, private_no_role]), s.dimension == :package_roles, do: s

      assert roles.present
    end
  end

  # --- quarterly freshness predicate ---------------------------------------

  describe "stale?/2 (jido-e12-t36: each quarter)" do
    @reviewed ~D[2026-07-23]

    test "default window is one quarter (90 days)" do
      assert Review.default_review_days() == 90
    end

    test "a freshly reviewed source is not stale" do
      state = good_state(:proof, last_reviewed: @reviewed)

      refute Review.stale?(state, today: @reviewed)
      refute Review.stale?(state, today: Date.add(@reviewed, 90))
    end

    test "a source reviewed more than a quarter ago is stale" do
      state = good_state(:proof, last_reviewed: @reviewed)
      assert Review.stale?(state, today: Date.add(@reviewed, 91))
    end

    test "a dimension that records no date is not calendar-stale" do
      # package_roles records no review date; its freshness gate is presence,
      # not the calendar.
      refute Review.stale?(good_state(:package_roles), today: @today)
    end

    test "the review_after_days opt moves the boundary" do
      recent = good_state(:proof, last_reviewed: Date.add(@reviewed, 1))

      refute Review.stale?(recent, today: Date.add(@reviewed, 30))
      assert Review.stale?(recent, today: Date.add(@reviewed, 30), review_after_days: 10)
    end
  end

  # --- review queue + reviewed_together? -----------------------------------

  describe "review_queue/1 and reviewed_together?/1 (jido-e12-t36)" do
    test "reviewed_together? is true today (current sources are fresh and coherent)" do
      # The deterministic baseline the review measures drift from.
      assert Review.reviewed_together?(today: @today)
      assert Review.review_queue(today: @today) == []
    end

    test "a dated source goes on the queue once the quarter elapses" do
      # Push today past the latest recorded review date. position, proof, and
      # audience are then due for re-review this quarter.
      latest =
        Review.dimensions()
        |> Enum.map(& &1.last_reviewed)
        |> Enum.reject(&is_nil/1)
        |> Enum.max(Date)

      queue = Review.review_queue(today: Date.add(latest, 91))

      due = Enum.map(queue, & &1.dimension) |> Enum.sort()

      assert due == [:audience, :position, :proof],
             "expected the three dated dimensions on the queue once the quarter elapses"

      refute Review.reviewed_together?(today: Date.add(latest, 91))
    end

    test "a divergent anchor makes a dimension due even when freshly reviewed" do
      # Coherence is independent of the calendar: a source reviewed today but
      # recording a different anchor is still due this quarter.
      divergent =
        good_state(:audience,
          anchor: "A runtime for reliable, multi-agent systems.",
          last_reviewed: @today
        )

      refute Review.stale?(divergent, today: @today)
      refute Review.verification(divergent).coherent
      assert Review.due?(divergent, today: @today)
    end

    test "a public package losing its role puts package_roles on the queue" do
      good_pkg = %{id: "jido", visibility: :public, tagline: "core agent framework"}
      no_role = %{id: "ghost", visibility: :public, tagline: ""}

      queue = Review.review_queue(today: @today, packages: [good_pkg, no_role])

      [entry] = for e <- queue, e.dimension == :package_roles, do: e
      assert entry.reason =~ "role"
      refute Review.reviewed_together?(today: @today, packages: [good_pkg, no_role])
    end

    test "every queue entry carries its source, reason, and verification" do
      latest =
        Review.dimensions()
        |> Enum.map(& &1.last_reviewed)
        |> Enum.reject(&is_nil/1)
        |> Enum.max(Date)

      queue = Review.review_queue(today: Date.add(latest, 120))

      for entry <- queue do
        assert Map.keys(entry) |> Enum.sort() == [:dimension, :reason, :source, :verification]

        assert String.trim(entry.source) != ""
        assert String.trim(entry.reason) != ""

        v = entry.verification
        assert Map.keys(v) |> Enum.sort() == [:anchor, :coherent, :dimension, :last_reviewed, :present]

        # The entry is genuinely due (that is why it is on the queue).
        assert Review.stale?(%{last_reviewed: v.last_reviewed}, today: Date.add(latest, 120))
      end
    end

    test "is deterministic under a fixed :today" do
      latest =
        Review.dimensions()
        |> Enum.map(& &1.last_reviewed)
        |> Enum.reject(&is_nil/1)
        |> Enum.max(Date)

      today = Date.add(latest, 95)

      one = Review.review_queue(today: today) |> Enum.map(& &1.dimension)
      two = Review.review_queue(today: today) |> Enum.map(& &1.dimension)

      assert one == two
    end

    test "every public package in the real registry currently carries a role" do
      # The registry is the package_roles source of truth. A package that ships
      # publicly without a role is an unreviewed message gap.
      public = for pkg <- Ecosystem.all_packages(), pkg.visibility == :public, do: pkg
      assert public != [], "registry must carry public packages"

      for pkg <- public do
        assert String.trim(pkg.tagline || "") != "",
               "public package #{inspect(pkg.id)} has no role (tagline)"
      end
    end
  end

  # --- helpers --------------------------------------------------------------

  defp good_state(dim, opts \\ [])

  defp good_state(:package_roles, opts) do
    %{
      dimension: :package_roles,
      source: "priv/ecosystem/*.md (registry)",
      anchor: nil,
      last_reviewed: nil,
      present: Keyword.get(opts, :present, true)
    }
  end

  defp good_state(dim, opts) when dim in [:position, :proof, :audience] do
    %{
      dimension: dim,
      source: "specs/#{dim}.md",
      anchor: Keyword.get(opts, :anchor, Review.anchor()),
      last_reviewed: Keyword.get(opts, :last_reviewed, ~D[2026-07-23]),
      present: Keyword.get(opts, :present, true)
    }
  end
end
