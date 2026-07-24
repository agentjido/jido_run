defmodule AgentJido.Demos.ApprovalBoundary.RequestPublishAction do
  @moduledoc """
  First half of a human-approval boundary (jido-e07-T43). Records that a
  high-impact publish was requested and pauses for an explicit decision.
  """
  use Jido.Action,
    name: "request_publish",
    description: "Requests a publish and pauses for approval",
    schema: [topic: [type: :string, required: true]]

  @impl true
  def run(%{topic: topic}, %{state: state}) do
    {:ok, Map.merge(state, %{pending: true, pending_topic: topic})}
  end
end
