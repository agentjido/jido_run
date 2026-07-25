defmodule AgentJido.Demos.LongRunningReference.HandleRetryAction do
  @moduledoc """
  Handles one retry attempt for the reference application.

  Each invocation is one bounded attempt: increment `attempts`, and either
  complete when the budget is reached or reschedule another `reference.retry`
  Signal. The observable result (`attempts` never exceeding `max_attempts`,
  status ending at `:recovered`) is the retry-and-failure-policy proof.
  """

  alias Jido.Agent.Directive
  alias Jido.Signal

  use Jido.Action,
    name: "reference_handle_retry",
    description: "Processes one bounded retry attempt"

  @impl true
  def run(_params, context) do
    state = context.state
    attempts = Map.get(state, :attempts, 0) + 1
    max_attempts = Map.get(state, :max_attempts, 3)
    retry_delay_ms = Map.get(state, :retry_delay_ms, 40)

    if attempts >= max_attempts do
      {:ok, %{status: :recovered, attempts: attempts, last_event: "retry.recovered"}}
    else
      retry_signal = Signal.new!("reference.retry", %{}, source: "/reference")
      schedule = %Directive.Schedule{delay_ms: retry_delay_ms, message: retry_signal}
      {:ok, %{status: :retrying, attempts: attempts, last_event: "retry.attempt"}, schedule}
    end
  end
end
