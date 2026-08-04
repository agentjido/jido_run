defmodule AgentJidoWeb.Plugs.PlausibleProxy.Client do
  @moduledoc false

  @callback request(
              method :: atom(),
              url :: String.t(),
              headers :: [{String.t(), String.t()}],
              body :: iodata(),
              options :: keyword()
            ) :: {:ok, Finch.Response.t()} | {:error, term()}

  @spec request(atom(), String.t(), [{String.t(), String.t()}], iodata(), keyword()) ::
          {:ok, Finch.Response.t()} | {:error, term()}
  def request(method, url, headers, body, options) do
    method
    |> Finch.build(url, headers, body)
    |> Finch.request(AgentJido.Finch, options)
  end
end

defmodule AgentJidoWeb.Plugs.PlausibleProxy do
  @moduledoc """
  Proxies the Plausible tracker and event endpoint through fixed first-party paths.

  The proxy is active only when site analytics are enabled. It accepts events only
  for the configured site domain and forwards the Fly client IP instead of the
  application server IP.
  """

  import Plug.Conn

  require Logger

  @behaviour Plug

  @max_event_body_size 64_000
  @request_options [pool_timeout: 2_000, receive_timeout: 5_000]
  @script_response_headers ~w(cache-control content-type etag last-modified)
  @event_response_headers ~w(content-type x-plausible-dropped)

  @impl Plug
  def init(options), do: options

  @impl Plug
  def call(conn, options) do
    settings = settings(options)

    cond do
      not enabled?(options) ->
        conn

      conn.method == "GET" and conn.request_path == settings[:script_path] ->
        proxy_script(conn, settings)

      conn.method == "POST" and conn.request_path == settings[:event_path] ->
        proxy_event(conn, settings)

      true ->
        conn
    end
  end

  @doc "Returns the public first-party path for the Plausible tracker script."
  @spec script_path() :: String.t()
  def script_path, do: configured_value!(:script_path)

  @doc "Returns the public first-party path for the Plausible event endpoint."
  @spec event_path() :: String.t()
  def event_path, do: configured_value!(:event_path)

  defp proxy_script(conn, settings) do
    headers = conditional_request_headers(conn)

    case client(settings).request(
           :get,
           settings[:script_url],
           headers,
           "",
           @request_options
         ) do
      {:ok, response} ->
        relay_response(conn, response, @script_response_headers)

      {:error, reason} ->
        Logger.warning("Plausible script proxy failed: #{inspect(reason)}")
        send_error(conn, 502, "Tracker unavailable")
    end
  end

  defp proxy_event(conn, settings) do
    with :ok <- validate_content_type(conn),
         {:ok, body, conn} <- read_event_body(conn),
         :ok <- validate_site_domain(body, settings[:site_domain]),
         {:ok, user_agent} <- required_request_header(conn, "user-agent"),
         {:ok, response} <-
           client(settings).request(
             :post,
             settings[:event_url],
             event_request_headers(conn, user_agent),
             body,
             @request_options
           ) do
      relay_response(conn, response, @event_response_headers)
    else
      {:error, :unsupported_content_type} ->
        send_error(conn, 415, "Unsupported event content type")

      {:error, :body_too_large, conn} ->
        send_error(conn, 413, "Event payload too large")

      {:error, :invalid_body, conn} ->
        send_error(conn, 400, "Invalid event payload")

      {:error, :invalid_site_domain} ->
        send_error(conn, 400, "Invalid event site")

      {:error, :missing_header} ->
        send_error(conn, 400, "Missing event client information")

      {:error, reason} ->
        Logger.warning("Plausible event proxy failed: #{inspect(reason)}")
        send_error(conn, 502, "Event service unavailable")
    end
  end

  defp settings(options) do
    :agent_jido
    |> Application.get_env(:plausible_proxy, [])
    |> Keyword.merge(options)
  end

  defp configured_value!(key) do
    :agent_jido
    |> Application.fetch_env!(:plausible_proxy)
    |> Keyword.fetch!(key)
  end

  defp enabled?(options) do
    case Keyword.fetch(options, :enabled) do
      {:ok, enabled} -> enabled
      :error -> Application.get_env(:agent_jido, :enable_analytics, false)
    end
  end

  defp client(settings), do: Keyword.get(settings, :client, __MODULE__.Client)

  defp validate_content_type(conn) do
    case get_req_header(conn, "content-type") do
      [content_type | _] ->
        if String.starts_with?(content_type, ["application/json", "text/plain"]) do
          :ok
        else
          {:error, :unsupported_content_type}
        end

      [] ->
        {:error, :unsupported_content_type}
    end
  end

  defp read_event_body(conn) do
    case read_body(conn, length: @max_event_body_size, read_length: @max_event_body_size) do
      {:ok, body, conn} -> {:ok, body, conn}
      {:more, _partial_body, conn} -> {:error, :body_too_large, conn}
      {:error, _reason} -> {:error, :invalid_body, conn}
    end
  end

  defp validate_site_domain(body, expected_domain) do
    with {:ok, payload} when is_map(payload) <- Jason.decode(body),
         domain when is_binary(domain) <- payload["d"] || payload["domain"],
         true <- domain == expected_domain do
      :ok
    else
      _ -> {:error, :invalid_site_domain}
    end
  end

  defp required_request_header(conn, name) do
    case get_req_header(conn, name) do
      [value | _] when value != "" -> {:ok, value}
      _ -> {:error, :missing_header}
    end
  end

  defp event_request_headers(conn, user_agent) do
    [
      {"content-type", conn |> get_req_header("content-type") |> List.first()},
      {"user-agent", user_agent},
      {"x-forwarded-for", client_ip(conn)}
    ]
  end

  defp client_ip(conn) do
    conn
    |> get_req_header("fly-client-ip")
    |> List.first()
    |> normalize_ip()
    |> case do
      nil -> conn.remote_ip |> :inet.ntoa() |> to_string()
      ip -> ip
    end
  end

  defp normalize_ip(nil), do: nil

  defp normalize_ip(value) do
    value = String.trim(value)

    case :inet.parse_address(String.to_charlist(value)) do
      {:ok, address} -> address |> :inet.ntoa() |> to_string()
      {:error, _reason} -> nil
    end
  end

  defp conditional_request_headers(conn) do
    ["if-none-match", "if-modified-since"]
    |> Enum.flat_map(fn name ->
      Enum.map(get_req_header(conn, name), &{name, &1})
    end)
  end

  defp relay_response(conn, %Finch.Response{} = response, allowed_headers) do
    conn
    |> copy_response_headers(response.headers, allowed_headers)
    |> send_resp(response.status, response.body)
    |> halt()
  end

  defp copy_response_headers(conn, headers, allowed_headers) do
    Enum.reduce(headers, conn, fn {name, value}, conn ->
      name = String.downcase(name)

      if name in allowed_headers do
        put_resp_header(conn, name, value)
      else
        conn
      end
    end)
  end

  defp send_error(conn, status, message) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(status, message)
    |> halt()
  end
end
