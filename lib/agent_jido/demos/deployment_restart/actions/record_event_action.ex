defmodule AgentJido.Demos.DeploymentRestart.RecordEvent do
  @moduledoc """
  Increments the deployment-restart example agent's `events` counter.

  Deterministic and side-effect free — no API key, network, or runtime is
  required. The "deployment restart" does not come from here; it is the whole
  supervised tree being torn down and rebuilt (a deploy, a release upgrade, or
  a node restart). That destroys the in-memory counter, which is exactly the
  contrast the example makes observable.
  """

  use Jido.Action,
    name: "deployment_restart_record",
    schema: [
      by: [type: :integer, default: 1, doc: "Number of events to record"]
    ]

  @impl true
  def run(%{by: by}, %{state: %{events: events}}) do
    {:ok, %{events: events + by}}
  end
end
