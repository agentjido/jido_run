defmodule AgentJidoWeb.LegacyRedirects do
  @moduledoc """
  Compile-time legacy redirect table for public routes.

  Redirects are path-to-path only (query strings are preserved by the caller).
  Both HTML and `.md` variants are supported from one canonical map.
  """

  @doc_redirects AgentJido.Pages.docs_legacy_redirects()
  @extra_redirects [
    # The full catalog now starts collapsed behind the dependency-map disclosure
    # (jido-e09-t38), so the legacy matrix routes land on the always-present
    # dependency-map header rather than the collapsed compare anchor.
    {"/ecosystem/matrix", "/ecosystem#dependency-map"},
    {"/ecosystem/package-matrix", "/ecosystem#dependency-map"},
    # The public Training routes are retired and /getting-started was superseded
    # by the canonical /docs/getting-started path. Redirect both HTML and .md
    # variants to active Docs/Examples routes (jido-e01: E01-T13, E01-T14, E01-T15).
    {"/getting-started", "/docs/getting-started"},
    {"/training", "/docs/getting-started"},
    {"/training/agent-fundamentals", "/docs/getting-started/first-agent"},
    {"/training/actions-validation", "/docs/concepts/actions"},
    {"/training/signals-routing", "/docs/concepts/signals"},
    {"/training/directives-scheduling", "/docs/concepts/directives"},
    {"/training/liveview-integration", "/docs/getting-started/elixir-developers"},
    {"/training/production-readiness", "/docs/guides/error-handling-and-recovery"}
  ]

  @redirects Map.new(@doc_redirects ++ @extra_redirects)

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
