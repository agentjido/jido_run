defmodule AgentJido.Examples do
  @moduledoc """
  Static interactive examples registry for the Jido Workbench.

  Powered by NimblePublisher, this module compiles Markdown files from
  `priv/examples/` into structured `Example` structs at build time.
  Provides indexed lookups by slug, category, and tag.
  """

  alias AgentJido.Examples.Example
  alias AgentJido.Examples.Taxonomy

  # NimblePublisher 2.0 builds entries in Task.async_stream, which cannot
  # lazily compile modules the builder calls. Example.build/3 calls Taxonomy,
  # so force it to compile before extraction.
  Code.ensure_compiled!(AgentJido.Examples.Taxonomy)

  use NimblePublisher,
    build: Example,
    from: Application.app_dir(:agent_jido, "priv/examples/**/*.md"),
    as: :examples,
    highlighters: [:makeup_elixir, :makeup_js, :makeup_html]

  @all_examples Enum.sort_by(@examples, fn e -> {e.category, e.sort_order, e.title} end)
  @examples Enum.filter(@all_examples, &(&1.status == :live))

  @all_examples_by_slug Map.new(@all_examples, &{&1.slug, &1})
  @examples_by_slug Map.new(@examples, &{&1.slug, &1})

  @all_examples_by_category @all_examples |> Enum.group_by(& &1.category) |> Map.new()
  @examples_by_category @examples |> Enum.group_by(& &1.category) |> Map.new()

  @all_tags @all_examples |> Enum.flat_map(& &1.tags) |> Enum.uniq() |> Enum.sort()
  @tags @examples |> Enum.flat_map(& &1.tags) |> Enum.uniq() |> Enum.sort()

  @all_categories @all_examples |> Enum.map(& &1.category) |> Enum.uniq() |> Enum.sort()
  @categories @examples |> Enum.map(& &1.category) |> Enum.uniq() |> Enum.sort()

  @all_statuses @all_examples |> Enum.map(& &1.status) |> Enum.uniq() |> Enum.sort()
  @statuses @examples |> Enum.map(& &1.status) |> Enum.uniq() |> Enum.sort()

  @all_scenario_clusters @all_examples |> Enum.map(& &1.scenario_cluster) |> Enum.uniq() |> Enum.sort()
  @scenario_clusters @examples |> Enum.map(& &1.scenario_cluster) |> Enum.uniq() |> Enum.sort()

  @all_waves @all_examples |> Enum.map(& &1.wave) |> Enum.uniq() |> Enum.sort()
  @waves @examples |> Enum.map(& &1.wave) |> Enum.uniq() |> Enum.sort()

  @all_capability_themes @all_examples |> Enum.map(& &1.capability_theme) |> Enum.uniq() |> Enum.sort()
  @capability_themes @examples |> Enum.map(& &1.capability_theme) |> Enum.uniq() |> Enum.sort()

  @all_journey_stages @all_examples |> Enum.map(& &1.journey_stage) |> Enum.uniq() |> Enum.sort()
  @journey_stages @examples |> Enum.map(& &1.journey_stage) |> Enum.uniq() |> Enum.sort()

  @all_content_intents @all_examples |> Enum.map(& &1.content_intent) |> Enum.uniq() |> Enum.sort()
  @content_intents @examples |> Enum.map(& &1.content_intent) |> Enum.uniq() |> Enum.sort()

  @all_evidence_surfaces @all_examples |> Enum.map(& &1.evidence_surface) |> Enum.uniq() |> Enum.sort()
  @evidence_surfaces @examples |> Enum.map(& &1.evidence_surface) |> Enum.uniq() |> Enum.sort()

  @all_demo_modes @all_examples |> Enum.map(& &1.demo_mode) |> Enum.uniq() |> Enum.sort()
  @demo_modes @examples |> Enum.map(& &1.demo_mode) |> Enum.uniq() |> Enum.sort()

  defmodule NotFoundError do
    defexception [:message, plug_status: 404]
  end

  @spec all_examples() :: [Example.t()]
  def all_examples, do: @examples

  @spec all_examples(keyword()) :: [Example.t()]
  def all_examples(opts) when is_list(opts) do
    opts
    |> base_examples()
    |> filter_examples(opts)
  end

  @spec all_tags() :: [String.t()]
  def all_tags, do: @tags

  @spec all_tags(keyword()) :: [String.t()]
  def all_tags(opts) when is_list(opts) do
    if include_drafts?(opts), do: @all_tags, else: @tags
  end

  @spec all_categories() :: [atom()]
  def all_categories, do: @categories

  @spec all_categories(keyword()) :: [atom()]
  def all_categories(opts) when is_list(opts) do
    if include_drafts?(opts), do: @all_categories, else: @categories
  end

  @spec all_statuses() :: [atom()]
  def all_statuses, do: @statuses

  @spec all_statuses(keyword()) :: [atom()]
  def all_statuses(opts) when is_list(opts) do
    if include_drafts?(opts), do: @all_statuses, else: @statuses
  end

  @spec all_scenario_clusters() :: [atom()]
  def all_scenario_clusters, do: @scenario_clusters

  @spec all_scenario_clusters(keyword()) :: [atom()]
  def all_scenario_clusters(opts) when is_list(opts) do
    if include_drafts?(opts), do: @all_scenario_clusters, else: @scenario_clusters
  end

  @spec all_waves() :: [atom()]
  def all_waves, do: @waves

  @spec all_waves(keyword()) :: [atom()]
  def all_waves(opts) when is_list(opts) do
    if include_drafts?(opts), do: @all_waves, else: @waves
  end

  @spec all_capability_themes() :: [atom()]
  def all_capability_themes, do: @capability_themes

  @spec all_capability_themes(keyword()) :: [atom()]
  def all_capability_themes(opts) when is_list(opts) do
    if include_drafts?(opts), do: @all_capability_themes, else: @capability_themes
  end

  @spec all_journey_stages() :: [atom()]
  def all_journey_stages, do: @journey_stages

  @spec all_journey_stages(keyword()) :: [atom()]
  def all_journey_stages(opts) when is_list(opts) do
    if include_drafts?(opts), do: @all_journey_stages, else: @journey_stages
  end

  @spec all_content_intents() :: [atom()]
  def all_content_intents, do: @content_intents

  @spec all_content_intents(keyword()) :: [atom()]
  def all_content_intents(opts) when is_list(opts) do
    if include_drafts?(opts), do: @all_content_intents, else: @content_intents
  end

  @spec all_evidence_surfaces() :: [atom()]
  def all_evidence_surfaces, do: @evidence_surfaces

  @spec all_evidence_surfaces(keyword()) :: [atom()]
  def all_evidence_surfaces(opts) when is_list(opts) do
    if include_drafts?(opts), do: @all_evidence_surfaces, else: @evidence_surfaces
  end

  @spec all_demo_modes() :: [atom()]
  def all_demo_modes, do: @demo_modes

  @spec all_demo_modes(keyword()) :: [atom()]
  def all_demo_modes(opts) when is_list(opts) do
    if include_drafts?(opts), do: @all_demo_modes, else: @demo_modes
  end

  @spec get_example(String.t()) :: Example.t() | nil
  def get_example(slug), do: Map.get(@examples_by_slug, slug)

  @spec get_example(String.t(), keyword()) :: Example.t() | nil
  def get_example(slug, opts) when is_list(opts) do
    if include_drafts?(opts) do
      Map.get(@all_examples_by_slug, slug)
    else
      Map.get(@examples_by_slug, slug)
    end
  end

  @spec get_example!(String.t()) :: Example.t()
  def get_example!(slug) do
    get_example(slug) ||
      raise NotFoundError, "example with slug=#{slug} not found"
  end

  @spec get_example!(String.t(), keyword()) :: Example.t()
  def get_example!(slug, opts) when is_list(opts) do
    get_example(slug, opts) ||
      raise NotFoundError, "example with slug=#{slug} not found"
  end

  @spec examples_by_category(atom()) :: [Example.t()]
  def examples_by_category(category), do: Map.get(@examples_by_category, category, [])

  @spec examples_by_category(atom(), keyword()) :: [Example.t()]
  def examples_by_category(category, opts) when is_list(opts) do
    if include_drafts?(opts) do
      Map.get(@all_examples_by_category, category, [])
    else
      Map.get(@examples_by_category, category, [])
    end
  end

  @spec examples_by_tag(String.t()) :: [Example.t()]
  def examples_by_tag(tag), do: Enum.filter(@examples, &(tag in &1.tags))

  @spec examples_by_tag(String.t(), keyword()) :: [Example.t()]
  def examples_by_tag(tag, opts) when is_list(opts) do
    source = if include_drafts?(opts), do: @all_examples, else: @examples
    Enum.filter(source, &(tag in &1.tags))
  end

  @spec example_count() :: non_neg_integer()
  def example_count, do: length(@examples)

  @spec example_count(keyword()) :: non_neg_integer()
  def example_count(opts) when is_list(opts) do
    if include_drafts?(opts), do: length(@all_examples), else: length(@examples)
  end

  @spec taxonomy_enums() :: map()
  def taxonomy_enums do
    %{
      statuses: Taxonomy.statuses(),
      demo_modes: Taxonomy.demo_modes(),
      scenario_clusters: Taxonomy.scenario_clusters(),
      waves: Taxonomy.waves(),
      journey_stages: Taxonomy.journey_stages(),
      content_intents: Taxonomy.content_intents(),
      capability_themes: Taxonomy.capability_themes(),
      evidence_surfaces: Taxonomy.evidence_surfaces()
    }
  end

  defp include_drafts?(opts) do
    Keyword.get(opts, :include_drafts, false) or Keyword.get(opts, :include_unpublished, false)
  end

  defp base_examples(opts) do
    if include_drafts?(opts), do: @all_examples, else: @examples
  end

  defp filter_examples(examples, opts) do
    examples
    |> maybe_filter_value(:status, opts)
    |> maybe_filter_value(:category, opts)
    |> maybe_filter_value(:difficulty, opts)
    |> maybe_filter_value(:scenario_cluster, opts)
    |> maybe_filter_value(:wave, opts)
    |> maybe_filter_value(:capability_theme, opts)
    |> maybe_filter_value(:journey_stage, opts)
    |> maybe_filter_value(:content_intent, opts)
    |> maybe_filter_value(:evidence_surface, opts)
    |> maybe_filter_value(:demo_mode, opts)
    |> maybe_filter_tag(opts)
  end

  defp maybe_filter_value(examples, key, opts) do
    case Keyword.get(opts, key) do
      nil ->
        examples

      value ->
        Enum.filter(examples, fn example ->
          Map.get(example, key) == value
        end)
    end
  end

  defp maybe_filter_tag(examples, opts) do
    case Keyword.get(opts, :tag) do
      nil ->
        examples

      tag ->
        Enum.filter(examples, fn example ->
          tag in List.wrap(example.tags)
        end)
    end
  end
end
