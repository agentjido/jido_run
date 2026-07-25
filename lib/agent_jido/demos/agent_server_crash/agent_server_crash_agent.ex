defmodule AgentJido.Demos.AgentServerCrashAgent do
  @moduledoc """
  Supervised agent for the **Process crash and restart** example (`jido-e07-t12`).

  It holds a single `events` counter that increments through a validated
  Action. The counter is intentionally kept in process state so the example
  can show what OTP supervision recovers after a process crash — a fresh,
  restarted process — and what it does **not** recover: the in-memory state
  that was lost when the process died. That contrast is the "observed state
  result" the example makes explicit.

  Note: Jido isolates Action errors — a raise inside `RecordEvent.run/2` is
  caught and returned as `{:error, _}`, it does **not** crash the AgentServer.
  The example terminates the process directly, which is the kind of
  process-level failure OTP supervision exists to recover from.
  """

  alias AgentJido.Demos.AgentServerCrash.RecordEvent

  use Jido.Agent,
    name: "agent_server_crash_agent",
    description: "Supervised agent for the Process crash and restart example",
    schema: [
      events: [type: :integer, default: 0]
    ],
    signal_routes: [
      {"agent_server_crash.record", RecordEvent}
    ]
end
