defmodule AgentJidoWeb.StaticAssetHeaders do
  @moduledoc """
  Sets immutable caching for content-hashed esbuild split assets.
  """

  @immutable_cache_control "public, max-age=31536000, immutable"
  @hashed_esbuild_asset ~r/\A\/assets\/(?:chunk|module)-[A-Z0-9]{8}\.js\z/

  @doc """
  Returns response headers for a static asset request.
  """
  @spec headers(Plug.Conn.t()) :: [{String.t(), String.t()}]
  def headers(%Plug.Conn{request_path: request_path}) do
    if Regex.match?(@hashed_esbuild_asset, request_path) do
      [{"cache-control", @immutable_cache_control}]
    else
      []
    end
  end
end
