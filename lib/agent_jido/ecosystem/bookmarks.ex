defmodule AgentJido.Ecosystem.Bookmarks do
  @moduledoc """
  Builds a Netscape bookmarks export for the public Jido ecosystem repositories.

  The export is derived from ecosystem package metadata so newly added public
  packages with GitHub URLs automatically appear in the downloadable file.
  """

  alias AgentJido.Ecosystem

  @filename "jido-ecosystem-repos.bookmarks.html"
  @title "Jido Ecosystem Repos"
  @generated_comment "Generated from the public Jido ecosystem registry at jido.run"

  @type package_like :: map()

  @doc """
  Returns the download filename for the public bookmarks export.
  """
  @spec filename() :: String.t()
  def filename, do: @filename

  @doc """
  Returns the number of public package bookmarks included in the export.
  """
  @spec count() :: non_neg_integer()
  def count do
    Ecosystem.public_packages()
    |> included_packages()
    |> length()
  end

  @doc """
  Renders the public repository bookmarks export as Netscape bookmark HTML.
  """
  @spec export_html() :: String.t()
  def export_html do
    Ecosystem.public_packages()
    |> export_html()
  end

  @doc """
  Renders the provided packages as Netscape bookmark HTML.

  This arity is primarily useful for tests.
  """
  @spec export_html([package_like()]) :: String.t()
  def export_html(packages) when is_list(packages) do
    packages = included_packages(packages)
    org_root = org_root_bookmark(packages)

    [
      "<!DOCTYPE NETSCAPE-Bookmark-file-1>\n",
      "<!-- ",
      @generated_comment,
      " -->\n",
      "<META HTTP-EQUIV=\"Content-Type\" CONTENT=\"text/html; charset=UTF-8\">\n",
      "<TITLE>",
      html_escape(@title),
      "</TITLE>\n",
      "<H1>",
      html_escape(@title),
      "</H1>\n",
      "<DL><p>\n",
      "  <DT><H3>",
      html_escape(@title),
      "</H3>\n",
      "  <DL><p>\n",
      render_org_root(org_root),
      render_package_bookmarks(packages),
      "  </DL><p>\n",
      "</DL><p>\n"
    ]
    |> IO.iodata_to_binary()
  end

  defp render_org_root(nil), do: []

  defp render_org_root(%{href: href, title: title}) do
    [
      "    <DT><A HREF=\"",
      html_escape(href),
      "\">",
      html_escape(title),
      "</A>\n"
    ]
  end

  defp render_package_bookmarks(packages) do
    Enum.map(packages, fn pkg ->
      [
        "    <DT><A HREF=\"",
        html_escape(Map.get(pkg, :github_url) || Map.get(pkg, "github_url")),
        "\">",
        html_escape(bookmark_title(pkg)),
        "</A>\n"
      ]
    end)
  end

  defp included_packages(packages) do
    packages
    |> Enum.filter(&bookmark_included?/1)
    |> Enum.sort_by(&sort_key/1)
  end

  defp bookmark_included?(pkg) do
    bookmark_include?(pkg) and present?(Map.get(pkg, :github_url) || Map.get(pkg, "github_url"))
  end

  defp bookmark_include?(pkg) do
    case Map.get(pkg, :bookmark_include, Map.get(pkg, "bookmark_include", true)) do
      false -> false
      _other -> true
    end
  end

  defp sort_key(pkg) do
    {
      String.downcase(bookmark_title(pkg)),
      String.downcase(Map.get(pkg, :id) || Map.get(pkg, "id") || "")
    }
  end

  defp bookmark_title(pkg) do
    custom_title = Map.get(pkg, :bookmark_title) || Map.get(pkg, "bookmark_title")

    case normalize_text(custom_title) do
      nil -> default_bookmark_title(pkg)
      title -> title
    end
  end

  defp default_bookmark_title(pkg) do
    repo_label = repo_label(pkg)

    case normalize_text(Map.get(pkg, :tagline) || Map.get(pkg, "tagline")) do
      nil -> repo_label
      tagline -> "#{repo_label}: #{tagline}"
    end
  end

  defp repo_label(pkg) do
    org = normalize_text(Map.get(pkg, :github_org) || Map.get(pkg, "github_org"))

    repo =
      normalize_text(Map.get(pkg, :github_repo) || Map.get(pkg, "github_repo")) ||
        repo_from_url(Map.get(pkg, :github_url) || Map.get(pkg, "github_url"))

    repo_label(org, repo, pkg)
  end

  defp repo_label(org, repo, _pkg) when not is_nil(org) and not is_nil(repo), do: "#{org}/#{repo}"
  defp repo_label(_org, repo, _pkg) when not is_nil(repo), do: repo
  defp repo_label(_org, _repo, pkg), do: normalize_text(Map.get(pkg, :title) || Map.get(pkg, "title")) || "repository"

  defp repo_from_url(url) do
    url
    |> normalize_text()
    |> case do
      nil ->
        nil

      normalized ->
        normalized
        |> URI.parse()
        |> Map.get(:path, "")
        |> String.trim("/")
        |> String.split("/", trim: true)
        |> List.last()
        |> normalize_text()
    end
  end

  defp org_root_bookmark([]), do: nil

  defp org_root_bookmark(packages) do
    packages
    |> Enum.map(&(Map.get(&1, :github_org) || Map.get(&1, "github_org")))
    |> Enum.map(&normalize_text/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.frequencies()
    |> Enum.max_by(fn {_org, count} -> count end, fn -> nil end)
    |> case do
      {org, count} when count > 1 ->
        %{href: "https://github.com/#{org}", title: org}

      _other ->
        nil
    end
  end

  defp present?(value), do: not is_nil(normalize_text(value))

  defp normalize_text(value) when is_binary(value) do
    value
    |> String.trim()
    |> case do
      "" -> nil
      normalized -> normalized
    end
  end

  defp normalize_text(_value), do: nil

  defp html_escape(nil), do: ""

  defp html_escape(value) do
    value
    |> to_string()
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end
end
