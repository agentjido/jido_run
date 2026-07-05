defmodule AgentJido.ContentIngest.EcosystemDocs.Extractor do
  @moduledoc """
  Extracts searchable content from ExDoc HTML pages.
  """

  alias AgentJido.ContentIngest.EcosystemDocs.HexDocsClient

  @content_selectors ["main#main #content", "#content", "main#main"]
  @drop_selectors [
    ".top-search",
    ".search-settings",
    ".autocomplete",
    ".engine-selector",
    ".display-settings",
    ".icon-action",
    ".hover-link",
    ".bottom-actions",
    "#bottom-actions",
    "footer",
    "script",
    "style",
    "noscript"
  ]

  @spec extract(String.t(), keyword()) :: {:ok, %{text: String.t(), title: String.t() | nil}} | {:error, term()}
  def extract(html, opts \\ [])

  def extract(html, opts) when is_binary(html) do
    with {:ok, document} <- Floki.parse_document(html),
         {:ok, content} <- find_content(document) do
      cleaned =
        Enum.reduce(@drop_selectors, content, fn selector, acc ->
          Floki.filter_out(acc, selector)
        end)

      title =
        cleaned
        |> Floki.find("#top-content h1, .top-heading h1, h1")
        |> Floki.text(sep: " ")
        |> normalize_text()

      text =
        cleaned
        |> Floki.text(sep: "\n")
        |> normalize_text()

      if text == "" do
        {:error, :empty_content}
      else
        {:ok, %{text: text, title: title_from_opts_or_content(opts, title)}}
      end
    end
  end

  def extract(_html, _opts), do: {:error, :invalid_html}

  @spec canonical_url([{String.t(), String.t()}], String.t() | nil) :: String.t() | nil
  def canonical_url(headers, fallback \\ nil)

  def canonical_url(headers, fallback) when is_list(headers) do
    case HexDocsClient.header(headers, "link") do
      nil ->
        fallback

      link_header ->
        case Regex.run(~r/<([^>]+)>;\s*rel="canonical"/, link_header, capture: :all_but_first) do
          [url] -> url
          _other -> fallback
        end
    end
  end

  def canonical_url(_headers, fallback), do: fallback

  defp find_content(document) do
    case Enum.find_value(@content_selectors, &find_first_node(document, &1)) do
      nil -> {:error, :missing_content}
      node -> {:ok, node}
    end
  end

  defp find_first_node(document, selector) do
    case Floki.find(document, selector) do
      [node | _rest] -> node
      _other -> nil
    end
  end

  defp normalize_text(text) when is_binary(text) do
    text
    |> String.replace(~r/[ \t\r\f\v]+/u, " ")
    |> String.replace(~r/\n{3,}/u, "\n\n")
    |> String.trim()
  end

  defp title_from_opts_or_content(opts, title) do
    case Keyword.get(opts, :title) do
      provided when is_binary(provided) and provided != "" -> provided
      _other -> title
    end
  end
end
