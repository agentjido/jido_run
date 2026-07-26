defmodule AgentJido.Demos.DataPipeline.Actions.SummarizeAction do
  @moduledoc """
  Summarizes the pipeline run into one human-readable report.

  Delegates to `AgentJido.Demos.DataPipeline.Pipeline`, which rolls the resolved
  state -- sources collected, records ingested, valid, rejected, transformed,
  and loaded -- into a single line. The full projection is resolved lazily from
  the ingested batch when earlier steps have not run yet, so this step is
  self-sufficient: summarize straight after ingest still produces a complete
  report (and persists the resolved validation, transform, load, and checksum
  into state). No LLM is called.
  """

  use Jido.Action,
    name: "summarize",
    description: "Summarizes the pipeline run into a report"

  alias AgentJido.Demos.DataPipeline.Pipeline

  @impl true
  def run(_params, %{state: state}) do
    resolved = Pipeline.resolve(state)
    projection = Map.merge(state, resolved)

    {:ok,
     %{
       status: "summarized",
       valid: resolved.valid,
       rejected: resolved.rejected,
       transformed: resolved.transformed,
       loaded_count: resolved.loaded_count,
       destination_checksum: resolved.destination_checksum,
       report: Pipeline.summarize(projection)
     }}
  end
end
