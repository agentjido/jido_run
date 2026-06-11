defmodule AgentJido.Analytics.Ingestion.HexClient do
  @moduledoc """
  Finch-backed Hex.pm package stats API client.
  """

  alias AgentJido.Analytics.Ingestion
  alias AgentJido.Analytics.Ingestion.TrackedHexPackage

  @user_agent "AgentJido-AnalyticsIngestion"

  @doc """
  Fetches package-level download counters and bounded release-level counters.
  """
  @spec fetch(TrackedHexPackage.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def fetch(%TrackedHexPackage{package_name: package_name}, opts \\ []) when is_binary(package_name) do
    snapshot_date = Keyword.get(opts, :snapshot_date, Date.utc_today())

    with {:ok, package} <- fetch_package(package_name, opts),
         {:ok, releases} <- fetch_releases(package_name, package, opts) do
      {:ok,
       %{
         package: normalize_package(package, snapshot_date),
         releases: Enum.map(releases, &normalize_release(&1, package_name, snapshot_date)),
         metadata: %{"release_count" => length(package["releases"] || [])}
       }}
    end
  end

  defp fetch_package(package_name, opts) do
    case get_json("/api/packages/#{URI.encode(package_name)}", opts) do
      {:ok, package} -> {:ok, package}
      {:error, {:hex_not_found, _body}} -> {:error, {:hex_package_not_found, package_name}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp fetch_releases(package_name, package, opts) do
    release_limit = Ingestion.config(:hex_release_limit, 20)

    (package["releases"] || [])
    |> Enum.map(& &1["version"])
    |> Enum.reject(&is_nil/1)
    |> Enum.take(max(release_limit, 0))
    |> Enum.reduce_while({:ok, []}, fn release, {:ok, acc} ->
      case get_json("/api/packages/#{URI.encode(package_name)}/releases/#{URI.encode(release)}", opts) do
        {:ok, release} -> {:cont, {:ok, [release | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, releases} -> {:ok, Enum.reverse(releases)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_json(path, opts) do
    base_url = Ingestion.config(:hex_api_base_url, "https://hex.pm")
    timeout = Keyword.get(opts, :request_timeout_ms, Ingestion.config(:request_timeout_ms, 15_000))

    request =
      Finch.build(:get, "#{base_url}#{path}", [
        {"User-Agent", @user_agent},
        {"Accept", "application/json"}
      ])

    case Finch.request(request, AgentJido.Finch, receive_timeout: timeout) do
      {:ok, %Finch.Response{status: status, body: body}} when status in 200..299 ->
        Jason.decode(body)

      {:ok, %Finch.Response{status: 404, body: body}} ->
        {:error, {:hex_not_found, body}}

      {:ok, %Finch.Response{status: 429, body: body}} ->
        {:error, {:hex_rate_limited, body}}

      {:ok, %Finch.Response{status: status, body: body}} ->
        {:error, {:hex_http_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp normalize_package(package, snapshot_date) do
    downloads = package["downloads"] || %{}

    %{
      day: snapshot_date,
      package_name: package["name"],
      latest_version: package["latest_version"],
      downloads_day: int(downloads["day"]),
      downloads_week: int(downloads["week"]),
      downloads_recent: int(downloads["recent"]),
      downloads_all: int(downloads["all"]),
      metadata: %{
        "html_url" => package["html_url"],
        "repository" => package["repository"],
        "inserted_at" => package["inserted_at"],
        "updated_at" => package["updated_at"]
      }
    }
  end

  defp normalize_release(release, package_name, snapshot_date) do
    %{
      day: snapshot_date,
      package_name: package_name,
      version: release["version"],
      downloads_total: int(release["downloads"]),
      release_inserted_at: release["inserted_at"],
      has_docs: release["has_docs"],
      metadata: %{
        "requirements" => release["requirements"] || %{},
        "retirement" => release["retirement"],
        "url" => release["url"]
      }
    }
  end

  defp int(value) when is_integer(value), do: value
  defp int(value) when is_float(value), do: trunc(value)
  defp int(_value), do: 0
end
