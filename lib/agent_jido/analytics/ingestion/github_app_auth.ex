defmodule AgentJido.Analytics.Ingestion.GitHubAppAuth do
  @moduledoc """
  GitHub App installation-token auth for analytics ingestion.
  """

  alias AgentJido.Analytics.Ingestion

  @user_agent "AgentJido-AnalyticsIngestion"
  @token_cache_table __MODULE__.TokenCache
  @token_expiry_skew_seconds 60

  @doc """
  Returns true when enough GitHub App config exists to mint an installation token.
  """
  @spec configured?(keyword()) :: boolean()
  def configured?(opts \\ []) do
    present?(value(opts, :github_app_id)) and
      present?(value(opts, :github_app_installation_id)) and
      (present?(value(opts, :github_app_private_key)) or present?(value(opts, :github_app_private_key_path)))
  end

  @doc """
  Mints a GitHub App installation access token.
  """
  @spec fetch_installation_token(keyword()) :: {:ok, String.t()} | {:error, term()}
  def fetch_installation_token(opts \\ []) do
    with true <- configured?(opts),
         {:ok, app_id} <- app_id(opts),
         {:ok, installation_id} <- installation_id(opts) do
      fetch_cached_or_mint({app_id, installation_id}, installation_id, opts)
    else
      false -> {:error, :missing_github_app_config}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Builds a short-lived GitHub App JWT.
  """
  @spec app_jwt(keyword()) :: {:ok, String.t()} | {:error, term()}
  def app_jwt(opts \\ []) do
    with {:ok, app_id} <- app_id(opts),
         {:ok, private_key} <- private_key(opts),
         {:ok, decoded_key} <- decode_private_key(private_key) do
      now = System.system_time(:second)

      header = %{"alg" => "RS256", "typ" => "JWT"}
      payload = %{"iat" => now - 60, "exp" => now + 9 * 60, "iss" => app_id}
      signing_input = "#{json64(header)}.#{json64(payload)}"

      signature =
        signing_input
        |> :public_key.sign(:sha256, decoded_key)
        |> Base.url_encode64(padding: false)

      {:ok, "#{signing_input}.#{signature}"}
    end
  end

  defp fetch_cached_or_mint(cache_key, installation_id, opts) do
    case cached_token(cache_key) do
      {:ok, token} -> {:ok, token}
      :miss -> mint_installation_token(cache_key, installation_id, opts)
    end
  end

  defp mint_installation_token(cache_key, installation_id, opts) do
    with {:ok, jwt} <- app_jwt(opts),
         {:ok, %{"token" => token} = response} <- request_installation_token(jwt, installation_id, opts) do
      cache_token(cache_key, token, response["expires_at"])
      {:ok, token}
    end
  end

  defp request_installation_token(jwt, installation_id, opts) do
    timeout = Keyword.get(opts, :request_timeout_ms, Ingestion.config(:request_timeout_ms, 15_000))
    url = "https://api.github.com/app/installations/#{installation_id}/access_tokens"

    headers = [
      {"Accept", "application/vnd.github+json"},
      {"Authorization", "Bearer #{jwt}"},
      {"X-GitHub-Api-Version", Ingestion.config(:github_api_version, "2026-03-10")},
      {"User-Agent", @user_agent}
    ]

    request = Finch.build(:post, url, headers, "")

    case Finch.request(request, AgentJido.Finch, receive_timeout: timeout) do
      {:ok, %Finch.Response{status: status, body: body}} when status in 200..299 ->
        Jason.decode(body)

      {:ok, %Finch.Response{status: 401, body: body}} ->
        {:error, {:github_app_unauthorized, body}}

      {:ok, %Finch.Response{status: 403, body: body}} ->
        {:error, {:github_app_forbidden, body}}

      {:ok, %Finch.Response{status: 404, body: body}} ->
        {:error, {:github_app_installation_not_found, body}}

      {:ok, %Finch.Response{status: status, body: body}} ->
        {:error, {:github_app_http_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp cached_token(cache_key) do
    case :ets.lookup(token_cache_table(), cache_key) do
      [{^cache_key, token, expires_at}] ->
        if expires_at > System.system_time(:second) + @token_expiry_skew_seconds do
          {:ok, token}
        else
          :miss
        end

      [] ->
        :miss
    end
  end

  defp cache_token(cache_key, token, expires_at) do
    expires_at = parse_expires_at(expires_at)

    if is_integer(expires_at) do
      :ets.insert(token_cache_table(), {cache_key, token, expires_at})
    end

    :ok
  end

  defp parse_expires_at(expires_at) when is_binary(expires_at) do
    case DateTime.from_iso8601(expires_at) do
      {:ok, date_time, _offset} -> DateTime.to_unix(date_time)
      {:error, _reason} -> nil
    end
  end

  defp parse_expires_at(_expires_at), do: nil

  defp token_cache_table do
    case :ets.whereis(@token_cache_table) do
      :undefined ->
        :ets.new(@token_cache_table, [:named_table, :public, read_concurrency: true, write_concurrency: true])

      _table ->
        @token_cache_table
    end
  catch
    :error, :badarg -> @token_cache_table
  end

  defp app_id(opts) do
    case value(opts, :github_app_id) |> normalize_text() do
      nil -> {:error, :missing_github_app_id}
      app_id -> {:ok, app_id}
    end
  end

  defp installation_id(opts) do
    case value(opts, :github_app_installation_id) |> normalize_text() do
      nil -> {:error, :missing_github_app_installation_id}
      installation_id -> {:ok, installation_id}
    end
  end

  defp private_key(opts) do
    cond do
      present?(value(opts, :github_app_private_key)) ->
        {:ok, normalize_private_key(value(opts, :github_app_private_key))}

      present?(value(opts, :github_app_private_key_path)) ->
        value(opts, :github_app_private_key_path)
        |> Path.expand()
        |> File.read()
        |> case do
          {:ok, contents} -> {:ok, contents}
          {:error, reason} -> {:error, {:github_app_private_key_read_error, reason}}
        end

      true ->
        {:error, :missing_github_app_private_key}
    end
  end

  defp decode_private_key(pem) when is_binary(pem) do
    case :public_key.pem_decode(pem) do
      [entry | _rest] ->
        {:ok, :public_key.pem_entry_decode(entry)}

      [] ->
        {:error, :invalid_github_app_private_key}
    end
  rescue
    reason -> {:error, {:invalid_github_app_private_key, reason}}
  end

  defp normalize_private_key(value) when is_binary(value) do
    String.replace(value, "\\n", "\n")
  end

  defp value(opts, key) when is_list(opts), do: Keyword.get(opts, key, Ingestion.config(key))

  defp json64(payload) do
    payload
    |> Jason.encode!()
    |> Base.url_encode64(padding: false)
  end

  defp normalize_text(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp normalize_text(value) when is_integer(value), do: Integer.to_string(value)
  defp normalize_text(_value), do: nil

  defp present?(value), do: not is_nil(normalize_text(value))
end
