defmodule AgentJido.Ecosystem.Package do
  @moduledoc """
  Represents a package in the Jido ecosystem.

  Parsed at compile time from Markdown files in `priv/ecosystem/`.
  Frontmatter provides structured metadata; the body contains
  rich Markdown rendered as HTML for site pages and available
  as raw Markdown for RAG ingestion.
  """

  alias AgentJido.Ecosystem.SupportLevel

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.string(description: "Unique slug derived from filename"),
              name: Zoi.string(description: "Hex package name"),
              title: Zoi.string(description: "Human-readable display name"),
              version: Zoi.string(description: "Current version") |> Zoi.default("0.0.0"),
              tagline: Zoi.string(description: "One-line description") |> Zoi.default(""),
              graph_label: Zoi.string(description: "Short graph label for ecosystem ASCII map") |> Zoi.optional(),
              orbit_domain:
                Zoi.atom(description: "Optional orbit grouping key for ecosystem visualizations")
                |> Zoi.optional(),
              orbit_parent:
                Zoi.string(description: "Optional parent package id for selective sub-orbit rendering")
                |> Zoi.optional(),
              orbit_order:
                Zoi.integer(description: "Optional explicit orbit sort order within a domain")
                |> Zoi.optional(),
              compare_order:
                Zoi.integer(description: "Optional explicit sort order for ecosystem comparison views")
                |> Zoi.optional(),
              orbit_label:
                Zoi.string(description: "Optional short label override for orbit node rendering")
                |> Zoi.optional(),
              orbit_weight:
                Zoi.number(description: "Optional orbit node size/weight override for visualizations")
                |> Zoi.optional(),
              orbit_visible:
                Zoi.boolean(description: "Whether this package should be included in orbit visualizations")
                |> Zoi.default(true),
              description: Zoi.string(description: "Longer description paragraph") |> Zoi.optional(),
              landing_summary: Zoi.string(description: "High-level landing summary blurb") |> Zoi.optional(),
              landing_cliff_notes:
                Zoi.any(description: "List of short cliff-note bullets for landing pages")
                |> Zoi.default([]),
              landing_use_when:
                Zoi.any(description: "List of concise reasons this package is the right choice")
                |> Zoi.default([]),
              landing_not_for:
                Zoi.any(description: "List of concise cases where this package is not the right fit")
                |> Zoi.default([]),
              landing_resources:
                Zoi.any(description: "Curated internal or external resource links grouped for package landing pages")
                |> Zoi.default([]),
              landing_best_example:
                Zoi.map(
                  %{
                    label:
                      Zoi.string(description: "Display label for the single best example that proves this package")
                      |> Zoi.optional(),
                    href:
                      Zoi.string(description: "Internal (/examples/...) or absolute URL to the best example")
                      |> Zoi.optional(),
                    note:
                      Zoi.string(description: "Short note on what this example proves about the package")
                      |> Zoi.optional()
                  },
                  description:
                    "Curated single best example that proves this package (label/href/note). When absent the package page auto-resolves the best live example from the examples registry, or states that proof is missing."
                )
                |> Zoi.default(%{}),
              landing_best_guide:
                Zoi.map(
                  %{
                    label:
                      Zoi.string(description: "Display label for the single best guide / maintained learning path that teaches this package")
                      |> Zoi.optional(),
                    href:
                      Zoi.string(description: "Internal (/docs/...) or absolute URL to the best guide")
                      |> Zoi.optional(),
                    note:
                      Zoi.string(description: "Short note on what this guide teaches about the package")
                      |> Zoi.optional()
                  },
                  description:
                    "Curated single best guide / maintained learning path that teaches this package (label/href/note). When absent the package page auto-resolves the best published guide whose tested_with set declares this package, or states that no guide exists yet."
                )
                |> Zoi.default(%{}),
              landing_related_packages:
                Zoi.any(description: "Curated related package links grouped by relationship for landing pages")
                |> Zoi.default([]),
              landing_faq:
                Zoi.any(description: "Curated FAQ entries for package landing pages")
                |> Zoi.default([]),
              landing_install:
                Zoi.map(
                  %{
                    label: Zoi.string(description: "Short install box label") |> Zoi.optional(),
                    snippet: Zoi.string(description: "Install snippet to render verbatim") |> Zoi.optional(),
                    note: Zoi.string(description: "Short explanatory install note") |> Zoi.optional(),
                    source:
                      Zoi.atom(description: "Install source classification (hex, github, manual)")
                      |> Zoi.optional()
                  },
                  description: "Curated install presentation metadata"
                )
                |> Zoi.default(%{}),
              landing_important_packages:
                Zoi.any(description: "Important ecosystem package links and reasons")
                |> Zoi.default([]),
              landing_major_components:
                Zoi.any(description: "Major components with explicit documentation links")
                |> Zoi.default([]),
              landing_module_map:
                Zoi.any(description: "Curated high-level module map metadata")
                |> Zoi.default(%{}),
              seo:
                Zoi.map(
                  %{
                    title: Zoi.string(description: "Curated page title for the package page") |> Zoi.optional(),
                    description:
                      Zoi.string(description: "Curated meta description for the package page")
                      |> Zoi.optional(),
                    keywords: Zoi.any(description: "Curated SEO keywords for the package page") |> Zoi.default([]),
                    og_title:
                      Zoi.string(description: "Curated Open Graph title for the package page")
                      |> Zoi.optional(),
                    og_description:
                      Zoi.string(description: "Curated Open Graph description for the package page")
                      |> Zoi.optional()
                  },
                  description: "Curated SEO metadata for the package landing page"
                )
                |> Zoi.default(%{}),
              license: Zoi.string(description: "SPDX license identifier") |> Zoi.default("Apache-2.0"),
              visibility: Zoi.atom(description: "Public or private package") |> Zoi.default(:public),
              category:
                Zoi.atom(description: "Package category (core, ai, tools, runtime, integrations)")
                |> Zoi.default(:tools),
              tier:
                Zoi.integer(description: "Display/sort tier (1=core, 2=official, 3=community)")
                |> Zoi.default(2),
              tags: Zoi.any(description: "List of tag atoms") |> Zoi.default([]),
              hex_url: Zoi.string(description: "Hex.pm package URL") |> Zoi.optional(),
              hexdocs_url: Zoi.string(description: "HexDocs URL") |> Zoi.optional(),
              github_url: Zoi.string(description: "GitHub repository URL") |> Zoi.optional(),
              github_org: Zoi.string(description: "GitHub organization") |> Zoi.default("agentjido"),
              github_repo: Zoi.string(description: "GitHub repository name") |> Zoi.optional(),
              bookmark_include:
                Zoi.boolean(description: "Whether the package should appear in the public repo bookmarks export")
                |> Zoi.default(true),
              bookmark_title:
                Zoi.string(description: "Optional bookmark label override for repo bookmark exports")
                |> Zoi.optional(),
              atlas_facet:
                Zoi.atom(description: "Optional secondary Atlas grouping under the canonical category")
                |> Zoi.optional(),
              tech_lead:
                Zoi.string(description: "Canonical GitHub-handle-first owner or tech lead for the package")
                |> Zoi.optional(),
              elixir: Zoi.string(description: "Required Elixir version") |> Zoi.optional(),
              ecosystem_deps:
                Zoi.any(description: "List of ecosystem package id strings this depends on")
                |> Zoi.default([]),
              key_features: Zoi.any(description: "List of feature highlight strings") |> Zoi.default([]),
              support_level:
                Zoi.atom(description: "Public support level (stable, beta, experimental)")
                |> Zoi.optional(),
              maturity:
                Zoi.atom(description: "Maturity tier (stable, beta, experimental, planned)")
                |> Zoi.default(:experimental),
              hex_status:
                Zoi.string(description: "Hex.pm publication status (published version or unreleased)")
                |> Zoi.default("unreleased"),
              tested_version:
                Zoi.string(description: "Version this package's registry entry was validated/tested against (falls back to version)")
                |> Zoi.default(""),
              last_synced:
                Zoi.string(description: "ISO date (YYYY-MM-DD) this package's registry entry was last synced/validated")
                |> Zoi.default(""),
              api_stability:
                Zoi.string(description: "API stability expectations")
                |> Zoi.default("not yet defined"),
              limitations:
                Zoi.any(description: "Known limitations or non-goals")
                |> Zoi.default([]),
              stub: Zoi.boolean(description: "Whether this is a stub vs real usable code") |> Zoi.default(false),
              support:
                Zoi.atom(description: "Support expectations (best_effort, community, maintained)")
                |> Zoi.default(:best_effort),
              body: Zoi.string(description: "Rendered HTML body") |> Zoi.default(""),
              path: Zoi.string(description: "Source file path") |> Zoi.default("")
            },
            coerce: true
          )

  @type t :: unquote(Zoi.type_spec(@schema))

  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  def schema, do: @schema

  @doc """
  NimblePublisher build callback.

  Receives the filename, frontmatter attrs map, and parsed HTML body.
  Derives the package `id` from the filename slug.
  """
  def build(filename, attrs, body) do
    id =
      filename
      |> Path.rootname()
      |> Path.basename()

    support_level =
      attrs
      |> Map.get(:support_level)
      |> Kernel.||(Map.get(attrs, :maturity))
      |> SupportLevel.normalize()

    attrs =
      attrs
      |> Map.put(:id, id)
      |> Map.put(:body, body)
      |> Map.put(:path, filename)
      |> Map.put_new(:name, id)
      |> Map.put_new(:title, id |> String.replace("_", " ") |> String.split() |> Enum.map_join(" ", &String.capitalize/1))
      |> maybe_put(:support_level, support_level)

    case Zoi.parse(@schema, attrs) do
      {:ok, package} -> package
      {:error, errors} -> raise "Invalid package #{id}: #{inspect(errors)}"
    end
  end

  defp maybe_put(attrs, _key, nil), do: attrs
  defp maybe_put(attrs, key, value), do: Map.put(attrs, key, value)
end
