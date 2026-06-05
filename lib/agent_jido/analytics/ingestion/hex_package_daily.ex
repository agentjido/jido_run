defmodule AgentJido.Analytics.Ingestion.HexPackageDaily do
  @moduledoc """
  Daily Hex package download counter snapshots.
  """
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "analytics_hex_package_daily" do
    field :package_name, :string
    field :day, :date
    field :latest_version, :string
    field :downloads_day, :integer, default: 0
    field :downloads_week, :integer, default: 0
    field :downloads_recent, :integer, default: 0
    field :downloads_all, :integer, default: 0
    field :metadata, :map, default: %{}

    belongs_to :tracked_hex_package, AgentJido.Analytics.Ingestion.TrackedHexPackage,
      type: :binary_id,
      foreign_key: :tracked_hex_package_id

    timestamps(type: :utc_datetime_usec)
  end
end
