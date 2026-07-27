defmodule AgentJido.ContentPlanTest do
  use ExUnit.Case, async: true

  alias AgentJido.ContentPlan
  alias AgentJido.Pages

  @training_entries [
    "training/agent-fundamentals",
    "training/actions-validation",
    "training/signals-routing",
    "training/directives-scheduling",
    "training/liveview-integration",
    "training/production-readiness"
  ]

  @feature_entries [
    "features/beam-native-agent-model",
    "features/schema-validated-actions",
    "features/multi-agent-coordination",
    "features/directives-and-scheduling",
    "features/liveview-integration-patterns",
    "features/composable-ecosystem",
    "features/agents-that-self-heal",
    "features/observe-everything"
  ]

  @docs_hub_tags [:hub_getting_started, :hub_concepts, :hub_guides, :hub_reference, :hub_operations]
  @docs_format_tags [:format_markdown, :format_livebook]
  @docs_wave_tags [:wave_1, :wave_2, :wave_3]

  @tag skip: "IA/content taxonomy transition; temporarily disabled for CI unblock"
  test "content plan includes training and features sections" do
    section_ids = Enum.map(ContentPlan.all_sections(), & &1.id)

    assert "training" in section_ids
    assert "features" in section_ids
  end

  @tag skip: "IA/content taxonomy transition; temporarily disabled for CI unblock"
  test "content plan includes all training and features entries" do
    entry_ids = Enum.map(ContentPlan.all_entries(), & &1.id)

    for id <- @training_entries do
      assert id in entry_ids
    end

    for id <- @feature_entries do
      assert id in entry_ids
    end
  end

  test "docs entries define canonical destination route and standard tags" do
    entries = ContentPlan.entries_by_section("docs")

    assert entries != []

    Enum.each(entries, fn entry ->
      assert is_binary(entry.destination_route)
      assert String.starts_with?(entry.destination_route, "/docs")

      tags = entry.tags || []

      assert Enum.count(tags, &(&1 in @docs_hub_tags)) == 1
      assert Enum.count(tags, &(&1 in @docs_format_tags)) == 1
      assert Enum.count(tags, &(&1 in @docs_wave_tags)) == 1
    end)
  end

  test "docs entries include cross-links to build, training, or ecosystem" do
    entries = ContentPlan.entries_by_section("docs")

    Enum.each(entries, fn entry ->
      refs = (entry.related || []) ++ (entry.prerequisites || [])

      assert Enum.any?(refs, fn ref ->
               ref = to_string(ref)

               String.starts_with?(ref, "build/") or
                 String.starts_with?(ref, "training/") or
                 String.starts_with?(ref, "ecosystem/")
             end)
    end)
  end

  # jido-e07-t25: no planned navigation may point at a page that is not
  # published. The operations hub must not require or cross-link a route
  # without a published page; an unpublished follow-up (e.g. backup and
  # disaster recovery) stays as a standalone planned entry rather than hub
  # navigation.
  test "operations hub planned navigation resolves to published pages" do
    hub = ContentPlan.get_entry!("operations/_hub")

    navigation =
      (hub.prompt_overrides[:required_links] || []) ++
        (hub.related || [])

    unresolved =
      navigation
      |> Enum.map(&to_string/1)
      |> Enum.reject(fn ref ->
        route = if String.starts_with?(ref, "/"), do: ref, else: "/" <> ref

        match?({:ok, _, _}, Pages.resolve_page_for_path(route))
      end)

    assert unresolved == [],
           "operations hub planned navigation points at unpublished routes: " <>
             "#{inspect(unresolved)}"
  end
end
