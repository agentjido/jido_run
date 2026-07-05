defmodule AgentJidoWeb.ContentOpsGithubLive do
  @moduledoc """
  LiveView for viewing open GitHub issues and PRs.

  Provides:
  - List of open issues with "Solve with ContentOps" action
  - List of open PRs with "Merge to main" action
  - Manual refresh button (no auto-polling to avoid API rate limits)
  - ETS cache with configurable TTL
  - PubSub listener for webhook-driven cache invalidation

  ## Configuration

      config :agent_jido, AgentJidoWeb.ContentOpsGithubLive,
        owner: "agentjido",
        repo: "agentjido_xyz",
        cache_ttl_minutes: 15,
        contentops_timeout_ms: 60_000

  ## Webhook integration (future)

  When a GitHub webhook arrives, broadcast to invalidate the cache:

      Phoenix.PubSub.broadcast(AgentJido.PubSub, "contentops:github", :github_updated)
  """
  use AgentJidoWeb, :live_view

  alias AgentJido.ContentOps.OrchestratorAgent
  alias AgentJido.Github.Optional, as: GithubOptional

  @cache_table :contentops_github_cache
  @pubsub_topic "contentops:github"

  defp config(key) do
    defaults = %{
      owner: "agentjido",
      repo: "agentjido_xyz",
      cache_ttl_minutes: 15,
      contentops_timeout_ms: 60_000,
      github_mutations_enabled: false
    }

    app_config = Application.get_env(:agent_jido, __MODULE__, [])
    Keyword.get(app_config, key) || Map.fetch!(defaults, key)
  end

  @impl true
  def mount(_params, _session, socket) do
    token = System.get_env("GITHUB_TOKEN")
    ensure_cache_table()

    if connected?(socket) do
      Phoenix.PubSub.subscribe(AgentJido.PubSub, @pubsub_topic)
    end

    owner = config(:owner)
    repo = config(:repo)

    socket =
      socket
      |> assign(:owner, owner)
      |> assign(:repo, repo)
      |> assign(:github_mutations_enabled, config(:github_mutations_enabled) == true)
      |> assign(:token, token)
      |> assign(:issues, nil)
      |> assign(:prs, nil)
      |> assign(:loading, true)
      |> assign(:error, nil)
      |> assign(:issues_task_ref, nil)
      |> assign(:prs_task_ref, nil)
      |> assign(:merge_task_ref, nil)
      |> assign(:solve_task_ref, nil)
      |> assign(:cached_at, nil)

    socket =
      if connected?(socket) and token do
        load_from_cache_or_fetch(socket)
      else
        if is_nil(token) do
          socket
          |> assign(:loading, false)
          |> assign(:error, "GITHUB_TOKEN environment variable is not set.")
        else
          socket
        end
      end

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <AgentJidoWeb.Jido.AdminNav.admin_shell current_path="/dashboard/contentops/github">
      <div class="container max-w-5xl mx-auto px-6 py-12 space-y-6">
        <%!-- Nav strip --%>
        <div class="flex items-center gap-3 text-sm">
          <.link navigate="/dashboard/contentops" class="text-primary hover:text-primary/80 transition-colors">
            ← Dashboard
          </.link>
        </div>

        <%!-- Header --%>
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-2xl font-bold text-foreground">GitHub Issues & PRs</h1>
            <p class="text-sm text-muted-foreground mt-1">
              {@owner}/{@repo} — open issues and pull requests
            </p>
          </div>
          <div class="flex items-center gap-3">
            <span :if={@cached_at} class="text-[10px] text-muted-foreground font-mono">
              cached {format_time_ago(@cached_at)}
            </span>
            <button
              phx-click="refresh"
              disabled={@loading}
              class="text-sm text-primary hover:text-primary/80 transition-colors disabled:opacity-50"
            >
              ↻ Refresh
            </button>
          </div>
        </div>

        <%!-- Error --%>
        <div :if={@error} class="rounded-lg border border-accent-red/30 bg-accent-red/10 p-4">
          <p class="text-sm text-accent-red font-mono">⚠ {@error}</p>
        </div>

        <%!-- Loading --%>
        <div :if={@loading} class="rounded-lg border border-border bg-card p-8 text-center">
          <p class="text-sm text-muted-foreground animate-pulse">Loading GitHub data…</p>
        </div>

        <%!-- Issues --%>
        <.issues_card :if={@issues} issues={@issues} />

        <%!-- PRs --%>
        <.prs_card :if={@prs} prs={@prs} />
      </div>
    </AgentJidoWeb.Jido.AdminNav.admin_shell>
    """
  end

  # ── Issues Card ────────────────────────────────────────────────────

  defp issues_card(assigns) do
    ~H"""
    <div class="rounded-lg border border-border bg-card p-6">
      <h2 class="text-sm font-semibold text-foreground mb-4">
        Open Issues ({length(@issues)})
      </h2>

      <div :if={@issues == []} class="text-sm text-muted-foreground italic">
        No open issues.
      </div>

      <div class="space-y-3">
        <div
          :for={issue <- @issues}
          class="rounded-md border border-border bg-elevated p-4 flex items-start justify-between gap-4"
        >
          <div class="min-w-0 flex-1">
            <div class="flex items-center gap-2 flex-wrap">
              <span class="text-xs font-mono text-muted-foreground shrink-0">
                #{issue["number"]}
              </span>
              <span class="text-sm font-medium text-foreground truncate">
                {issue["title"]}
              </span>
            </div>
            <div class="flex items-center gap-3 mt-1.5 flex-wrap">
              <span
                :for={label <- issue["labels"] || []}
                class="text-[10px] px-1.5 py-0.5 rounded font-semibold"
                style={"background-color: ##{label["color"]}20; color: ##{label["color"]};"}
              >
                {label["name"]}
              </span>
              <span class="text-[10px] text-muted-foreground">
                opened {format_date(issue["created_at"])} by {get_in(issue, ["user", "login"]) || "unknown"}
              </span>
            </div>
          </div>
          <button
            phx-click="solve_issue"
            phx-value-number={issue["number"]}
            phx-value-title={issue["title"]}
            disabled={not @github_mutations_enabled}
            class="shrink-0 text-xs px-3 py-1.5 rounded-md border border-border bg-card text-foreground hover:bg-elevated transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          >
            🤖 Solve with ContentOps
          </button>
        </div>
      </div>
    </div>
    """
  end

  # ── PRs Card ───────────────────────────────────────────────────────

  defp prs_card(assigns) do
    ~H"""
    <div class="rounded-lg border border-border bg-card p-6">
      <h2 class="text-sm font-semibold text-foreground mb-4">
        Open Pull Requests ({length(@prs)})
      </h2>

      <div :if={@prs == []} class="text-sm text-muted-foreground italic">
        No open pull requests.
      </div>

      <div class="space-y-3">
        <div
          :for={pr <- @prs}
          class="rounded-md border border-border bg-elevated p-4 flex items-start justify-between gap-4"
        >
          <div class="min-w-0 flex-1">
            <div class="flex items-center gap-2 flex-wrap">
              <span class="text-xs font-mono text-muted-foreground shrink-0">
                #{pr["number"]}
              </span>
              <span class="text-sm font-medium text-foreground truncate">
                {pr["title"]}
              </span>
            </div>
            <div class="flex items-center gap-3 mt-1.5 flex-wrap">
              <span class="text-[10px] font-mono text-muted-foreground">
                {get_in(pr, ["head", "ref"])} → {get_in(pr, ["base", "ref"])}
              </span>
              <span class="text-[10px] text-muted-foreground">
                by {get_in(pr, ["user", "login"]) || "unknown"}
              </span>
              <.mergeable_badge mergeable={pr["mergeable"]} />
            </div>
          </div>
          <button
            phx-click="merge_pr"
            phx-value-number={pr["number"]}
            phx-value-title={pr["title"]}
            disabled={not @github_mutations_enabled}
            class="shrink-0 text-xs px-3 py-1.5 rounded-md border border-accent-green/30 bg-accent-green/10 text-accent-green hover:bg-accent-green/20 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          >
            Merge to main
          </button>
        </div>
      </div>
    </div>
    """
  end

  defp mergeable_badge(assigns) do
    ~H"""
    <span
      :if={@mergeable == true}
      class="text-[10px] px-1.5 py-0.5 rounded bg-accent-green/10 text-accent-green font-semibold"
    >
      mergeable
    </span>
    <span
      :if={@mergeable == false}
      class="text-[10px] px-1.5 py-0.5 rounded bg-accent-red/10 text-accent-red font-semibold"
    >
      conflicts
    </span>
    <span
      :if={is_nil(@mergeable)}
      class="text-[10px] px-1.5 py-0.5 rounded bg-accent-yellow/10 text-accent-yellow font-semibold"
    >
      unknown
    </span>
    """
  end

  # ── Events ─────────────────────────────────────────────────────────

  @impl true
  def handle_event("refresh", _params, socket) do
    invalidate_cache()

    socket =
      socket
      |> assign(:loading, true)
      |> assign(:error, nil)
      |> fetch_data()

    {:noreply, socket}
  end

  def handle_event("merge_pr", %{"number" => number_str, "title" => title}, socket) do
    if socket.assigns.github_mutations_enabled do
      {:noreply, start_merge_task(socket, number_str, title)}
    else
      {:noreply, put_flash(socket, :error, "GitHub mutations are disabled for this environment.")}
    end
  end

  def handle_event("solve_issue", %{"number" => number_str, "title" => title}, socket) do
    if socket.assigns.github_mutations_enabled do
      timeout = config(:contentops_timeout_ms)

      task =
        Task.async(fn ->
          OrchestratorAgent.run(mode: :weekly, timeout: timeout)
        end)

      socket =
        socket
        |> assign(:solve_task_ref, {task.ref, String.to_integer(number_str), title})
        |> put_flash(:info, "🤖 ContentOps triggered for issue ##{number_str}: #{title}")

      {:noreply, socket}
    else
      {:noreply, put_flash(socket, :error, "GitHub mutations are disabled for this environment.")}
    end
  end

  defp start_merge_task(socket, number_str, title) do
    number = String.to_integer(number_str)

    task =
      Task.async(fn ->
        merge_pull_request(socket.assigns.token, socket.assigns.owner, socket.assigns.repo, number)
      end)

    socket
    |> assign(:merge_task_ref, {task.ref, number, title})
    |> put_flash(:info, "Merging PR ##{number}…")
  end

  defp merge_pull_request(token, owner, repo, number) do
    with {:ok, client} <- GithubOptional.build_client(token) do
      GithubOptional.pulls_merge(client, owner, repo, number, %{})
    end
  end

  # ── Info handlers ──────────────────────────────────────────────────

  @impl true
  def handle_info({ref, {:issues, result}}, socket) when ref == socket.assigns.issues_task_ref do
    Process.demonitor(ref, [:flush])

    socket = assign(socket, :issues_task_ref, nil)

    socket =
      case result do
        {200, issues, _} ->
          filtered = Enum.reject(issues, &Map.has_key?(&1, "pull_request"))
          write_cache(:issues, filtered)
          assign(socket, :issues, filtered)

        {status, body, _} ->
          assign(socket, :error, "Failed to fetch issues: HTTP #{status} — #{inspect(body)}")

        error ->
          assign(socket, :error, "Failed to fetch issues: #{inspect(error)}")
      end

    socket = maybe_done_loading(socket)
    {:noreply, socket}
  end

  def handle_info({ref, {:prs, result}}, socket) when ref == socket.assigns.prs_task_ref do
    Process.demonitor(ref, [:flush])

    socket = assign(socket, :prs_task_ref, nil)

    socket =
      case result do
        {200, prs, _} ->
          write_cache(:prs, prs)
          assign(socket, :prs, prs)

        {status, body, _} ->
          assign(socket, :error, "Failed to fetch PRs: HTTP #{status} — #{inspect(body)}")

        error ->
          assign(socket, :error, "Failed to fetch PRs: #{inspect(error)}")
      end

    socket = maybe_done_loading(socket)
    {:noreply, socket}
  end

  def handle_info({ref, result}, socket) when is_reference(ref) do
    case socket.assigns.merge_task_ref do
      {^ref, number, title} ->
        Process.demonitor(ref, [:flush])
        {:noreply, handle_merge_result(assign(socket, :merge_task_ref, nil), result, number, title)}

      _ ->
        {:noreply, handle_solve_result(socket, ref, result)}
    end
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, socket) when is_reference(ref) do
    socket =
      cond do
        match?({^ref, _, _}, socket.assigns.merge_task_ref) ->
          socket
          |> assign(:merge_task_ref, nil)
          |> put_flash(:error, "Merge task crashed: #{inspect(reason)}")

        match?({^ref, _, _}, socket.assigns.solve_task_ref) ->
          socket
          |> assign(:solve_task_ref, nil)
          |> put_flash(:error, "ContentOps task crashed: #{inspect(reason)}")

        ref == socket.assigns.issues_task_ref ->
          socket
          |> assign(:issues_task_ref, nil)
          |> assign(:error, "Failed to fetch issues: task crashed")
          |> maybe_done_loading()

        ref == socket.assigns.prs_task_ref ->
          socket
          |> assign(:prs_task_ref, nil)
          |> assign(:error, "Failed to fetch PRs: task crashed")
          |> maybe_done_loading()

        true ->
          socket
      end

    {:noreply, socket}
  end

  # Webhook-driven cache invalidation via PubSub
  def handle_info(:github_updated, socket) do
    invalidate_cache()

    if socket.assigns.token do
      {:noreply,
       socket
       |> assign(:loading, true)
       |> assign(:error, nil)
       |> fetch_data()}
    else
      {:noreply, socket}
    end
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  # ── Private helpers ────────────────────────────────────────────────

  defp handle_merge_result(socket, {200, %{"merged" => true}, _}, number, title) do
    invalidate_cache()

    socket
    |> put_flash(:info, "✓ PR ##{number} (#{title}) merged successfully!")
    |> assign(:loading, true)
    |> fetch_data()
  end

  defp handle_merge_result(socket, {status, body, _}, number, _title) do
    put_flash(socket, :error, "Failed to merge PR ##{number}: HTTP #{status} — #{inspect(body)}")
  end

  defp handle_merge_result(socket, error, number, _title) do
    put_flash(socket, :error, "Failed to merge PR ##{number}: #{inspect(error)}")
  end

  defp handle_solve_result(socket, ref, result) do
    case socket.assigns.solve_task_ref do
      {^ref, number, _title} ->
        Process.demonitor(ref, [:flush])
        socket = assign(socket, :solve_task_ref, nil)
        solve_flash(socket, result, number)

      _other ->
        socket
    end
  end

  defp solve_flash(socket, %{status: :completed}, number) do
    put_flash(socket, :info, "✓ ContentOps completed for issue ##{number}!")
  end

  defp solve_flash(socket, _result, number) do
    put_flash(socket, :info, "ContentOps run finished for issue ##{number}.")
  end

  defp fetch_data(socket) do
    token = socket.assigns.token
    owner = socket.assigns.owner
    repo = socket.assigns.repo

    issues_task =
      Task.async(fn ->
        result =
          with {:ok, client} <- GithubOptional.build_client(token) do
            GithubOptional.issues_filter(client, owner, repo, %{state: "open"})
          end

        {:issues, result}
      end)

    prs_task =
      Task.async(fn ->
        result =
          with {:ok, client} <- GithubOptional.build_client(token) do
            GithubOptional.pulls_filter(client, owner, repo, %{state: "open"})
          end

        {:prs, result}
      end)

    socket
    |> assign(:issues_task_ref, issues_task.ref)
    |> assign(:prs_task_ref, prs_task.ref)
  end

  defp maybe_done_loading(socket) do
    if is_nil(socket.assigns.issues_task_ref) and is_nil(socket.assigns.prs_task_ref) do
      socket
      |> assign(:loading, false)
      |> assign(:cached_at, DateTime.utc_now())
    else
      socket
    end
  end

  defp format_date(nil), do: "—"

  defp format_date(date_string) when is_binary(date_string) do
    case DateTime.from_iso8601(date_string) do
      {:ok, dt, _offset} -> Calendar.strftime(dt, "%Y-%m-%d")
      _ -> date_string
    end
  end

  defp format_date(_), do: "—"

  defp format_time_ago(%DateTime{} = dt) do
    diff = DateTime.diff(DateTime.utc_now(), dt, :second)

    cond do
      diff < 5 -> "just now"
      diff < 60 -> "#{diff}s ago"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      true -> "#{div(diff, 3600)}h ago"
    end
  end

  defp format_time_ago(_), do: ""

  # ── Cache ──────────────────────────────────────────────────────────

  defp cache_ttl_ms, do: :timer.minutes(config(:cache_ttl_minutes))

  defp ensure_cache_table do
    if :ets.whereis(@cache_table) == :undefined do
      :ets.new(@cache_table, [:set, :public, :named_table])
    end
  end

  defp load_from_cache_or_fetch(socket) do
    now = System.monotonic_time(:millisecond)
    ttl = cache_ttl_ms()

    cached_issues = read_cache(:issues, now, ttl)
    cached_prs = read_cache(:prs, now, ttl)

    if cached_issues && cached_prs do
      {_key, issues, cached_at_dt, _ts} = cached_issues
      {_key, prs, _cached_at_dt, _ts} = cached_prs

      socket
      |> assign(:issues, issues)
      |> assign(:prs, prs)
      |> assign(:loading, false)
      |> assign(:cached_at, cached_at_dt)
    else
      fetch_data(socket)
    end
  end

  defp read_cache(key, now, ttl) do
    case :ets.lookup(@cache_table, key) do
      [{^key, _data, _dt, ts}] = [entry] when now - ts < ttl -> entry
      _ -> nil
    end
  end

  defp write_cache(key, data) do
    :ets.insert(@cache_table, {key, data, DateTime.utc_now(), System.monotonic_time(:millisecond)})
  end

  defp invalidate_cache do
    if :ets.whereis(@cache_table) != :undefined do
      :ets.delete_all_objects(@cache_table)
    end
  end
end
