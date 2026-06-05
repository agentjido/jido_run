defmodule AgentJido.Repo.Migrations.CreateExternalAnalyticsIngestionTables do
  use Ecto.Migration

  def change do
    create table(:analytics_tracked_repositories, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:provider, :string, null: false, default: "github")
      add(:owner, :string, null: false)
      add(:name, :string, null: false)
      add(:full_name, :string, null: false)
      add(:url, :text)
      add(:label, :string)
      add(:source, :string)
      add(:active, :boolean, null: false, default: true)
      add(:metadata, :map, null: false, default: %{})

      timestamps(type: :utc_datetime_usec)
    end

    create(unique_index(:analytics_tracked_repositories, [:provider, :owner, :name]))
    create(index(:analytics_tracked_repositories, [:active, :provider]))
    create(index(:analytics_tracked_repositories, [:full_name]))

    create table(:analytics_ingestion_runs, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:source, :string, null: false)
      add(:status, :string, null: false)
      add(:started_at, :utc_datetime_usec, null: false)
      add(:finished_at, :utc_datetime_usec)
      add(:date_from, :date)
      add(:date_to, :date)
      add(:rows_count, :integer, null: false, default: 0)
      add(:error, :text)
      add(:metadata, :map, null: false, default: %{})

      add(
        :tracked_repository_id,
        references(:analytics_tracked_repositories, type: :binary_id, on_delete: :nilify_all)
      )

      timestamps(updated_at: false, type: :utc_datetime_usec)
    end

    create(index(:analytics_ingestion_runs, [:source, :started_at]))
    create(index(:analytics_ingestion_runs, [:status, :started_at]))
    create(index(:analytics_ingestion_runs, [:tracked_repository_id, :started_at]))

    create table(:analytics_github_repo_daily, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:tracked_repository_id, references(:analytics_tracked_repositories, type: :binary_id, on_delete: :delete_all), null: false)
      add(:day, :date, null: false)
      add(:views_count, :integer, null: false, default: 0)
      add(:views_uniques, :integer, null: false, default: 0)
      add(:clones_count, :integer, null: false, default: 0)
      add(:clones_uniques, :integer, null: false, default: 0)
      add(:metadata, :map, null: false, default: %{})

      timestamps(type: :utc_datetime_usec)
    end

    create(unique_index(:analytics_github_repo_daily, [:tracked_repository_id, :day]))
    create(index(:analytics_github_repo_daily, [:day]))

    create table(:analytics_github_referrer_snapshots, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:tracked_repository_id, references(:analytics_tracked_repositories, type: :binary_id, on_delete: :delete_all), null: false)
      add(:snapshot_date, :date, null: false)
      add(:rank, :integer, null: false)
      add(:referrer, :string, null: false)
      add(:count, :integer, null: false, default: 0)
      add(:uniques, :integer, null: false, default: 0)
      add(:metadata, :map, null: false, default: %{})

      timestamps(updated_at: false, type: :utc_datetime_usec)
    end

    create(unique_index(:analytics_github_referrer_snapshots, [:tracked_repository_id, :snapshot_date, :referrer]))
    create(index(:analytics_github_referrer_snapshots, [:snapshot_date]))

    create table(:analytics_github_path_snapshots, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:tracked_repository_id, references(:analytics_tracked_repositories, type: :binary_id, on_delete: :delete_all), null: false)
      add(:snapshot_date, :date, null: false)
      add(:rank, :integer, null: false)
      add(:path, :text, null: false)
      add(:path_key, :string, null: false)
      add(:title, :text)
      add(:count, :integer, null: false, default: 0)
      add(:uniques, :integer, null: false, default: 0)
      add(:metadata, :map, null: false, default: %{})

      timestamps(updated_at: false, type: :utc_datetime_usec)
    end

    create(unique_index(:analytics_github_path_snapshots, [:tracked_repository_id, :snapshot_date, :path_key]))
    create(index(:analytics_github_path_snapshots, [:snapshot_date]))

    create table(:analytics_plausible_site_daily, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:site_id, :string, null: false)
      add(:day, :date, null: false)
      add(:visitors, :integer, null: false, default: 0)
      add(:visits, :integer, null: false, default: 0)
      add(:pageviews, :integer, null: false, default: 0)
      add(:bounce_rate, :float)
      add(:visit_duration, :integer)
      add(:events, :integer, null: false, default: 0)
      add(:metadata, :map, null: false, default: %{})

      timestamps(type: :utc_datetime_usec)
    end

    create(unique_index(:analytics_plausible_site_daily, [:site_id, :day]))
    create(index(:analytics_plausible_site_daily, [:day]))

    create table(:analytics_plausible_dimension_daily, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:site_id, :string, null: false)
      add(:day, :date, null: false)
      add(:dimension, :string, null: false)
      add(:value, :text, null: false)
      add(:value_key, :string, null: false)
      add(:visitors, :integer, null: false, default: 0)
      add(:visits, :integer, null: false, default: 0)
      add(:pageviews, :integer, null: false, default: 0)
      add(:bounce_rate, :float)
      add(:visit_duration, :integer)
      add(:events, :integer, null: false, default: 0)
      add(:metadata, :map, null: false, default: %{})

      timestamps(type: :utc_datetime_usec)
    end

    create(unique_index(:analytics_plausible_dimension_daily, [:site_id, :day, :dimension, :value_key]))
    create(index(:analytics_plausible_dimension_daily, [:dimension, :day]))

    create table(:analytics_search_console_daily, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:site_url, :string, null: false)
      add(:day, :date, null: false)
      add(:dimension_set, :string, null: false)
      add(:dimension_key, :string, null: false)
      add(:search_type, :string, null: false, default: "web")
      add(:query, :text)
      add(:page, :text)
      add(:country, :string)
      add(:device, :string)
      add(:clicks, :integer, null: false, default: 0)
      add(:impressions, :integer, null: false, default: 0)
      add(:ctr, :float)
      add(:position, :float)
      add(:metadata, :map, null: false, default: %{})

      timestamps(type: :utc_datetime_usec)
    end

    create(unique_index(:analytics_search_console_daily, [:site_url, :day, :dimension_set, :dimension_key, :search_type]))
    create(index(:analytics_search_console_daily, [:day]))
    create(index(:analytics_search_console_daily, [:dimension_set, :day]))
  end
end
