defmodule AgentJido.Analytics.GitHub.PathDaily do
  @moduledoc """
  Daily snapshot of top GitHub traffic paths.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "analytics_github_paths_daily" do
    field(:date, :date)
    field(:repo, :string)
    field(:path, :string)
    field(:title, :string)
    field(:views, :integer, default: 0)
    field(:uniques, :integer, default: 0)
    field(:fetched_at, :utc_datetime_usec)

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(row, attrs) do
    row
    |> cast(attrs, [:date, :repo, :path, :title, :views, :uniques, :fetched_at])
    |> validate_required([:date, :repo, :path, :views, :uniques, :fetched_at])
    |> validate_number(:views, greater_than_or_equal_to: 0)
    |> validate_number(:uniques, greater_than_or_equal_to: 0)
    |> unique_constraint([:date, :repo, :path])
  end
end
