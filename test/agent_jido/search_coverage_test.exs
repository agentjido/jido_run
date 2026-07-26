defmodule AgentJido.SearchCoverageTest do
  @moduledoc """
  Public-content search coverage gate (jido-e12-t12).

  Acceptance condition: a new public item must be indexed or explicitly excluded.

  Every item the site publishes — docs pages, blog posts, ecosystem packages,
  examples, and package skills — must either appear in the search inventory
  (`AgentJido.ContentIngest.Inventory.build/1`, the document set Arcana ingests
  and the local fallback searches) or be on a documented exclusion rule. A new
  public page, example, package, or skill that the inventory forgets — or a new
  exclusion the inventory silently introduces — trips this gate so the gap lands
  in CI instead of shipping as a missing search result.

  The existing `InventoryTest` locks the inventory's aggregate shape (counts,
  per-scope wiring, alias indexing). It cannot catch a single public item that
  drops out of the index, because it never asks "is *this* public item here?"
  This gate asks that question for every public item.

  The effective exclusion set is *discovered* by diffing each public catalog
  against the indexed source ids, then asserted to be fully explained by the
  documented rules below. That keeps the gate honest in both directions: a
  dropped item with no matching rule fails, and a rule that excludes nothing
  fails (no stale exclusions to rot beside the inventory).
  """

  use ExUnit.Case, async: true

  alias AgentJido.Blog
  alias AgentJido.ContentIngest.Inventory
  alias AgentJido.Ecosystem
  alias AgentJido.Examples
  alias AgentJido.Pages
  alias AgentJido.UpstreamSkillCatalog

  # Documented exclusion rules for the docs surface. Each entry is
  # `{path_prefix, reason}`. The inventory drops these public routes from search
  # via its `@excluded_doc_path_prefixes`; naming them here is the "explicitly
  # excluded" branch of the acceptance condition. To stop indexing a public
  # docs page, add the rule here AND keep the inventory prefix in lockstep — the
  # gate proves the two cannot drift.
  @doc_exclusion_rules [
    {"/build", "preview/blueprint page tree — public routes but intentionally not search targets"},
    {"/training", "retired Training section — /training routes redirect to active Docs pages"}
  ]

  # Blog posts, ecosystem packages, examples, and package skills are indexed in
  # full: every public item is a search target, so they carry no exclusion
  # rules. The per-surface tests below lock that invariant — adding a silent
  # exclusion to any of those builders fails the gate.

  describe "public-content search coverage (jido-e12-t12)" do
    test "every public docs page is indexed or explicitly excluded" do
      public_paths = Pages.all_pages() |> Enum.map(& &1.path) |> MapSet.new()

      indexed_paths =
        :docs
        |> indexed_ids()
        |> Enum.map(&String.replace_prefix(&1, "docs:", ""))
        |> MapSet.new()

      dropped = public_paths |> MapSet.difference(indexed_paths) |> MapSet.to_list()
      extra = indexed_paths |> MapSet.difference(public_paths) |> MapSet.to_list()

      # Every dropped page must be explained by a documented rule.
      assert unexplained_exclusions(dropped, @doc_exclusion_rules) == [],
             "public docs pages are missing from the search inventory with no " <>
               "documented exclusion: #{inspect(unexplained_exclusions(dropped, @doc_exclusion_rules))}. " <>
               "Either index them via Inventory.build/1 or add a documented rule " <>
               "to @doc_exclusion_rules (jido-e12-t12)."

      # Every documented rule must still exclude something (no stale rules).
      assert stale_rules(dropped, @doc_exclusion_rules) == [],
             "documented docs exclusion rules exclude nothing — they rotted beside " <>
               "the inventory: #{inspect(stale_rules(dropped, @doc_exclusion_rules))}. " <>
               "Remove them from @doc_exclusion_rules (jido-e12-t12)."

      # Nothing indexed that is not a public page (no phantom sources).
      assert extra == [],
             "the search inventory indexes docs pages that are not public: " <>
               "#{inspect(extra)} (jido-e12-t12)."
    end

    test "every public blog post is indexed" do
      assert_full_coverage("blog", Blog.all_posts(), &"blog:#{&1.id}", indexed_ids(:blog))
    end

    test "every public ecosystem package is indexed" do
      assert_full_coverage(
        "ecosystem",
        Ecosystem.public_packages(),
        &"ecosystem:#{&1.id}",
        indexed_ids(:ecosystem)
      )
    end

    test "every public example is indexed" do
      assert_full_coverage(
        "examples",
        Examples.all_examples(),
        &"examples:#{&1.slug}",
        indexed_ids(:examples)
      )
    end

    test "every public package skill is indexed" do
      assert_full_coverage(
        "skills",
        UpstreamSkillCatalog.package_entries(),
        &"skills:#{&1.id}",
        indexed_ids(:skills)
      )
    end

    # Positive control (jido-e12-t12): proves a NEW public docs page that the
    # inventory neither indexes nor documents trips the gate — the same check
    # the docs test applies to the live dropped set.
    test "a newly introduced un-indexed, un-excluded docs page is flagged" do
      # A page under a brand-new prefix the inventory forgot to document is not
      # explained by any documented rule and so must be flagged.
      flagged = unexplained_exclusions(["/internal/new-page"], @doc_exclusion_rules)
      assert flagged == ["/internal/new-page"]

      # Negative control: pages under a documented prefix are explained, not
      # flagged, so legitimate exclusions do not raise.
      assert unexplained_exclusions(["/build/anything", "/training/anything"], @doc_exclusion_rules) == []
    end
  end

  # Full-coverage surface: the indexed set must equal the public set exactly,
  # in both directions. No exclusions are documented for these surfaces.
  defp assert_full_coverage(label, items, id_fn, indexed) do
    public = items |> Enum.map(id_fn) |> MapSet.new()

    missing = public |> MapSet.difference(indexed) |> MapSet.to_list()

    assert missing == [],
           "#{label}: every public item must be in the search inventory — no " <>
             "exclusions are documented for this surface — but these are missing: " <>
             "#{inspect(missing)}. Wire them into Inventory.build/1 or add a " <>
             "documented exclusion rule (jido-e12-t12)."

    extra = indexed |> MapSet.difference(public) |> MapSet.to_list()

    assert extra == [],
           "#{label}: the search inventory indexes items that are not public: " <>
             "#{inspect(extra)} (jido-e12-t12)."
  end

  defp indexed_ids(scope) do
    Inventory.build(only: [scope])
    |> Enum.map(& &1.source_id)
    |> MapSet.new()
  end

  # Dropped paths no documented rule explains — the "indexed or explicitly
  # excluded" offenders for the docs surface.
  defp unexplained_exclusions(paths, rules) do
    prefixes = Enum.map(rules, &elem(&1, 0))
    Enum.reject(paths, &matches_any_prefix?(&1, prefixes))
  end

  # Documented rules that exclude nothing — stale rules rotting beside the
  # inventory.
  defp stale_rules(dropped_paths, rules) do
    Enum.reject(rules, fn {prefix, _reason} ->
      Enum.any?(dropped_paths, &String.starts_with?(&1, prefix))
    end)
  end

  defp matches_any_prefix?(path, prefixes) do
    Enum.any?(prefixes, &String.starts_with?(path, &1))
  end
end
