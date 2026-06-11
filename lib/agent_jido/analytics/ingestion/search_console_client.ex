defmodule AgentJido.Analytics.Ingestion.SearchConsoleClient do
  @moduledoc """
  Google Search Console Search Analytics API client.
  """

  alias AgentJido.Analytics.Ingestion

  @scope "https://www.googleapis.com/auth/webmasters.readonly"
  @default_dimension_sets [
    ["date"],
    ["date", "page"],
    ["date", "query"],
    ["date", "query", "page"],
    ["date", "country"],
    ["date", "device"],
    ["date", "query", "country"],
    ["date", "query", "device"],
    ["date", "page", "country"],
    ["date", "page", "device"]
  ]

  @doc """
  Fetches bounded Search Analytics rows for useful SEO dimension sets.
  """
  @spec fetch(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def fetch(site_url, opts \\ []) when is_binary(site_url) do
    with {:ok, credentials} <- credentials(opts),
         {:ok, token} <- access_token(credentials),
         {:ok, rows} <- fetch_dimension_sets(site_url, token, quota_project(credentials), opts) do
      {:ok, %{rows: rows}}
    end
  end

  @doc """
  Finch adapter used by Goth while exchanging service-account credentials.
  """
  @spec goth_request(keyword()) :: {:ok, map()} | {:error, term()}
  def goth_request(opts) when is_list(opts) do
    request = Finch.build(opts[:method], opts[:url], opts[:headers], opts[:body])

    case Finch.request(request, AgentJido.Finch, receive_timeout: Keyword.get(opts, :receive_timeout, 15_000)) do
      {:ok, %Finch.Response{status: status, headers: headers, body: body}} ->
        {:ok, %{status: status, headers: headers, body: body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp query(site_url, dimensions, token, quota_project, opts) do
    encoded_site_url = URI.encode_www_form(site_url)
    url = "https://www.googleapis.com/webmasters/v3/sites/#{encoded_site_url}/searchAnalytics/query"
    timeout = Keyword.get(opts, :request_timeout_ms, Ingestion.config(:request_timeout_ms, 15_000))
    search_type = Ingestion.config(:search_console_search_type, "web")

    body =
      Jason.encode!(%{
        "startDate" => opts |> Keyword.fetch!(:date_from) |> Date.to_iso8601(),
        "endDate" => opts |> Keyword.fetch!(:date_to) |> Date.to_iso8601(),
        "dimensions" => dimensions,
        "type" => search_type,
        "rowLimit" => Ingestion.config(:search_console_row_limit, 1_000)
      })

    headers =
      [
        {"Authorization", "Bearer #{token}"},
        {"Content-Type", "application/json"}
      ]
      |> maybe_put_quota_project(quota_project)

    request = Finch.build(:post, url, headers, body)

    case Finch.request(request, AgentJido.Finch, receive_timeout: timeout) do
      {:ok, %Finch.Response{status: status, body: body}} when status in 200..299 ->
        parse_response(body, dimensions, search_type)

      {:ok, %Finch.Response{status: 401, body: body}} ->
        {:error, {:search_console_unauthorized, body}}

      {:ok, %Finch.Response{status: 403, body: body}} ->
        {:error, {:search_console_forbidden, body}}

      {:ok, %Finch.Response{status: 429, body: body}} ->
        {:error, {:search_console_rate_limited, body}}

      {:ok, %Finch.Response{status: status, body: body}} ->
        {:error, {:search_console_http_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp access_token(credentials) do
    with {:ok, source} <- token_source(credentials),
         {:ok, token} <-
           Goth.Token.fetch(
             source: source,
             http_client: {&__MODULE__.goth_request/1, receive_timeout: Ingestion.config(:request_timeout_ms, 15_000)}
           ) do
      {:ok, token.token}
    end
  end

  defp fetch_dimension_sets(site_url, token, quota_project, opts) do
    Enum.reduce_while(dimension_sets(), {:ok, []}, fn dimensions, {:ok, acc} ->
      case query(site_url, dimensions, token, quota_project, opts) do
        {:ok, rows} -> {:cont, {:ok, acc ++ rows}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp dimension_sets do
    :search_console_dimension_sets
    |> Ingestion.config(@default_dimension_sets)
    |> case do
      dimension_sets when is_list(dimension_sets) ->
        dimension_sets
        |> Enum.map(&normalize_dimension_set/1)
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq()

      _value ->
        @default_dimension_sets
    end
  end

  defp credentials(opts) do
    cond do
      json = opts |> Keyword.get(:search_console_credentials_json, Ingestion.config(:search_console_credentials_json)) |> normalize_json() ->
        Jason.decode(json)

      path =
          opts
          |> Keyword.get(:search_console_credentials_json_path, Ingestion.config(:search_console_credentials_json_path))
          |> normalize_json() ->
        path
        |> Path.expand()
        |> File.read()
        |> case do
          {:ok, json} -> Jason.decode(json)
          {:error, reason} -> {:error, {:search_console_credentials_read_error, reason}}
        end

      true ->
        {:error, :missing_search_console_credentials_json}
    end
  end

  defp token_source(%{"type" => "service_account"} = credentials) do
    {:ok, {:service_account, credentials, scopes: [@scope]}}
  end

  defp token_source(%{"refresh_token" => _, "client_id" => _, "client_secret" => _} = credentials) do
    {:ok, {:refresh_token, credentials}}
  end

  defp token_source(_credentials), do: {:error, :unsupported_search_console_credentials}

  defp quota_project(credentials) do
    Ingestion.config(:search_console_quota_project) || Map.get(credentials, "quota_project_id")
  end

  defp maybe_put_quota_project(headers, quota_project) when is_binary(quota_project) do
    case String.trim(quota_project) do
      "" -> headers
      project -> [{"x-goog-user-project", project} | headers]
    end
  end

  defp maybe_put_quota_project(headers, _quota_project), do: headers

  defp parse_response(body, dimensions, search_type) do
    with {:ok, decoded} <- Jason.decode(body) do
      rows =
        decoded
        |> Map.get("rows", [])
        |> Enum.map(&parse_row(&1, dimensions, search_type))
        |> Enum.reject(&is_nil/1)

      {:ok, rows}
    end
  end

  defp parse_row(%{"keys" => keys} = row, dimensions, search_type) when is_list(keys) do
    values = Enum.zip(dimensions, keys) |> Map.new()
    day = Map.get(values, "date")

    if is_binary(day) do
      %{
        day: day,
        dimension_set: Enum.join(dimensions, "+"),
        dimension_key: dimension_key(values, dimensions),
        search_type: search_type,
        query: Map.get(values, "query"),
        page: Map.get(values, "page"),
        country: Map.get(values, "country"),
        device: Map.get(values, "device"),
        clicks: row["clicks"],
        impressions: row["impressions"],
        ctr: row["ctr"],
        position: row["position"],
        metadata: %{"dimensions" => values}
      }
    end
  end

  defp parse_row(_row, _dimensions, _search_type), do: nil

  defp dimension_key(values, dimensions) do
    dimensions
    |> Enum.reject(&(&1 == "date"))
    |> Enum.map_join("|", fn dimension -> "#{dimension}=#{Map.get(values, dimension, "")}" end)
    |> case do
      "" -> "site"
      value -> hash(value)
    end
  end

  defp normalize_json(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      json -> json
    end
  end

  defp normalize_json(_value), do: nil

  defp normalize_dimension_set(dimensions) when is_list(dimensions) do
    dimensions =
      dimensions
      |> Enum.map(&normalize_dimension/1)
      |> Enum.reject(&is_nil/1)

    if "date" in dimensions, do: dimensions
  end

  defp normalize_dimension_set(_dimensions), do: nil

  defp normalize_dimension(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      dimension -> dimension
    end
  end

  defp normalize_dimension(_value), do: nil

  defp hash(value) when is_binary(value) do
    :sha256
    |> :crypto.hash(value)
    |> Base.encode16(case: :lower)
  end
end
