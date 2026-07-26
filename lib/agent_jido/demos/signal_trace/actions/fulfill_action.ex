defmodule AgentJido.Demos.SignalTrace.Actions.FulfillAction do
  @moduledoc """
  Agent B's Action in the two-agent signal-trace example.

  `FulfillmentAgent` routes the `work.ready` Signal (emitted by Agent A) to this
  Action. Its validated schema mirrors the Signal payload, and its result — the
  *result* leg of the trace — is the state change that records the fulfilled
  work and the unit total.
  """

  use Jido.Action,
    name: "fulfill",
    description: "Fulfils a unit of work routed by the work.ready Signal",
    schema: [
      work_id: [type: :string, required: true, doc: "Identifier of the work being fulfilled"],
      units: [type: :integer, required: true, doc: "Number of units to fulfil"]
    ]

  @impl true
  def run(%{work_id: work_id, units: units}, context) do
    prior = Map.get(context.state, :fulfilled, [])
    total = Map.get(context.state, :total_units, 0)
    entry = %{work_id: work_id, units: units}

    {:ok, %{fulfilled: [entry | prior], total_units: total + units}}
  end
end
