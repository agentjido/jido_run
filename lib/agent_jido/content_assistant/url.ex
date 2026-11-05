defmodule AgentJido.ContentAssistant.URL do
  @moduledoc """
  URL normalization helpers for content assistant links and citations.
  """

  @spec normalize_href(term()) :: String.t() | nil
  def normalize_href(url) when is_binary(url) do
    candidate = String.trim(url)

    cond do
      candidate == "" ->
        nil

      String.starts_with?(candidate, "/") ->
        normalize_path(candidate)

      true ->
        normalize_absolute(candidate)
    end
  end

  def normalize_href(_url), do: nil

  @spec canonicalize(term()) :: String.t() | nil
  def canonicalize(url), do: normalize_href(url)

  defp normalize_absolute(url) do
    case URI.parse(url) do
      %URI{scheme: scheme, host: host} = uri when scheme in ["http", "https"] and is_binary(host) ->
        normalized_scheme = String.downcase(scheme)
        normalized_host = String.downcase(host)
        path = uri.path || "/"
        query = uri.query
        fragment = uri.fragment
        path_with_parts = normalize_path_with_parts(path, query, fragment)

        case internal_host?(normalized_host) do
          true -> path_with_parts
          false -> external_absolute_url(normalized_scheme, normalized_host, path_with_parts)
        end

      _ ->
        nil
    end
  end

  defp normalize_path(path) when is_binary(path) do
    case URI.parse(path) do
      %URI{path: parsed_path, query: query, fragment: fragment} when is_binary(parsed_path) ->
        normalize_path_with_parts(parsed_path, query, fragment)

      _ ->
        nil
    end
  end

  defp normalize_path_with_parts(path, query, fragment) when is_binary(path) do
    normalized_path =
      path
      |> String.trim()
      |> case do
        "" -> "/"
        "/" <> _ = absolute -> absolute
        relative -> "/" <> relative
      end

    query_part = if is_binary(query) and query != "", do: "?" <> query, else: ""
    fragment_part = if is_binary(fragment) and fragment != "", do: "#" <> fragment, else: ""

    normalized_path <> query_part <> fragment_part
  end

  defp normalize_path_with_parts(_path, _query, _fragment), do: nil

  defp external_absolute_url(_scheme, _host, nil), do: nil
  defp external_absolute_url(scheme, host, path_with_parts), do: "#{scheme}://#{host}#{path_with_parts}"

  defp internal_host?(host) when is_binary(host) do
    host in AgentJido.Site.internal_hosts()
  end

  defp internal_host?(_host), do: false
end
