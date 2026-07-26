defmodule AgentJido.Demos.CodingAssistant.Actions.ReadSourceAction do
  @moduledoc """
  Loads the fixture parser source into agent state.

  Resets any prior findings and patch so a fresh read starts the workflow
  cleanly.
  """

  use Jido.Action,
    name: "read_source",
    description: "Loads the fixture parser source into agent state"

  alias AgentJido.Demos.CodingAssistant.Fixtures

  @impl true
  def run(_params, _context) do
    {:ok, %{source: Fixtures.parser_source(), findings: "", patch: ""}}
  end
end
