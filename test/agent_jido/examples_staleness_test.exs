defmodule AgentJido.ExamplesStalenessTest do
  @moduledoc """
  E08-T15: stale examples can be found.

  The Example card contract carries two freshness fields — `last_validated`
  (ISO date the example was last run) and `tested_with` (the version set it was
  validated against). Neither is required to publish an example, so staleness
  has to be *queryable* rather than enforced by a build-time gate. The
  `Examples.stale_examples/1` and `Examples.stale?/2` functions are that query:
  they surface every example that has no validation date, an out-of-window date,
  or an empty version set.
  """

  use ExUnit.Case, async: true

  alias AgentJido.Examples
  alias AgentJido.Examples.Example

  @live_slug "counter-agent"

  describe "stale examples can be found (jido-e08-t15)" do
    test "there is at least one published example to check" do
      assert Examples.example_count() > 0
    end

    test "stale_examples/0 surfaces examples that lack validation metadata" do
      stale_slugs = Examples.stale_examples() |> Enum.map(& &1.slug)

      # Only the controlled-agent example declares a last_validated date so far,
      # and no shipped example declares a tested_with version set yet, so every
      # published example is still stale — and findable.
      assert length(stale_slugs) == Examples.example_count()
      assert @live_slug in stale_slugs
    end

    test "stale_examples/1 honors the include_unpublished opt" do
      published = Examples.stale_examples() |> Enum.map(& &1.slug)
      with_drafts = Examples.stale_examples(include_unpublished: true) |> Enum.map(& &1.slug)

      # The draft-only budget-guardrail-agent is stale and only appears once
      # drafts are included.
      refute "budget-guardrail-agent" in published
      assert "budget-guardrail-agent" in with_drafts
      assert length(with_drafts) >= length(published)
    end
  end

  describe "Examples.stale?/2" do
    setup do
      base = Examples.get_example!(@live_slug, include_unpublished: true)
      {:ok, base: base, today: Date.utc_today()}
    end

    test "a freshly validated example with a version set is not stale", %{base: base, today: today} do
      fresh = %Example{
        base
        | last_validated: Date.to_iso8601(today),
          tested_with: %{jido: "1.0.0"}
      }

      refute Examples.stale?(fresh)
    end

    test "an example missing both fields is stale", %{base: base} do
      unvalidated = %Example{base | last_validated: "", tested_with: %{}}

      assert Examples.stale?(unvalidated)
    end

    test "an example with a fresh date but no version set is stale", %{base: base, today: today} do
      missing_versions = %Example{base | last_validated: Date.to_iso8601(today), tested_with: %{}}

      assert Examples.stale?(missing_versions)
    end

    test "an example validated before the default 90-day window is stale", %{base: base, today: today} do
      old_date = today |> Date.add(-120) |> Date.to_iso8601()
      stale = %Example{base | last_validated: old_date, tested_with: %{jido: "1.0.0"}}

      assert Examples.stale?(stale)
    end

    test "the stale_after_days opt moves the freshness boundary", %{base: base, today: today} do
      recent = today |> Date.add(-40) |> Date.to_iso8601()
      example = %Example{base | last_validated: recent, tested_with: %{jido: "1.0.0"}}

      # 40 days old is fresh under the default 90-day window but stale under 30.
      refute Examples.stale?(example)
      assert Examples.stale?(example, stale_after_days: 30)
    end

    test "a malformed last_validated date is treated as stale", %{base: base} do
      malformed = %Example{base | last_validated: "last tuesday", tested_with: %{jido: "1.0.0"}}

      assert Examples.stale?(malformed)
    end
  end
end
