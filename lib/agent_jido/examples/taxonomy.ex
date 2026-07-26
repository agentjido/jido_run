defmodule AgentJido.Examples.Taxonomy do
  @moduledoc """
  Canonical taxonomy and normalization helpers for examples metadata.

  Aligns examples with the site taxonomy model in `specs/taxonomy.md`.
  """

  @statuses [:draft, :live]
  @demo_modes [:real, :simulated]

  @scenario_clusters [
    :core_mechanics,
    :coordination,
    :ai_tool_use,
    :liveview_product,
    :ops_governance,
    :foundational_legacy
  ]

  @waves [:l1, :l2, :legacy]
  @journey_stages [:awareness, :orientation, :evaluation, :activation, :operationalization, :expansion, :advocacy]
  @content_intents [:explanation, :guide, :tutorial, :reference, :cookbook, :case_study, :decision_brief]

  @capability_themes [
    :runtime_foundations,
    :reliability_architecture,
    :coordination_orchestration,
    :operations_observability,
    :ai_intelligence,
    :execution_tooling,
    :integration_interop,
    :adoption_architecture,
    :learning_enablement,
    :community_adoption
  ]

  @evidence_surfaces [:package, :runnable_example, :training_module, :docs_reference, :runbook, :case_study]

  # Operational-control types a public example can prove it exercises (jido-e08
  # E08-T35). Each example may list any subset of these in its card contract;
  # the example frontmatter value is normalized to this canonical set. The
  # acceptance fixes the eight members: identity context, authorization, policy,
  # quota, approval, history, observation, and redaction.
  @control_types [
    :identity_context,
    :authorization,
    :policy,
    :quota,
    :approval,
    :history,
    :observation,
    :redaction
  ]

  # Task-oriented labels that describe the user job an example proves, intended
  # to replace internal taxonomy terms on public cards (jido-e08 E08-T01).
  @tasks [
    :chat_and_support,
    :research,
    :coding,
    :browser_work,
    :data_and_documents,
    :scheduling,
    :persistence,
    :recovery,
    :coordination,
    :observability
  ]

  @type metadata :: %{
          status: atom(),
          published: boolean(),
          scenario_cluster: atom(),
          wave: atom(),
          journey_stage: atom(),
          content_intent: atom(),
          capability_theme: atom(),
          evidence_surface: atom(),
          demo_mode: atom(),
          control_types: [atom()],
          tasks: [atom()]
        }

  @spec statuses() :: [atom()]
  def statuses, do: @statuses

  @spec demo_modes() :: [atom()]
  def demo_modes, do: @demo_modes

  @spec scenario_clusters() :: [atom()]
  def scenario_clusters, do: @scenario_clusters

  @spec waves() :: [atom()]
  def waves, do: @waves

  @spec journey_stages() :: [atom()]
  def journey_stages, do: @journey_stages

  @spec content_intents() :: [atom()]
  def content_intents, do: @content_intents

  @spec capability_themes() :: [atom()]
  def capability_themes, do: @capability_themes

  @spec evidence_surfaces() :: [atom()]
  def evidence_surfaces, do: @evidence_surfaces

  @spec control_types() :: [atom()]
  def control_types, do: @control_types

  @spec tasks() :: [atom()]
  def tasks, do: @tasks

  @spec metadata(keyword() | map()) :: metadata()
  def metadata(attrs) when is_list(attrs), do: attrs |> Map.new() |> metadata()

  def metadata(attrs) when is_map(attrs) do
    tags = Map.get(attrs, :tags) || Map.get(attrs, "tags") || []
    slug = value_for(attrs, :slug)
    category = normalize_enum(value_for(attrs, :category), [:core, :ai, :production], :core)

    status =
      case normalize_enum(value_for(attrs, :status), @statuses, nil) do
        nil ->
          case value_for(attrs, :published) do
            true -> :live
            false -> :draft
            _ -> :draft
          end

        explicit ->
          explicit
      end

    scenario_cluster =
      attrs
      |> value_for(:scenario_cluster)
      |> normalize_enum(@scenario_clusters, nil)
      |> Kernel.||(infer_scenario_cluster(slug, tags, category))

    wave =
      attrs
      |> value_for(:wave)
      |> normalize_enum(@waves, nil)
      |> Kernel.||(infer_wave(tags))

    journey_stage =
      attrs
      |> value_for(:journey_stage)
      |> normalize_enum(@journey_stages, :activation)

    content_intent =
      attrs
      |> value_for(:content_intent)
      |> normalize_enum(@content_intents, :tutorial)

    capability_theme =
      attrs
      |> value_for(:capability_theme)
      |> normalize_enum(@capability_themes, nil)
      |> Kernel.||(infer_capability_theme(scenario_cluster, category, tags))

    evidence_surface =
      attrs
      |> value_for(:evidence_surface)
      |> normalize_enum(@evidence_surfaces, :runnable_example)

    demo_mode =
      attrs
      |> value_for(:demo_mode)
      |> normalize_enum(@demo_modes, nil)
      |> Kernel.||(infer_demo_mode(tags, category))

    control_types =
      attrs
      |> value_for(:control_types)
      |> normalize_control_types()

    %{
      status: status,
      published: status == :live,
      scenario_cluster: scenario_cluster,
      wave: wave,
      journey_stage: journey_stage,
      content_intent: content_intent,
      capability_theme: capability_theme,
      evidence_surface: evidence_surface,
      demo_mode: demo_mode,
      control_types: control_types
    }
  end

  defp value_for(attrs, key) do
    Map.get(attrs, key) || Map.get(attrs, Atom.to_string(key))
  end

  defp normalize_enum(nil, _allowed, default), do: default

  defp normalize_enum(value, allowed, default) when is_atom(value) do
    if Enum.member?(allowed, value), do: value, else: default
  end

  defp normalize_enum(value, allowed, default) when is_binary(value) do
    normalized = value |> String.trim() |> String.downcase()

    Enum.find(allowed, default, fn candidate ->
      Atom.to_string(candidate) == normalized
    end)
  end

  defp normalize_enum(_value, _allowed, default), do: default

  # The card-contract control_types field is a list; normalize each member to the
  # canonical set, dropping unknowns and duplicates so the published contract
  # only ever carries a clean subset of AgentJido.Examples.Taxonomy.control_types/0.
  defp normalize_control_types(nil), do: []

  defp normalize_control_types(values) when is_list(values) do
    values
    |> Enum.map(&to_control_type/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp normalize_control_types(value), do: normalize_control_types([value])

  defp to_control_type(value) when is_atom(value) do
    if value in @control_types, do: value
  end

  defp to_control_type(value) when is_binary(value) do
    normalized = value |> String.trim() |> String.downcase()

    Enum.find(@control_types, fn candidate ->
      Atom.to_string(candidate) == normalized
    end)
  end

  defp to_control_type(_), do: nil

  defp infer_scenario_cluster(slug, tags, category) do
    cond do
      slug in ["counter-agent", "demand-tracker-agent"] -> :foundational_legacy
      has_any?(tags, ["core-mechanics", "core_mechanics"]) -> :core_mechanics
      has_any?(tags, ["coordination"]) -> :coordination
      has_any?(tags, ["ai-tool-use", "ai_tool_use"]) -> :ai_tool_use
      has_any?(tags, ["liveview-product", "liveview_product"]) -> :liveview_product
      has_any?(tags, ["ops-governance", "ops_governance"]) -> :ops_governance
      category == :ai -> :ai_tool_use
      true -> :foundational_legacy
    end
  end

  defp infer_wave(tags) do
    cond do
      has_any?(tags, ["l1"]) -> :l1
      has_any?(tags, ["l2"]) -> :l2
      true -> :legacy
    end
  end

  defp infer_capability_theme(scenario_cluster, category, tags) do
    cond do
      has_any?(tags, ["ops", "observability", "telemetry"]) -> :operations_observability
      has_any?(tags, ["llm", "ai", "browser", "tool-use", "tool_use"]) -> :ai_intelligence
      scenario_cluster == :coordination -> :coordination_orchestration
      scenario_cluster == :ops_governance -> :operations_observability
      scenario_cluster == :liveview_product -> :integration_interop
      scenario_cluster == :ai_tool_use -> :ai_intelligence
      category == :production -> :reliability_architecture
      true -> :runtime_foundations
    end
  end

  defp infer_demo_mode(tags, _category) do
    if has_any?(tags, ["simulated", "fake", "mocked"]), do: :simulated, else: :real
  end

  defp has_any?(tags, candidates) do
    normalized =
      tags
      |> List.wrap()
      |> Enum.map(&normalize_tag/1)
      |> Enum.reject(&is_nil/1)
      |> MapSet.new()

    Enum.any?(candidates, fn candidate ->
      MapSet.member?(normalized, normalize_tag(candidate))
    end)
  end

  defp normalize_tag(tag) when is_atom(tag), do: tag |> Atom.to_string() |> normalize_tag()

  defp normalize_tag(tag) when is_binary(tag) do
    tag
    |> String.trim()
    |> String.downcase()
    |> String.replace(~r/\s+/, "_")
    |> String.replace("-", "_")
    |> case do
      "" -> nil
      normalized -> normalized
    end
  end

  defp normalize_tag(_), do: nil
end
