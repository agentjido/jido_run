defmodule AgentJido.Demos.ApprovalBoundary.ConfirmPublishAction do
  @moduledoc """
  Second half of the human-approval boundary (jido-e07-T43). The high-impact
  publish effect only runs after an explicit confirm decision; without a prior
  request it is rejected (fail closed), and the decision is recorded.
  """
  use Jido.Action,
    name: "confirm_publish",
    description: "Approves and runs a pending publish, recording the decision",
    schema: [by: [type: :string, required: true]]

  @impl true
  def run(%{by: by}, %{state: %{pending: true} = state}) do
    {:ok,
     Map.merge(state, %{
       pending: false,
       pending_topic: nil,
       published_count: state[:published_count] + 1,
       last_decided_by: by
     })}
  end

  def run(_params, %{state: %{pending: false}}) do
    {:error, :no_pending_publish}
  end
end
