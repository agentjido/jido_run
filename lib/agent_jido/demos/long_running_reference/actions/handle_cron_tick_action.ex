defmodule AgentJido.Demos.LongRunningReference.HandleCronTickAction do
  @moduledoc """
  Handles a scheduled CRON tick for the reference application.

  The agent declares a CRON schedule (`*/1 * * * *` → `reference.cron`). This
  action is what that schedule — or an operator-driven `reference.cron` Signal —
  runs. It is the "scheduling or event input" step of the linear path: the
  agent takes work on a schedule, not only on request.

  The handler is deterministic and side-effect free; the scheduling proof is
  that the tick advances observable state.
  """

  use Jido.Action,
    name: "reference_handle_cron_tick",
    description: "Handles a scheduled reference.cron tick"

  @impl true
  def run(_params, %{state: state}) do
    {:ok,
     %{
       cron_ticks: state.cron_ticks + 1,
       status: :scheduled,
       last_event: "cron.ticked"
     }}
  end
end
