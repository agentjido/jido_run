defmodule AgentJidoWeb.StructuredData do
  @moduledoc """
  Builds shared Schema.org structured data for public pages.
  """

  alias AgentJido.Pages
  alias AgentJido.Pages.Page
  alias AgentJidoWeb.MarkdownLinks

  @home {"Jido", "/"}

  @category_roots %{
    build: {"Build", "/build"},
    community: {"Community", "/community"},
    compare: {"Compare", "/compare"},
    features: {"How Jido Works", "/features"},
    training: {"Learn", "/docs/learn"}
  }

  @type breadcrumb_item :: {String.t(), String.t()}

  @doc """
  Builds a Schema.org `BreadcrumbList` from semantic page names and paths.
  """
  @spec breadcrumb_list([breadcrumb_item()]) :: map()
  def breadcrumb_list(items) when is_list(items) do
    normalized_items = Enum.map(items, &normalize_item!/1)

    if length(normalized_items) < 2 do
      raise ArgumentError, "a breadcrumb list requires at least two items"
    end

    %{
      "@context" => "https://schema.org",
      "@type" => "BreadcrumbList",
      "itemListElement" =>
        normalized_items
        |> Enum.with_index(1)
        |> Enum.map(fn {{name, path}, position} ->
          %{
            "@type" => "ListItem",
            "position" => position,
            "name" => name,
            "item" => MarkdownLinks.absolute_url(path)
          }
        end)
    }
  end

  @doc """
  Builds a breadcrumb list for a published page from the Pages system.
  """
  @spec page_breadcrumb_list(Page.t()) :: map()
  def page_breadcrumb_list(%Page{category: :docs} = page) do
    page.path
    |> Pages.breadcrumbs_with_docs()
    |> Enum.flat_map(fn
      {_segment, %Page{} = breadcrumb_page} ->
        [{breadcrumb_page.title, Pages.route_for(breadcrumb_page)}]

      _missing_page ->
        []
    end)
    |> then(&breadcrumb_list([@home | &1]))
  end

  def page_breadcrumb_list(%Page{} = page) do
    category_root = Map.fetch!(@category_roots, page.category)
    page_path = Pages.route_for(page)

    items =
      if elem(category_root, 1) == page_path do
        [@home, category_root]
      else
        [@home, category_root, {page.title, page_path}]
      end

    breadcrumb_list(items)
  end

  defp normalize_item!({name, path}) when is_binary(name) and is_binary(path) do
    normalized_name = String.trim(name)

    cond do
      normalized_name == "" ->
        raise ArgumentError, "breadcrumb names must not be empty"

      not String.starts_with?(path, "/") ->
        raise ArgumentError, "breadcrumb paths must start with '/': #{inspect(path)}"

      true ->
        {normalized_name, path}
    end
  end

  defp normalize_item!(item) do
    raise ArgumentError, "invalid breadcrumb item: #{inspect(item)}"
  end
end
