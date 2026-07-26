defmodule AgentJido.Demos.DataPipeline.Actions.ValidateRecordsAction do
  @moduledoc """
  Validates the collected batch against each record's source schema.

  Delegates to `AgentJido.Demos.DataPipeline.Pipeline`, which checks the real
  fields on each record and partitions the batch into valid records and
  rejected records (each with a reason). The check is real -- it inspects the
  loaded records -- so a malformed record is rejected for real. No LLM is
  called.
  """

  use Jido.Action,
    name: "validate_records",
    description: "Validates collected records against their source schemas"

  alias AgentJido.Demos.DataPipeline.Pipeline

  @impl true
  def run(_params, %{state: %{ingested: ingested}}) do
    {valid, rejected} = Pipeline.validate(ingested)

    {:ok, %{status: "validated", valid: valid, rejected: rejected}}
  end
end
