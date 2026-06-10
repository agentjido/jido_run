defmodule AgentJido.Analytics.GitHub do
  @moduledoc """
  Persistence helpers for GitHub traffic analytics snapshots.
  """

  import Ecto.Query, warn: false

  alias AgentJido.Analytics.GitHub.PathDaily
  alias AgentJido.Analytics.GitHub.ReferrerDaily
  alias AgentJido.Analytics.GitHub.RepoDaily
  alias AgentJido.Repo

  @type repo_daily_attrs :: %{
          required(:date) => Date.t(),
          required(:repo) => String.t(),
          optional(:views) => non_neg_integer(),
          optional(:unique_visitors) => non_neg_integer(),
          optional(:clones) => non_neg_integer(),
          optional(:unique_cloners) => non_neg_integer(),
          required(:fetched_at) => DateTime.t()
        }

  @doc """
  Upserts one repository daily traffic row.
  """
  @spec upsert_repo_daily(repo_daily_attrs()) :: {:ok, RepoDaily.t()} | {:error, Ecto.Changeset.t()}
  def upsert_repo_daily(attrs) when is_map(attrs) do
    changeset = RepoDaily.changeset(%RepoDaily{}, attrs)

    Repo.insert(changeset,
      on_conflict: {:replace, [:views, :unique_visitors, :clones, :unique_cloners, :fetched_at, :updated_at]},
      conflict_target: [:date, :repo],
      returning: true
    )
  end

  @doc """
  Upserts the top referrer rows for one repo snapshot date.
  """
  @spec upsert_referrers(Date.t(), String.t(), [map()], DateTime.t()) :: {:ok, [ReferrerDaily.t()]} | {:error, term()}
  def upsert_referrers(date, repo, referrers, fetched_at) when is_list(referrers) do
    Repo.transaction(fn ->
      delete_referrer_daily_rows(date, repo)

      referrers
      |> Enum.reduce_while([], fn referrer, acc ->
        case insert_referrer_daily(date, repo, referrer, fetched_at) do
          {:ok, row} -> {:cont, [row | acc]}
          {:error, reason} -> Repo.rollback(reason)
        end
      end)
      |> Enum.reverse()
    end)
  end

  @doc """
  Upserts the top path rows for one repo snapshot date.
  """
  @spec upsert_paths(Date.t(), String.t(), [map()], DateTime.t()) :: {:ok, [PathDaily.t()]} | {:error, term()}
  def upsert_paths(date, repo, paths, fetched_at) when is_list(paths) do
    Repo.transaction(fn ->
      delete_path_daily_rows(date, repo)

      paths
      |> Enum.reduce_while([], fn path, acc ->
        case insert_path_daily(date, repo, path, fetched_at) do
          {:ok, row} -> {:cont, [row | acc]}
          {:error, reason} -> Repo.rollback(reason)
        end
      end)
      |> Enum.reverse()
    end)
  end

  @doc """
  Lists repository daily traffic rows newest first.
  """
  @spec list_repo_daily(String.t(), keyword()) :: [RepoDaily.t()]
  def list_repo_daily(repo, opts \\ []) when is_binary(repo) do
    limit = opts |> Keyword.get(:limit, 30) |> normalize_limit()

    RepoDaily
    |> where([r], r.repo == ^repo)
    |> order_by([r], desc: r.date)
    |> limit(^limit)
    |> Repo.all()
  end

  defp map_get(map, key, default \\ nil)
  defp map_get(map, key, default) when is_atom(key), do: Map.get(map, key, Map.get(map, Atom.to_string(key), default))

  defp delete_referrer_daily_rows(date, repo) do
    ReferrerDaily
    |> where([r], r.date == ^date and r.repo == ^repo)
    |> Repo.delete_all()
  end

  defp delete_path_daily_rows(date, repo) do
    PathDaily
    |> where([p], p.date == ^date and p.repo == ^repo)
    |> Repo.delete_all()
  end

  defp insert_referrer_daily(date, repo, referrer, fetched_at) do
    attrs = %{
      date: date,
      repo: repo,
      referrer: map_get(referrer, :referrer),
      views: map_get(referrer, :views, 0),
      uniques: map_get(referrer, :uniques, 0),
      fetched_at: fetched_at
    }

    %ReferrerDaily{}
    |> ReferrerDaily.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, [:views, :uniques, :fetched_at, :updated_at]},
      conflict_target: [:date, :repo, :referrer],
      returning: true
    )
  end

  defp insert_path_daily(date, repo, path, fetched_at) do
    attrs = %{
      date: date,
      repo: repo,
      path: map_get(path, :path),
      title: map_get(path, :title),
      views: map_get(path, :views, 0),
      uniques: map_get(path, :uniques, 0),
      fetched_at: fetched_at
    }

    %PathDaily{}
    |> PathDaily.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, [:title, :views, :uniques, :fetched_at, :updated_at]},
      conflict_target: [:date, :repo, :path],
      returning: true
    )
  end

  defp normalize_limit(limit) when is_integer(limit) and limit > 0, do: min(limit, 500)
  defp normalize_limit(_limit), do: 30
end
