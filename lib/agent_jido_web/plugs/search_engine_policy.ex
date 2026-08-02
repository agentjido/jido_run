defmodule AgentJidoWeb.Plugs.SearchEnginePolicy do
  @moduledoc """
  Adds a response header that prevents indexing on non-public environments.
  """

  @behaviour Plug

  import Plug.Conn

  alias AgentJido.Site

  @robots_policy "noindex, nofollow"

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    if Site.indexable?() do
      conn
    else
      put_resp_header(conn, "x-robots-tag", @robots_policy)
    end
  end
end
