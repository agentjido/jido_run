defmodule AgentJido.Demos.ControlledAgent do
  @moduledoc """
  Controlled-agent reference demo (jido-e07).

  A supervised agent whose Actions pass through a fail-closed authorization
  plugin before execution. Only principals in the allowlist may run the
  protected Action.
  """

  alias AgentJido.Demos.ControlledAgent.{ApproveAction, AuthorizationPlugin, IngressPlugin}

  use Jido.Agent,
    name: "controlled_agent",
    description: "Controlled agent with fail-closed authorization",
    schema: [approved_count: [type: :integer, default: 0]],
    plugins: [
      # Verify/enrich incoming context before Agent processing (jido-e07-t38),
      # then fail-closed authorization before the Action runs.
      {IngressPlugin, %{}},
      {AuthorizationPlugin, %{allowed: ["alice"]}}
    ],
    signal_routes: [{"work.approve", ApproveAction}]
end
