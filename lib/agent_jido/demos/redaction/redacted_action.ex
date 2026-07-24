defmodule AgentJido.Demos.Redaction.RedactedAction do
  @moduledoc """
  Action that receives a sensitive token (e.g. a provider key) as a param.
  Used by the redaction regression test (jido-e12-T41 / jido-e08-T44) to prove
  the secret never appears in telemetry metadata.
  """
  use Jido.Action,
    name: "redacted",
    description: "Receives a secret param; stores nothing",
    schema: [token: [type: :string, default: ""]]

  @impl true
  def run(_params, _context), do: {:ok, %{}}
end
