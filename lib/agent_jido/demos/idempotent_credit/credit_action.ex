defmodule AgentJido.Demos.IdempotentCredit.CreditAction do
  @moduledoc """
  Idempotent action (jido-e07-T04/T15). Uses a caller-supplied dedup key so a
  duplicate Signal delivery does not credit the account twice.
  """
  use Jido.Action,
    name: "credit",
    description: "Credits the account once per dedup key",
    schema: [
      key: [type: :string, required: true],
      amount: [type: :integer, default: 1]
    ]

  @impl true
  def run(%{key: key, amount: amount}, %{state: %{applied_keys: applied, balance: balance} = state}) do
    if key in applied do
      # Duplicate delivery: no state change.
      {:ok, state}
    else
      {:ok, Map.merge(state, %{balance: balance + amount, applied_keys: [key | applied]})}
    end
  end
end
