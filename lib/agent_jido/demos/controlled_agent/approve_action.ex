defmodule AgentJido.Demos.ControlledAgent.ApproveAction do
  @moduledoc """
  Protected Action for the controlled-agent demo. Increments the approved-work
  counter. It only runs when the AuthorizationPlugin permits the caller.
  """
  use Jido.Action,
    name: "approve",
    description: "Increments the approved-work counter",
    schema: [note: [type: :string, default: ""]]

  @impl true
  def run(_params, %{state: %{approved_count: count}}) do
    {:ok, %{approved_count: count + 1}}
  end
end
