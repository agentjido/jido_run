defmodule AgentJido.Demos.SignalTrace.Actions.EmitReadyAction do
  @moduledoc """
  Agent A's Action in the two-agent signal-trace example.

  It accepts an intake request and emits a downstream `work.ready` Signal — the
  *cause* the second agent (`FulfillmentAgent`) routes and acts on. The emitted
  Signal carries the work id and unit count forward so the downstream leg is
  causally linked to this one.
  """

  alias Jido.Agent.Directive
  alias Jido.Signal

  use Jido.Action,
    name: "emit_ready",
    description: "Emits the work.ready Signal a second agent routes",
    schema: [
      work_id: [type: :string, required: true, doc: "Identifier of the accepted work"],
      units: [type: :integer, required: true, doc: "Number of units to fulfil"]
    ]

  @impl true
  def run(%{work_id: work_id, units: units}, _context) do
    cause =
      Signal.new!("work.ready", %{work_id: work_id, units: units}, source: "/signal_trace/emitter")

    {:ok, %{dispatched_work_id: work_id}, %Directive.Emit{signal: cause}}
  end
end
