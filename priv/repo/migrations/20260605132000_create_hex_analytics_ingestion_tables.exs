defmodule AgentJido.Repo.Migrations.CreateHexAnalyticsIngestionTables do
  use Ecto.Migration

  def change do
    create table(:analytics_tracked_hex_packages, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:package_name, :string, null: false)
      add(:display_name, :string)
      add(:url, :text)
      add(:source, :string)
      add(:active, :boolean, null: false, default: true)
      add(:metadata, :map, null: false, default: %{})

      timestamps(type: :utc_datetime_usec)
    end

    create(unique_index(:analytics_tracked_hex_packages, [:package_name]))
    create(index(:analytics_tracked_hex_packages, [:active]))

    create table(:analytics_hex_package_daily, primary_key: false) do
      add(:id, :binary_id, primary_key: true)

      add(
        :tracked_hex_package_id,
        references(:analytics_tracked_hex_packages, type: :binary_id, on_delete: :delete_all),
        null: false
      )

      add(:package_name, :string, null: false)
      add(:day, :date, null: false)
      add(:latest_version, :string)
      add(:downloads_day, :integer, null: false, default: 0)
      add(:downloads_week, :integer, null: false, default: 0)
      add(:downloads_recent, :integer, null: false, default: 0)
      add(:downloads_all, :integer, null: false, default: 0)
      add(:metadata, :map, null: false, default: %{})

      timestamps(type: :utc_datetime_usec)
    end

    create(unique_index(:analytics_hex_package_daily, [:tracked_hex_package_id, :day]))
    create(index(:analytics_hex_package_daily, [:package_name, :day]))
    create(index(:analytics_hex_package_daily, [:day]))

    create table(:analytics_hex_release_daily, primary_key: false) do
      add(:id, :binary_id, primary_key: true)

      add(
        :tracked_hex_package_id,
        references(:analytics_tracked_hex_packages, type: :binary_id, on_delete: :delete_all),
        null: false
      )

      add(:package_name, :string, null: false)
      add(:version, :string, null: false)
      add(:day, :date, null: false)
      add(:downloads_total, :integer, null: false, default: 0)
      add(:release_inserted_at, :utc_datetime_usec)
      add(:has_docs, :boolean)
      add(:metadata, :map, null: false, default: %{})

      timestamps(type: :utc_datetime_usec)
    end

    create(unique_index(:analytics_hex_release_daily, [:tracked_hex_package_id, :version, :day]))
    create(index(:analytics_hex_release_daily, [:package_name, :version, :day]))
    create(index(:analytics_hex_release_daily, [:day]))
  end
end
