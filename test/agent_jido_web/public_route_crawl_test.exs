defmodule AgentJidoWeb.PublicRouteCrawlTest do
  @moduledoc """
  Endpoint crawl for every internal link rendered by every published page.

  This is different from the source link audit. It sends each route through the
  Phoenix endpoint, follows internal redirects, and verifies the response that
  a browser receives.
  """

  use AgentJidoWeb.ConnCase, async: false

  alias AgentJido.Pages

  @moduletag timeout: 120_000
  @redirect_statuses [301, 302, 307, 308]
  @internal_hosts [nil, "jido.run", "www.jido.run", "localhost"]
  @max_redirects 5
  @public_root_routes ~w(
    /
    /about
    /blog
    /build
    /community
    /community/showcase
    /compare
    /docs
    /ecosystem
    /examples
    /features
    /skills
  )

  test "every internal destination from every published page resolves" do
    source_results =
      (Enum.map(Pages.all_pages(), &Pages.route_for/1) ++ @public_root_routes)
      |> Enum.uniq()
      |> Enum.sort()
      |> Enum.map(&load_source/1)

    source_failures =
      for {:error, failure} <- source_results do
        failure
      end

    destination_failures =
      source_results
      |> Enum.flat_map(fn
        {:ok, source, body} -> internal_links(body, source)
        {:error, _failure} -> []
      end)
      |> Enum.uniq()
      |> Enum.sort()
      |> Enum.flat_map(fn {source, destination} ->
        case resolve_destination(destination) do
          :ok -> []
          {:error, reason} -> ["#{source} -> #{destination}: #{reason}"]
        end
      end)

    failures = source_failures ++ destination_failures

    assert failures == [],
           "public route crawl found #{length(failures)} failure(s):\n" <>
             Enum.map_join(failures, "\n", &"  - #{&1}")
  end

  defp load_source(path), do: load_source(path, MapSet.new(), 0)

  defp load_source(path, visited, depth) when depth <= @max_redirects do
    if MapSet.member?(visited, path) do
      {:error, "#{path}: published page has a redirect loop"}
    else
      conn = request(path)

      cond do
        conn.status == 200 ->
          {:ok, path, conn.resp_body || ""}

        conn.status in @redirect_statuses ->
          load_redirected_source(conn, path, MapSet.put(visited, path), depth + 1)

        true ->
          {:error, "#{path}: published page returned HTTP #{conn.status}"}
      end
    end
  rescue
    error -> {:error, "#{path}: request raised #{Exception.message(error)}"}
  end

  defp load_source(path, _visited, _depth), do: {:error, "#{path}: published page has too many redirects"}

  defp load_redirected_source(conn, source_path, visited, depth) do
    case get_resp_header(conn, "location") do
      [location | _rest] ->
        case normalize_internal_destination(location, source_path) do
          nil -> {:error, "#{source_path}: published page redirects outside the site"}
          destination -> load_source(destination, visited, depth)
        end

      [] ->
        {:error, "#{source_path}: HTTP #{conn.status} redirect has no Location header"}
    end
  end

  defp internal_links(html, source_path) do
    html
    |> Floki.parse_document!()
    |> Floki.find("a[href]")
    |> Floki.attribute("href")
    |> Enum.flat_map(fn href ->
      case normalize_internal_destination(href, source_path) do
        nil -> []
        destination -> [{source_path, destination}]
      end
    end)
  end

  defp normalize_internal_destination(href, source_path) when is_binary(href) do
    uri = URI.parse(String.trim(href))

    cond do
      href == "" or String.starts_with?(href, "#") ->
        nil

      uri.scheme in ["mailto", "tel", "javascript", "data"] ->
        nil

      uri.host not in @internal_hosts ->
        nil

      is_binary(uri.scheme) and uri.scheme not in ["http", "https"] ->
        nil

      true ->
        uri
        |> internal_path(source_path)
        |> append_query(uri.query)
    end
  end

  defp normalize_internal_destination(_href, _source_path), do: nil

  defp internal_path(%URI{path: "/" <> _rest = path}, _source_path), do: path

  defp internal_path(%URI{path: nil}, source_path), do: source_path
  defp internal_path(%URI{path: ""}, source_path), do: source_path

  defp internal_path(%URI{path: relative_path}, source_path) do
    ("https://jido.run" <> source_path)
    |> URI.merge(relative_path)
    |> Map.fetch!(:path)
  end

  defp append_query(path, nil), do: path
  defp append_query(path, ""), do: path
  defp append_query(path, query), do: path <> "?" <> query

  defp resolve_destination(path), do: follow_redirects(path, MapSet.new(), 0)

  defp follow_redirects(path, visited, depth) when depth <= @max_redirects do
    if MapSet.member?(visited, path) do
      {:error, "redirect loop at #{path}"}
    else
      conn = request(path)

      cond do
        conn.status == 200 ->
          :ok

        conn.status in @redirect_statuses ->
          follow_location(conn, path, MapSet.put(visited, path), depth + 1)

        true ->
          {:error, "HTTP #{conn.status}"}
      end
    end
  rescue
    error -> {:error, "request raised #{Exception.message(error)}"}
  end

  defp follow_redirects(path, _visited, _depth), do: {:error, "too many redirects at #{path}"}

  defp follow_location(conn, source_path, visited, depth) do
    case get_resp_header(conn, "location") do
      [location | _rest] ->
        case normalize_internal_destination(location, source_path) do
          nil -> :ok
          destination -> follow_redirects(destination, visited, depth)
        end

      [] ->
        {:error, "HTTP #{conn.status} redirect has no Location header"}
    end
  end

  defp request(path) do
    Phoenix.ConnTest.build_conn()
    |> get(path)
  end
end
