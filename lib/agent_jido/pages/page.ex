defmodule AgentJido.Pages.Page do
  @moduledoc """
  Unified Page schema combining Documentation.Document and Training.Module fields.

  Represents a page parsed from a Markdown or Livebook file under `priv/pages/`.
  Category is derived from the first subdirectory (docs/, training/, features/,
  build/, community/, compare/).

  Uses Zoi-validated schemas with rich metadata for validation, freshness
  tracking, SEO, quality assessment, and Livebook integration.

  ## Fields

  ### Core
  - `id` - Unique identifier derived from path (e.g., "chat-response")
  - `title` - Page title from frontmatter
  - `description` - Optional description
  - `category` - Category atom derived from path (:docs, :training, :features, :build, :community, :compare)
  - `tags` - List of tag atoms for filtering
  - `order` - Sort order within category (default: 9999)
  - `body` - Parsed HTML content
  - `path` - URL path relative to pages root
  - `source_path` - Original file path on disk
  - `is_livebook` - Whether this is a .livemd file
  - `github_url` - Link to view on GitHub
  - `livebook_url` - Link to run in Livebook
  - `menu_path` - List of path segments for menu hierarchy
  - `draft` - If true, page is hidden from listings
  - `in_menu` - If false, page is hidden from navigation menu
  - `menu_label` - Override title in menu display
  - `legacy_paths` - Legacy URL aliases that should redirect to this page
  - `status` - Content maturity (`:published`, `:draft`, `:experimental`). Distinct from
    `draft` (which hides a page from public indexes): a *visible* page can still carry a
    `:draft` or `:experimental` status so hub cards label it instead of letting it look
    complete (E06-T24).

  ### Document metadata
  - `doc_type` - Document type (:guide, :reference, :tutorial, :explanation, :cookbook)
  - `audience` - Target audience (:beginner, :intermediate, :advanced)
  - `word_count` - Computed word count
  - `reading_time_minutes` - Computed reading time
  - `related_docs` - List of related document IDs
  - `related_posts` - List of related blog post IDs
  - `related_packages` - List of `%{id, role}` maps naming the ecosystem packages a
    guide uses and the role each plays in it; rendered near the guide's instructions
    with each package's maturity (E06-T26)
  - `related_examples` - List of `%{id, role}` maps naming the published interactive
    examples that prove a guide and the role each plays in it; rendered near the
    guide's instructions with each example's outcome as runnable proof (E06-T27)
  - `control_types` - List of operational-control surfaces the page documents
    (:identity_context, :authorization, :policy, :quota, :approval, :history,
    :observation, :redaction); normalized to the canonical set and used by the
    Docs control-type filter (E06-T37)
  - `control_intent` - Optional operational-control reader intent the page primarily
    serves (:evaluate, :enforce, :preserve, :observe, :investigate); distinct from
    `control_types`, which names the surface (E06-T37)

  ### Training-specific (optional)
  - `track` - Training track (:foundations, :coordination, :integration, :operations)
  - `difficulty` - Difficulty level (:beginner, :intermediate, :advanced)
  - `duration_minutes` - Estimated duration in minutes
  - `prerequisites` - List of prerequisite page IDs
  - `learning_outcomes` - List of learning outcome strings

  ### Validation
  - `last_validated` - ISO date this page's code was last validated
  - `tested_with` - Map of package/version pairs this page was validated against
  - `owner` - Accountable owner for executable pages (who re-validates it when it goes stale)
  - `sources` - External reference sources backing a page's claims (`[%{label, url}]`), e.g. a
    comparison page's competitor repo and docs. Rendered so old facts stay visible (E12-T19).

  ### SEO
  - `og_image` - Per-page Open Graph image override
  - `seo` - Nested SEO metadata map
  - `validation` - Nested validation metadata
  - `freshness` - Nested freshness tracking metadata
  - `quality` - Nested quality assessment metadata
  - `livebook` - Nested Livebook integration metadata
  """

  @github_repo "https://github.com/agentjido/agentjido_xyz"
  alias AgentJido.Html.CodeEntityDecoder

  # Operational-control surfaces a page can document (jido-e06-t37). A page may
  # cover several; the frontmatter value is normalized to this canonical set at
  # build time. The atoms are identical to AgentJido.Examples.Taxonomy.control_types/0
  # so the site carries one notion of a control type across docs and examples.
  # The seven the acceptance names — identity context, authorization, policy,
  # history, observation, approval, and redaction — are always present; quota is
  # included for parity with the examples taxonomy (it is not required by the
  # acceptance, but rate-limits-and-cost-budgets documents it).
  @control_types [
    %{id: :identity_context, label: "Identity context"},
    %{id: :authorization, label: "Authorization"},
    %{id: :policy, label: "Policy"},
    %{id: :quota, label: "Quota"},
    %{id: :approval, label: "Approval"},
    %{id: :history, label: "History"},
    %{id: :observation, label: "Observation"},
    %{id: :redaction, label: "Redaction"}
  ]

  @control_type_ids Enum.map(@control_types, & &1.id)

  # The operational-control reader intent a page primarily serves (jido-e06-t37).
  # Distinct from control_types (the surface the page documents): intent names
  # the reader's job. A page picks one primary intent; pages that are not about
  # operational control carry none.
  @control_intents [
    %{id: :evaluate, label: "Evaluate control coverage"},
    %{id: :enforce, label: "Enforce a control"},
    %{id: :preserve, label: "Preserve context or history"},
    %{id: :observe, label: "Observe the system"},
    %{id: :investigate, label: "Investigate what happened"}
  ]

  @control_intent_ids Enum.map(@control_intents, & &1.id)

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.string(description: "Unique identifier derived from path"),
              title: Zoi.string(description: "Page title from frontmatter"),
              description: Zoi.string(description: "Optional description") |> Zoi.optional(),
              category: Zoi.atom(description: "Category atom derived from path (:docs, :training, :features, :build, :community, :compare)"),
              tags: Zoi.any(description: "List of tag atoms for filtering") |> Zoi.default([]),
              order: Zoi.integer(description: "Sort order within category") |> Zoi.default(9999),
              body: Zoi.string(description: "Rendered HTML content") |> Zoi.default(""),
              path:
                Zoi.string(description: "URL path relative to pages root")
                |> Zoi.default(""),
              source_path: Zoi.string(description: "Absolute file path on disk") |> Zoi.default(""),
              is_livebook:
                Zoi.boolean(description: "Whether this is a .livemd file")
                |> Zoi.default(false),
              github_url: Zoi.string(description: "Link to view on GitHub") |> Zoi.default(""),
              livebook_url: Zoi.string(description: "Link to run in Livebook") |> Zoi.optional(),
              menu_path:
                Zoi.any(description: "List of path segments for menu hierarchy")
                |> Zoi.default([]),
              draft:
                Zoi.boolean(description: "If true, page is hidden from listings")
                |> Zoi.default(false),
              in_menu:
                Zoi.boolean(description: "If false, page is hidden from navigation menu")
                |> Zoi.default(true),
              menu_label: Zoi.string(description: "Override title in menu display") |> Zoi.optional(),
              # Content maturity — distinct from the `draft` visibility boolean. A visible
              # page (draft: false) can still be :draft or :experimental so hub cards label
              # it instead of letting it look complete (E06-T24).
              status:
                Zoi.atom(
                  description:
                    "Content maturity (:published | :draft | :experimental). A visible page with :draft or :experimental is labeled on hub cards."
                )
                |> Zoi.default(:published),
              legacy_paths:
                Zoi.any(description: "Legacy URL paths that should redirect to this page")
                |> Zoi.default([]),
              # Per-page quick links control
              quick_links:
                Zoi.any(description: "Custom quick links list of maps with :label, :href, and optional :icon keys")
                |> Zoi.default([]),
              quick_links_mode:
                Zoi.atom(description: "How custom quick_links merge with defaults: :append or :replace")
                |> Zoi.default(:append),
              quick_links_hide_defaults:
                Zoi.any(description: "List of default link labels to hide (e.g. [\"HexDocs\", \"Hex.pm\"])")
                |> Zoi.default([]),
              # Document metadata
              doc_type:
                Zoi.atom(description: "Document type (:guide, :reference, :tutorial, :explanation, :cookbook)")
                |> Zoi.default(:guide),
              audience:
                Zoi.atom(description: "Target audience (:beginner, :intermediate, :advanced)")
                |> Zoi.default(:beginner),
              word_count: Zoi.integer(description: "Computed word count") |> Zoi.default(0),
              reading_time_minutes: Zoi.integer(description: "Computed reading time in minutes") |> Zoi.default(0),
              related_docs: Zoi.any(description: "List of related document IDs") |> Zoi.default([]),
              related_posts: Zoi.any(description: "List of related blog post IDs") |> Zoi.default([]),
              # E06-T26: the ecosystem packages a guide uses and the role each
              # plays in it. Each entry is %{id: "jido", role: "..."}; the docs
              # shell resolves each id to its public ecosystem package so the
              # package's role and maturity render near the guide's instructions.
              related_packages:
                Zoi.any(
                  description:
                    "List of %{id, role} maps: ecosystem package ids a guide uses and the role each plays in it (rendered near instructions with each package's maturity)"
                )
                |> Zoi.default([]),
              # E06-T27: the runnable examples that prove a guide. Each entry is
              # %{id: "counter-agent", role: "..."}; the docs shell resolves each
              # id to its published interactive example so a reader reaches
              # runnable proof of the guide's instructions without leaving the page.
              related_examples:
                Zoi.any(
                  description:
                    "List of %{id, role} maps: published interactive example slugs that prove a guide and the role each plays in it (rendered near instructions with each example's outcome)"
                )
                |> Zoi.default([]),
              # E06-T37: the operational-control surfaces a page documents
              # (identity context, authorization, policy, quota, approval,
              # history, observation, redaction). A page may cover several; the
              # frontmatter value is normalized to the canonical set in
              # normalize_control_types/1. The Docs control-type filter uses it
              # so a reader can find the page for each control surface.
              control_types:
                Zoi.any(
                  description:
                    "Operational-control surfaces a page documents (canonical set in AgentJido.Pages.Page.control_types/0); normalized at build time"
                )
                |> Zoi.default([]),
              # E06-T37: the operational-control reader intent a page primarily
              # serves (evaluate, enforce, preserve, observe, investigate).
              # Optional; pages that are not about operational control carry
              # none. Distinct from control_types (the surface): intent names
              # the reader's job.
              control_intent:
                Zoi.atom(
                  description:
                    "Operational-control reader intent a page primarily serves (canonical set in AgentJido.Pages.Page.control_intents/0); optional"
                )
                |> Zoi.optional(),
              # Training-specific fields (optional)
              track:
                Zoi.atom(description: "Training track (:foundations, :coordination, :integration, :operations)")
                |> Zoi.optional(),
              difficulty:
                Zoi.atom(description: "Difficulty level (:beginner, :intermediate, :advanced)")
                |> Zoi.optional(),
              duration_minutes: Zoi.integer(description: "Estimated duration in minutes") |> Zoi.optional(),
              prerequisites: Zoi.any(description: "List of prerequisite page IDs") |> Zoi.default([]),
              learning_outcomes: Zoi.any(description: "List of learning outcome strings") |> Zoi.default([]),
              # Validation metadata (author-set; surfaced to readers so they can
              # see the last validation date and the versions a page was tested with)
              last_validated:
                Zoi.string(description: "ISO date this page's code was last validated against tested_with")
                |> Zoi.default(""),
              tested_with:
                Zoi.any(description: "Map of package/version pairs this page was validated against (e.g. %{jido: \"2.3.2\"})")
                |> Zoi.default(%{}),
              # Ownership metadata (author-set; required on executable pages so a
              # stale runnable notebook has a named accountable owner to ping —
              # pairs with last_validated/tested_with as the freshness+ownership
              # trio enforced by the E12-T14 publication gate).
              owner:
                Zoi.string(description: "Accountable owner for executable pages (who re-validates the notebook when it goes stale)")
                |> Zoi.default(""),
              # External reference sources (author-set; jido-e12-t19). Each entry
              # is %{label, url} naming a URL the page's facts were checked
              # against — a comparison page's competitor repo and docs. Rendered
              # so old facts stay visible and re-checkable: a reader can see
              # where a comparison came from and re-verify it. Distinct from the
              # internal validation repos/source_modules in :validation (those
              # name this project's own code); :sources names external evidence.
              sources:
                Zoi.any(
                  description:
                    "External reference sources backing a page's claims — list of %{label, url} maps (e.g. a comparison page's competitor repo and docs). Rendered so old facts stay visible and re-checkable."
                )
                |> Zoi.default([]),
              # SEO top-level override
              og_image: Zoi.string(description: "Per-page Open Graph image override") |> Zoi.optional(),
              # Nested metadata maps
              validation:
                Zoi.map(
                  %{
                    repos: Zoi.any(description: "Referenced repos") |> Zoi.default([]),
                    source_modules: Zoi.any(description: "Referenced source modules") |> Zoi.default([]),
                    source_files: Zoi.any(description: "Referenced source files") |> Zoi.default([]),
                    ecosystem_packages: Zoi.any(description: "Referenced ecosystem packages") |> Zoi.default([]),
                    min_elixir_version:
                      Zoi.string(description: "Minimum Elixir version required")
                      |> Zoi.optional(),
                    min_package_versions: Zoi.any(description: "Minimum package versions") |> Zoi.default([]),
                    claims: Zoi.any(description: "Factual claims to verify") |> Zoi.default([]),
                    feature_flags: Zoi.any(description: "Required feature flags") |> Zoi.default([])
                  },
                  description: "Validation metadata"
                )
                |> Zoi.default(%{}),
              freshness:
                Zoi.map(
                  %{
                    content_hash: Zoi.string(description: "SHA256 hash of content") |> Zoi.default(""),
                    stale_after_days:
                      Zoi.integer(description: "Days before content is considered stale")
                      |> Zoi.default(120),
                    last_refreshed_at: Zoi.string(description: "ISO8601 date of last refresh") |> Zoi.optional(),
                    last_validated_at:
                      Zoi.string(description: "ISO8601 date of last validation")
                      |> Zoi.optional(),
                    validation_status: Zoi.atom(description: "Current validation status") |> Zoi.default(:unknown),
                    validated_by: Zoi.string(description: "Who last validated") |> Zoi.optional(),
                    validation_notes: Zoi.string(description: "Notes from last validation") |> Zoi.optional()
                  },
                  description: "Freshness tracking metadata"
                )
                |> Zoi.default(%{}),
              seo:
                Zoi.map(
                  %{
                    canonical_url: Zoi.string(description: "Canonical URL") |> Zoi.optional(),
                    og_title: Zoi.string(description: "Open Graph title") |> Zoi.optional(),
                    og_description: Zoi.string(description: "Open Graph description") |> Zoi.optional(),
                    og_image: Zoi.string(description: "Open Graph image URL") |> Zoi.optional(),
                    keywords: Zoi.any(description: "SEO keywords") |> Zoi.default([]),
                    noindex:
                      Zoi.boolean(description: "Whether to noindex this page")
                      |> Zoi.default(false)
                  },
                  description: "SEO metadata"
                )
                |> Zoi.default(%{}),
              quality:
                Zoi.map(
                  %{
                    reviewed_by: Zoi.any(description: "List of reviewers") |> Zoi.default([]),
                    reviewed_at: Zoi.string(description: "ISO8601 date of last review") |> Zoi.optional(),
                    confidence: Zoi.number(description: "Confidence score 0.0-1.0") |> Zoi.default(0.7),
                    examples_present:
                      Zoi.boolean(description: "Whether examples are present")
                      |> Zoi.default(false),
                    tested_examples:
                      Zoi.boolean(description: "Whether examples have been tested")
                      |> Zoi.default(false)
                  },
                  description: "Quality assessment metadata"
                )
                |> Zoi.default(%{}),
              livebook:
                Zoi.map(
                  %{
                    runnable:
                      Zoi.boolean(description: "Whether livebook is runnable")
                      |> Zoi.default(false),
                    elixir_version: Zoi.string(description: "Required Elixir version") |> Zoi.optional(),
                    mix_deps: Zoi.any(description: "Required Mix dependencies") |> Zoi.default([]),
                    required_env_vars: Zoi.any(description: "Required environment variables") |> Zoi.default([]),
                    required_services: Zoi.any(description: "Required external services") |> Zoi.default([]),
                    requires_network:
                      Zoi.boolean(description: "Whether network access is required")
                      |> Zoi.default(false),
                    setup_instructions: Zoi.string(description: "Setup instructions") |> Zoi.optional()
                  },
                  description: "Livebook integration metadata"
                )
                |> Zoi.default(%{})
            },
            coerce: true
          )

  @type t :: unquote(Zoi.type_spec(@schema))

  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  @doc """
  Returns the Zoi schema for introspection.
  """
  @spec schema() :: Zoi.t()
  def schema, do: @schema

  # --- Operational-control taxonomy (jido-e06-t37) ---
  #
  # The canonical sets live here (not on the Pages context) because they are
  # needed at build time, before the Pages compile-time indexes exist. The
  # Pages context re-exposes them alongside its lookup and filter helpers.

  @doc """
  The operational-control surfaces a page can document, with display labels.

  Each entry is `%{id: atom(), label: String.t()}`. The atoms are identical to
  `AgentJido.Examples.Taxonomy.control_types/0` so docs and examples share one
  control-type vocabulary. See jido-e06-t37.
  """
  @spec control_types() :: [%{id: atom(), label: String.t()}]
  def control_types, do: @control_types

  @doc """
  The control-surface atoms a page can carry, in canonical order.
  """
  @spec control_type_ids() :: [atom()]
  def control_type_ids, do: @control_type_ids

  @doc """
  Human display label for a control surface, or `nil` when it is unknown.
  """
  @spec control_type_label(atom()) :: String.t() | nil
  def control_type_label(control_type) when is_atom(control_type) do
    Enum.find_value(@control_types, fn %{id: id, label: label} ->
      if id == control_type, do: label
    end)
  end

  def control_type_label(_), do: nil

  @doc """
  The operational-control reader intents a page can serve, with display labels.
  See jido-e06-t37.
  """
  @spec control_intents() :: [%{id: atom(), label: String.t()}]
  def control_intents, do: @control_intents

  @doc """
  The control-intent atoms a page can carry, in canonical order.
  """
  @spec control_intent_ids() :: [atom()]
  def control_intent_ids, do: @control_intent_ids

  @doc """
  Human display label for a control intent, or `nil` when it is unknown.
  """
  @spec control_intent_label(atom()) :: String.t() | nil
  def control_intent_label(intent) when is_atom(intent) do
    Enum.find_value(@control_intents, fn %{id: id, label: label} ->
      if id == intent, do: label
    end)
  end

  def control_intent_label(_), do: nil

  @doc """
  Normalizes a frontmatter `control_types` value to a clean subset of the
  canonical set: unknown members are dropped and duplicates removed, so a
  published page only ever carries control surfaces the Docs filter knows.

  Accepts atoms, strings (matched case/whitespace-insensitively to the atom),
  a single value, or `nil`.
  """
  @spec normalize_control_types(term()) :: [atom()]
  def normalize_control_types(nil), do: []

  def normalize_control_types(values) when is_list(values) do
    values
    |> Enum.map(&to_control_type/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  def normalize_control_types(value), do: normalize_control_types([value])

  @doc """
  Normalizes a frontmatter `control_intent` value to a canonical intent atom,
  or `nil` when it is missing or unknown. Accepts an atom or a string.
  """
  @spec normalize_control_intent(term()) :: atom() | nil
  def normalize_control_intent(nil), do: nil

  def normalize_control_intent(value) when is_atom(value) do
    if value in @control_intent_ids, do: value
  end

  def normalize_control_intent(value) when is_binary(value) do
    normalized = value |> String.trim() |> String.downcase()

    Enum.find(@control_intent_ids, fn candidate ->
      Atom.to_string(candidate) == normalized
    end)
  end

  def normalize_control_intent(_), do: nil

  defp to_control_type(value) when is_atom(value) do
    if value in @control_type_ids, do: value
  end

  defp to_control_type(value) when is_binary(value) do
    normalized = value |> String.trim() |> String.downcase()

    Enum.find(@control_type_ids, fn candidate ->
      Atom.to_string(candidate) == normalized
    end)
  end

  defp to_control_type(_), do: nil

  @doc """
  Builds a Page struct from a file.

  Called by NimblePublisher at compile time for each file matching the glob.

  ## Parameters

  - `filename` - The full path to the source file
  - `attrs` - Map of metadata attributes from frontmatter
  - `body` - The parsed HTML content of the file
  """
  @spec build(String.t(), map(), String.t()) :: t()
  def build(filename, attrs, body) do
    body = CodeEntityDecoder.decode_quotes_in_code(body)

    order = Map.get(attrs, :order, 9999)

    full_app_path = Application.app_dir(:agent_jido)
    source_path = filename
    app_relative_path = String.replace(filename, full_app_path, "")

    doc_root = "/priv/pages"
    path = String.replace(app_relative_path, doc_root, "")

    # Derive category from first path segment; frontmatter can override
    category = Map.get(attrs, :category) || derive_category(path)

    is_livebook = String.ends_with?(filename, ".livemd")

    path = normalize_path(path)
    id = derive_id(path)
    menu_path = derive_menu_path(path)

    github_url = build_github_url(doc_root, path, is_livebook)
    livebook_url = Map.get(attrs, :livebook_url) || build_livebook_url(path, is_livebook)

    word_count = compute_word_count(body)
    reading_time_minutes = max(1, div(word_count, 200))

    content_hash =
      :crypto.hash(:sha256, "#{filename}\n#{body}") |> Base.encode16(case: :lower)

    user_freshness = Map.get(attrs, :freshness, %{})
    computed_freshness = Map.merge(%{content_hash: content_hash}, user_freshness)

    attrs =
      attrs
      |> Map.put(:id, id)
      |> Map.put(:category, category)
      |> Map.put(:body, body)
      |> Map.put(:path, path)
      |> Map.put(:source_path, source_path)
      |> Map.put(:is_livebook, is_livebook)
      |> Map.put(:github_url, github_url)
      |> Map.put(:menu_path, menu_path)
      |> Map.put(:order, order)
      |> Map.put(:legacy_paths, normalize_legacy_paths(Map.get(attrs, :legacy_paths, [])))
      |> Map.put(:word_count, word_count)
      |> Map.put(:reading_time_minutes, reading_time_minutes)
      |> Map.put(:freshness, computed_freshness)
      |> Map.put(:control_types, normalize_control_types(Map.get(attrs, :control_types)))
      |> Map.put(:control_intent, normalize_control_intent(Map.get(attrs, :control_intent)))

    attrs =
      if livebook_url, do: Map.put(attrs, :livebook_url, livebook_url), else: attrs

    case Zoi.parse(@schema, attrs) do
      {:ok, page} -> page
      {:error, errors} -> raise "Invalid page #{id}: #{inspect(errors)}"
    end
  end

  @doc false
  @spec derive_category(String.t()) :: atom()
  def derive_category(path) do
    case path |> String.trim_leading("/") |> String.split("/", parts: 2) do
      ["docs" | _] -> :docs
      ["training" | _] -> :training
      ["features" | _] -> :features
      ["build" | _] -> :build
      ["community" | _] -> :community
      ["compare" | _] -> :compare
      _ -> :docs
    end
  end

  defp compute_word_count(html) do
    html
    |> String.replace(~r/<[^>]+>/, " ")
    |> String.split(~r/\s+/, trim: true)
    |> length()
  end

  defp normalize_path(path) do
    if String.ends_with?(path, "/index.md") or String.ends_with?(path, "/index.livemd") do
      String.replace(path, ~r{/index\.(md|livemd)$}, "")
    else
      String.replace(path, ~r{\.(md|livemd)$}, "")
    end
  end

  defp derive_id(path) do
    path
    |> String.trim_leading("/")
    |> String.split("/", parts: 2)
    |> case do
      [_category, rest] -> rest
      [only] -> only
      [] -> "root"
    end
    |> String.replace("/", "-")
    |> case do
      "" -> "index"
      id -> id
    end
  end

  defp derive_menu_path(path) do
    path
    |> String.trim_leading("/")
    |> String.split("/")
    |> Enum.filter(&(&1 != "index" and &1 != ""))
  end

  defp normalize_legacy_paths(paths) when is_list(paths) do
    paths
    |> Enum.map(&normalize_legacy_path/1)
    |> Enum.uniq()
  end

  defp normalize_legacy_paths(_paths), do: []

  defp normalize_legacy_path(path) when is_binary(path) do
    path
    |> String.trim()
    |> case do
      "" ->
        "/"

      "/" ->
        "/"

      p ->
        if String.starts_with?(p, "/"), do: p, else: "/" <> p
    end
    |> case do
      "/" = root -> root
      other -> String.trim_trailing(other, "/")
    end
  end

  defp build_github_url(doc_root, path, true = _is_livebook) do
    "#{@github_repo}/blob/main#{doc_root}#{path}.livemd"
  end

  defp build_github_url(doc_root, path, false = _is_livebook) do
    "#{@github_repo}/blob/main#{doc_root}#{path}.md"
  end

  defp build_livebook_url(path, true = _is_livebook) do
    expanded_source_url = "https://jido.run#{path}.livemd"

    "https://livebook.dev/run?url=#{URI.encode_www_form(expanded_source_url)}"
  end

  defp build_livebook_url(_path, false = _is_livebook), do: nil
end
