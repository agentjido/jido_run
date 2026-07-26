defmodule AgentJidoWeb.AdminAnalyticsLive do
  @moduledoc """
  Admin analytics dashboard for first-party learning signals.
  """
  use AgentJidoWeb, :live_view

  alias AgentJido.Analytics

  @default_days 7
  @allowed_days [7, 30]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Analytics")
     |> assign(:analytics_days, @default_days)
     |> assign(:allowed_days, @allowed_days)
     |> assign(:analytics_snapshot, empty_snapshot(@default_days))
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
    <AgentJidoWeb.Jido.AdminNav.admin_shell current_path="/dashboard/analytics">
      <div class="container mx-auto max-w-6xl space-y-8 px-6 py-12">
        <header class="space-y-2">
          <p class="text-xs font-semibold uppercase tracking-[0.2em] text-primary">Admin Control Plane</p>
          <h1 class="text-3xl font-semibold text-foreground">First-Party Analytics</h1>
          <p class="max-w-3xl text-sm text-muted-foreground">
            Tracker-blocker resilient demand and outcome analytics for content assistant and docs learning flows.
          </p>
        </header>

        <section class="flex flex-wrap items-center justify-between gap-3 rounded-lg border border-border bg-card p-4">
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

          <div class="flex items-center gap-2">
            <.link
              href={~p"/dashboard/analytics/export/gaps.csv?days=#{@analytics_days}"}
              class="rounded-md border border-border bg-background px-3 py-2 text-xs font-semibold text-foreground hover:border-primary/50"
            >
              Export gaps CSV
            </.link>
            <.link
              href={~p"/dashboard/analytics/export/feedback.csv?days=#{@analytics_days}"}
              class="rounded-md border border-border bg-background px-3 py-2 text-xs font-semibold text-foreground hover:border-primary/50"
            >
              Export feedback CSV
            </.link>
            <button
              type="button"
              phx-click="refresh"
              class="rounded-md bg-primary px-3 py-2 text-xs font-semibold text-primary-foreground hover:bg-primary/90"
            >
              Refresh
            </button>
          </div>
        </section>

        <p :if={!@analytics_snapshot.authorized?} class="text-sm font-semibold text-accent-yellow">
          Analytics insights require an authenticated admin scope.
        </p>

        <p :if={@analytics_snapshot.unavailable?} class="text-sm font-semibold text-accent-yellow">
          Analytics snapshot is currently unavailable.
        </p>

        <section class="grid gap-3 md:grid-cols-4">
          <article class="rounded-lg border border-border bg-card p-4">
            <p class="text-xs uppercase tracking-wide text-muted-foreground">Total queries</p>
            <p class="mt-2 text-2xl font-semibold text-foreground">{@analytics_snapshot.summary.total_queries || 0}</p>
          </article>
          <article class="rounded-lg border border-border bg-card p-4">
            <p class="text-xs uppercase tracking-wide text-muted-foreground">Failed queries</p>
            <p class="mt-2 text-2xl font-semibold text-foreground">{@analytics_snapshot.summary.failed_queries || 0}</p>
          </article>
          <article class="rounded-lg border border-border bg-card p-4">
            <p class="text-xs uppercase tracking-wide text-muted-foreground">Helpful feedback</p>
            <p class="mt-2 text-2xl font-semibold text-foreground">{@analytics_snapshot.summary.helpful_feedback || 0}</p>
          </article>
          <article class="rounded-lg border border-border bg-card p-4">
            <p class="text-xs uppercase tracking-wide text-muted-foreground">Not helpful</p>
            <p class="mt-2 text-2xl font-semibold text-foreground">{@analytics_snapshot.summary.not_helpful_feedback || 0}</p>
          </article>
        </section>

        <section class="rounded-lg border border-border bg-card p-5">
          <h2 class="text-lg font-semibold text-foreground">Home → onboarding conversion</h2>
          <p class="mt-1 text-sm text-muted-foreground">
            Clicks on each home call-to-action, so the hero and section CTA paths into onboarding are visible — not only page traffic.
          </p>
          <table class="mt-4 w-full text-sm">
            <thead>
              <tr class="text-left text-xs uppercase tracking-wide text-muted-foreground">
                <th class="py-2 pr-4 font-semibold">CTA path</th>
                <th class="py-2 pr-4 font-semibold">Section</th>
                <th class="py-2 font-semibold">Clicks</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={row <- @analytics_snapshot.home_conversion} class="border-t border-border/70">
                <td class="py-2 pr-4 font-medium text-foreground">{home_conversion_label(row.section_id)}</td>
                <td class="py-2 pr-4 text-muted-foreground">{row.section_id}</td>
                <td class="py-2 text-foreground">{row.clicks}</td>
              </tr>
              <tr :if={@analytics_snapshot.home_conversion == []}>
                <td colspan="3" class="py-2 text-sm text-muted-foreground">
                  No home CTA clicks in this window yet.
                </td>
              </tr>
            </tbody>
          </table>
        </section>

        <section class="rounded-lg border border-border bg-card p-5">
          <h2 class="text-lg font-semibold text-foreground">First Livebook open</h2>
          <p class="mt-1 text-sm text-muted-foreground">
            Where activation starts — the surface each visitor first opened a Livebook from, so the team can see activation by entry point, not only total runs.
          </p>
          <table class="mt-4 w-full text-sm">
            <thead>
              <tr class="text-left text-xs uppercase tracking-wide text-muted-foreground">
                <th class="py-2 pr-4 font-semibold">Activation surface</th>
                <th class="py-2 pr-4 font-semibold">Source</th>
                <th class="py-2 font-semibold">First opens</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={row <- @analytics_snapshot.first_livebook_open} class="border-t border-border/70">
                <td class="py-2 pr-4 font-medium text-foreground">{first_livebook_open_label(row.source)}</td>
                <td class="py-2 pr-4 text-muted-foreground">{row.source}</td>
                <td class="py-2 text-foreground">{row.activations}</td>
              </tr>
              <tr :if={@analytics_snapshot.first_livebook_open == []}>
                <td colspan="3" class="py-2 text-sm text-muted-foreground">
                  No first Livebook opens in this window yet.
                </td>
              </tr>
            </tbody>
          </table>
        </section>

        <section class="rounded-lg border border-border bg-card p-5">
          <div class="flex flex-wrap items-center justify-between gap-3">
            <h2 class="text-lg font-semibold text-foreground">Collector Health</h2>
            <span class="text-xs text-muted-foreground">Rows shown for the selected {@analytics_days}d window</span>
          </div>
          <div class="mt-3 overflow-x-auto rounded-md border border-border bg-background">
            <table class="min-w-full text-left text-xs">
              <thead class="bg-elevated text-muted-foreground">
                <tr>
                  <th class="px-3 py-2 font-semibold">Source</th>
                  <th class="px-3 py-2 font-semibold">Configured</th>
                  <th class="px-3 py-2 font-semibold">Tracked</th>
                  <th class="px-3 py-2 font-semibold">Latest run</th>
                  <th class="px-3 py-2 font-semibold">Latest data day</th>
                  <th class="px-3 py-2 font-semibold">Rows</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={source <- @analytics_snapshot.ingestion.sources} class="border-t border-border/70">
                  <td class="whitespace-nowrap px-3 py-2 font-semibold text-foreground">{source.label}</td>
                  <td class="whitespace-nowrap px-3 py-2">
                    <span class={configured_badge_class(source[:configured?])}>{configured_label(source[:configured?])}</span>
                  </td>
                  <td class="px-3 py-2 text-muted-foreground">{source.tracked_count}</td>
                  <td class="whitespace-nowrap px-3 py-2">
                    <span class={run_status_class(get_in(source, [:latest_run, :status]))}>
                      {run_status_label(get_in(source, [:latest_run, :status]))}
                    </span>
                  </td>
                  <td class="whitespace-nowrap px-3 py-2 text-muted-foreground">{format_date(source.latest_day)}</td>
                  <td class="px-3 py-2 text-muted-foreground">{source.rows_count}</td>
                </tr>
                <tr :if={@analytics_snapshot.ingestion.sources == []}>
                  <td colspan="6" class="px-3 py-3 text-muted-foreground">No collector health data available.</td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>

        <section class="rounded-lg border border-border bg-card p-5">
          <div class="flex flex-wrap items-center justify-between gap-3">
            <h2 class="text-lg font-semibold text-foreground">Recent Search Messages</h2>
            <div class="flex flex-wrap gap-2 text-xs text-muted-foreground">
              <span>success {@analytics_snapshot.local_search.summary.successful_messages || 0}</span>
              <span>no results {@analytics_snapshot.local_search.summary.no_result_messages || 0}</span>
              <span>failed {@analytics_snapshot.local_search.summary.failed_messages || 0}</span>
            </div>
          </div>
          <div class="mt-3 overflow-x-auto rounded-md border border-border bg-background">
            <table class="min-w-full text-left text-xs">
              <thead class="bg-elevated text-muted-foreground">
                <tr>
                  <th class="px-3 py-2 font-semibold">When</th>
                  <th class="px-3 py-2 font-semibold">Query</th>
                  <th class="px-3 py-2 font-semibold">Channel</th>
                  <th class="px-3 py-2 font-semibold">Status</th>
                  <th class="px-3 py-2 font-semibold">Results</th>
                  <th class="px-3 py-2 font-semibold">Latency</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={message <- @analytics_snapshot.local_search.recent_messages} class="border-t border-border/70">
                  <td class="whitespace-nowrap px-3 py-2 text-muted-foreground">{format_datetime(message.inserted_at)}</td>
                  <td class="max-w-[420px] break-words px-3 py-2 text-foreground">{truncate(message.query)}</td>
                  <td class="whitespace-nowrap px-3 py-2 text-muted-foreground">{message.channel || "-"}</td>
                  <td class="whitespace-nowrap px-3 py-2">
                    <span class={search_status_class(message.status)}>{search_status_label(message.status)}</span>
                  </td>
                  <td class="px-3 py-2 text-muted-foreground">{message.results_count || 0}</td>
                  <td class="whitespace-nowrap px-3 py-2 text-muted-foreground">{format_latency(message.latency_ms)}</td>
                </tr>
                <tr :if={@analytics_snapshot.local_search.recent_messages == []}>
                  <td colspan="6" class="px-3 py-3 text-muted-foreground">No search messages collected yet.</td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>

        <section class="grid gap-6 lg:grid-cols-2">
          <article class="space-y-3 rounded-lg border border-border bg-card p-5">
            <h2 class="text-lg font-semibold text-foreground">Top demand topics</h2>
            <div class="flex flex-wrap gap-2">
              <span
                :for={row <- @analytics_snapshot.top_demand_topics}
                class="rounded-full border border-border bg-background px-3 py-1 text-xs text-foreground"
              >
                {truncate(row.query)} <span class="text-muted-foreground">({row.demand_count})</span>
              </span>
              <span :if={@analytics_snapshot.top_demand_topics == []} class="text-sm text-muted-foreground">
                No demand topics yet.
              </span>
            </div>
          </article>

          <article class="space-y-3 rounded-lg border border-border bg-card p-5">
            <h2 class="text-lg font-semibold text-foreground">Reformulation leaderboard</h2>
            <div class="flex flex-wrap gap-2">
              <span
                :for={row <- @analytics_snapshot.reformulations}
                class="rounded-full border border-border bg-background px-3 py-1 text-xs text-foreground"
              >
                {truncate(row.query)} <span class="text-muted-foreground">({row.count})</span>
              </span>
              <span :if={@analytics_snapshot.reformulations == []} class="text-sm text-muted-foreground">
                No reformulations detected.
              </span>
            </div>
          </article>
        </section>

        <section class="rounded-lg border border-border bg-card p-5">
          <h2 class="text-lg font-semibold text-foreground">High Demand, Low Success</h2>
          <div class="mt-3 overflow-x-auto rounded-md border border-border bg-background">
            <table class="min-w-full text-left text-xs">
              <thead class="bg-elevated text-muted-foreground">
                <tr>
                  <th class="px-3 py-2 font-semibold">Topic</th>
                  <th class="px-3 py-2 font-semibold">Demand</th>
                  <th class="px-3 py-2 font-semibold">Success</th>
                  <th class="px-3 py-2 font-semibold">Failures</th>
                  <th class="px-3 py-2 font-semibold">Failure rate</th>
                  <th class="px-3 py-2 font-semibold">Gap score</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={row <- @analytics_snapshot.content_gaps} class="border-t border-border/70">
                  <td class="max-w-[440px] break-words px-3 py-2 text-foreground">{row.query}</td>
                  <td class="px-3 py-2 text-muted-foreground">{row.demand_count}</td>
                  <td class="px-3 py-2 text-muted-foreground">{row.success_count}</td>
                  <td class="px-3 py-2 text-muted-foreground">{row.failure_count}</td>
                  <td class="px-3 py-2 text-muted-foreground">{percent(row.failure_rate)}</td>
                  <td class="px-3 py-2 text-foreground">{row.gap_score}</td>
                </tr>
                <tr :if={@analytics_snapshot.content_gaps == []}>
                  <td colspan="6" class="px-3 py-3 text-muted-foreground">No content gaps detected yet.</td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>

        <section class="grid gap-6 lg:grid-cols-2">
          <article class="rounded-lg border border-border bg-card p-5">
            <h2 class="text-lg font-semibold text-foreground">Feedback breakdown</h2>
            <div class="mt-3 overflow-x-auto rounded-md border border-border bg-background">
              <table class="min-w-full text-left text-xs">
                <thead class="bg-elevated text-muted-foreground">
                  <tr>
                    <th class="px-3 py-2 font-semibold">Surface</th>
                    <th class="px-3 py-2 font-semibold">Feedback</th>
                    <th class="px-3 py-2 font-semibold">Count</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={row <- @analytics_snapshot.feedback_breakdown} class="border-t border-border/70">
                    <td class="px-3 py-2 text-foreground">{row.surface}</td>
                    <td class="px-3 py-2 text-muted-foreground">{row.feedback_value}</td>
                    <td class="px-3 py-2 text-muted-foreground">{row.count}</td>
                  </tr>
                  <tr :if={@analytics_snapshot.feedback_breakdown == []}>
                    <td colspan="3" class="px-3 py-3 text-muted-foreground">No feedback submitted yet.</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </article>

          <article class="rounded-lg border border-border bg-card p-5">
            <h2 class="text-lg font-semibold text-foreground">Recent feedback (helpful + not helpful)</h2>
            <div class="mt-3 overflow-x-auto rounded-md border border-border bg-background">
              <table class="min-w-full text-left text-xs">
                <thead class="bg-elevated text-muted-foreground">
                  <tr>
                    <th class="px-3 py-2 font-semibold">When</th>
                    <th class="px-3 py-2 font-semibold">Surface</th>
                    <th class="px-3 py-2 font-semibold">Feedback</th>
                    <th class="px-3 py-2 font-semibold">Path</th>
                    <th class="px-3 py-2 font-semibold">Note</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={entry <- @analytics_snapshot.recent_feedback} class="border-t border-border/70">
                    <td class="whitespace-nowrap px-3 py-2 text-muted-foreground">{format_datetime(entry.inserted_at)}</td>
                    <td class="whitespace-nowrap px-3 py-2 text-foreground">{entry.surface || entry.source || "-"}</td>
                    <td class="whitespace-nowrap px-3 py-2">
                      <span class={feedback_badge_class(entry.feedback_value)}>{feedback_label(entry.feedback_value)}</span>
                    </td>
                    <td class="max-w-[180px] truncate px-3 py-2 text-muted-foreground" title={entry.path}>{entry.path}</td>
                    <td class="max-w-[320px] truncate px-3 py-2 text-foreground" title={entry.feedback_note || "(no note provided)"}>
                      {entry.feedback_note || "(no note provided)"}
                    </td>
                  </tr>
                  <tr :if={@analytics_snapshot.recent_feedback == []}>
                    <td colspan="5" class="px-3 py-3 text-muted-foreground">No feedback submitted yet.</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </article>
        </section>
      </div>
    </AgentJidoWeb.Jido.AdminNav.admin_shell>
    """
  end

  defp load_snapshot(socket) do
    snapshot =
      analytics_module().dashboard_snapshot(
        socket.assigns.current_scope,
        socket.assigns.analytics_days,
        top_limit: 12,
        gap_limit: 20,
        reform_limit: 12,
        feedback_limit: 50
      )

    assign(socket, :analytics_snapshot, snapshot)
  end

  defp parse_days(raw_days) do
    case Integer.parse(to_string(raw_days)) do
      {days, ""} when days in @allowed_days -> days
      _ -> @default_days
    end
  end

  defp empty_snapshot(days) do
    %{
      days: days,
      since: NaiveDateTime.utc_now(),
      unavailable?: false,
      authorized?: false,
      summary: %{
        total_queries: 0,
        failed_queries: 0,
        helpful_feedback: 0,
        not_helpful_feedback: 0
      },
      top_demand_topics: [],
      content_gaps: [],
      reformulations: [],
      feedback_breakdown: [],
      recent_feedback: [],
      recent_negative_feedback: [],
      home_conversion: [],
      first_livebook_open: [],
      local_search: %{
        summary: %{
          total_messages: 0,
          submitted_messages: 0,
          successful_messages: 0,
          no_result_messages: 0,
          failed_messages: 0
        },
        outcome_breakdown: [],
        channel_breakdown: [],
        recent_messages: []
      },
      ingestion: %{
        sources: [],
        recent_runs: []
      }
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

  defp truncate(query) when is_binary(query) do
    trimmed = String.trim(query)

    cond do
      trimmed == "" -> "(empty)"
      String.length(trimmed) > 72 -> String.slice(trimmed, 0, 69) <> "..."
      true -> trimmed
    end
  end

  defp truncate(_query), do: "(empty)"

  defp percent(rate) when is_number(rate) do
    "#{Float.round(rate * 100, 1)}%"
  end

  defp percent(_rate), do: "0.0%"

  defp configured_label(true), do: "Ready"
  defp configured_label(false), do: "Missing"
  defp configured_label(_value), do: "Missing"

  defp configured_badge_class(true) do
    "inline-flex rounded-full border border-accent-green/30 bg-accent-green/10 px-2 py-0.5 text-[11px] font-semibold text-accent-green"
  end

  defp configured_badge_class(_value) do
    "inline-flex rounded-full border border-accent-yellow/30 bg-accent-yellow/10 px-2 py-0.5 text-[11px] font-semibold text-accent-yellow"
  end

  defp run_status_label("completed"), do: "Completed"
  defp run_status_label("running"), do: "Running"
  defp run_status_label("failed"), do: "Failed"
  defp run_status_label(_status), do: "No runs"

  defp run_status_class("completed") do
    "inline-flex rounded-full border border-accent-green/30 bg-accent-green/10 px-2 py-0.5 text-[11px] font-semibold text-accent-green"
  end

  defp run_status_class("running") do
    "inline-flex rounded-full border border-accent-cyan/30 bg-accent-cyan/10 px-2 py-0.5 text-[11px] font-semibold text-accent-cyan"
  end

  defp run_status_class("failed") do
    "inline-flex rounded-full border border-accent-red/30 bg-accent-red/10 px-2 py-0.5 text-[11px] font-semibold text-accent-red"
  end

  defp run_status_class(_status) do
    "inline-flex rounded-full border border-border bg-background px-2 py-0.5 text-[11px] font-semibold text-muted-foreground"
  end

  defp search_status_label("success"), do: "Success"
  defp search_status_label("no_results"), do: "No results"
  defp search_status_label("error"), do: "Error"
  defp search_status_label("challenge"), do: "Challenge"
  defp search_status_label("submitted"), do: "Submitted"
  defp search_status_label(_status), do: "Unknown"

  defp search_status_class("success") do
    "inline-flex rounded-full bg-accent-green/15 px-2 py-0.5 text-[11px] font-semibold text-accent-green"
  end

  defp search_status_class("no_results") do
    "inline-flex rounded-full bg-accent-yellow/15 px-2 py-0.5 text-[11px] font-semibold text-accent-yellow"
  end

  defp search_status_class("error") do
    "inline-flex rounded-full bg-accent-red/15 px-2 py-0.5 text-[11px] font-semibold text-accent-red"
  end

  defp search_status_class("challenge") do
    "inline-flex rounded-full bg-accent-yellow/15 px-2 py-0.5 text-[11px] font-semibold text-accent-yellow"
  end

  defp search_status_class("submitted") do
    "inline-flex rounded-full bg-accent-cyan/15 px-2 py-0.5 text-[11px] font-semibold text-accent-cyan"
  end

  defp search_status_class(_status) do
    "inline-flex rounded-full bg-muted px-2 py-0.5 text-[11px] font-semibold text-muted-foreground"
  end

  defp format_latency(latency_ms) when is_integer(latency_ms), do: "#{latency_ms}ms"
  defp format_latency(_latency_ms), do: "-"

  defp feedback_label("helpful"), do: "Helpful"
  defp feedback_label("not_helpful"), do: "Not helpful"
  defp feedback_label(_value), do: "-"

  # Human-readable label for each instrumented home -> onboarding CTA path
  # (jido-e12-t21). Maps the section_id each CTA carries to the path name a
  # maintainer reads in the dashboard; an unknown section falls back to a
  # title-cased slug so a newly added CTA is never blank.
  defp home_conversion_label("hero"), do: "Hero CTA"
  defp home_conversion_label("start-with-one-agent"), do: "Start with one agent"
  defp home_conversion_label("quick-start"), do: "Quick start"
  defp home_conversion_label("agent-model"), do: "Agent model"
  defp home_conversion_label("build-first-agent"), do: "Build first agent"

  defp home_conversion_label(section_id) when is_binary(section_id) do
    section_id
    |> String.replace("-", " ")
    |> String.split(" ")
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp home_conversion_label(_section_id), do: "-"

  # Human-readable label for each Livebook activation surface (jido-e12-t22).
  # Maps the source a first-open event carries to the surface name a maintainer
  # reads in the dashboard; an unknown source falls back to a title-cased slug
  # so a newly instrumented surface is never blank.
  defp first_livebook_open_label("docs"), do: "Docs — Run in Livebook CTA"
  defp first_livebook_open_label("example"), do: "Example — companion notebook"

  defp first_livebook_open_label(source) when is_binary(source) do
    source
    |> String.replace("-", " ")
    |> String.split(" ")
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp first_livebook_open_label(_source), do: "-"

  defp feedback_badge_class("helpful") do
    "inline-flex rounded-full border border-accent-green/30 bg-accent-green/10 px-2 py-0.5 text-[11px] font-semibold text-accent-green"
  end

  defp feedback_badge_class("not_helpful") do
    "inline-flex rounded-full border border-accent-yellow/30 bg-accent-yellow/10 px-2 py-0.5 text-[11px] font-semibold text-accent-yellow"
  end

  defp feedback_badge_class(_value) do
    "inline-flex rounded-full border border-border bg-background px-2 py-0.5 text-[11px] font-semibold text-muted-foreground"
  end

  defp format_datetime(%NaiveDateTime{} = datetime), do: Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S")
  defp format_datetime(%DateTime{} = datetime), do: Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S")
  defp format_datetime(_datetime), do: "-"

  defp format_date(%Date{} = date), do: Date.to_iso8601(date)
  defp format_date(_date), do: "-"

  defp analytics_module do
    Application.get_env(:agent_jido, :analytics_module, Analytics)
  end
end
