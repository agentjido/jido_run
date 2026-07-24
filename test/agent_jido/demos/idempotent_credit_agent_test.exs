defmodule AgentJido.Demos.IdempotentCreditAgentTest do
  @moduledoc """
  Idempotent Actions (jido-e07-T04/T15): a duplicate Signal delivery with the
  same dedup key is a no-op.
  """
  use ExUnit.Case, async: true

  alias AgentJido.Demos.IdempotentCredit.CreditAction
  alias AgentJido.Demos.IdempotentCreditAgent

  test "duplicate delivery with the same key is applied once" do
    agent = IdempotentCreditAgent.new()

    {agent, _} = IdempotentCreditAgent.cmd(agent, {CreditAction, %{key: "tx-1", amount: 5}})
    assert agent.state.balance == 5

    # Duplicate delivery of the same Signal (same key) is a no-op.
    {agent, _} = IdempotentCreditAgent.cmd(agent, {CreditAction, %{key: "tx-1", amount: 5}})
    assert agent.state.balance == 5

    # A different key is applied.
    {agent, _} = IdempotentCreditAgent.cmd(agent, {CreditAction, %{key: "tx-2", amount: 3}})
    assert agent.state.balance == 8
  end
end
