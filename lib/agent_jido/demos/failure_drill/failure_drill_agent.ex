defmodule AgentJido.Demos.FailureDrillAgent do
  @moduledoc """
  Supervised agent used by the **Run a failure drill** example.

  It holds a single `ticks` counter that increments through a validated
  Action. The counter is intentionally kept in process state so the drill
  can show what OTP supervision recovers (a fresh process) and what it does
  not (the in-memory state that was lost when the process died).

  Note: Jido isolates Action errors — a raise inside `TickAction.run/2` is
  caught and returned as `{:error, _}`, it does **not** crash the AgentServer.
  The failure drill terminates the process directly, which is the kind of
  process-level failure OTP supervision exists to recover from.
  """

  alias AgentJido.Demos.FailureDrill.TickAction

  use Jido.Agent,
    name: "failure_drill_agent",
    description: "Supervised agent for the Run a failure drill example",
    schema: [
      ticks: [type: :integer, default: 0]
    ],
    signal_routes: [
      {"failure_drill.tick", TickAction}
    ]
end
