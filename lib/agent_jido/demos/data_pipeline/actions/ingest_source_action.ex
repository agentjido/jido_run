defmodule AgentJido.Demos.DataPipeline.Actions.IngestSourceAction do
  @moduledoc """
  Collects one source's records into the pipeline batch.

  Selects the orders, users, or events fixture by the `which` parameter, tags
  each record with its `source`, and appends it to the ingested batch so a
  visitor can collect from multiple sources before processing. A fresh collect
  clears any prior validation, transform, load, and summary so downstream steps
  re-run against the new batch instead of stale output.
  """

  use Jido.Action,
    name: "ingest_source",
    description: "Collects a fixture source's records into the pipeline batch"

  alias AgentJido.Demos.DataPipeline.Fixtures

  @impl true
  def run(%{which: which}, %{state: %{ingested: ingested, sources_loaded: sources}})
      when which in [:orders, :users, :events] do
    batch = Fixtures.fetch(which)

    tagged = Enum.map(batch.records, &Map.put(&1, :source, batch.source))

    updated_sources =
      if batch.source in sources, do: sources, else: sources ++ [batch.source]

    {:ok,
     %{
       ingested: ingested ++ tagged,
       sources_loaded: updated_sources,
       status: "ingesting",
       valid: [],
       rejected: [],
       transformed: [],
       loaded_count: 0,
       destination_checksum: "",
       report: ""
     }}
  end

  def run(_params, %{state: %{ingested: ingested, sources_loaded: sources}}) do
    # Unknown source: collect nothing but still reset downstream output.
    {:ok,
     %{
       ingested: ingested,
       sources_loaded: sources,
       status: "ingesting",
       valid: [],
       rejected: [],
       transformed: [],
       loaded_count: 0,
       destination_checksum: "",
       report: ""
     }}
  end
end
