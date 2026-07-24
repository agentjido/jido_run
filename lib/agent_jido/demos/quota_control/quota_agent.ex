defmodule AgentJido.Demos.QuotaControlAgent do
  @moduledoc """
  Quota/cost-control reference demo (jido-e07-T42 / jido-e05-T38).

  Enforces a request quota: the BilledAction runs until the budget is reached,
  then is rejected with a clear, observable result.
  """

  alias AgentJido.Demos.QuotaControl.BilledAction

  use Jido.Agent,
    name: "quota_control_agent",
    description: "Demonstrates a bounded request/token quota",
    schema: [
      calls: [type: :integer, default: 0],
      max_calls: [type: :integer, default: 3]
    ],
    signal_routes: [{"quota.billed", BilledAction}]
end
