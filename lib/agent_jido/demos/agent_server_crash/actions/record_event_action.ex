defmodule AgentJido.Demos.AgentServerCrash.RecordEvent do
  @moduledoc """
  Increments the crash example agent's `events` counter.

  Deterministic and side-effect free — no API key, network, or runtime is
  required. The example's "crash" does not come from here; it is a deliberate
  process termination handled by the supervisor.
  """

  use Jido.Action,
    name: "agent_server_crash_record",
    schema: [
      by: [type: :integer, default: 1, doc: "Number of events to record"]
    ]

  @impl true
  def run(%{by: by}, %{state: %{events: events}}) do
    {:ok, %{events: events + by}}
  end
end
