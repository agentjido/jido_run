defmodule AgentJido.Demos.CodingAssistant.Actions.AnalyzeCodeAction do
  @moduledoc """
  Scans the agent's loaded source for real nil-handling defects.

  `String.trim/1` raises `FunctionClauseError` on `nil`, so any direct call is
  a latent crash when the input can be nil. This action performs that scan for
  real -- it walks the loaded source line by line and reports each call site --
  rather than replaying a canned finding.
  """

  use Jido.Action,
    name: "analyze_code",
    description: "Scans source for String.trim/1 calls that raise on nil input"

  @impl true
  def run(_params, %{state: %{source: source}}) do
    findings =
      source
      |> String.split("\n", trim: false)
      |> Enum.with_index(1)
      |> Enum.filter(fn {line, _index} -> String.contains?(line, "String.trim(") end)
      |> Enum.map(fn {line, index} ->
        "- line #{index}: #{String.trim(line)} -- String.trim/1 raises on nil input"
      end)
      |> Enum.join("\n")

    # A fresh analysis clears any stale patch so the workflow stays honest.
    {:ok, %{findings: findings, patch: ""}}
  end
end
