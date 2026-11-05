defmodule AgentJidoWeb.MarkdownLinks do
  @moduledoc """
  URL helpers for content source and canonical URL workflows.
  """

  @repo "https://github.com/agentjido/agentjido_xyz"
  @repo_blob_prefix "#{@repo}/blob/main/"
  @repo_raw_prefix "https://raw.githubusercontent.com/agentjido/agentjido_xyz/main/"

  @type markdown_action :: %{
          url: String.t(),
          label: String.t(),
          source_backed?: boolean(),
          source_url: String.t() | nil,
          raw_source_url: String.t() | nil
        }

  @doc """
  Returns an absolute URL for a path and optional query string.
  """
  @spec absolute_url(String.t(), String.t() | nil) :: String.t()
  def absolute_url(path, query \\ nil) when is_binary(path) do
    normalized_path =
      if String.starts_with?(path, "/"), do: path, else: "/" <> path

    base = AgentJidoWeb.Endpoint.url() <> normalized_path

    case query do
      q when is_binary(q) and q != "" -> base <> "?" <> q
      _other -> base
    end
  end

  @doc """
  Returns the deterministic markdown route for a canonical path.
  """
  @spec markdown_path(String.t()) :: String.t()
  def markdown_path(path) when is_binary(path) do
    {base_path, fragment} = split_fragment(path)

    normalized_path =
      if String.starts_with?(base_path, "/"), do: base_path, else: "/" <> base_path

    markdown_base =
      cond do
        normalized_path == "/" -> "/index.md"
        String.ends_with?(normalized_path, ".md") -> normalized_path
        true -> normalized_path <> ".md"
      end

    case fragment do
      nil -> markdown_base
      value -> markdown_base <> "#" <> value
    end
  end

  @doc """
  Converts an in-repo GitHub blob URL to the corresponding raw content URL.
  """
  @spec github_blob_to_raw(String.t() | nil) :: String.t() | nil
  def github_blob_to_raw(url) when is_binary(url) do
    case String.split(url, @repo_blob_prefix, parts: 2) do
      ["", relative] when relative != "" -> @repo_raw_prefix <> relative
      _other -> nil
    end
  end

  def github_blob_to_raw(_url), do: nil

  @doc """
  Returns the GitHub blob URL for a local or repo-relative source path.
  """
  @spec source_url_from_path(String.t() | nil) :: String.t() | nil
  def source_url_from_path(path) when is_binary(path) and path != "" do
    case normalize_repo_relative_path(path) do
      relative when is_binary(relative) -> @repo_blob_prefix <> relative
      _other -> nil
    end
  end

  def source_url_from_path(_path), do: nil

  @doc """
  Returns the best source URL for a content struct/map, if available.
  """
  @spec source_url_from(map() | nil) :: String.t() | nil
  def source_url_from(%{} = item) do
    source_path_url =
      item
      |> map_get(:source_path)
      |> source_url_from_path()

    path_url =
      item
      |> map_get(:path)
      |> source_url_from_path()

    github_url = map_get(item, :github_url)

    cond do
      is_binary(source_path_url) ->
        source_path_url

      is_binary(path_url) ->
        path_url

      valid_github_source_url?(github_url) ->
        github_url

      true ->
        nil
    end
  end

  def source_url_from(_item), do: nil

  @doc """
  Returns the raw source URL for a content struct/map, if available.
  """
  @spec raw_source_url_from(map() | nil) :: String.t() | nil
  def raw_source_url_from(%{} = item) do
    case source_url_from(item) do
      nil ->
        nil

      source_url ->
        github_blob_to_raw(source_url) ||
          if(valid_raw_markdown_url?(source_url), do: source_url, else: nil)
    end
  end

  def raw_source_url_from(_item), do: nil

  @doc """
  Builds a content action preferring source URLs and falling back to
  the canonical rendered page URL.
  """
  @spec markdown_action(map() | nil, String.t()) :: markdown_action()
  def markdown_action(item, page_absolute_url) when is_binary(page_absolute_url) do
    source_url = source_url_from(item)

    case source_url do
      url when is_binary(url) and url != "" ->
        %{
          url: url,
          label: "Open source on GitHub",
          source_backed?: true,
          source_url: source_url,
          raw_source_url: raw_source_url_from(item)
        }

      _other ->
        %{
          url: page_absolute_url,
          label: "Open canonical page",
          source_backed?: false,
          source_url: nil,
          raw_source_url: nil
        }
    end
  end

  defp normalize_repo_relative_path(path) do
    cond do
      String.starts_with?(path, "priv/") or String.starts_with?(path, "lib/") ->
        path

      String.starts_with?(path, "/priv/") or String.starts_with?(path, "/lib/") ->
        String.trim_leading(path, "/")

      true ->
        path
        |> trim_to_repo_relative("priv")
        |> case do
          nil -> trim_to_repo_relative(path, "lib")
          found -> found
        end
    end
  end

  defp trim_to_repo_relative(path, segment) do
    marker = "/" <> segment <> "/"

    case String.split(path, marker, parts: 2) do
      [_prefix, suffix] when is_binary(suffix) and suffix != "" ->
        segment <> "/" <> suffix

      _other ->
        nil
    end
  end

  defp map_get(map, key) when is_map(map) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end

  defp valid_github_source_url?(url) when is_binary(url) do
    String.starts_with?(url, @repo_blob_prefix) and markdown_file_url?(url)
  end

  defp valid_github_source_url?(_url), do: false

  defp valid_raw_markdown_url?(url) when is_binary(url) do
    String.starts_with?(url, @repo_raw_prefix) and markdown_file_url?(url)
  end

  defp markdown_file_url?(url) when is_binary(url) do
    String.match?(url, ~r/\.(md|livemd)(?:$|[?#])/i)
  end

  defp split_fragment(path) do
    case String.split(path, "#", parts: 2) do
      [base_path, fragment] when fragment != "" -> {base_path, fragment}
      [base_path, _fragment] -> {base_path, nil}
      [base_path] -> {base_path, nil}
    end
  end
end
