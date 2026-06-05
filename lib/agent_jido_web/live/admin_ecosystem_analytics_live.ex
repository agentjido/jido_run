defmodule AgentJidoWeb.AdminEcosystemAnalyticsLive do
  @moduledoc """
  Admin dashboard for external Jido ecosystem analytics signals.
  """
  use AgentJidoWeb, :live_view

  alias AgentJido.Analytics

  @default_days 30
  @allowed_days [7, 30]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Ecosystem Analytics")
     |> assign(:analytics_days, @default_days)
     |> assign(:allowed_days, @allowed_days)
     |> assign(:ecosystem_snapshot, empty_snapshot(@default_days))
     |> load_snapshot()}
  end

  @impl true
  def handle_event("set_window", %{"days" => raw_days}, socket) do
    days = parse_days(raw_days)

    {:noreply,
     socket
     |> assign(:analytics_days, days)
     |> load_snapshot()}
  end

  def handle_event("refresh", _params, socket) do
    {:noreply, load_snapshot(socket)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <AgentJidoWeb.Jido.AdminNav.admin_shell current_path="/dashboard/ecosystem-analytics">
      <div class="container mx-auto max-w-7xl space-y-7 px-6 py-12">
        <header class="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
          <div class="space-y-2">
            <p class="text-xs font-semibold uppercase tracking-[0.2em] text-primary">Admin Control Plane</p>
            <h1 class="text-3xl font-semibold text-foreground">Ecosystem Analytics</h1>
            <p class="max-w-3xl text-sm text-muted-foreground">
              Collector-backed demand and adoption signals across the Jido site, repos, packages, and search footprint.
            </p>
          </div>

          <div class="flex flex-wrap items-center gap-2">
            <div class="inline-flex items-center gap-2 rounded-md border border-border bg-background p-1">
              <button
                :for={days <- @allowed_days}
                type="button"
                phx-click="set_window"
                phx-value-days={days}
                class={window_button_class(@analytics_days, days)}
              >
                {days}d
              </button>
            </div>
            <button
              type="button"
              phx-click="refresh"
              class="rounded-md bg-primary px-3 py-2 text-xs font-semibold text-primary-foreground transition-colors hover:bg-primary/90"
            >
              Refresh
            </button>
          </div>
        </header>

        <p :if={!@ecosystem_snapshot.authorized?} class="text-sm font-semibold text-accent-yellow">
          Ecosystem analytics requires an authenticated admin scope.
        </p>

        <p :if={@ecosystem_snapshot.unavailable?} class="text-sm font-semibold text-accent-yellow">
          Ecosystem analytics is currently unavailable.
        </p>

        <section class="grid gap-3 md:grid-cols-2 xl:grid-cols-4">
          <.metric_card
            label="Search visibility"
            value={format_count(@ecosystem_snapshot.totals.search_console.impressions)}
            subvalue={"#{format_count(@ecosystem_snapshot.totals.search_console.clicks)} clicks"}
            meta={"CTR #{format_percent(@ecosystem_snapshot.totals.search_console.ctr)}"}
          />
          <.metric_card
            label="Site engagement"
            value={format_count(@ecosystem_snapshot.totals.plausible.visitors)}
            subvalue={"#{format_count(@ecosystem_snapshot.totals.plausible.pageviews)} pageviews"}
            meta={"#{format_duration(@ecosystem_snapshot.totals.plausible.visit_duration)} avg visit"}
          />
          <.metric_card
            label="Repository traffic"
            value={format_count(@ecosystem_snapshot.totals.github.views_count)}
            subvalue={"#{format_count(@ecosystem_snapshot.totals.github.clones_count)} clones"}
            meta={"#{format_count(@ecosystem_snapshot.totals.github.views_uniques)} unique viewers"}
          />
          <.metric_card
            label="Package downloads"
            value={format_count(@ecosystem_snapshot.totals.hex.downloads_recent)}
            subvalue={"#{format_count(@ecosystem_snapshot.totals.hex.downloads_week)} this week"}
            meta={"#{@ecosystem_snapshot.totals.hex.packages_count} published packages"}
          />
        </section>

        <section class="grid gap-6 xl:grid-cols-[minmax(0,1fr)_minmax(460px,0.82fr)]">
          <article class="rounded-lg border border-border bg-card p-5">
            <div class="flex flex-wrap items-center justify-between gap-3">
              <h2 class="text-lg font-semibold text-foreground">Acquisition Sources</h2>
              <span class="text-xs text-muted-foreground">Plausible visitors</span>
            </div>

            <div class="mt-4 space-y-3">
              <div
                :for={source <- @ecosystem_snapshot.acquisition_sources}
                class="grid gap-2 sm:grid-cols-[minmax(150px,0.9fr)_minmax(0,1.4fr)_90px] sm:items-center"
              >
                <div class="min-w-0 truncate text-sm font-medium text-foreground" title={source.value}>{source.value}</div>
                <div class="h-2 overflow-hidden rounded-full bg-background">
                  <div
                    class="h-full rounded-full bg-primary/80"
                    style={"width: #{bar_width(source.visitors, max_metric(@ecosystem_snapshot.acquisition_sources, :visitors))}%"}
                  >
                  </div>
                </div>
                <div class="text-right text-xs text-muted-foreground">
                  {format_count(source.visitors)} visitors
                </div>
              </div>
              <p :if={@ecosystem_snapshot.acquisition_sources == []} class="text-sm text-muted-foreground">
                No source data collected yet.
              </p>
            </div>
          </article>

          <article class="rounded-lg border border-border bg-card p-5">
            <div class="flex flex-wrap items-center justify-between gap-3">
              <h2 class="text-lg font-semibold text-foreground">Collection Coverage</h2>
              <span class="text-xs text-muted-foreground">Window starts {format_date(@ecosystem_snapshot.since_date)}</span>
            </div>

            <div class="mt-4 overflow-x-auto rounded-md border border-border bg-background">
              <table class="min-w-full text-left text-xs">
                <thead class="bg-elevated text-muted-foreground">
                  <tr>
                    <th class="px-3 py-2 font-semibold">Source</th>
                    <th class="px-3 py-2 font-semibold">Config</th>
                    <th class="px-3 py-2 font-semibold">Run</th>
                    <th class="px-3 py-2 text-right font-semibold">Tracked</th>
                    <th class="px-3 py-2 text-right font-semibold">Rows</th>
                    <th class="px-3 py-2 font-semibold">Latest Data</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={source <- @ecosystem_snapshot.collection.sources} class="border-t border-border/70">
                    <td class="whitespace-nowrap px-3 py-2 font-semibold text-foreground">
                      {source.label}
                    </td>
                    <td class="whitespace-nowrap px-3 py-2">
                      <span class={config_status_class(source.configured?)}>
                        {config_status_label(source.configured?)}
                      </span>
                    </td>
                    <td class="whitespace-nowrap px-3 py-2">
                      <span class={run_status_class(get_in(source, [:latest_run, :status]))}>
                        {run_status_label(get_in(source, [:latest_run, :status]))}
                      </span>
                    </td>
                    <td class="px-3 py-2 text-right text-muted-foreground">{format_count(source.tracked_count)}</td>
                    <td class="px-3 py-2 text-right text-muted-foreground">{format_count(source.rows_count)}</td>
                    <td class="whitespace-nowrap px-3 py-2 text-muted-foreground">{format_date(source.latest_day)}</td>
                  </tr>
                  <tr :if={@ecosystem_snapshot.collection.sources == []}>
                    <td colspan="6" class="px-3 py-3 text-muted-foreground">No collector runs yet.</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </article>
        </section>

        <section class="grid gap-6 xl:grid-cols-2">
          <.data_table title="Search Queries" rows={@ecosystem_snapshot.search_queries} empty="No Search Console query data yet.">
            <:col :let={row} label="Query">{truncate(row.value, 58)}</:col>
            <:col :let={row} label="Clicks">{format_count(row.clicks)}</:col>
            <:col :let={row} label="Impr.">{format_count(row.impressions)}</:col>
            <:col :let={row} label="Pos.">{format_float(row.position)}</:col>
          </.data_table>

          <.data_table title="Search Landing Pages" rows={@ecosystem_snapshot.search_pages} empty="No Search Console page data yet.">
            <:col :let={row} label="Page">{truncate(row.value, 58)}</:col>
            <:col :let={row} label="Clicks">{format_count(row.clicks)}</:col>
            <:col :let={row} label="Impr.">{format_count(row.impressions)}</:col>
            <:col :let={row} label="Pos.">{format_float(row.position)}</:col>
          </.data_table>

          <.data_table title="Repo Interest" rows={@ecosystem_snapshot.repo_interest} empty="No GitHub traffic data yet.">
            <:col :let={row} label="Repo">{truncate(row.repository, 42)}</:col>
            <:col :let={row} label="Views">{format_count(row.views_count)}</:col>
            <:col :let={row} label="Clones">{format_count(row.clones_count)}</:col>
            <:col :let={row} label="Unique">{format_count(row.views_uniques)}</:col>
          </.data_table>

          <.data_table title="Package Adoption" rows={@ecosystem_snapshot.package_adoption} empty="No Hex package snapshots yet.">
            <:col :let={row} label="Package">{row.package_name}</:col>
            <:col :let={row} label="Version">{row.latest_version || "-"}</:col>
            <:col :let={row} label="Recent">{format_count(row.downloads_recent)}</:col>
            <:col :let={row} label="All">{format_count(row.downloads_all)}</:col>
          </.data_table>

          <.data_table title="Site Pages" rows={@ecosystem_snapshot.site_pages} empty="No Plausible page data yet.">
            <:col :let={row} label="Page">{truncate(row.value, 52)}</:col>
            <:col :let={row} label="Visitors">{format_count(row.visitors)}</:col>
            <:col :let={row} label="Views">{format_count(row.pageviews)}</:col>
            <:col :let={row} label="Bounce">{format_percent_from_100(row.bounce_rate)}</:col>
          </.data_table>

          <.data_table title="Content Gaps" rows={@ecosystem_snapshot.content_gaps} empty="No local search gaps yet.">
            <:col :let={row} label="Query">{truncate(row.query, 52)}</:col>
            <:col :let={row} label="Demand">{format_count(row.demand_count)}</:col>
            <:col :let={row} label="Failures">{format_count(row.failure_count)}</:col>
            <:col :let={row} label="Rate">{format_percent(row.failure_rate)}</:col>
          </.data_table>
        </section>

        <section class="grid gap-6 xl:grid-cols-2">
          <.data_table title="GitHub Paths" rows={@ecosystem_snapshot.github_paths} empty="No GitHub path snapshots yet.">
            <:col :let={row} label="Repo">{truncate(row.repository, 34)}</:col>
            <:col :let={row} label="Path">{truncate(row.path, 52)}</:col>
            <:col :let={row} label="Views">{format_count(row.count)}</:col>
            <:col :let={row} label="Unique">{format_count(row.uniques)}</:col>
          </.data_table>

          <.data_table title="GitHub Referrers" rows={@ecosystem_snapshot.github_referrers} empty="No GitHub referrer snapshots yet.">
            <:col :let={row} label="Referrer">{truncate(row.referrer, 42)}</:col>
            <:col :let={row} label="Repo">{truncate(row.repository, 34)}</:col>
            <:col :let={row} label="Views">{format_count(row.count)}</:col>
            <:col :let={row} label="Unique">{format_count(row.uniques)}</:col>
          </.data_table>
        </section>
      </div>
    </AgentJidoWeb.Jido.AdminNav.admin_shell>
    """
  end

  defp load_snapshot(socket) do
    snapshot =
      analytics_module().ecosystem_snapshot(
        socket.assigns.current_scope,
        socket.assigns.analytics_days,
        limit: 8
      )

    assign(socket, :ecosystem_snapshot, snapshot)
  end

  defp parse_days(raw_days) when is_binary(raw_days) do
    case Integer.parse(raw_days) do
      {days, ""} when days in @allowed_days -> days
      _value -> @default_days
    end
  end

  defp parse_days(_raw_days), do: @default_days

  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :subvalue, :string, required: true
  attr :meta, :string, required: true

  defp metric_card(assigns) do
    ~H"""
    <article class="rounded-lg border border-border bg-card p-4">
      <p class="text-xs font-semibold uppercase tracking-[0.14em] text-muted-foreground">{@label}</p>
      <p class="mt-3 text-2xl font-semibold text-foreground">{@value}</p>
      <div class="mt-2 flex flex-wrap gap-x-3 gap-y-1 text-xs text-muted-foreground">
        <span>{@subvalue}</span>
        <span>{@meta}</span>
      </div>
    </article>
    """
  end

  attr :title, :string, required: true
  attr :rows, :list, required: true
  attr :empty, :string, required: true

  slot :col, required: true do
    attr :label, :string, required: true
  end

  defp data_table(assigns) do
    ~H"""
    <article class="rounded-lg border border-border bg-card p-5">
      <h2 class="text-lg font-semibold text-foreground">{@title}</h2>
      <div class="mt-4 overflow-x-auto rounded-md border border-border bg-background">
        <table class="min-w-full text-left text-xs">
          <thead class="bg-elevated text-muted-foreground">
            <tr>
              <th :for={col <- @col} class="px-3 py-2 font-semibold">{col.label}</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={row <- @rows} class="border-t border-border/70">
              <td :for={col <- @col} class="max-w-[360px] px-3 py-2 text-foreground">
                {render_slot(col, row)}
              </td>
            </tr>
            <tr :if={@rows == []}>
              <td colspan={length(@col)} class="px-3 py-3 text-muted-foreground">{@empty}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </article>
    """
  end

  defp empty_snapshot(days) do
    %{
      days: days,
      since_date: Date.utc_today() |> Date.add(-days + 1),
      unavailable?: false,
      authorized?: true,
      totals: %{
        github: %{views_count: 0, views_uniques: 0, clones_count: 0, clones_uniques: 0},
        plausible: %{visitors: 0, visits: 0, pageviews: 0, events: 0, bounce_rate: nil, visit_duration: nil},
        search_console: %{clicks: 0, impressions: 0, ctr: 0.0, position: nil},
        hex: %{day: nil, packages_count: 0, downloads_day: 0, downloads_week: 0, downloads_recent: 0, downloads_all: 0}
      },
      collection: %{sources: [], recent_runs: []},
      acquisition_sources: [],
      site_pages: [],
      search_queries: [],
      search_pages: [],
      repo_interest: [],
      github_paths: [],
      github_referrers: [],
      package_adoption: [],
      release_adoption: [],
      content_gaps: []
    }
  end

  defp window_button_class(selected_days, days) do
    base = "rounded px-3 py-1.5 text-xs font-semibold transition-colors"

    if selected_days == days do
      base <> " bg-primary text-primary-foreground"
    else
      base <> " text-muted-foreground hover:text-foreground"
    end
  end

  defp run_status_label("completed"), do: "Completed"
  defp run_status_label("running"), do: "Running"
  defp run_status_label("failed"), do: "Failed"
  defp run_status_label(_status), do: "No runs"

  defp config_status_label(true), do: "Configured"
  defp config_status_label(_configured?), do: "Missing"

  defp config_status_class(true) do
    "inline-flex shrink-0 rounded-full border border-accent-green/30 bg-accent-green/10 px-2 py-0.5 text-[11px] font-semibold text-accent-green"
  end

  defp config_status_class(_configured?) do
    "inline-flex shrink-0 rounded-full border border-accent-yellow/30 bg-accent-yellow/10 px-2 py-0.5 text-[11px] font-semibold text-accent-yellow"
  end

  defp run_status_class("completed") do
    "inline-flex shrink-0 rounded-full border border-accent-green/30 bg-accent-green/10 px-2 py-0.5 text-[11px] font-semibold text-accent-green"
  end

  defp run_status_class("running") do
    "inline-flex shrink-0 rounded-full border border-accent-cyan/30 bg-accent-cyan/10 px-2 py-0.5 text-[11px] font-semibold text-accent-cyan"
  end

  defp run_status_class("failed") do
    "inline-flex shrink-0 rounded-full border border-accent-red/30 bg-accent-red/10 px-2 py-0.5 text-[11px] font-semibold text-accent-red"
  end

  defp run_status_class(_status) do
    "inline-flex shrink-0 rounded-full border border-border bg-background px-2 py-0.5 text-[11px] font-semibold text-muted-foreground"
  end

  defp max_metric(rows, key) do
    rows
    |> Enum.map(&(Map.get(&1, key) || 0))
    |> Enum.max(fn -> 0 end)
  end

  defp bar_width(value, max_value) when is_number(value) and is_number(max_value) and max_value > 0 do
    width =
      value
      |> Kernel./(max_value)
      |> Kernel.*(100.0)
      |> min(100.0)
      |> max(4.0)

    Float.round(width, 1)
  end

  defp bar_width(_value, _max_value), do: 0

  defp format_count(nil), do: "0"
  defp format_count(value) when is_float(value), do: value |> round() |> format_count()

  defp format_count(value) when is_integer(value) do
    value
    |> Integer.to_string()
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.map(&Enum.join/1)
    |> Enum.join(",")
    |> String.reverse()
  end

  defp format_count(_value), do: "0"

  defp format_percent(value) when is_number(value), do: "#{value |> Kernel.*(100.0) |> Float.round(1)}%"
  defp format_percent(_value), do: "0.0%"

  defp format_percent_from_100(value) when is_number(value), do: "#{value |> Kernel.*(1.0) |> Float.round(1)}%"
  defp format_percent_from_100(_value), do: "-"

  defp format_float(value) when is_float(value), do: value |> Float.round(1) |> :erlang.float_to_binary(decimals: 1)
  defp format_float(value) when is_integer(value), do: Integer.to_string(value)
  defp format_float(_value), do: "-"

  defp format_duration(value) when is_float(value), do: value |> round() |> format_duration()
  defp format_duration(%Decimal{} = value), do: value |> Decimal.round(0) |> Decimal.to_integer() |> format_duration()
  defp format_duration(value) when is_integer(value) and value >= 60, do: "#{div(value, 60)}m #{rem(value, 60)}s"
  defp format_duration(value) when is_integer(value) and value >= 0, do: "#{value}s"
  defp format_duration(_value), do: "-"

  defp format_date(%Date{} = date), do: Date.to_iso8601(date)
  defp format_date(_date), do: "-"

  defp truncate(value, limit) when is_binary(value) do
    trimmed = String.trim(value)

    cond do
      trimmed == "" -> "-"
      String.length(trimmed) > limit -> String.slice(trimmed, 0, limit - 3) <> "..."
      true -> trimmed
    end
  end

  defp truncate(_value, _limit), do: "-"

  defp analytics_module do
    Application.get_env(:agent_jido, :analytics_module, Analytics)
  end
end
