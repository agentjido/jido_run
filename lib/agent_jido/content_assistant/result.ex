defmodule AgentJido.ContentAssistant.Result do
  @moduledoc """
  Normalized citation result used by the content assistant.
  """

  @enforce_keys [:title, :snippet, :url, :source_type]
  defstruct [
    :title,
    :snippet,
    :url,
    :source_type,
    :score,
    :external?,
    :provider,
    :package_id,
    :package_name,
    :package_title,
    :package_version,
    :page_kind,
    :secondary_url,
    :content_type,
    :proof_level
  ]

  @type source_type :: :docs | :blog | :ecosystem | :ecosystem_docs | :examples | :skills

  @typedoc """
  Content type a user can distinguish across search results.

  The first five map directly to the operational-control delivery contract
  (jido-e10-t28): a user searching for a control term should be able to tell a
  definition, guide, package surface, example, and case study apart. The
  remaining values (`:skill`, `:article`, `:reference`) are graceful fallbacks
  so every result still carries a recognizable type.
  """
  @type content_type ::
          :definition
          | :guide
          | :package
          | :example
          | :case_study
          | :skill
          | :article
          | :reference

  @typedoc """
  Strength of evidence behind a result, matching the four proof levels in
  `specs/style-voice.md`: (1) design intent, (2) tested behavior, (3)
  benchmark, (4) production evidence. Each search result names its proof level
  so a user can weigh how much to trust a citation (jido-e10-t28).
  """
  @type proof_level ::
          :design_intent
          | :tested_behavior
          | :benchmark
          | :production_evidence

  @type t :: %__MODULE__{
          title: String.t(),
          snippet: String.t(),
          url: String.t(),
          source_type: source_type(),
          score: number() | nil,
          external?: boolean() | nil,
          provider: atom() | String.t() | nil,
          package_id: String.t() | nil,
          package_name: String.t() | nil,
          package_title: String.t() | nil,
          package_version: String.t() | nil,
          page_kind: atom() | String.t() | nil,
          secondary_url: String.t() | nil,
          content_type: content_type() | nil,
          proof_level: proof_level() | nil
        }

  @content_types [:definition, :guide, :package, :example, :case_study, :skill, :article, :reference]

  @doc """
  Classify a search result into a content type a user can distinguish.

  Operates on a keyword list or map of the signals already on a `Result`
  (`:source_type`, `:page_kind`, `:url`) plus the richer document metadata
  available at retrieval time (`:path`, `:post_type`, `:content_intent`,
  `:evidence_surface`). The classification is the single source of truth used
  by both the local retrieval path (metadata-rich) and the backend normalize
  path (field-only), so every search result resolves to the same type for the
  same content (jido-e10-t28).
  """
  @spec classify_content_type(keyword() | map()) :: content_type() | nil
  def classify_content_type(signals) when is_map(signals) do
    classify_content_type(Map.to_list(signals))
  end

  def classify_content_type(signals) when is_list(signals) do
    # An explicitly declared content type (e.g. from document metadata) wins
    # over inferred classification.
    case normalize_content_type(signal(signals, :content_type)) do
      nil -> classify_by_source(signal(signals, :source_type), signals)
      explicit -> explicit
    end
  end

  defp classify_by_source(:examples, _signals), do: :example

  defp classify_by_source(source_type, _signals) when source_type in [:ecosystem, :ecosystem_docs],
    do: :package

  defp classify_by_source(:skills, _signals), do: :skill

  defp classify_by_source(:blog, signals) do
    if case_study_signal?(signals), do: :case_study, else: :article
  end

  defp classify_by_source(:docs, signals) do
    path = string_signal(signals, :path) || path_from_url(string_signal(signals, :url))
    docs_content_type(path, signal(signals, :page_kind))
  end

  defp classify_by_source(_source_type, signals) do
    if signal(signals, :page_kind) == :guide, do: :guide
  end

  @doc """
  Resolve the proof level for a content type.

  Maps each content type to the strongest evidence it can honestly carry,
  following the proof-level ladder in `specs/style-voice.md`. A case study is
  production evidence; a runnable example or a released package is tested
  behavior; a definition or guide states design intent. Returns `nil` when no
  content type is set (jido-e10-t28).
  """
  @spec proof_level_for(content_type() | nil) :: proof_level() | nil
  def proof_level_for(:case_study), do: :production_evidence
  def proof_level_for(:example), do: :tested_behavior
  def proof_level_for(:package), do: :tested_behavior
  def proof_level_for(:skill), do: :tested_behavior
  def proof_level_for(:reference), do: :tested_behavior
  def proof_level_for(:guide), do: :design_intent
  def proof_level_for(:definition), do: :design_intent
  def proof_level_for(:article), do: :design_intent
  def proof_level_for(nil), do: nil

  @content_type_strings %{
    "definition" => :definition,
    "guide" => :guide,
    "package" => :package,
    "example" => :example,
    "case_study" => :case_study,
    "case study" => :case_study,
    "skill" => :skill,
    "article" => :article,
    "reference" => :reference
  }

  @doc """
  Coerce a raw content-type value (atom or string from document metadata) into
  a canonical atom, or `nil` when it is not a recognized type.
  """
  @spec normalize_content_type(atom() | String.t() | nil) :: content_type() | nil
  def normalize_content_type(value) when value in @content_types, do: value

  def normalize_content_type(value) when is_binary(value) do
    Map.get(@content_type_strings, String.downcase(String.trim(value)))
  end

  def normalize_content_type(_value), do: nil

  defp case_study_signal?(signals) do
    Enum.any?([:post_type, :content_intent, :evidence_surface], fn key ->
      case signal(signals, key) do
        value when is_atom(value) -> value == :case_study
        value when is_binary(value) -> String.downcase(value) =~ "case_study"
        _ -> false
      end
    end)
  end

  defp docs_content_type(path, page_kind) do
    cond do
      page_kind == :guide -> :guide
      is_binary(path) and String.starts_with?(path, "/docs/concepts/") -> :definition
      is_binary(path) and guide_path?(path) -> :guide
      true -> :reference
    end
  end

  defp guide_path?(path) do
    String.starts_with?(path, "/docs/guides/") or
      String.starts_with?(path, "/docs/getting-started") or
      String.starts_with?(path, "/docs/learn/") or
      String.starts_with?(path, "/docs/operations/")
  end

  defp path_from_url(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{path: path} when is_binary(path) and path != "" -> path
      _ -> nil
    end
  end

  defp path_from_url(_url), do: nil

  defp signal(signals, key) when is_list(signals), do: Keyword.get(signals, key)
  defp signal(signals, key) when is_map(signals), do: Map.get(signals, key)

  defp string_signal(signals, key) do
    case signal(signals, key) do
      value when is_binary(value) -> value
      _ -> nil
    end
  end
end
