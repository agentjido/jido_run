defmodule AgentJido.ReleaseCatalog do
  @moduledoc """
  Canonical release metadata for user-facing install guidance.

  This reads the public ecosystem package registry in `priv/ecosystem/` and
  exposes exact versions, recommended dependency requirements, and placeholder
  expansion for static page content.
  """

  @ecosystem_files Path.wildcard(Application.app_dir(:agent_jido, "priv/ecosystem/*.md"))
                   |> Enum.sort()

  for file <- @ecosystem_files do
    @external_resource file
  end

  @packages (
              parse_frontmatter = fn path, frontmatter ->
                trimmed = String.trim(frontmatter)

                case Code.string_to_quoted(trimmed, file: path) do
                  {:ok, {:%{}, _meta, _pairs} = ast} ->
                    {attrs, _binding} = Code.eval_quoted(ast)
                    attrs

                  {:ok, _other} ->
                    raise ArgumentError, "release metadata frontmatter in #{inspect(path)} must be a map literal"

                  {:error, {line, error, token}} ->
                    raise ArgumentError,
                          "invalid release metadata frontmatter in #{inspect(path)} at line #{line}: #{error}#{token}"
                end
              end

              infer_requirement = fn version ->
                case Version.parse(version) do
                  {:ok, %Version{major: major, minor: minor}} ->
                    "~> #{major}.#{minor}"

                  :error ->
                    case String.split(version, ".") do
                      [major, minor | _rest] -> "~> #{major}.#{minor}"
                      [major] -> "~> #{major}"
                      _ -> version
                    end
                end
              end

              load_package = fn path ->
                {frontmatter, _body} =
                  case Regex.split(~r/^---\s*$/m, File.read!(path), parts: 2) do
                    [attrs, body] -> {attrs, body}
                    [attrs_only] -> {attrs_only, ""}
                  end

                attrs = parse_frontmatter.(path, frontmatter)
                id = path |> Path.rootname() |> Path.basename()
                name = Map.get(attrs, :name, id)
                version = Map.get(attrs, :version, "0.0.0")

                %{
                  id: id,
                  name: name,
                  version: version,
                  requirement: Map.get(attrs, :install_requirement, infer_requirement.(version)),
                  hex_url: Map.get(attrs, :hex_url),
                  hexdocs_url: Map.get(attrs, :hexdocs_url),
                  github_url: Map.get(attrs, :github_url)
                }
              end

              Enum.map(@ecosystem_files, load_package)
            )
  @packages_by_id Map.new(@packages, &{&1.id, &1})
  @placeholder_pattern ~r/\{\{([a-z_]+):([a-z0-9_-]+)\}\}/

  @type package :: %{
          id: String.t(),
          name: String.t(),
          version: String.t(),
          requirement: String.t(),
          hex_url: String.t() | nil,
          hexdocs_url: String.t() | nil,
          github_url: String.t() | nil
        }

  @doc """
  Returns the public package metadata used for release-driven docs.
  """
  @spec packages() :: [package()]
  def packages, do: @packages

  @doc """
  Returns release metadata for a package id or package name.
  """
  @spec package(String.t()) :: package() | nil
  def package(id_or_name) when is_binary(id_or_name) do
    id = normalize_id(id_or_name)
    Map.get(@packages_by_id, id)
  end

  @doc """
  Returns release metadata for a package id or package name.
  Raises if the package is not known.
  """
  @spec package!(String.t()) :: package()
  def package!(id_or_name) do
    package(id_or_name) ||
      raise ArgumentError, "unknown package release metadata for #{inspect(id_or_name)}"
  end

  @doc """
  Returns the latest Hex version recorded in the ecosystem registry.
  """
  @spec version(String.t()) :: String.t()
  def version(id_or_name), do: package!(id_or_name).version

  @doc """
  Returns the recommended Mix requirement for public docs.
  """
  @spec requirement(String.t()) :: String.t()
  def requirement(id_or_name), do: package!(id_or_name).requirement

  @doc """
  Returns a rendered dependency tuple snippet like:

      {:jido, "~> 2.2"}
  """
  @spec mix_dep(String.t()) :: String.t()
  def mix_dep(id_or_name) do
    pkg = package!(id_or_name)
    ~s({:#{pkg.name}, "#{pkg.requirement}"})
  end

  @doc """
  Formats a full `defp deps` block for LiveView and template use.
  """
  @spec deps_block([String.t()], keyword()) :: String.t()
  def deps_block(ids, opts \\ []) when is_list(ids) do
    indent = Keyword.get(opts, :indent, 4)
    line_indent = String.duplicate(" ", indent + 2)

    deps = Enum.map_join(ids, ",\n#{line_indent}", &mix_dep/1)

    """
    defp deps do
    #{String.duplicate(" ", indent)}[
    #{line_indent}#{deps}
    #{String.duplicate(" ", indent)}]
    end
    """
    |> String.trim_trailing()
  end

  @doc """
  Expands release placeholders in page content.

  Supported placeholders:

    * `{{pkg_version:jido}}`
    * `{{pkg_requirement:jido}}`
    * `{{pkg_hex_url:jido}}`
    * `{{pkg_hexdocs_url:jido}}`
    * `{{pkg_github_url:jido}}`
    * `{{mix_dep:jido}}`
  """
  @spec expand_placeholders(String.t()) :: String.t()
  def expand_placeholders(content) when is_binary(content) do
    Regex.replace(@placeholder_pattern, content, fn _full, key, id ->
      replace_placeholder(key, id)
    end)
  end

  defp replace_placeholder("pkg_version", id), do: version(id)
  defp replace_placeholder("pkg_requirement", id), do: requirement(id)
  defp replace_placeholder("pkg_hex_url", id), do: package!(id).hex_url || raise_missing_url!(id, :hex_url)
  defp replace_placeholder("pkg_hexdocs_url", id), do: package!(id).hexdocs_url || raise_missing_url!(id, :hexdocs_url)
  defp replace_placeholder("pkg_github_url", id), do: package!(id).github_url || raise_missing_url!(id, :github_url)
  defp replace_placeholder("mix_dep", id), do: mix_dep(id)

  defp replace_placeholder(key, id) do
    raise ArgumentError, "unsupported release placeholder {{#{key}:#{id}}}"
  end

  defp raise_missing_url!(id, field) do
    raise ArgumentError, "package #{inspect(id)} is missing #{field} in release metadata"
  end

  defp normalize_id(id_or_name) do
    id_or_name
    |> String.trim()
    |> String.replace("-", "_")
  end
end
