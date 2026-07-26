defmodule AgentJido.ContentAssistant.SearchAliases do
  @moduledoc """
  Common user terms (aliases) mapped to their canonical site pages.

  A search for a colloquial term — "agent server", "function calling",
  "durable" — should surface the authoritative page, not whichever page
  happens to mention the word most. It also covers retired route terms:
  the public Training section was retired, so an old term like "training"
  or "signals routing" must lead to the active Docs page that replaced it
  (jido-e10-t05). This module is the single source of truth for those
  term→page mappings, and both search paths consume it:

    * `AgentJido.ContentIngest.Inventory` appends a page's aliases to the
      document text it builds for Arcana, so the backend indexes them and
      a query for the term retrieves the canonical page.
    * `AgentJido.ContentAssistant.Retrieval` appends them to the local
      fallback's searchable text and gives an alias-matched canonical page
      priority in reranking, so it surfaces at the top regardless of which
      path serves the query.

  It also covers operational-control terms: identity context, authorization,
  audit, observability, policy, quota, approval, redaction, and the
  controlled-Agent pattern are all dimensions of one control model, so each
  resolves to the canonical Security and Governance guide rather than whichever
  page mentions the word most (jido-e10-t27).

  Keys are canonical page routes — the value `AgentJido.Pages.route_for/1`
  returns and the inventory indexes as the document path. An alias matches
  a query when every token of an alias phrase is present in the query, so
  "how does the agent server work" matches the "agent server" alias while
  "agent" alone does not (jido-e10 E10-T04).
  """

  @aliases %{
    # Colloquial user terms -> canonical page (jido-e10-t04).
    "/docs/concepts/agent-runtime" => ["agent server", "AgentServer", "long-running"],
    "/docs/operations/supervision-and-failure-boundaries" => ["supervision"],
    "/docs/operations/process-crash-and-restart" => ["restart"],
    "/docs/concepts/persistence" => ["durable", "durability"],
    "/features/tools" => ["tools"],
    "/docs/learn/ai-agent-with-tools" => ["function calling", "tool use", "tool-use"],
    # Retired /training route terms -> the active Docs page each one redirected
    # to (jido-e10-t05). The public Training section was retired; these are the
    # old slugs a returning user still searches for. The mapping mirrors the
    # path-to-path table in `AgentJidoWeb.LegacyRedirects`, so a search for an
    # old term lands on the same active Docs page the HTTP redirect serves.
    "/docs/getting-started" => ["training"],
    "/docs/getting-started/first-agent" => ["agent fundamentals"],
    "/docs/concepts/actions" => ["actions validation"],
    "/docs/concepts/signals" => ["signals routing"],
    "/docs/concepts/directives" => ["directives scheduling"],
    "/docs/getting-started/elixir-developers" => ["liveview integration"],
    "/docs/guides/error-handling-and-recovery" => ["production readiness"],
    # Operational-control terms -> the canonical control guide (jido-e10-t27).
    # The nine dimensions a production agent touches — identity context,
    # authorization, audit, observability, policy, quota, approval, redaction,
    # and the controlled-Agent pattern itself — all live on the Security and
    # Governance page, which states what Jido supplies, what the application
    # owns, and the proof for each. The page is the controlled-Agent example's
    # documented "full operational-control model," so a search for any control
    # term lands on the one guide that draws every boundary. The matching
    # example and package surface alongside it through ordinary lexical search
    # (the controlled-Agent example and the control packages carry these terms).
    "/docs/operations/security-and-governance" => [
      "identity context",
      "authorization",
      "audit",
      "observability",
      "policy",
      "quota",
      "approval",
      "redaction",
      "controlled agent"
    ]
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
