defmodule AgentJidoWeb.Plugs.SecurityHeaders do
  @moduledoc """
  Adds browser security headers and a per-request CSP nonce.
  """

  import Plug.Conn

  @hsts "max-age=31536000; includeSubDomains"
  @script_hosts [
    "https://plausible.io",
    "https://e.jido.run",
    "https://us.i.posthog.com",
    "https://eu.i.posthog.com",
    "https://app.posthog.com",
    "https://static.cloudflareinsights.com",
    "https://challenges.cloudflare.com"
  ]

  @doc false
  @spec init(keyword()) :: keyword()
  def init(opts), do: opts

  @doc false
  @spec call(Plug.Conn.t(), keyword()) :: Plug.Conn.t()
  def call(conn, _opts) do
    nonce = :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)

    conn
    |> assign(:csp_nonce, nonce)
    |> put_resp_header("content-security-policy", content_security_policy(nonce))
    |> put_resp_header("strict-transport-security", @hsts)
    |> put_resp_header("cross-origin-opener-policy", "same-origin")
  end

  defp content_security_policy(nonce) do
    script_sources = Enum.join(["'self'", "'nonce-#{nonce}'" | @script_hosts], " ")

    [
      "default-src 'self'",
      "base-uri 'self'",
      "object-src 'none'",
      "frame-ancestors 'self'",
      "form-action 'self'",
      "script-src #{script_sources}",
      "style-src 'self' 'unsafe-inline'",
      "font-src 'self'",
      "img-src 'self' data: https:",
      "connect-src 'self' https: wss:",
      "frame-src 'self' https://challenges.cloudflare.com",
      "worker-src 'self' blob:"
    ]
    |> Enum.join("; ")
  end
end
