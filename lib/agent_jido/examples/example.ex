defmodule AgentJido.Examples.Example do
  @moduledoc """
  Represents an interactive example in the Jido Workbench.

  Parsed at compile time from Markdown files in `priv/examples/`.
  Frontmatter provides structured metadata; the body contains rendered HTML.
  Each example references a LiveView module for the interactive demo and
  explicitly lists source files to display alongside the explanation.
  Set `status: :draft` in frontmatter to keep an example hidden from public routes.

  Source files are read and syntax-highlighted at compile time via Makeup,
  ensuring they are available in production releases.
  """

  alias AgentJido.Examples.Taxonomy

  @schema Zoi.struct(
            __MODULE__,
            %{
              slug: Zoi.string(description: "Unique slug derived from filename"),
              title: Zoi.string(description: "Example title"),
              description: Zoi.string(description: "Short summary") |> Zoi.default(""),
              body: Zoi.string(description: "Rendered HTML body") |> Zoi.default(""),
              tags: Zoi.any(description: "List of tag strings for categorization") |> Zoi.default([]),
              category:
                Zoi.enum([:core, :ai, :production],
                  description: "Primary category"
                )
                |> Zoi.default(:core),
              emoji: Zoi.string(description: "Emoji icon for display") |> Zoi.default("⚡"),
              source_files:
                Zoi.any(description: "Explicit list of repo-relative source file paths to showcase")
                |> Zoi.default([]),
              related_resources:
                Zoi.any(description: "Optional list of related resource descriptors (docs paths, companion livebooks, or external links)")
                |> Zoi.default([]),
              sources:
                Zoi.any(description: "Compile-time embedded source code: list of %{path, content, highlighted}")
                |> Zoi.default([]),
              live_view_module: Zoi.string(description: "Fully-qualified LiveView module name that runs the interactive demo"),
              difficulty:
                Zoi.enum([:beginner, :intermediate, :advanced],
                  description: "Difficulty level"
                )
                |> Zoi.default(:beginner),
              status:
                Zoi.enum(Taxonomy.statuses(),
                  description: "Visibility state used for examples index and routes"
                )
                |> Zoi.default(:draft),
              published:
                Zoi.boolean(description: "Whether this example is visible on public examples pages")
                |> Zoi.default(true),
              scenario_cluster:
                Zoi.enum(Taxonomy.scenario_clusters(),
                  description: "Taxonomy grouping for the example scenario type"
                )
                |> Zoi.default(:foundational_legacy),
              wave:
                Zoi.enum(Taxonomy.waves(),
                  description: "Example rollout wave marker"
                )
                |> Zoi.default(:legacy),
              journey_stage:
                Zoi.enum(Taxonomy.journey_stages(),
                  description: "Primary user journey stage this example supports"
                )
                |> Zoi.default(:activation),
              content_intent:
                Zoi.enum(Taxonomy.content_intents(),
                  description: "Primary content intent for this example"
                )
                |> Zoi.default(:tutorial),
              capability_theme:
                Zoi.enum(Taxonomy.capability_themes(),
                  description: "Primary capability theme alignment"
                )
                |> Zoi.default(:runtime_foundations),
              evidence_surface:
                Zoi.enum(Taxonomy.evidence_surfaces(),
                  description: "Proof surface represented by this example"
                )
                |> Zoi.default(:runnable_example),
              demo_mode:
                Zoi.enum(Taxonomy.demo_modes(),
                  description: "Whether the demo uses real runtime behavior or a deterministic simulation"
                )
                |> Zoi.default(:real),
              outcome:
                Zoi.string(description: "Card contract: one sentence stating what this example proves")
                |> Zoi.default(""),
              packages:
                Zoi.any(description: "Card contract: required Jido packages for this example")
                |> Zoi.default([]),
              package_maturity:
                Zoi.string(description: "Card contract: Stable/Beta/Experimental maturity of the dependencies")
                |> Zoi.default(""),
              prerequisites:
                Zoi.any(description: "Card contract: list of prerequisite strings (keys, services, binaries, dbs)")
                |> Zoi.default([]),
              expected_result:
                Zoi.string(description: "Card contract: what a successful run produces")
                |> Zoi.default(""),
              run_command:
                Zoi.string(description: "Card contract: command to run this example locally")
                |> Zoi.default(""),
              last_validated:
                Zoi.string(description: "Card contract: ISO date this example was last validated")
                |> Zoi.default(""),
              tested_with:
                Zoi.any(description: "Card contract: map of tested package/version pairs")
                |> Zoi.default(%{}),
              sort_order:
                Zoi.integer(description: "Sort order within category")
                |> Zoi.default(100),
              path: Zoi.string(description: "App-relative source path") |> Zoi.default(""),
              source_path: Zoi.string(description: "Absolute source filename") |> Zoi.default("")
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
  Derives the example `slug` from the filename. Reads and highlights
  all source files at compile time.
  """
  def build(filename, attrs, body) do
    slug =
      filename
      |> Path.rootname()
      |> Path.basename()

    base_path = Application.app_dir(:agent_jido)
    path = String.replace(filename, base_path, "")

    source_files = Map.get(attrs, :source_files, [])
    sources = embed_sources(source_files)

    taxonomy_metadata =
      attrs
      |> Map.put(:slug, slug)
      |> Taxonomy.metadata()

    attrs =
      attrs
      |> Map.put(:slug, slug)
      |> Map.put(:body, body)
      |> Map.put(:path, path)
      |> Map.put(:source_path, filename)
      |> Map.put(:sources, sources)
      |> Map.merge(taxonomy_metadata)

    case Zoi.parse(@schema, attrs) do
      {:ok, example} -> example
      {:error, errors} -> raise "Invalid example #{slug}: #{inspect(errors)}"
    end
  end

  defp embed_sources(paths) do
    Enum.map(paths, fn rel_path ->
      content =
        case File.read(rel_path) do
          {:ok, content} -> content
          {:error, _} -> "# Source file not found: #{rel_path}"
        end

      highlighted =
        try do
          Makeup.highlight(content)
        rescue
          _ -> "<pre><code>#{content}</code></pre>"
        end

      %{path: rel_path, content: content, highlighted: highlighted}
    end)
  end
end
