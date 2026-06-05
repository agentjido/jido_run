defmodule AgentJido.Repo.Migrations.AddGithubTrafficAnalytics do
  use Ecto.Migration

  def change do
    create table(:analytics_github_repo_daily, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:date, :date, null: false)
      add(:repo, :string, null: false)
      add(:views, :integer, null: false, default: 0)
      add(:unique_visitors, :integer, null: false, default: 0)
      add(:clones, :integer, null: false, default: 0)
      add(:unique_cloners, :integer, null: false, default: 0)
      add(:fetched_at, :utc_datetime_usec, null: false)

      timestamps(type: :utc_datetime_usec)
    end

    create(unique_index(:analytics_github_repo_daily, [:date, :repo]))
    create(index(:analytics_github_repo_daily, [:repo, :date]))

    create table(:analytics_github_referrers_daily, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:date, :date, null: false)
      add(:repo, :string, null: false)
      add(:referrer, :string, null: false)
      add(:views, :integer, null: false, default: 0)
      add(:uniques, :integer, null: false, default: 0)
      add(:fetched_at, :utc_datetime_usec, null: false)

      timestamps(type: :utc_datetime_usec)
    end

    create(unique_index(:analytics_github_referrers_daily, [:date, :repo, :referrer]))
    create(index(:analytics_github_referrers_daily, [:repo, :date]))

    create table(:analytics_github_paths_daily, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:date, :date, null: false)
      add(:repo, :string, null: false)
      add(:path, :text, null: false)
      add(:title, :text)
      add(:views, :integer, null: false, default: 0)
      add(:uniques, :integer, null: false, default: 0)
      add(:fetched_at, :utc_datetime_usec, null: false)

      timestamps(type: :utc_datetime_usec)
    end

    create(unique_index(:analytics_github_paths_daily, [:date, :repo, :path]))
    create(index(:analytics_github_paths_daily, [:repo, :date]))
  end
end
