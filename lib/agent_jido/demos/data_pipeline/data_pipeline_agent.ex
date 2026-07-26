defmodule AgentJido.Demos.DataPipeline do
  @moduledoc """
  A deterministic data-pipeline (ETL) agent.

  It demonstrates a collect → validate → transform → load → summarize pipeline
  on the real Jido runtime: collect records from one or more fixture sources
  with a typed `IngestSource` action, validate them against their source
  schemas with a typed `ValidateRecords` action, transform the valid batch with
  a typed `TransformRecords` action, load it to a destination with a typed
  `LoadRecords` action, and summarize the run with a typed `Summarize` action.
  No LLM provider is called -- the validation, transformation, loading, and
  checksum are real logic over the record values, so the demo is fully
  deterministic and needs no API key and no network.
  """

  use Jido.Agent,
    name: "data_pipeline_agent",
    description: "Collects records from multiple sources, validates, transforms, loads, and summarizes a scheduled batch",
    schema: [
      sources_loaded: [type: {:list, :string}, default: []],
      ingested: [type: {:list, :map}, default: []],
      valid: [type: {:list, :map}, default: []],
      rejected: [type: {:list, :map}, default: []],
      transformed: [type: {:list, :map}, default: []],
      loaded_count: [type: :integer, default: 0],
      destination_checksum: [type: :string, default: ""],
      status: [type: :string, default: ""],
      report: [type: :string, default: ""]
    ],
    signal_routes: [
      {"data.ingest", AgentJido.Demos.DataPipeline.Actions.IngestSourceAction},
      {"data.validate", AgentJido.Demos.DataPipeline.Actions.ValidateRecordsAction},
      {"data.transform", AgentJido.Demos.DataPipeline.Actions.TransformRecordsAction},
      {"data.load", AgentJido.Demos.DataPipeline.Actions.LoadRecordsAction},
      {"data.summarize", AgentJido.Demos.DataPipeline.Actions.SummarizeAction}
    ]

  alias AgentJido.Demos.DataPipeline.Actions.{
    IngestSourceAction,
    LoadRecordsAction,
    SummarizeAction,
    TransformRecordsAction,
    ValidateRecordsAction
  }

  alias AgentJido.Demos.DataPipeline.Fixtures

  @doc """
  Collects one named source's records into the batch. `which` selects the
  fixture (`:orders`, `:users`, or `:events`); a fresh collect resets the
  downstream validation, transform, load, and summary.
  """
  @spec ingest(Jido.Agent.t(), :orders | :users | :events | atom()) :: Jido.Agent.cmd_result()
  def ingest(agent, which) do
    cmd(agent, {IngestSourceAction, %{which: which}})
  end

  @doc """
  Collects every fixture source's records into the batch in display order.
  """
  @spec ingest_all(Jido.Agent.t()) :: Jido.Agent.cmd_result()
  def ingest_all(agent) do
    Enum.reduce(Fixtures.sources(), {agent, []}, fn which, {acc, _directives} ->
      ingest(acc, which)
    end)
  end

  @doc """
  Validates the collected batch against each record's source schema.
  """
  @spec validate_records(Jido.Agent.t()) :: Jido.Agent.cmd_result()
  def validate_records(agent) do
    cmd(agent, ValidateRecordsAction)
  end

  @doc """
  Transforms the valid records into a canonical, de-duplicated batch.
  """
  @spec transform_records(Jido.Agent.t()) :: Jido.Agent.cmd_result()
  def transform_records(agent) do
    cmd(agent, TransformRecordsAction)
  end

  @doc """
  Loads the transformed batch to the destination and produces a checksum.
  """
  @spec load_records(Jido.Agent.t()) :: Jido.Agent.cmd_result()
  def load_records(agent) do
    cmd(agent, LoadRecordsAction)
  end

  @doc """
  Summarizes the pipeline run into one human-readable report.
  """
  @spec summarize_run(Jido.Agent.t()) :: Jido.Agent.cmd_result()
  def summarize_run(agent) do
    cmd(agent, SummarizeAction)
  end
end
