defmodule AgentJido.Demos.QuotaControl.BilledAction do
  @moduledoc """
  Quota-controlled action (jido-e07-T42). Each call counts against a budget;
  once the quota is reached the action is rejected with an observable result,
  demonstrating bounded cost control without an LLM.
  """
  use Jido.Action,
    name: "billed",
    description: "Counts against a quota and rejects when it is exhausted",
    schema: [item: [type: :string, default: ""]]

  @impl true
  def run(_params, %{state: %{calls: calls, max_calls: max} = state}) when calls < max do
    {:ok, Map.put(state, :calls, calls + 1)}
  end

  def run(_params, _context) do
    {:error, :quota_exceeded}
  end
end
