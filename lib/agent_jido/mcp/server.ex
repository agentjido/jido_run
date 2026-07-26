defmodule AgentJido.MCP.Server do
  @moduledoc """
  Transport-neutral MCP server core for the docs tool surface.
  """

  alias AgentJido.MCP
  alias AgentJido.MCP.DocsTools

  @server_not_initialized_code -32_002
  @invalid_request_code -32_600
  @method_not_found_code -32_601
  @invalid_params_code -32_602
  @internal_error_code -32_603

  defmodule State do
    @moduledoc false
    defstruct initialized?: false, protocol_version: nil, client_info: %{}

    @type t :: %__MODULE__{
            initialized?: boolean(),
            protocol_version: String.t() | nil,
            client_info: map()
          }
  end

  @type response_tuple ::
          {:reply, map(), State.t()}
          | {:noreply, State.t()}

  @spec new(keyword()) :: State.t()
  def new(opts \\ []) do
    %State{protocol_version: Keyword.get(opts, :protocol_version, MCP.protocol_version())}
  end

  @doc """
  Public description returned to MCP clients on `initialize`.

  The v1 tool surface is intentionally docs-only. This string is the single
  source of truth for that scope claim so product copy and tool scope stay in
  agreement (jido-e10-t17). Examples, skills, and ecosystem retrieval are
  tracked as separate scope-expansion tasks (jido-e10-t18, jido-e10-t19).

  get_operational_control (jido-e10-t30) retrieves the canonical control
  overview — a docs page — and proof pointers, including links to the ecosystem
  package pages that carry each package's release version and proof; it does not
  retrieve those package pages, so the docs-only retrieval scope is preserved.
  """
  @spec instructions() :: String.t()
  def instructions do
    "Read-only documentation MCP server for Agent Jido. " <>
      "v1 scope is docs only — search_docs, get_doc, list_sections, and " <>
      "get_operational_control operate on published documentation pages (/docs/**) " <>
      "and exclude examples, skills, ecosystem packages, blog, and compare pages. " <>
      "get_operational_control returns the canonical operational-control overview " <>
      "(a docs page) with proof, so a client can retrieve it by name instead of " <>
      "guessing a control term. " <>
      "Available tools: search_docs, get_doc, list_sections, get_operational_control."
  end

  @spec handle_message(map(), State.t(), keyword()) :: response_tuple()
  def handle_message(message, state, opts \\ [])

  def handle_message(message, %State{} = state, opts) when is_map(message) and is_list(opts) do
    case normalize_request(message) do
      {:ok, request} ->
        dispatch(request, state, opts)

      {:error, {code, error_message, id}} ->
        {:reply, error_response(id, code, error_message), state}
    end
  end

  def handle_message(_message, %State{} = state, _opts) do
    {:reply, error_response(nil, @invalid_request_code, "Invalid JSON-RPC request"), state}
  end

  @spec handle_http_message(map(), keyword()) :: {:reply, map()} | :noreply
  def handle_http_message(message, opts \\ [])

  def handle_http_message(message, opts) when is_map(message) and is_list(opts) do
    method = Map.get(message, "method")

    state =
      case method do
        "initialize" -> new(opts)
        _other -> %State{initialized?: true, protocol_version: Keyword.get(opts, :protocol_version, MCP.protocol_version())}
      end

    case handle_message(message, state, opts) do
      {:reply, response, _state} -> {:reply, response}
      {:noreply, _state} -> :noreply
    end
  end

  def handle_http_message(_message, _opts), do: {:reply, error_response(nil, @invalid_request_code, "Invalid JSON-RPC request")}

  defp dispatch(%{method: "ping", id: nil}, state, _opts), do: {:noreply, state}

  defp dispatch(%{method: "ping", id: id}, state, _opts) do
    {:reply, success_response(id, %{}), state}
  end

  defp dispatch(%{method: "initialize", id: nil}, state, _opts), do: {:noreply, %{state | initialized?: true}}

  defp dispatch(%{method: "initialize", id: id, params: params}, %State{} = state, opts) do
    protocol_version = Keyword.get(opts, :protocol_version, MCP.protocol_version())

    next_state = %State{
      state
      | initialized?: true,
        protocol_version: protocol_version,
        client_info: normalize_map(Map.get(params, "clientInfo", %{}))
    }

    result = %{
      "protocolVersion" => protocol_version,
      "capabilities" => %{
        "tools" => %{"listChanged" => false}
      },
      "serverInfo" => %{
        "name" => MCP.server_name(),
        "version" => MCP.server_version()
      },
      "instructions" => instructions()
    }

    {:reply, success_response(id, result), next_state}
  end

  defp dispatch(%{method: "notifications/initialized"}, state, _opts) do
    {:noreply, %{state | initialized?: true}}
  end

  defp dispatch(%{method: "tools/list", id: id}, %State{initialized?: false} = state, _opts) do
    {:reply, error_response(id, @server_not_initialized_code, "Server not initialized"), state}
  end

  defp dispatch(%{method: "tools/list", id: nil}, state, _opts), do: {:noreply, state}

  defp dispatch(%{method: "tools/list", id: id}, state, opts) do
    tools_module = Keyword.get(opts, :tools_module, DocsTools)
    {:reply, success_response(id, %{"tools" => tools_module.tools()}), state}
  end

  defp dispatch(%{method: "tools/call", id: id}, %State{initialized?: false} = state, _opts) do
    {:reply, error_response(id, @server_not_initialized_code, "Server not initialized"), state}
  end

  defp dispatch(%{method: "tools/call", id: nil}, state, _opts), do: {:noreply, state}

  defp dispatch(%{method: "tools/call", id: id, params: params}, state, opts) do
    tools_module = Keyword.get(opts, :tools_module, DocsTools)
    tool_opts = Keyword.get(opts, :tool_opts, [])

    with {:ok, tool_name} <- fetch_non_empty_string(params, "name"),
         {:ok, arguments} <- fetch_arguments(params) do
      case tools_module.call_tool(tool_name, arguments, tool_opts) do
        {:ok, result} ->
          {:reply, success_response(id, result), state}

        {:error, %{"code" => code, "message" => message} = error} ->
          tool_error =
            %{
              "content" => [%{"type" => "text", "text" => message}],
              "structuredContent" => %{"ok" => false, "error" => error},
              "isError" => true
            }
            |> maybe_put_error_code(code)

          {:reply, success_response(id, tool_error), state}

        _other ->
          {:reply, error_response(id, @internal_error_code, "Tool dispatch failed"), state}
      end
    else
      {:error, message} ->
        {:reply, error_response(id, @invalid_params_code, message), state}
    end
  end

  defp dispatch(%{method: nil}, state, _opts), do: {:noreply, state}

  defp dispatch(%{method: _method, id: id}, state, _opts) do
    {:reply, error_response(id, @method_not_found_code, "Method not found"), state}
  end

  defp normalize_request(%{"jsonrpc" => "2.0", "method" => method} = request) when is_binary(method) do
    {:ok,
     %{
       id: Map.get(request, "id"),
       method: method,
       params: normalize_map(Map.get(request, "params", %{}))
     }}
  end

  defp normalize_request(%{"jsonrpc" => "2.0"} = request) do
    if Map.has_key?(request, "result") or Map.has_key?(request, "error") do
      {:ok, %{id: Map.get(request, "id"), method: nil, params: %{}}}
    else
      {:error, {@invalid_request_code, "Invalid JSON-RPC request", nil}}
    end
  end

  defp normalize_request(%{"method" => _method} = request) do
    {:error, {@invalid_request_code, "jsonrpc must be \"2.0\"", Map.get(request, "id")}}
  end

  defp normalize_request(_request) do
    {:error, {@invalid_request_code, "Invalid JSON-RPC request", nil}}
  end

  defp fetch_non_empty_string(params, key) when is_map(params) do
    case Map.get(params, key) do
      value when is_binary(value) ->
        trimmed = String.trim(value)

        if trimmed != "" do
          {:ok, trimmed}
        else
          {:error, "#{key} must be a non-empty string"}
        end

      _other ->
        {:error, "#{key} must be a non-empty string"}
    end
  end

  defp fetch_arguments(params) when is_map(params) do
    case Map.get(params, "arguments", %{}) do
      nil -> {:ok, %{}}
      arguments when is_map(arguments) -> {:ok, normalize_map(arguments)}
      _other -> {:error, "arguments must be an object"}
    end
  end

  defp normalize_map(map) when is_map(map), do: map
  defp normalize_map(_map), do: %{}

  defp success_response(id, result) do
    %{"jsonrpc" => "2.0", "id" => id, "result" => result}
  end

  defp error_response(id, code, message) do
    %{
      "jsonrpc" => "2.0",
      "id" => id,
      "error" => %{
        "code" => code,
        "message" => message
      }
    }
  end

  defp maybe_put_error_code(tool_error, code) when is_binary(code) do
    put_in(tool_error, ["structuredContent", "error", "code"], code)
  end

  defp maybe_put_error_code(tool_error, _code), do: tool_error
end
