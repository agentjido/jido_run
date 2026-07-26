defmodule AgentJido.Demos.SignalTrace.EmitterAgent do
  @moduledoc """
  Agent A in the two-agent signal-trace example.

  It accepts an `intake.request` and runs `EmitReadyAction`, which emits the
  downstream `work.ready` Signal — the cause the second agent reacts to.
  """

  alias AgentJido.Demos.SignalTrace.Actions.EmitReadyAction

  use Jido.Agent,
    name: "signal_trace_emitter",
    description: "Emits a downstream Signal that a second agent routes and fulfils",
    schema: [
      dispatched_work_id: [type: :string, default: ""]
    ],
    signal_routes: [
      {"intake.request", EmitReadyAction}
    ]

  @doc false
  @spec plugin_specs() :: nonempty_list(Jido.Plugin.Spec.t())
  def plugin_specs, do: super()
end
