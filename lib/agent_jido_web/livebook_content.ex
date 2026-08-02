defmodule AgentJidoWeb.LivebookContent do
  @moduledoc """
  Resolves expanded Livebook source for published documentation pages.

  The public `.livemd` response uses the same release-catalog expansion as the
  rendered HTML and public Markdown response. This keeps runnable dependency
  declarations equal on all delivery surfaces.
  """

  alias AgentJido.Pages
  alias AgentJido.ReleaseCatalog

  @type resolution :: {:ok, String.t()} | :no_match

  @doc """
  Returns expanded Livebook source for a published Livebook page.
  """
  @spec resolve(String.t()) :: resolution()
  def resolve(canonical_path) when is_binary(canonical_path) do
    with {:ok, page, _resolution} <- Pages.resolve_page_for_path(canonical_path),
         true <- page.is_livebook,
         true <- published_source?(page.source_path),
         {:ok, source} <- File.read(page.source_path) do
      {:ok, ReleaseCatalog.expand_placeholders(source)}
    else
      _other -> :no_match
    end
  end

  def resolve(_canonical_path), do: :no_match

  defp published_source?(source_path) when is_binary(source_path) do
    String.ends_with?(source_path, ".livemd")
  end

  defp published_source?(_source_path), do: false
end
