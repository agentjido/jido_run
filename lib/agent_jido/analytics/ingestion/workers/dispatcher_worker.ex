defmodule AgentJido.Analytics.Ingestion.Workers.DispatcherWorker do
  @moduledoc """
  Fans out scheduled GitHub traffic ingestion into one job per tracked repository.
  """
  use Oban.Worker,
    queue: :analytics,
    max_attempts: 1,
    tags: ["analytics", "dispatcher", "github"],
    unique: [
      period: 300,
      states: [:available, :scheduled, :executing, :retryable, :suspended],
      fields: [:worker, :args]
    ]

  alias AgentJido.Analytics.Ingestion

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    with :ok <- require_github_auth(),
         {:ok, _count} <- enqueue_repositories(date_opts(args)) do
      :ok
    end
  end

  defp require_github_auth do
    if Ingestion.github_auth_configured?(), do: :ok, else: {:cancel, :missing_github_auth}
  end

  defp enqueue_repositories(opts) do
    Ingestion.list_active_tracked_repositories()
    |> Enum.reduce_while({:ok, 0}, fn repository, {:ok, count} ->
      case Ingestion.enqueue_github_traffic(repository, opts) do
        {:ok, _job} -> {:cont, {:ok, count + 1}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp date_opts(args) do
    [
      date_from: parse_date(args["date_from"]),
      date_to: parse_date(args["date_to"])
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
