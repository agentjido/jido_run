defmodule AgentJido.Demos.SignalTrace.FulfillmentAgent do
  @moduledoc """
  Agent B in the two-agent signal-trace example.

  Its route table maps the `work.ready` Signal (emitted by `EmitterAgent`) to
  `FulfillAction`. Routing the Signal — not a hardcoded call — is what directs
  the work, which is the *route* and *Action* legs of the trace.
  """

  alias AgentJido.Demos.SignalTrace.Actions.FulfillAction

  use Jido.Agent,
    name: "signal_trace_fulfillment",
    description: "Routes the work.ready Signal to FulfillAction and records the result",
    schema: [
      fulfilled: [type: {:list, :map}, default: []],
      total_units: [type: :integer, default: 0]
    ],
    signal_routes: [
      {"work.ready", FulfillAction}
    ]

  @doc false
  @spec plugin_specs() :: nonempty_list(Jido.Plugin.Spec.t())
  def plugin_specs, do: super()
end
