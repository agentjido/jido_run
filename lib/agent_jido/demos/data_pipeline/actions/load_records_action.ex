defmodule AgentJido.Demos.DataPipeline.Actions.LoadRecordsAction do
  @moduledoc """
  Loads the transformed batch to the destination and produces a stable checksum.

  Delegates to `AgentJido.Demos.DataPipeline.Pipeline`, which "writes" the
  transformed records and derives a deterministic `phash2` checksum over a
  canonical projection of the batch. The transformed records are resolved from
  the stored value, or derived from the ingested batch when earlier steps have
  not run yet, so this step is self-sufficient. No LLM and no real network call
  is made -- the "destination" is a deterministic in-process projection.
  """

  use Jido.Action,
    name: "load_records",
    description: "Loads the transformed batch to the destination"

  alias AgentJido.Demos.DataPipeline.Pipeline

  @impl true
  def run(_params, %{state: state}) do
    resolved = Pipeline.resolve(state)
    loaded = Pipeline.load(resolved.transformed)

    {:ok,
     %{
       status: "loaded",
       valid: resolved.valid,
       rejected: resolved.rejected,
       transformed: resolved.transformed,
       loaded_count: loaded.loaded_count,
       destination_checksum: loaded.destination_checksum
     }}
  end
end
