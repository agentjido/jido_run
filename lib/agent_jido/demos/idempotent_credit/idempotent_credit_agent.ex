defmodule AgentJido.Demos.IdempotentCreditAgent do
  @moduledoc """
  Idempotent-Actions reference demo (jido-e07-T04/T15). Duplicate Signal
  delivery is a no-op via a dedup key.
  """

  alias AgentJido.Demos.IdempotentCredit.CreditAction

  use Jido.Agent,
    name: "idempotent_credit_agent",
    description: "Demonstrates idempotent Actions against duplicate delivery",
    schema: [
      balance: [type: :integer, default: 0],
      applied_keys: [type: {:array, :string}, default: []]
    ],
    signal_routes: [{"account.credit", CreditAction}]
end
