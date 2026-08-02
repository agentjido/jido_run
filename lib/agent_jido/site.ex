defmodule AgentJido.Site do
  @moduledoc """
  Site URL and hostname helpers derived from runtime config.
  """

  @localhost_hosts ["localhost", "127.0.0.1"]

  @doc """
  Returns the canonical host for the site.
  """
  @spec canonical_host() :: String.t()
  def canonical_host do
    configured_host() || endpoint_host() || "localhost"
  end

  @doc """
  Returns true when search engines can index this site.
  """
  @spec indexable?() :: boolean()
  def indexable? do
    Application.get_env(:agent_jido, :site_indexable, true)
  end

  @doc """
  Returns the host configured on the endpoint URL.
  """
  @spec endpoint_host() :: String.t() | nil
  def endpoint_host do
    case endpoint_url() do
      nil ->
        nil

      url ->
        normalize_host_from_url(url)
    end
  end

  defp endpoint_url do
    AgentJidoWeb.Endpoint.url()
  rescue
    RuntimeError ->
      endpoint_url_from_config()
  end

  defp endpoint_url_from_config do
    case Application.get_env(:agent_jido, AgentJidoWeb.Endpoint, []) do
      config when is_list(config) ->
        url_config = Keyword.get(config, :url, [])
        build_url_from_config(url_config)

      _other ->
        nil
    end
  end

  defp build_url_from_config(url_config) when is_list(url_config) do
    host =
      case Keyword.get(url_config, :host) do
        value when is_binary(value) and value != "" -> String.downcase(value)
        _other -> nil
      end

    scheme =
      case Keyword.get(url_config, :scheme, "https") do
        value when is_binary(value) and value != "" -> String.downcase(value)
        _other -> "https"
      end

    if is_binary(host), do: "#{scheme}://#{host}", else: nil
  end

  defp build_url_from_config(_url_config), do: nil

  defp normalize_host_from_url(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{host: host} when is_binary(host) and host != "" -> String.downcase(host)
      _ -> nil
    end
  end

  defp normalize_host_from_url(_url), do: nil

  @doc """
  Returns hosts treated as first-party/internal.
  """
  @spec internal_hosts() :: [String.t()]
  def internal_hosts do
    host = canonical_host()

    [host, "www." <> host | @localhost_hosts]
    |> Enum.uniq()
  end

  defp configured_host do
    case Application.get_env(:agent_jido, :canonical_host) do
      host when is_binary(host) ->
        host
        |> String.trim()
        |> String.downcase()
        |> case do
          "" -> nil
          normalized -> normalized
        end

      _ ->
        nil
    end
  end
end
