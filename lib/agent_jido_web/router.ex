defmodule AgentJidoWeb.Router do
  use AgentJidoWeb, :router

  alias AgentJido.Accounts

  import AgentJidoWeb.UserAuth
  import Phoenix.LiveDashboard.Router
  import JidoStudio.Router
  import ArcanaWeb.Router

  # Build page routes at compile time from the unified Pages system
  @page_routes (for page <- AgentJido.Pages.all_pages(),
                    route = AgentJido.Pages.route_for(page),
                    route != "/docs",
                    not String.starts_with?(route, "/training/") do
                  route
                end)
  @admin_on_mount [
    {AgentJidoWeb.UserAuth, :require_authenticated},
    {AgentJidoWeb.UserAuth, :require_admin}
  ]

  pipeline :browser do
    plug(AgentJidoWeb.Plugs.LLMAcceptCompat)
    plug(:accepts, ["html", "json"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, {AgentJidoWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(AgentJidoWeb.Plugs.SecurityHeaders)
    plug(:put_secure_browser_headers)
    plug(:fetch_current_scope_for_user)
    plug(AgentJidoWeb.Plugs.LLMResponse)
    plug(AgentJidoWeb.Plugs.AnalyticsIdentity)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/", AgentJidoWeb do
    pipe_through(:browser)

    get "/ecosystem/bookmarks.html", EcosystemBookmarksController, :show

    live_session :public_site, session: {__MODULE__, :examples_live_session, []} do
      live "/", JidoHomeLive, :index
      live "/skills", JidoSkillsLive, :index
      live "/ecosystem", JidoEcosystemLive, :index
      live "/ecosystem/:id", JidoEcosystemPackageLive, :show
      live "/getting-started", JidoGettingStartedLive, :index

      live "/examples", JidoExamplesLive, :index
      live "/examples/:slug", JidoExampleLive, :show

      live "/features", JidoFeaturesLive, :index

      # Pages system — index routes
      live "/docs", PageLive, :index
      live "/build", PageLive, :index
      live "/compare", PageLive, :index
      live "/community/showcase", JidoCommunityShowcaseLive, :index
      live "/community", JidoCommunityLive, :index
      live "/about", JidoAboutLive, :index

      # Pages system — compile-time show routes
      for route_path <- @page_routes do
        live route_path, PageLive, :show
      end

      live "/blog", BlogLive, :index
      live "/blog/tags/:tag", BlogLive, :tag
      live "/blog/:slug", BlogLive, :show
    end

    get("/discord", PageController, :discord)

    get "/og/render/*path", OGImageController, :render

    post "/analytics/events", AnalyticsEventController, :create
    get("/feed", BlogController, :feed)
    get("/sitemap.xml", SitemapController, :index)
    get("/robots.txt", RobotsTxtController, :index)
    get("/llms.txt", LLMSTxtController, :index)
  end

  scope "/mcp", AgentJidoWeb do
    pipe_through(:api)

    match :*, "/docs", MCPDocsController, :handle
  end

  if Application.compile_env(:agent_jido, :dev_routes) do
    scope "/dev" do
      pipe_through([:browser])
      forward("/mailbox", Plug.Swoosh.MailboxPreview)
    end
  end

  scope "/dev" do
    pipe_through([:browser, :require_authenticated_user, :require_admin_user])

    live_dashboard("/dashboard",
      metrics: AgentJidoWeb.Telemetry,
      additional_pages: JidoLiveDashboard.pages(),
      on_mount: @admin_on_mount
    )

    jido_studio("/jido", host_app_js_path: "/assets/app.js", on_mount: @admin_on_mount)

    get("/arcana", AgentJidoWeb.PageController, :arcana_redirect)
    get("/arcana/*path", AgentJidoWeb.PageController, :arcana_redirect)
  end

  scope "/", AgentJidoWeb do
    pipe_through([:browser, :require_authenticated_user, :require_admin_user])

    live_session :admin_control_plane,
      on_mount: @admin_on_mount do
      live "/dashboard", AdminDashboardLive, :index
      live "/dashboard/analytics", AdminAnalyticsLive, :index
      live "/dashboard/ecosystem-analytics", AdminEcosystemAnalyticsLive, :index
      live "/dashboard/content-ingestion", AdminContentIngestionLive, :index
      live "/dashboard/content-ingestion/audit", AdminContentIngestionLive, :index
      live "/dashboard/contentops", ContentOpsLive, :index
      live "/dashboard/contentops/github", ContentOpsGithubLive, :index
      live "/dashboard/content-generator", AdminContentGeneratorLive, :plan
      live "/dashboard/content-generator/runs", AdminContentGeneratorLive, :runs
      live "/dashboard/content-generator/runs/:run_id", AdminContentGeneratorLive, :run
      live "/dashboard/content-generator/entries/:entry_id", AdminContentGeneratorLive, :entry
      live "/dashboard/chatops", ChatOpsLive, :index
    end

    get "/dashboard/analytics/export/gaps.csv", AdminAnalyticsExportController, :gaps
    get "/dashboard/analytics/export/feedback.csv", AdminAnalyticsExportController, :feedback
  end

  scope "/" do
    pipe_through([:browser, :require_authenticated_user, :require_admin_user])
    get("/assets/js/app.js", AgentJidoWeb.PageController, :arcana_legacy_app_js)
    arcana_dashboard("/arcana", repo: AgentJido.Repo, on_mount: @admin_on_mount)
  end

  ## Authentication routes

  scope "/", AgentJidoWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{AgentJidoWeb.UserAuth, :require_authenticated}] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  scope "/", AgentJidoWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{AgentJidoWeb.UserAuth, :mount_current_scope}] do
      live "/search", ContentAssistantLive, :index
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end

  scope "/", AgentJidoWeb do
    pipe_through :browser

    match :*, "/*path", PageController, :not_found
  end

  def examples_live_session(conn) do
    %{
      "examples_include_drafts" =>
        case conn.assigns[:current_scope] do
          %{user: user} -> Accounts.admin?(user)
          _other -> false
        end
    }
  end
end
