defmodule AgentJido.Analytics.GitHub.RepoDaily do
  @moduledoc """
  Daily GitHub repository traffic totals.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "analytics_github_repo_daily" do
    field(:date, :date)
    field(:repo, :string)
    field(:views, :integer, default: 0)
    field(:unique_visitors, :integer, default: 0)
    field(:clones, :integer, default: 0)
    field(:unique_cloners, :integer, default: 0)
    field(:fetched_at, :utc_datetime_usec)

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(row, attrs) do
    row
    |> cast(attrs, [:date, :repo, :views, :unique_visitors, :clones, :unique_cloners, :fetched_at])
    |> validate_required([:date, :repo, :views, :unique_visitors, :clones, :unique_cloners, :fetched_at])
    |> validate_number(:views, greater_than_or_equal_to: 0)
    |> validate_number(:unique_visitors, greater_than_or_equal_to: 0)
    |> validate_number(:clones, greater_than_or_equal_to: 0)
    |> validate_number(:unique_cloners, greater_than_or_equal_to: 0)
    |> unique_constraint([:date, :repo])
  end
end
