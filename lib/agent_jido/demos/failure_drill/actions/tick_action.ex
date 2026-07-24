defmodule AgentJido.Demos.FailureDrill.TickAction do
  @moduledoc """
  Increments the failure-drill agent's `ticks` counter.

  Deterministic and side-effect free — no API key, network, or runtime is
  required. The drill's "crash" does not come from here; it is a deliberate
  process termination handled by the supervisor.
  """

  use Jido.Action,
    name: "failure_drill_tick",
    schema: [
      by: [type: :integer, default: 1, doc: "Number of ticks to add"]
    ]

  @impl true
  def run(%{by: by}, %{state: %{ticks: ticks}}) do
    {:ok, %{ticks: ticks + by}}
  end
end
