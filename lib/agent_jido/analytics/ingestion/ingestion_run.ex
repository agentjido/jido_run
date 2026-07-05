defmodule AgentJido.Analytics.Ingestion.IngestionRun do
  @moduledoc """
  Audit row for a single external analytics ingestion attempt.
  """
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "analytics_ingestion_runs" do
    field :source, :string
    field :status, :string
    field :started_at, :utc_datetime_usec
    field :finished_at, :utc_datetime_usec
    field :date_from, :date
    field :date_to, :date
    field :rows_count, :integer, default: 0
    field :error, :string
    field :metadata, :map, default: %{}

    belongs_to :tracked_repository, AgentJido.Analytics.Ingestion.TrackedRepository

    timestamps(updated_at: false, type: :utc_datetime_usec)
  end

  @type t :: %__MODULE__{}
end
