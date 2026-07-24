defmodule AgentJido.TerminologyLintTest do
  @moduledoc """
  Agent/AgentServer terminology gate (jido-e12-t07): public pages must not
  describe an Agent as a process. An Agent is data; an AgentServer is the
  process. Negated statements ("an Agent is not a process") are allowed.
  """
  use ExUnit.Case, async: true

  alias AgentJido.Pages

  @bad_phrases [
    "agent is a process",
    "agents are processes",
    "an agent is a process",
    "the agent is a process",
    "agent is its own process"
  ]

  @negators ["not ", "isn't", "aren't", "never ", "no longer"]

  test "public pages do not describe an Agent as a process" do
    offenders =
      for page <- Pages.all_pages(),
          path = source_path(page),
          is_binary(path) and File.regular?(path),
          content = strip_code(File.read!(path)),
          sentence <- sentences(content),
          phrase <- @bad_phrases,
          String.contains?(sentence, phrase),
          not negated?(sentence),
          do: {page.path, phrase}

    assert offenders == [],
           "pages describe an Agent as a process (should be AgentServer): #{inspect(offenders)}"
  end

  defp source_path(page), do: Map.get(page, :source_path) || Map.get(page, "source_path")

  defp strip_code(text) do
    text |> String.replace(~r/```.*?```/s, "") |> String.replace(~r/~~~.*?~~~/s, "")
  end

  defp sentences(text), do: String.split(text, ~r/(?<=[.!?\n])\s+/)

  defp negated?(sentence) do
    lower = String.downcase(sentence)
    Enum.any?(@negators, &String.contains?(lower, &1))
  end
end
