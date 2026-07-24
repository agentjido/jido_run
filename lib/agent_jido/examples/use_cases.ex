defmodule AgentJido.Examples.UseCases do
  @moduledoc """
  Home use-case definitions shared by the landing page and the examples index.

  Each use case scopes the examples index by the tags that signal that user job,
  so a home use-case card and its scoped `/examples?use_case=<slug>` destination
  agree on which examples count. The home card status label ("Runnable example"
  vs "Planned pattern") is derived from the same match, so a visitor can tell a
  runnable example from a planned pattern (jido-e04-t21, jido-e04-t22).
  """

  alias AgentJido.Examples
  alias AgentJido.Examples.Example

  # Order here is the order the cards render on the home page. A use case matches
  # an example when the example carries any of the use case's tags.
  @use_cases [
    {"coding", %{label: "Coding agents", tags: ~w(coding)}},
    {"research", %{label: "Research and synthesis", tags: ~w(runic research)}},
    {"documents", %{label: "Document processing", tags: ~w(documents document policy)}},
    {"support", %{label: "Customer support", tags: ~w(support ticket triage)}},
    {"devops",
     %{
       label: "DevOps and monitoring",
       tags: ~w(ops-governance operations observability telemetry incident supervision reliability restart)
     }},
    {"data-pipelines", %{label: "Data pipelines", tags: ~w(data pipeline sql etl)}}
  ]

  @by_slug Map.new(@use_cases)

  @doc """
  All home use cases in card order, as maps with `:slug`, `:label`, and `:tags`.
  """
  @spec all() :: [%{slug: String.t(), label: String.t(), tags: [String.t()]}]
  def all do
    Enum.map(@use_cases, fn {slug, %{label: label, tags: tags}} ->
      %{slug: slug, label: label, tags: tags}
    end)
  end

  @doc """
  Look up a single use case by slug. Returns `%{label:, tags:}` or `nil`.

  Unknown slugs return `nil` so callers can fall back to the unfiltered index.
  """
  @spec fetch(binary()) :: %{label: String.t(), tags: [String.t()]} | nil
  def fetch(slug) when is_binary(slug) do
    case Map.get(@by_slug, slug) do
      nil -> nil
      %{label: label, tags: tags} -> %{label: label, tags: tags}
    end
  end

  @doc """
  Scope a list of examples to a use case.

  A `nil` use case leaves the list unfiltered (the unfiltered examples index).
  Otherwise an example matches when it carries any tag that signals the use case.
  """
  @spec scope([Example.t()], %{tags: [String.t()]} | nil) :: [Example.t()]
  def scope(examples, nil), do: examples

  def scope(examples, %{tags: tags}) do
    wanted = MapSet.new(tags, &normalize_tag/1)

    Enum.filter(examples, fn example ->
      example_tags =
        example
        |> Map.get(:tags, [])
        |> List.wrap()
        |> Enum.map(&normalize_tag/1)
        |> MapSet.new()

      not MapSet.disjoint?(wanted, example_tags)
    end)
  end

  @doc """
  Whether a use case has at least one matching example.

  Defaults to public (non-draft) examples, which drives the home card status
  label. Pass `include_drafts: true` to count drafts as well.
  """
  @spec available?(binary(), keyword()) :: boolean()
  def available?(slug, opts \\ []) do
    case fetch(slug) do
      nil ->
        false

      %{tags: tags} ->
        scope(Examples.all_examples(opts), %{tags: tags}) != []
    end
  end

  defp normalize_tag(tag) do
    tag |> to_string() |> String.downcase() |> String.replace("_", "-") |> String.trim()
  end
end
