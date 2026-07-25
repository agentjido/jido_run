defmodule AgentJido.Demos.LongRunningReference.StartRetryAction do
  @moduledoc """
  Starts a bounded retry loop for the reference application.

  The "retry and failure policy" step of the linear path. A transient failure
  is recovered by re-dispatching the work to itself on a schedule directive,
  bounded by `max_attempts`. This mirrors the proven
  `AgentJido.Demos.ScheduleDirective` pattern: the first attempt schedules a
  `reference.retry` Signal after `retry_delay_ms`, and `HandleRetryAction`
  reschedules until the budget is spent.
  """

  alias Jido.Agent.Directive
  alias Jido.Signal

  use Jido.Action,
    name: "reference_start_retry",
    description: "Starts a bounded retry loop for transient failure",
    schema: [
      max_attempts: [type: :integer, default: 3],
      retry_delay_ms: [type: :integer, default: 40]
    ]

  @impl true
  def run(%{max_attempts: max_attempts, retry_delay_ms: retry_delay_ms}, _context) do
    retry_signal = Signal.new!("reference.retry", %{}, source: "/reference")
    schedule = %Directive.Schedule{delay_ms: retry_delay_ms, message: retry_signal}

    {:ok,
     %{
       status: :retrying,
       attempts: 0,
       max_attempts: max_attempts,
       retry_delay_ms: retry_delay_ms,
       last_event: "retry.started"
     }, schedule}
  end
end
