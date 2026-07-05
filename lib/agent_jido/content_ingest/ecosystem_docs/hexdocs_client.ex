defmodule AgentJido.ContentIngest.EcosystemDocs.HexDocsClient do
  @moduledoc """
  Finch-backed client for Hex release metadata and HexDocs HTML assets.
  """

  @default_request_timeout_ms 15_000
  @user_agent "AgentJido-HexDocsCrawler"

  @type response :: %{
          status: pos_integer(),
          body: String.t(),
          headers: [{String.t(), String.t()}],
          url: String.t()
        }

  @spec fetch_release(String.t(), String.t(), keyword()) :: {:ok, response()} | {:error, term()}
  def fetch_release(package_name, version, opts \\ [])
      when is_binary(package_name) and is_binary(version) do
    url = "https://hex.pm/api/packages/#{package_name}/releases/#{version}"
    fetch(url, opts)
  end

  @spec fetch(String.t(), keyword()) :: {:ok, response()} | {:error, term()}
  def fetch(url, opts \\ []) when is_binary(url) do
    timeout_ms = Keyword.get(opts, :request_timeout_ms, config(:request_timeout_ms, @default_request_timeout_ms))

    request =
      Finch.build(:get, url, [
        {"accept", "*/*"},
        {"user-agent", @user_agent}
      ])

    case Finch.request(request, AgentJido.Finch, receive_timeout: timeout_ms) do
      {:ok, %Finch.Response{} = response} ->
        {:ok,
         %{
           status: response.status,
           body: response.body,
           headers: response.headers,
           url: url
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec header([{String.t(), String.t()}], String.t()) :: String.t() | nil
  def header(headers, name) when is_list(headers) and is_binary(name) do
    target = String.downcase(name)

    Enum.find_value(headers, fn
      {header_name, value} when is_binary(header_name) and is_binary(value) ->
        if String.downcase(header_name) == target, do: value

      _other ->
        nil
    end)
  end

  def header(_headers, _name), do: nil

  defp config(key, default) do
    case Application.get_env(:agent_jido, AgentJido.ContentIngest.EcosystemDocs.Crawler, []) do
      config when is_list(config) -> Keyword.get(config, key, default)
      config when is_map(config) -> Map.get(config, key, default)
      _other -> default
    end
  end
end
