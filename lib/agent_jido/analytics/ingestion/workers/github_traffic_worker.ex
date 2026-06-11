defmodule AgentJido.Analytics.Ingestion.Workers.GitHubTrafficWorker do
  @moduledoc """
  Collects GitHub traffic for one tracked repository.
  """
  use Oban.Worker,
    queue: :analytics,
    max_attempts: 3,
    tags: ["analytics", "github"],
    unique: [
      period: 3600,
      states: [:available, :scheduled, :executing, :retryable, :suspended],
      fields: [:worker, :args]
    ]

  alias AgentJido.Analytics.Ingestion

  @source "github_traffic"

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"tracked_repository_id" => repository_id} = args}) do
    with {:ok, repository} <- repository(repository_id),
         :ok <- require_github_auth() do
      opts = date_opts(args)

      run =
        Ingestion.start_run(@source,
          date_from: opts[:date_from],
          date_to: opts[:date_to],
          tracked_repository_id: repository.id,
          metadata: %{"repository" => repository.full_name}
        )

      case Ingestion.config(:github_client).fetch(repository, opts) do
        {:ok, result} ->
          rows_count = Ingestion.upsert_github_traffic(repository, result)
          Ingestion.complete_run(run, rows_count, Map.get(result, :metadata, %{}))
          :ok

        {:error, reason} ->
          Ingestion.fail_run(run, reason)
          error_result(reason)
      end
    else
      {:error, reason} -> {:cancel, reason}
    end
  end

  def perform(_job), do: {:cancel, :missing_tracked_repository_id}

  defp repository(id) do
    case Ingestion.get_tracked_repository(id) do
      nil -> {:error, :tracked_repository_not_found}
      repository -> {:ok, repository}
    end
  end

  defp require_github_auth do
    if Ingestion.github_auth_configured?(), do: :ok, else: {:error, :missing_github_auth}
  end

  defp error_result(:missing_github_auth), do: {:cancel, :missing_github_auth}
  defp error_result(reason), do: {:error, reason}

  defp date_opts(args) do
    [
      date_from: parse_date(args["date_from"]),
      date_to: parse_date(args["date_to"]),
      request_timeout_ms: Ingestion.config(:request_timeout_ms, 15_000)
    ]
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
  end

  defp parse_date(value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> date
      {:error, _reason} -> nil
    end
  end

  defp parse_date(_value), do: nil
end
