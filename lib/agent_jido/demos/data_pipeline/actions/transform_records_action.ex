defmodule AgentJido.Demos.DataPipeline.Actions.TransformRecordsAction do
  @moduledoc """
  Transforms the valid records into a canonical, de-duplicated batch.

  Delegates to `AgentJido.Demos.DataPipeline.Pipeline`, which applies the real
  per-source transforms -- currency normalization, derived amounts, canonical
  analytics kinds -- and de-duplicates by source and id. The valid records are
  resolved from the stored value, or re-derived from the ingested batch when
  validation has not run yet, so this step is self-sufficient. No LLM is called.
  """

  use Jido.Action,
    name: "transform_records",
    description: "Transforms valid records into a canonical batch"

  alias AgentJido.Demos.DataPipeline.Pipeline

  @impl true
  def run(_params, %{state: state}) do
    resolved = Pipeline.resolve(state)

    {:ok,
     %{
       status: "transformed",
       valid: resolved.valid,
       rejected: resolved.rejected,
       transformed: resolved.transformed
     }}
  end
end
