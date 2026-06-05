defmodule AgentJido.Analytics.Ingestion.HexReleaseDaily do
  @moduledoc """
  Daily Hex release download counter snapshots.
  """
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "analytics_hex_release_daily" do
    field :package_name, :string
    field :version, :string
    field :day, :date
    field :downloads_total, :integer, default: 0
    field :release_inserted_at, :utc_datetime_usec
    field :has_docs, :boolean
    field :metadata, :map, default: %{}

    belongs_to :tracked_hex_package, AgentJido.Analytics.Ingestion.TrackedHexPackage,
      type: :binary_id,
      foreign_key: :tracked_hex_package_id

    timestamps(type: :utc_datetime_usec)
  end
end
