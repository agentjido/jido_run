defmodule AgentJidoWeb.LegacyRedirects do
  @moduledoc """
  Compile-time legacy redirect table for public routes.

  Documentation redirects come from page `legacy_paths`. Other redirects come
  from `priv/redirects.exs`.

  Redirects are path-to-path only. The caller preserves query strings. Both
  HTML and `.md` variants are supported from one canonical map.

  The table is validated during compilation. Sources must be unique, and each
  target must be a final URL instead of another redirect source.
  """

  @manual_redirects_path Path.expand("../../priv/redirects.exs", __DIR__)
  @external_resource @manual_redirects_path

  {manual_redirects, _binding} = Code.eval_file(@manual_redirects_path)

  unless is_list(manual_redirects) do
    raise ArgumentError, "#{@manual_redirects_path} must contain a list of {source, destination} tuples"
  end

  @doc_redirects AgentJido.Pages.docs_legacy_redirects()

  redirect_pairs =
    Enum.map(@doc_redirects ++ manual_redirects, fn
      {source, destination} when is_binary(source) and is_binary(destination) ->
        normalized_source =
          source
          |> then(&if(String.starts_with?(&1, "/"), do: &1, else: "/" <> &1))
          |> then(&if(&1 == "/", do: &1, else: String.trim_trailing(&1, "/")))

        unless String.starts_with?(destination, "/") do
          raise ArgumentError, "redirect destination must start with '/': #{inspect(destination)}"
        end

        if String.contains?(normalized_source, ["?", "#"]) do
          raise ArgumentError, "redirect source must not contain a query or fragment: #{inspect(source)}"
        end

        if String.contains?(destination, "?") do
          raise ArgumentError, "redirect destination must not contain a query: #{inspect(destination)}"
        end

        {normalized_source, destination}

      invalid ->
        raise ArgumentError,
              "invalid redirect entry in #{@manual_redirects_path}: #{inspect(invalid)}"
    end)

  duplicate_sources =
    redirect_pairs
    |> Enum.frequencies_by(&elem(&1, 0))
    |> Enum.filter(fn {_source, count} -> count > 1 end)
    |> Enum.map(&elem(&1, 0))
    |> Enum.sort()

  if duplicate_sources != [] do
    raise ArgumentError, "duplicate redirect sources: #{Enum.join(duplicate_sources, ", ")}"
  end

  redirect_sources = redirect_pairs |> Enum.map(&elem(&1, 0)) |> MapSet.new()

  redirect_chains =
    Enum.filter(redirect_pairs, fn {_source, destination} ->
      destination_path = destination |> String.split("#", parts: 2) |> hd()
      MapSet.member?(redirect_sources, destination_path)
    end)

  if redirect_chains != [] do
    formatted_chains =
      Enum.map_join(redirect_chains, ", ", fn {source, destination} ->
        "#{source} -> #{destination}"
      end)

    raise ArgumentError, "redirect targets must be final destinations: #{formatted_chains}"
  end

  @redirects Map.new(redirect_pairs)

  @doc """
  Returns the canonical redirect destination for a request path, or `nil`.

  If the legacy request ends in `.md`, the destination also ends in `.md`.
  """
  @spec destination(String.t()) :: String.t() | nil
  def destination(path) when is_binary(path) do
    normalized = normalize_path(path)

    cond do
      normalized == "/" ->
        nil

      String.ends_with?(normalized, ".md") ->
        canonical = normalize_path(String.trim_trailing(normalized, ".md"))

        case Map.get(@redirects, canonical) do
          destination when is_binary(destination) ->
            AgentJidoWeb.MarkdownLinks.markdown_path(destination)

          _other ->
            nil
        end

      true ->
        Map.get(@redirects, normalized)
    end
  end

  @doc """
  Returns all base (non-markdown) redirect pairs for introspection/testing.
  """
  @spec all() :: %{String.t() => String.t()}
  def all, do: @redirects

  defp normalize_path(path) do
    normalized =
      if String.starts_with?(path, "/"), do: path, else: "/" <> path

    case normalized do
      "/" -> "/"
      other -> String.trim_trailing(other, "/")
    end
  end
end
