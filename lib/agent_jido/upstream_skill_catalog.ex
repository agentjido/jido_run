defmodule AgentJido.UpstreamSkillCatalog do
  @moduledoc """
  Static catalog for the vendored `arrowcircle/jido-skills` package skills.

  Each entry surfaces enough detail — the upstream package it serves, the task
  it covers, the package maturity, and the source links — for a contributor to
  pick a skill from the catalog page without opening every `SKILL.md`
  (jido-e10 E10-T24).
  """

  alias Jido.AI.Skill.Loader

  alias AgentJido.Ecosystem
  alias AgentJido.Ecosystem.SupportLevel

  @catalog_root Application.app_dir(:agent_jido, "priv/skills/arrowcircle-jido-skills")
  @skills_root Path.join(@catalog_root, "skills")
  @repo_url "https://github.com/arrowcircle/jido-skills"
  @readme_source_path "priv/skills/arrowcircle-jido-skills/README.md"
  @source_prompt_source_path "priv/skills/arrowcircle-jido-skills/source/prompts.md"
  @manifest_source_path "priv/skills/arrowcircle-jido-skills/skills/jido-skill-router/references/skill-manifest.yaml"

  # Machine-readable routing manifest. Parsed at compile time so the catalog
  # page can show each skill's task ("role") and triggers ("use_when") without
  # re-reading the file per request. Falls back to an empty map if the file is
  # absent so a partial checkout still compiles.
  @manifest_path Path.join(@catalog_root, "skills/jido-skill-router/references/skill-manifest.yaml")

  @manifest_skills (if File.exists?(@manifest_path) do
                      @manifest_path
                      |> YamlElixir.read_from_file!()
                      |> Map.get("skills", [])
                      |> Enum.map(fn entry -> {entry["skill"], entry} end)
                      |> Map.new()
                    else
                      %{}
                    end)

  @catalog_files Path.wildcard(Path.join(@catalog_root, "**/*"))
                 |> Enum.filter(&File.regular?/1)
                 |> Enum.sort()

  Enum.each(@catalog_files, &Module.put_attribute(__MODULE__, :external_resource, &1))

  @type category :: :package | :router

  @type entry :: %{
          id: String.t(),
          name: String.t(),
          title: String.t(),
          description: String.t(),
          category: category(),
          skill_source_path: String.t(),
          upstream_url: String.t(),
          ecosystem_package_id: String.t() | nil,
          ecosystem_path: String.t() | nil,
          agent_files: [String.t()],
          reference_files: [String.t()],
          # Package the skill serves (Hex name + display title).
          package_name: String.t() | nil,
          package_title: String.t() | nil,
          # Task the skill covers — the manifest "role" plus its "use_when" triggers.
          task: String.t() | nil,
          use_when: [String.t()],
          # Package maturity, resolved from the public Ecosystem package.
          maturity_label: String.t() | nil,
          maturity_note: String.t() | nil,
          # Package source links (absent for unreleased packages).
          hex_url: String.t() | nil,
          hexdocs_url: String.t() | nil,
          github_url: String.t() | nil
        }

  @spec all_entries() :: [entry()]
  def all_entries do
    skill_paths()
    |> Enum.map(&build_entry!/1)
  end

  @spec package_entries() :: [entry()]
  def package_entries do
    Enum.filter(all_entries(), &(&1.category == :package))
  end

  @spec router_entries() :: [entry()]
  def router_entries do
    Enum.filter(all_entries(), &(&1.category == :router))
  end

  @spec count() :: non_neg_integer()
  def count, do: length(all_entries())

  @spec package_count() :: non_neg_integer()
  def package_count, do: length(package_entries())

  @spec router_count() :: non_neg_integer()
  def router_count, do: length(router_entries())

  @spec repo_url() :: String.t()
  def repo_url, do: @repo_url

  @spec readme_source_path() :: String.t()
  def readme_source_path, do: @readme_source_path

  @spec source_prompt_source_path() :: String.t()
  def source_prompt_source_path, do: @source_prompt_source_path

  @spec manifest_source_path() :: String.t()
  def manifest_source_path, do: @manifest_source_path

  @spec skills_root_source_path() :: String.t()
  def skills_root_source_path, do: "priv/skills/arrowcircle-jido-skills/skills"

  @spec support_file_count() :: non_neg_integer()
  def support_file_count do
    all_entries()
    |> Enum.map(&(length(&1.agent_files) + length(&1.reference_files)))
    |> Enum.sum()
  end

  defp build_entry!(skill_path) do
    {:ok, spec} = Loader.load(skill_path)

    skill_dir = Path.dirname(skill_path)
    id = Path.basename(skill_dir)
    category = if id == "jido-skill-router", do: :router, else: :package
    ecosystem_package_id = ecosystem_package_id(id, category)
    ecosystem_path = ecosystem_path(ecosystem_package_id)
    package = Ecosystem.get_public_package(ecosystem_package_id)

    %{
      id: id,
      name: spec.name,
      title: title_for(id, category),
      description: spec.description,
      category: category,
      skill_source_path: relative_to_cwd(skill_path),
      upstream_url: "#{@repo_url}/tree/main/skills/#{id}",
      ecosystem_package_id: ecosystem_package_id,
      ecosystem_path: ecosystem_path,
      agent_files: support_files(skill_dir, "agents"),
      reference_files: support_files(skill_dir, "references"),
      package_name: package_name(id, package),
      package_title: if(package, do: package.title),
      task: task_for(id, category),
      use_when: use_when_for(id, category),
      maturity_label: maturity_label(package),
      maturity_note: maturity_note(package, category),
      hex_url: if(package, do: package.hex_url),
      hexdocs_url: if(package, do: package.hexdocs_url),
      github_url: if(package, do: package.github_url)
    }
  end

  defp support_files(skill_dir, subdir) do
    skill_dir
    |> Path.join("#{subdir}/**/*")
    |> Path.wildcard()
    |> Enum.filter(&File.regular?/1)
    |> Enum.map(&relative_to_cwd/1)
    |> Enum.sort()
  end

  defp skill_paths do
    @skills_root
    |> Path.join("*/SKILL.md")
    |> Path.wildcard()
    |> Enum.sort()
  end

  defp ecosystem_package_id(_id, :router), do: nil
  defp ecosystem_package_id(id, :package), do: String.replace(id, "-", "_")

  defp ecosystem_path(nil), do: nil

  defp ecosystem_path(package_id) do
    if AgentJido.Ecosystem.get_public_package(package_id) do
      "/ecosystem/#{package_id}"
    else
      nil
    end
  end

  defp title_for(_id, :router), do: "Jido Skill Router"

  defp title_for("llm-db", :package), do: "LLM DB"
  defp title_for("req-llm", :package), do: "Req LLM"

  defp title_for(id, :package) do
    id
    |> String.split("-")
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  # The manifest carries the authoritative package each skill serves plus its
  # role/triggers. For every package skill the manifest `upstream_package`
  # matches the resolved Ecosystem package id; we prefer the Ecosystem package
  # title/name so the card shows the curated display name, and fall back to the
  # manifest only when the package is not in the public catalog.
  defp package_name(_id, %{name: name}), do: name
  defp package_name(id, nil), do: manifest_field(id, "upstream_package")

  defp task_for("jido-skill-router", :router),
    do: "Routes a task to the right package skill when the boundary is unclear or the work crosses packages."

  defp task_for(id, :package), do: manifest_field(id, "role")

  defp use_when_for("jido-skill-router", :router),
    do: ["unclear package boundary", "task spans multiple packages"]

  defp use_when_for(id, :package) do
    case Map.get(@manifest_skills, id) do
      %{"use_when" => triggers} when is_list(triggers) -> triggers
      _ -> []
    end
  end

  defp maturity_label(%{support_level: level}), do: SupportLevel.label(level)
  defp maturity_label(nil), do: nil

  # Self-contained "maturity note" combining the support-level label/summary
  # with the package's API-stability detail, so a contributor can judge whether
  # a skill's package is safe to build on without opening its files.
  defp maturity_note(nil, :router),
    do: "Generated meta-skill — hand off to the matching package skill rather than loading every skill."

  defp maturity_note(_package, :router), do: maturity_note(nil, :router)

  defp maturity_note(nil, :package), do: nil

  defp maturity_note(package, :package) do
    case SupportLevel.definition(package.support_level) do
      %{label: label, summary: summary} ->
        api = package.api_stability |> to_string() |> String.trim()

        redundant? =
          api in ["", "not yet defined"] or
            String.downcase(api) == String.downcase(label)

        if redundant? do
          "#{label} — #{summary}"
        else
          "#{label} — #{summary} (#{api})"
        end

      _ ->
        nil
    end
  end

  defp manifest_field(id, key) do
    case Map.get(@manifest_skills, id) do
      %{^key => value} when is_binary(value) -> value
      _ -> nil
    end
  end

  defp relative_to_cwd(path), do: Path.relative_to(path, Application.app_dir(:agent_jido))
end
