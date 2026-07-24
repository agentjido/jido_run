defmodule AgentJido.Demos.ApprovalBoundaryAgent do
  @moduledoc """
  Human-approval-boundary reference demo (jido-e07-T43/T23).

  A high-impact publish effect waits for an explicit confirm decision. The
  request pauses; only a confirm runs the effect and records who decided.
  """

  alias AgentJido.Demos.ApprovalBoundary.{ConfirmPublishAction, RequestPublishAction}

  use Jido.Agent,
    name: "approval_boundary_agent",
    description: "Demonstrates a human-approval boundary around a high-impact effect",
    schema: [
      published_count: [type: :integer, default: 0],
      pending: [type: :boolean, default: false],
      pending_topic: [type: :string, default: ""],
      last_decided_by: [type: :string, default: ""]
    ],
    signal_routes: [
      {"publish.request", RequestPublishAction},
      {"publish.confirm", ConfirmPublishAction}
    ]
end
