defmodule AgentJido.ContentAssistant.SearchAliases do
  @moduledoc """
  Common user terms (aliases) mapped to their canonical site pages.

  A search for a colloquial term — "agent server", "function calling",
  "durable" — should surface the authoritative page, not whichever page
  happens to mention the word most. This module is the single source of
  truth for those term→page mappings, and both search paths consume it:

    * `AgentJido.ContentIngest.Inventory` appends a page's aliases to the
      document text it builds for Arcana, so the backend indexes them and
      a query for the term retrieves the canonical page.
    * `AgentJido.ContentAssistant.Retrieval` appends them to the local
      fallback's searchable text and gives an alias-matched canonical page
      priority in reranking, so it surfaces at the top regardless of which
      path serves the query.

  Keys are canonical page routes — the value `AgentJido.Pages.route_for/1`
  returns and the inventory indexes as the document path. An alias matches
  a query when every token of an alias phrase is present in the query, so
  "how does the agent server work" matches the "agent server" alias while
  "agent" alone does not (jido-e10 E10-T04).
  """

  @aliases %{
    "/docs/concepts/agent-runtime" => ["agent server", "AgentServer", "long-running"],
    "/docs/operations/supervision-and-failure-boundaries" => ["supervision"],
    "/docs/operations/process-crash-and-restart" => ["restart"],
    "/docs/concepts/persistence" => ["durable", "durability"],
    "/features/tools" => ["tools"],
    "/docs/learn/ai-agent-with-tools" => ["function calling", "tool use", "tool-use"]
  }

  @doc """
  The alias phrases registered for a canonical page route.
  """
  @spec aliases_for_route(String.t()) :: [String.t()]
  def aliases_for_route(route) when is_binary(route) do
    Map.get(@aliases, normalize_route(route), [])
  end

  @doc """
  The full alias map (canonical route => alias phrases).
  """
  @spec all() :: %{String.t() => [String.t()]}
  def all, do: @aliases

  @doc """
  Returns the canonical routes whose registered alias matches the query.

  An alias matches when every token of an alias phrase is present in the
  query's token set, so "how does the agent server work" matches the
  "agent server" alias while "agent" alone does not. Token matching (rather
  than raw substring) keeps a generic word like "tools" from firing on
  unrelated compound terms.
  """
  @spec routes_for_query(String.t()) :: [String.t()]
  def routes_for_query(query) when is_binary(query) do
    query_tokens = tokenize(query)

    if query_tokens == [] do
      []
    else
      query_set = MapSet.new(query_tokens)

      @aliases
      |> Enum.filter(fn {_route, phrases} -> phrase_matches?(phrases, query_set) end)
      |> Enum.map(&elem(&1, 0))
    end
  end

  defp phrase_matches?(phrases, query_set) do
    Enum.any?(phrases, fn phrase ->
      phrase_tokens = tokenize(phrase)
      phrase_tokens != [] and MapSet.subset?(MapSet.new(phrase_tokens), query_set)
    end)
  end

  defp tokenize(value) do
    value
    |> String.downcase()
    |> String.split(~r/[^[:alnum:]_]+/u, trim: true)
    |> Enum.uniq()
  end

  defp normalize_route("/"), do: "/"

  defp normalize_route(route) when is_binary(route) do
    route |> String.trim_trailing("/")
  end
end
