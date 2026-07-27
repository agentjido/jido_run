defmodule AgentJido.PagesControlMetadataTest do
  @moduledoc """
  jido-e06-t37 — add control intent and control type to page metadata.

  Acceptance: "A reader can find pages for identity context, authorization,
  policy, history, observation, approval, and redaction."

  The Page schema carries two operational-control metadata fields:

    * `control_types` — the control surfaces a page documents (identity
      context, authorization, policy, quota, approval, history, observation,
      redaction). A page may cover several; the frontmatter value is normalized
      to the canonical set. The Docs control-type filter uses it so a reader can
      find the page(s) for each surface.
    * `control_intent` — the operational-control reader intent a page primarily
      serves (evaluate, enforce, preserve, observe, investigate). Optional and
      distinct from `control_types` (the surface): intent names the reader's job.

  These tests lock the contract: the canonical sets, the normalization, the
  Pages lookup/filter helpers, and the literal acceptance coverage (each of the
  seven named control surfaces has at least one published page).
  """

  use ExUnit.Case, async: true

  alias AgentJido.Pages
  alias AgentJido.Pages.Page

  # The seven control surfaces the acceptance condition names verbatim. Quota is
  # intentionally absent: it is part of the canonical set (parity with the
  # examples taxonomy, and rate-limits-and-cost-budgets documents it) but the
  # acceptance does not require it to be findable.
  @acceptance_control_types [
    :identity_context,
    :authorization,
    :policy,
    :history,
    :observation,
    :approval,
    :redaction
  ]

  describe "the page metadata contract (jido-e06-t37)" do
    test "the Page struct exposes control_types (default []) and control_intent (default nil)" do
      minimal = %Page{id: "x", title: "x", category: :docs}

      assert :control_types in Map.keys(minimal)
      assert :control_intent in Map.keys(minimal)
      assert minimal.control_types == []
      assert minimal.control_intent == nil
    end

    test "Page.control_types/0 is a superset of the seven acceptance surfaces plus quota" do
      ids = Page.control_type_ids()

      for required <- @acceptance_control_types do
        assert required in ids,
               "the canonical control-type set must include #{inspect(required)}"
      end

      # Parity with AgentJido.Examples.Taxonomy.control_types/0 — the site
      # carries one control-type vocabulary across docs and examples.
      assert :quota in ids

      assert Page.control_type_ids() ==
               [
                 :identity_context,
                 :authorization,
                 :policy,
                 :quota,
                 :approval,
                 :history,
                 :observation,
                 :redaction
               ]
    end

    test "every control type carries a human label" do
      for id <- Page.control_type_ids() do
        assert is_binary(Page.control_type_label(id)),
               "control type #{inspect(id)} has no label"
      end

      assert Page.control_type_label(:identity_context) == "Identity context"
      assert Page.control_type_label(:unknown) == nil
    end

    test "Page.control_intents/0 is the canonical reader-intent set with labels" do
      assert Page.control_intent_ids() ==
               [:evaluate, :enforce, :preserve, :observe, :investigate]

      for id <- Page.control_intent_ids() do
        assert is_binary(Page.control_intent_label(id)),
               "control intent #{inspect(id)} has no label"
      end

      assert Page.control_intent_label(:not_an_intent) == nil
    end
  end

  describe "control-type normalization" do
    test "unknown control types are dropped from the canonical set" do
      normalized = Page.normalize_control_types([:authorization, :bogus, :redaction])

      assert normalized == [:authorization, :redaction]
    end

    test "duplicate control types are removed" do
      normalized = Page.normalize_control_types([:policy, :policy, :quota])

      assert normalized == [:policy, :quota]
    end

    test "string control types are accepted and matched case-insensitively" do
      normalized = Page.normalize_control_types(["identity_context", "AUTHORIZATION"])

      assert normalized == [:identity_context, :authorization]
    end

    test "a single value and nil normalize cleanly" do
      assert Page.normalize_control_types(:authorization) == [:authorization]
      assert Page.normalize_control_types(nil) == []
      assert Page.normalize_control_types([]) == []
    end
  end

  describe "control-intent normalization" do
    test "a canonical intent atom is kept" do
      assert Page.normalize_control_intent(:observe) == :observe
    end

    test "a string is matched case-insensitively" do
      assert Page.normalize_control_intent("INVESTIGATE") == :investigate
    end

    test "nil and unknown values normalize to nil" do
      assert Page.normalize_control_intent(nil) == nil
      assert Page.normalize_control_intent(:bogus) == nil
      assert Page.normalize_control_intent("nope") == nil
    end
  end

  describe "Pages lookup helpers (jido-e06-t37)" do
    test "Pages.control_types/0 delegates to Page.control_types/0" do
      assert Pages.control_type_ids() == Page.control_type_ids()
      assert Pages.control_type_label(:authorization) == "Authorization"
      assert Pages.control_intent_label(:evaluate) == Page.control_intent_label(:evaluate)
    end

    test "pages_by_control_type/1 returns published pages carrying the surface, sorted" do
      pages = Pages.pages_by_control_type(:authorization)

      refute pages == [], "no published page documents the authorization control surface"

      # Every returned page carries the queried surface.
      Enum.each(pages, fn page ->
        assert :authorization in page.control_types
      end)

      # Sorted by order then path (deterministic).
      assert pages == Enum.sort_by(pages, &{&1.order, &1.path})
    end

    test "operations_pages_for_control_type/1 excludes the section root and narrows by surface" do
      all = Pages.operations_pages_for_control_type(nil)

      # The section root is an index, not a control page; it never lists itself.
      refute Enum.any?(all, &(&1.path == "/docs/operations"))

      auth_pages = Pages.operations_pages_for_control_type(:authorization)

      assert auth_pages != []
      assert Enum.all?(auth_pages, &(:authorization in &1.control_types))
      assert MapSet.new(auth_pages) |> MapSet.subset?(MapSet.new(all))
    end

    test "operations_pages_for_control_type(:all) returns the same full list as nil" do
      # The filter's "All" chip passes :all; it must not be treated as a surface.
      assert Pages.operations_pages_for_control_type(:all) ==
               Pages.operations_pages_for_control_type(nil)
    end
  end

  describe "the acceptance condition: every named control surface is findable" do
    # "A reader can find pages for identity context, authorization, policy,
    # history, observation, approval, and redaction." Each must resolve to at
    # least one published page through pages_by_control_type/1 — the function
    # the Docs control-type filter renders. (A compile-time gate in Pages
    # enforces the same; this is the runtime mirror.)
    test "each acceptance control type has at least one published page" do
      Enum.each(@acceptance_control_types, fn control_type ->
        pages = Pages.pages_by_control_type(control_type)

        assert pages != [],
               "a reader cannot find a page for the #{control_type} control surface"
      end)
    end

    test "each acceptance control type is reachable from the operations filter" do
      # The operations section is the control path; the filter narrows its pages.
      # Every acceptance surface must have at least one operations page a reader
      # can click to, so the filter never hides a named surface.
      Enum.each(@acceptance_control_types, fn control_type ->
        pages = Pages.operations_pages_for_control_type(control_type)

        assert pages != [],
               "the operations control-type filter has no page for #{control_type}"
      end)
    end
  end

  describe "every published page's control metadata stays within the canonical set" do
    # The build pipeline normalizes frontmatter to the canonical set, so this is
    # a contract gate mirroring the examples control-type contract.
    test "no published page lists a control type outside control_type_ids/0" do
      canonical = MapSet.new(Page.control_type_ids())

      offenders =
        Pages.all_pages()
        |> Enum.filter(fn page ->
          page.control_types
          |> List.wrap()
          |> Enum.any?(&(not MapSet.member?(canonical, &1)))
        end)
        |> Enum.map(& &1.id)

      assert offenders == [],
             "published pages listed out-of-set control types: #{inspect(offenders)}"
    end

    test "every published page's control_types is a unique list" do
      Enum.each(Pages.all_pages(), fn page ->
        types = List.wrap(page.control_types)

        assert types == Enum.uniq(types),
               "#{page.id} has duplicate control types: #{inspect(types)}"
      end)
    end

    test "no published page carries an out-of-set control intent" do
      canonical = MapSet.new(Page.control_intent_ids())

      offenders =
        Pages.all_pages()
        |> Enum.filter(fn page ->
          page.control_intent != nil and not MapSet.member?(canonical, page.control_intent)
        end)
        |> Enum.map(& &1.id)

      assert offenders == [],
             "published pages listed out-of-set control intents: #{inspect(offenders)}"
    end
  end
end
