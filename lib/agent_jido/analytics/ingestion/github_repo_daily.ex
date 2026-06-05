defmodule AgentJido.Analytics.Ingestion.GitHubRepoDaily do
  @moduledoc """
  Daily GitHub repository traffic counters.
  """
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "analytics_github_repo_daily" do
    field :day, :date
    field :views_count, :integer, default: 0
    field :views_uniques, :integer, default: 0
    field :clones_count, :integer, default: 0
    field :clones_uniques, :integer, default: 0
    field :metadata, :map, default: %{}

    belongs_to :tracked_repository, AgentJido.Analytics.Ingestion.TrackedRepository

    timestamps(type: :utc_datetime_usec)
  end
end
