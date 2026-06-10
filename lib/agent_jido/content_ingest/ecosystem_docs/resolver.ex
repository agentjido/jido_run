defmodule AgentJido.ContentIngest.EcosystemDocs.Resolver do
  @moduledoc """
  Resolves eligible public ecosystem packages against exact Hex releases.
  """

  alias AgentJido.ContentIngest.EcosystemDocs.HexDocsClient
  alias AgentJido.Ecosystem
  alias AgentJido.Ecosystem.Package

  @typedoc "Resolved package metadata for one exact Hex release."
  @type resolved_package :: %{
          package_id: String.t(),
          package_name: String.t(),
          package_title: String.t(),
          package_version: String.t(),
          package_url: String.t(),
          hexdocs_url: String.t(),
          github_url: String.t() | nil,
          docs_html_url: String.t() | nil
        }

  @spec public_packages(keyword()) :: [Package.t()]
  def public_packages(opts \\ []) do
    package_id = normalize_package_id(Keyword.get(opts, :package_id))

    packages = Ecosystem.public_packages()

    case package_id do
      nil ->
        packages

      id ->
        case Enum.filter(packages, &(&1.id == id)) do
          [] -> raise ArgumentError, "unknown public ecosystem package #{inspect(id)}"
          filtered -> filtered
        end
    end
  end

  @spec resolve_package(Package.t(), keyword()) ::
          {:ok, {:eligible | :skipped_unpublished, resolved_package()}} | {:error, term()}
  def resolve_package(%Package{} = package, opts \\ []) do
    client = Keyword.get(opts, :client, HexDocsClient)

    with {:ok, response} <- client.fetch_release(package.name, package.version, opts) do
      resolve_release_response(package, response)
    end
  end

  defp resolve_release_response(package, %{status: 404}) do
    {:ok, {:skipped_unpublished, build_resolved_package(package, nil)}}
  end

  defp resolve_release_response(_package, %{status: status}) when status in 500..599 do
    {:error, {:hex_http_error, status}}
  end

  defp resolve_release_response(package, %{status: 200, body: body}) do
    case Jason.decode(body) do
      {:ok, payload} ->
        docs_html_url = payload["docs_html_url"]

        if payload["has_docs"] == true and is_binary(docs_html_url) and String.trim(docs_html_url) != "" do
          {:ok, {:eligible, build_resolved_package(package, docs_html_url)}}
        else
          {:ok, {:skipped_unpublished, build_resolved_package(package, docs_html_url)}}
        end

      {:error, reason} ->
        {:error, {:invalid_release_json, reason}}
    end
  end

  defp resolve_release_response(_package, %{status: status, body: body}) do
    {:error, {:hex_http_error, status, body}}
  end

  defp build_resolved_package(%Package{} = package, docs_html_url) do
    %{
      package_id: package.id,
      package_name: package.name,
      package_title: package.title || package.name || package.id,
      package_version: package.version,
      package_url: "/ecosystem/#{package.id}",
      hexdocs_url: normalize_hexdocs_root(package.hexdocs_url, package.name),
      github_url: package.github_url,
      docs_html_url: normalize_docs_html_url(docs_html_url)
    }
  end

  defp normalize_docs_html_url(url) when is_binary(url) do
    url
    |> String.trim()
    |> case do
      "" -> nil
      value -> if String.ends_with?(value, "/"), do: value, else: value <> "/"
    end
  end

  defp normalize_docs_html_url(_url), do: nil

  defp normalize_hexdocs_root(url, package_name) when is_binary(url) do
    case String.trim(url) do
      "" -> "https://hexdocs.pm/#{package_name}"
      value -> String.trim_trailing(value, "/")
    end
  end

  defp normalize_hexdocs_root(_url, package_name), do: "https://hexdocs.pm/#{package_name}"

  defp normalize_package_id(nil), do: nil

  defp normalize_package_id(package_id) when is_binary(package_id) do
    case String.trim(package_id) do
      "" -> nil
      id -> id
    end
  end

  defp normalize_package_id(_package_id), do: nil
end
