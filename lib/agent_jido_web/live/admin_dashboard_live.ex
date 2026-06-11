defmodule AgentJidoWeb.AdminDashboardLive do
  @moduledoc """
  Admin control-plane landing page for privileged tools.
  """
  use AgentJidoWeb, :live_view

  alias AgentJido.Analytics
  alias AgentJido.QueryLogs
  alias AgentJidoWeb.SitePresence

  @query_window_days 7
  @query_recent_limit 80
  @query_top_limit 8

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      SitePresence.subscribe()
    end

    {:ok,
     socket
     |> assign(:query_tracking_snapshot, %{})
     |> assign(:analytics_snapshot, %{})
     |> assign(:live_presence, %{active_visitors: 0, active_sessions: 0})
     |> load_live_presence_snapshot()
     |> load_analytics_snapshot()
     |> load_query_tracking_snapshot()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <AgentJidoWeb.Jido.AdminNav.admin_shell
      current_path="/dashboard"
      exclude_paths={["/dashboard/contentops", "/dashboard/contentops/github", "/dashboard/content-generator"]}
    >
      <div class="container mx-auto max-w-5xl space-y-8 px-6 py-12">
        <header class="space-y-2">
          <p class="text-xs font-semibold uppercase tracking-[0.2em] text-primary">Admin Control Plane</p>
          <h1 class="text-3xl font-semibold text-foreground">Dashboard</h1>
          <p class="max-w-2xl text-sm text-muted-foreground">
            Launch operational tooling for search, studio workflows, and ContentOps execution.
          </p>
        </header>

        <section class="grid gap-4 md:grid-cols-2">
          <article
            id="dashboard-live-presence"
            data-active-visitors={@live_presence.active_visitors}
            data-active-sessions={@live_presence.active_sessions}
            class="space-y-2 rounded-lg border border-border bg-card p-6"
          >
            <h2 class="text-lg font-semibold text-foreground">Live Presence</h2>
            <p class="text-sm text-muted-foreground">
              Real-time active visitors and connected sessions on the LiveView site.
            </p>
            <div class="grid grid-cols-2 gap-2 text-xs text-muted-foreground">
              <span>visitors now</span>
              <span class="text-right font-semibold text-foreground">{@live_presence.active_visitors}</span>
              <span>sessions now</span>
              <span class="text-right font-semibold text-foreground">{@live_presence.active_sessions}</span>
            </div>
          </article>

          <article class="space-y-2 rounded-lg border border-border bg-card p-6">
            <h2 class="text-lg font-semibold text-foreground">Arcana dashboard</h2>
            <p class="text-sm text-muted-foreground">
              Inspect retrieval surfaces, collections, and search diagnostics.
            </p>
            <.link href="/arcana" class="text-sm font-semibold text-primary hover:text-primary/80">
              Open Arcana dashboard
            </.link>
          </article>

          <article class="space-y-2 rounded-lg border border-border bg-card p-6">
            <h2 class="text-lg font-semibold text-foreground">Jido Studio</h2>
            <p class="text-sm text-muted-foreground">
              Observe and operate agent workflows in the Jido Studio environment.
            </p>
            <.link href="/dev/jido" class="text-sm font-semibold text-primary hover:text-primary/80">
              Open Jido Studio
            </.link>
          </article>

          <article id="dashboard-content-ingest" class="space-y-2 rounded-lg border border-border bg-card p-6 md:col-span-2">
            <h2 class="text-lg font-semibold text-foreground">Content Ingestion</h2>
            <p class="text-sm text-muted-foreground">
              Review ingestion health, see what is stale, and trigger targeted or full refresh.
            </p>
            <.link
              navigate="/dashboard/content-ingestion"
              class="text-sm font-semibold text-primary hover:text-primary/80"
            >
              Open Content Ingestion
            </.link>
          </article>

          <article id="dashboard-ecosystem-analytics" class="space-y-2 rounded-lg border border-border bg-card p-6 md:col-span-2">
            <h2 class="text-lg font-semibold text-foreground">Ecosystem Analytics</h2>
            <p class="text-sm text-muted-foreground">
              Review external demand, package adoption, repo traffic, and Search Console evidence.
            </p>
            <.link
              navigate="/dashboard/ecosystem-analytics"
              class="text-sm font-semibold text-primary hover:text-primary/80"
            >
              Open ecosystem analytics
            </.link>
          </article>

          <article id="dashboard-query-tracking" class="space-y-4 rounded-lg border border-border bg-card p-6 md:col-span-2">
            <div class="flex flex-wrap items-start justify-between gap-3">
              <div class="space-y-2">
                <h2 class="text-lg font-semibold text-foreground">Query Tracking</h2>
                <p class="text-sm text-muted-foreground">
                  Tracks every content assistant query submitted through the site.
                </p>
              </div>

              <button
                type="button"
                phx-click="refresh_query_tracking"
                class="rounded-md border border-border bg-background px-3 py-2 text-xs font-semibold text-foreground hover:border-primary/50"
              >
                Refresh query logs
              </button>
            </div>

            <p :if={@query_tracking_snapshot.unavailable?} class="text-xs font-semibold text-accent-yellow">
              Query tracking is temporarily unavailable. Run migrations and refresh.
            </p>

            <div class="grid grid-cols-2 gap-2 text-xs text-muted-foreground md:grid-cols-5">
              <span>window: {@query_tracking_snapshot.summary.days}d</span>
              <span>total: {@query_tracking_snapshot.summary.total}</span>
              <span>content assistant: {@query_tracking_snapshot.summary.content_assistant}</span>
              <span>success: {@query_tracking_snapshot.summary.success}</span>
              <span>no results: {@query_tracking_snapshot.summary.no_results}</span>
            </div>

            <div :if={@query_tracking_snapshot.top_queries != []} class="space-y-2">
              <h3 class="text-xs font-semibold uppercase tracking-[0.14em] text-muted-foreground">Top queries</h3>
              <div class="flex flex-wrap gap-2">
                <span
                  :for={query <- @query_tracking_snapshot.top_queries}
                  class="rounded-full border border-border bg-background px-2.5 py-1 text-xs text-foreground"
                >
                  {truncate_query(query.query)} <span class="text-muted-foreground">({query.count})</span>
                </span>
              </div>
            </div>

            <div class="overflow-x-auto rounded-md border border-border bg-background">
              <table class="min-w-full text-left text-xs">
                <thead class="bg-elevated text-muted-foreground">
                  <tr>
                    <th class="px-3 py-2 font-semibold">Time (UTC)</th>
                    <th class="px-3 py-2 font-semibold">Source</th>
                    <th class="px-3 py-2 font-semibold">Channel</th>
                    <th class="px-3 py-2 font-semibold">Status</th>
                    <th class="px-3 py-2 font-semibold">Results</th>
                    <th class="px-3 py-2 font-semibold">Query</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={entry <- @query_tracking_snapshot.recent_queries} class="border-t border-border/70">
                    <td class="whitespace-nowrap px-3 py-2 text-muted-foreground">{format_timestamp(entry.inserted_at)}</td>
                    <td class="px-3 py-2 text-foreground">{source_label(entry.source)}</td>
                    <td class="px-3 py-2 text-muted-foreground">{entry.channel}</td>
                    <td class="px-3 py-2">
                      <span class={"rounded px-1.5 py-0.5 font-semibold #{query_status_class(entry.status)}"}>
                        {entry.status}
                      </span>
                    </td>
                    <td class="px-3 py-2 text-muted-foreground">{entry.results_count}</td>
                    <td class="max-w-[560px] break-words px-3 py-2 text-foreground">{entry.query}</td>
                  </tr>
                  <tr :if={@query_tracking_snapshot.recent_queries == []}>
                    <td colspan="6" class="px-3 py-3 text-muted-foreground">
                      No query logs yet.
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </article>

          <article id="dashboard-analytics-summary" class="space-y-4 rounded-lg border border-border bg-card p-6 md:col-span-2">
            <div class="flex items-start justify-between gap-3">
              <div class="space-y-2">
                <h2 class="text-lg font-semibold text-foreground">Learning Analytics</h2>
                <p class="text-sm text-muted-foreground">
                  Demand gaps and feedback signals from first-party analytics.
                </p>
              </div>

              <.link
                navigate="/dashboard/analytics"
                class="rounded-md border border-border bg-background px-3 py-2 text-xs font-semibold text-foreground hover:border-primary/50"
              >
                Open analytics dashboard
              </.link>
            </div>

            <div class="grid grid-cols-2 gap-2 text-xs text-muted-foreground md:grid-cols-4">
              <span>queries: {@analytics_snapshot.summary.total_queries || 0}</span>
              <span>failed: {@analytics_snapshot.summary.failed_queries || 0}</span>
              <span>helpful: {@analytics_snapshot.summary.helpful_feedback || 0}</span>
              <span>not helpful: {@analytics_snapshot.summary.not_helpful_feedback || 0}</span>
            </div>
          </article>
        </section>
      </div>
    </AgentJidoWeb.Jido.AdminNav.admin_shell>
    """
  end

  @impl true
  def handle_event("refresh_query_tracking", _params, socket) do
    {:noreply, socket |> load_live_presence_snapshot() |> load_query_tracking_snapshot() |> load_analytics_snapshot()}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff", topic: topic}, socket) do
    if topic == SitePresence.topic() do
      {:noreply, load_live_presence_snapshot(socket)}
    else
      {:noreply, socket}
    end
  end

  defp load_query_tracking_snapshot(socket) do
    snapshot =
      QueryLogs.dashboard_snapshot(
        @query_window_days,
        @query_recent_limit,
        @query_top_limit
      )

    assign(socket, :query_tracking_snapshot, snapshot)
  end

  defp load_analytics_snapshot(socket) do
    snapshot =
      Analytics.dashboard_snapshot(
        socket.assigns.current_scope,
        7,
        top_limit: 8,
        gap_limit: 8,
        reform_limit: 8,
        feedback_limit: 20
      )

    assign(socket, :analytics_snapshot, snapshot)
  end

  defp load_live_presence_snapshot(socket) do
    assign(socket, :live_presence, SitePresence.snapshot())
  end

  defp source_label("content_assistant"), do: "Content Assistant"
  defp source_label(source) when is_binary(source), do: source
  defp source_label(_source), do: "Unknown"

  defp query_status_class("success"), do: "bg-accent-green/15 text-accent-green"
  defp query_status_class("no_results"), do: "bg-accent-yellow/15 text-accent-yellow"
  defp query_status_class("error"), do: "bg-accent-red/15 text-accent-red"
  defp query_status_class("challenge"), do: "bg-accent-yellow/15 text-accent-yellow"
  defp query_status_class("submitted"), do: "bg-accent-cyan/15 text-accent-cyan"
  defp query_status_class(_status), do: "bg-muted text-muted-foreground"

  defp format_timestamp(%NaiveDateTime{} = datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S")
  end

  defp format_timestamp(_datetime), do: "—"

  defp truncate_query(query) when is_binary(query) do
    trimmed = String.trim(query)

    cond do
      trimmed == "" ->
        "(empty)"

      String.length(trimmed) > 80 ->
        String.slice(trimmed, 0, 77) <> "..."

      true ->
        trimmed
    end
  end

  defp truncate_query(_query), do: "(empty)"
end
