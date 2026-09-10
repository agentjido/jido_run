defmodule AgentJidoWeb.PageController do
  use AgentJidoWeb, :controller

  alias AgentJidoWeb.Showcase.V3

  def v3(conn, _params) do
    render(conn, :v3,
      page_title: "Jido V3: Large-scale Actor and Agent Systems on the BEAM",
      meta_description: "Coming soon: a code-first preview of Jido V3 for large-scale, production Actor and Agent systems on the BEAM.",
      og_title: "Jido V3 is coming soon",
      og_description: "See typed Actors and Agents, composable Flows, explicit Turns, owned Plugins, and supervised Topologies in Jido V3.",
      robots: ["noindex", "nofollow"],
      snippets: V3.snippets()
    )
  end

  def discord(conn, _params) do
    discord_invite_link = Application.get_env(:agent_jido, :discord_invite_link)
    redirect(conn, external: discord_invite_link)
  end

  def not_found(conn, _params) do
    conn
    |> put_status(:not_found)
    |> put_view(html: AgentJidoWeb.PageHTML)
    |> render(:not_found,
      request_path: conn.request_path,
      page_title: "Page Not Found",
      meta_description: "The requested page could not be found.",
      robots: ["noindex", "nofollow"]
    )
  end

  def arcana_redirect(conn, params) do
    path =
      params
      |> Map.get("path", [])
      |> List.wrap()
      |> Enum.join("/")

    target =
      case path do
        "" -> "/arcana"
        _ -> "/arcana/" <> path
      end

    target =
      case conn.query_string do
        "" -> target
        query -> target <> "?" <> query
      end

    redirect(conn, to: target)
  end

  def arcana_legacy_app_js(conn, _params) do
    redirect(conn, to: "/assets/app.js")
  end
end
