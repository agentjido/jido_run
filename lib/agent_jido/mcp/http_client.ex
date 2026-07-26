defmodule AgentJido.MCP.HTTPClient do
  @moduledoc """
  Minimal JSON-RPC client for the read-only docs MCP HTTP endpoint.
  """

  @type json_map :: %{required(String.t()) => term()}

  @request_headers [
    {~c"content-type", ~c"application/json"},
    {~c"accept", ~c"application/json"}
  ]

  @spec initialize(String.t(), keyword()) :: {:ok, json_map()} | {:error, String.t()}
  def initialize(endpoint, opts \\ []) when is_binary(endpoint) and is_list(opts) do
    rpc(endpoint, "initialize", initialize_params(), opts)
  end

  @spec search_docs(String.t(), String.t(), pos_integer(), keyword()) ::
          {:ok, json_map()} | {:error, String.t()}
  def search_docs(endpoint, query, limit, opts \\ [])
      when is_binary(endpoint) and is_binary(query) and is_integer(limit) and limit > 0 and is_list(opts) do
    rpc(endpoint, "tools/call", %{"name" => "search_docs", "arguments" => %{"query" => query, "limit" => limit}}, opts)
  end

  @spec get_doc(String.t(), String.t(), keyword()) :: {:ok, json_map()} | {:error, String.t()}
  def get_doc(endpoint, path, opts \\ []) when is_binary(endpoint) and is_binary(path) and is_list(opts) do
    rpc(endpoint, "tools/call", %{"name" => "get_doc", "arguments" => %{"path" => path}}, opts)
  end

  @spec list_sections(String.t(), keyword()) :: {:ok, json_map()} | {:error, String.t()}
  def list_sections(endpoint, opts \\ []) when is_binary(endpoint) and is_list(opts) do
    rpc(endpoint, "tools/call", %{"name" => "list_sections", "arguments" => %{}}, opts)
  end

  @spec get_operational_control(String.t(), keyword()) :: {:ok, json_map()} | {:error, String.t()}
  def get_operational_control(endpoint, opts \\ []) when is_binary(endpoint) and is_list(opts) do
    rpc(endpoint, "tools/call", %{"name" => "get_operational_control", "arguments" => %{}}, opts)
  end

  defp rpc(endpoint, method, params, opts) do
    request_id = System.unique_integer([:positive])

    payload = %{
      "jsonrpc" => "2.0",
      "id" => request_id,
      "method" => method,
      "params" => params
    }

    request_fun = Keyword.get(opts, :request_fun, &post_json/2)

    with {:ok, response} <- request_fun.(endpoint, payload) do
      case response do
        %{"error" => %{"message" => message}} ->
          {:error, message}

        %{"result" => %{"isError" => true, "structuredContent" => %{"error" => %{"message" => message}}}} ->
          {:error, message}

        %{"result" => result} when is_map(result) ->
          {:ok, result}

        _other ->
          {:error, "Unexpected MCP response"}
      end
    end
  end

  defp initialize_params do
    %{
      "protocolVersion" => AgentJido.MCP.protocol_version(),
      "clientInfo" => %{"name" => "agent_jido_mcp_cli", "version" => "1.0.0"},
      "capabilities" => %{}
    }
  end

  defp post_json(endpoint, payload) do
    ensure_http_started()

    body = Jason.encode!(payload)
    request = {String.to_charlist(endpoint), @request_headers, ~c"application/json", body}

    case :httpc.request(:post, request, http_options(endpoint), body_format: :binary) do
      {:ok, {{_http_version, status, _reason_phrase}, _headers, response_body}} when status in 200..299 ->
        decode_response(response_body)

      {:ok, {{_http_version, status, _reason_phrase}, _headers, response_body}} ->
        {:error, "HTTP #{status}: #{normalize_error_body(response_body)}"}

      {:error, reason} ->
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end

  defp ensure_http_started do
    _ = Application.ensure_all_started(:inets)
    _ = Application.ensure_all_started(:ssl)
    :ok
  end

  defp http_options(endpoint) do
    case URI.parse(endpoint) do
      %URI{scheme: "https"} -> [ssl: [{:verify, :verify_peer}]]
      _other -> []
    end
  end

  defp decode_response(""), do: {:ok, %{}}

  defp decode_response(response_body) when is_binary(response_body) do
    case Jason.decode(response_body) do
      {:ok, decoded} when is_map(decoded) -> {:ok, decoded}
      {:ok, _other} -> {:error, "Unexpected non-object JSON response"}
      {:error, reason} -> {:error, "Invalid JSON response: #{Exception.message(reason)}"}
    end
  end

  defp normalize_error_body(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, %{"error" => %{"message" => message}}} -> message
      {:ok, decoded} -> Jason.encode!(decoded)
      {:error, _reason} -> body
    end
  end

  defp normalize_error_body(_body), do: "Unexpected response body"
end
