defmodule AgentJido.Analytics.Ingestion.GitHubPathSnapshot do
  @moduledoc """
  Ranked GitHub path snapshot for a repository.
  """
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "analytics_github_path_snapshots" do
    field :snapshot_date, :date
    field :rank, :integer
    field :path, :string
    field :path_key, :string
    field :title, :string
    field :count, :integer, default: 0
    field :uniques, :integer, default: 0
    field :metadata, :map, default: %{}

    belongs_to :tracked_repository, AgentJido.Analytics.Ingestion.TrackedRepository

    timestamps(updated_at: false, type: :utc_datetime_usec)
  end
end
