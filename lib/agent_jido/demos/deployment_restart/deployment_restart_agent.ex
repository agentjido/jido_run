defmodule AgentJido.Demos.DeploymentRestartAgent do
  @moduledoc """
  Supervised agent for the **Deployment restart** example (`jido-e07-t14`).

  It holds a single `events` counter that increments through a validated
  Action. The counter lives only in process state, so when an entire
  deployment is torn down and rebuilt — a deploy, a release upgrade, or a node
  restart — the counter is gone. That is the contrast the example makes
  explicit: a fresh deployment boots a fresh agent at its **initial** state,
  so the workflow **safely restarts**, it does not *resume* mid-flight.

  Resuming mid-flight (reconstructing the pre-deploy state) is an
  application-owned decision: persist state and replay it on boot, or replay
  a durable Signal Journal. That work is separate from this example — see the
  page's "stated semantics" section.
  """

  alias AgentJido.Demos.DeploymentRestart.RecordEvent

  use Jido.Agent,
    name: "deployment_restart_agent",
    description: "Supervised agent for the Deployment restart example",
    schema: [
      events: [type: :integer, default: 0]
    ],
    signal_routes: [
      {"deployment_restart.record", RecordEvent}
    ]
end
