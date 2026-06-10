defmodule AgentJidoWeb.AdminContentIngestionLive do
  @moduledoc """
  Unified admin status page for content ingestion health and recovery actions.
  """
  use AgentJidoWeb, :live_view

  alias AgentJido.ContentIngest
  alias AgentJido.ContentIngest.EcosystemDocs
  alias AgentJido.ContentIngest.Inventory

  @task_supervisor_key :content_ingest_task_supervisor
  @task_ref_key :content_ingest_task_ref
  @running_key :content_ingest_running
  @ecosystem_docs_poll_default_ms 1_000

  @issue_order [
    :missing,
    :orphaned,
    :collection_mismatch,
    :stale_hash,
    :duplicate_source_id,
    :errored_or_unchunked
  ]

  @status_order [:ok | @issue_order]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(@running_key, false)
     |> assign(@task_ref_key, nil)
     |> assign(@task_supervisor_key, nil)
     |> assign(:current_run_label, nil)
     |> assign(:last_ingest_summary, nil)
     |> assign(:last_ingest_label, nil)
     |> assign(:audit_rows, [])
     |> assign(:audit_summary, empty_audit_summary())
     |> assign(:source_lookup, %{})
     |> assign(:collection_counts, %{})
     |> assign(:needs_refresh_count, 0)
     |> assign(:orphaned_count, 0)
     |> assign(:ecosystem_docs_status, empty_ecosystem_docs_status())
     |> assign(:ecosystem_docs_snapshot, empty_ecosystem_docs_snapshot())
     |> load_status()
     |> maybe_schedule_ecosystem_docs_refresh()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <AgentJidoWeb.Jido.AdminNav.admin_shell current_path="/dashboard/content-ingestion">
      <div class="container mx-auto max-w-7xl space-y-8 px-6 py-12">
        <header class="space-y-2">
          <p class="text-xs font-semibold uppercase tracking-[0.2em] text-primary">Admin Control Plane</p>
          <h1 class="text-3xl font-semibold text-foreground">Content Ingestion Status</h1>
          <p class="max-w-4xl text-sm text-muted-foreground">
            Shows what is ingested, what is out of date, and lets you trigger targeted or full refresh.
          </p>
        </header>

        <section class="space-y-4 rounded-lg border border-border bg-card p-6">
          <div class="flex flex-wrap items-start justify-between gap-3">
            <div class="space-y-1">
              <h2 class="text-lg font-semibold text-foreground">Current state</h2>
              <p class="text-sm text-muted-foreground">
                Out-of-date rows are missing/stale/unhealthy compared to expected local inventory.
              </p>
            </div>

            <div :if={@content_ingest_running} class="text-xs font-semibold uppercase tracking-wide text-accent-yellow">
              {@current_run_label || "Ingestion running"}…
            </div>
          </div>

          <div class="grid grid-cols-2 gap-2 text-xs text-muted-foreground md:grid-cols-5">
            <span>expected: {@audit_summary.expected_count}</span>
            <span>ingested: {@audit_summary.ingested_count}</span>
            <span>ok: {@audit_summary.ok_count}</span>
            <span>out_of_date: {@audit_summary.blocking_count}</span>
            <span>refreshable: {@needs_refresh_count}</span>
          </div>

          <div class="grid grid-cols-2 gap-2 text-xs text-muted-foreground md:grid-cols-4">
            <span>docs: {Map.get(@collection_counts, "site_docs", 0)}</span>
            <span>blog: {Map.get(@collection_counts, "site_blog", 0)}</span>
            <span>ecosystem: {Map.get(@collection_counts, "site_ecosystem", 0)}</span>
            <span>orphaned: {@orphaned_count}</span>
          </div>

          <div class="flex flex-wrap items-center gap-3">
            <button
              type="button"
              phx-click="refresh_status"
              disabled={@content_ingest_running}
              class="rounded-md border border-border bg-background px-3 py-2 text-xs font-semibold text-foreground hover:border-primary/50 disabled:cursor-not-allowed disabled:opacity-50"
            >
              Refresh status
            </button>

            <button
              type="button"
              phx-click="ingest_needs_refresh"
              disabled={@content_ingest_running or @needs_refresh_count == 0}
              class="rounded-md border border-border bg-background px-3 py-2 text-xs font-semibold text-foreground hover:border-primary/50 disabled:cursor-not-allowed disabled:opacity-50"
            >
              Ingest needs refresh
            </button>

            <button
              type="button"
              phx-click="ingest_all"
              disabled={@content_ingest_running}
              class="rounded-md bg-primary px-3 py-2 text-xs font-semibold text-primary-foreground hover:bg-primary/90 disabled:cursor-not-allowed disabled:opacity-50"
            >
              Ingest all
            </button>
          </div>

          <p :if={@orphaned_count > 0} class="text-xs font-semibold text-accent-yellow">
            Orphaned rows found. Run "Ingest all" to reconcile stale managed documents.
          </p>

          <section :if={@last_ingest_summary} class="space-y-2 rounded-md border border-border bg-background p-4">
            <h3 class="text-sm font-semibold text-foreground">Last run: {@last_ingest_label}</h3>
            <div class="grid grid-cols-2 gap-2 text-xs text-muted-foreground md:grid-cols-6">
              <span>sources: {@last_ingest_summary.total_sources}</span>
              <span>inserted: {@last_ingest_summary.inserted}</span>
              <span>updated: {@last_ingest_summary.updated}</span>
              <span>deleted: {@last_ingest_summary.deleted}</span>
              <span>skipped: {@last_ingest_summary.skipped}</span>
              <span>failed: {@last_ingest_summary.failed_count}</span>
            </div>
            <p class={summary_status_class(@last_ingest_summary)}>
              {summary_status_text(@last_ingest_summary)}
            </p>
          </section>
        </section>

        <section class="space-y-4 rounded-lg border border-border bg-card p-6">
          <div class="flex flex-wrap items-start justify-between gap-3">
            <div class="space-y-1">
              <h2 class="text-lg font-semibold text-foreground">Package docs crawl</h2>
              <p class="text-sm text-muted-foreground">
                Background-managed HexDocs ingestion for published ecosystem packages.
              </p>
            </div>

            <div class="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
              {if @ecosystem_docs_status.running, do: "Running", else: "Idle"}
            </div>
          </div>

          <div class="grid grid-cols-2 gap-2 text-xs text-muted-foreground md:grid-cols-5">
            <span>documents: {@ecosystem_docs_snapshot.total_documents}</span>
            <span>crawled packages: {@ecosystem_docs_snapshot.package_count}</span>
            <span>eligible: {ecosystem_docs_summary_value(@ecosystem_docs_status.last_summary, :eligible_packages)}</span>
            <span>skipped unpublished: {ecosystem_docs_summary_value(@ecosystem_docs_status.last_summary, :skipped_unpublished_count)}</span>
            <span>pages: {ecosystem_docs_summary_value(@ecosystem_docs_status.last_summary, :total_sources)}</span>
          </div>

          <div class="grid grid-cols-2 gap-2 text-xs text-muted-foreground md:grid-cols-3">
            <span>last crawled: {format_datetime(@ecosystem_docs_snapshot.latest_crawled_at)}</span>
            <span>last started: {format_datetime(@ecosystem_docs_status.last_started_at)}</span>
            <span>last finished: {format_datetime(@ecosystem_docs_status.last_finished_at)}</span>
          </div>

          <div class="flex flex-wrap items-center gap-3">
            <button
              type="button"
              phx-click="sync_ecosystem_docs"
              disabled={@ecosystem_docs_status.running}
              class="rounded-md bg-primary px-3 py-2 text-xs font-semibold text-primary-foreground hover:bg-primary/90 disabled:cursor-not-allowed disabled:opacity-50"
            >
              Sync package docs now
            </button>
          </div>

          <section :if={@ecosystem_docs_status.last_summary} class="space-y-2 rounded-md border border-border bg-background p-4">
            <h3 class="text-sm font-semibold text-foreground">Last package docs run</h3>
            <div class="grid grid-cols-2 gap-2 text-xs text-muted-foreground md:grid-cols-6">
              <span>inserted: {ecosystem_docs_summary_value(@ecosystem_docs_status.last_summary, :inserted)}</span>
              <span>updated: {ecosystem_docs_summary_value(@ecosystem_docs_status.last_summary, :updated)}</span>
              <span>deleted: {ecosystem_docs_summary_value(@ecosystem_docs_status.last_summary, :deleted)}</span>
              <span>skipped: {ecosystem_docs_summary_value(@ecosystem_docs_status.last_summary, :skipped)}</span>
              <span>failed: {ecosystem_docs_summary_value(@ecosystem_docs_status.last_summary, :failed_count)}</span>
              <span>mode: {Map.get(@ecosystem_docs_status.last_summary, :mode, :apply)}</span>
            </div>

            <div :if={ecosystem_docs_failures(@ecosystem_docs_status.last_summary) != []} class="space-y-1">
              <p class="text-xs font-semibold uppercase tracking-wide text-accent-yellow">Failed packages</p>
              <div class="space-y-1 text-xs text-muted-foreground">
                <p :for={failure <- ecosystem_docs_failures(@ecosystem_docs_status.last_summary)}>
                  {failure.package_id}: {failure.reason}
                </p>
              </div>
            </div>
          </section>
        </section>

        <section class="space-y-4 rounded-lg border border-border bg-card p-6">
          <div class="space-y-1">
            <h2 class="text-lg font-semibold text-foreground">Source status</h2>
            <p class="text-sm text-muted-foreground">
              One row per source id. Re-ingest is available when source still exists in local inventory.
            </p>
          </div>

          <div class="overflow-x-auto rounded-md border border-border bg-background">
            <table class="w-full table-fixed text-left text-[11px] leading-5">
              <thead class="bg-elevated text-muted-foreground">
                <tr>
                  <th class="w-[10%] px-2 py-1.5 font-semibold">Action</th>
                  <th class="w-[10%] px-2 py-1.5 font-semibold">Status</th>
                  <th class="w-[11%] px-2 py-1.5 font-semibold">Collection</th>
                  <th class="w-[17%] px-2 py-1.5 font-semibold">Title</th>
                  <th class="w-[17%] px-2 py-1.5 font-semibold">Path</th>
                  <th class="w-[18%] px-2 py-1.5 font-semibold">Source ID</th>
                  <th class="w-[17%] px-2 py-1.5 font-semibold">Details</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={row <- @audit_rows} class="border-t border-border/70 align-top">
                  <td class="px-2 py-1.5">
                    <button
                      :if={row.refreshable?}
                      type="button"
                      phx-click="ingest_source"
                      phx-value-source-id={row.source_id}
                      disabled={@content_ingest_running}
                      class="whitespace-nowrap rounded-md border border-border bg-background px-2 py-0.5 text-[11px] font-semibold text-foreground hover:border-primary/50 disabled:cursor-not-allowed disabled:opacity-50"
                    >
                      Re-ingest
                    </button>
                    <span :if={!row.refreshable?} class="text-muted-foreground">—</span>
                  </td>
                  <td class="px-2 py-1.5">
                    <span class={status_badge_class(row.status)}>{status_label(row.status)}</span>
                  </td>
                  <td class="px-2 py-1.5 text-muted-foreground">{row.collection}</td>
                  <td class="truncate px-2 py-1.5 text-foreground" title={row.title}>{row.title}</td>
                  <td class="truncate px-2 py-1.5 text-muted-foreground" title={row.path}>{row.path}</td>
                  <td class="truncate px-2 py-1.5 font-mono text-muted-foreground" title={row.source_id}>
                    {row.source_id}
                  </td>
                  <td class="px-2 py-1.5 text-muted-foreground">{row.details}</td>
                </tr>
                <tr :if={@audit_rows == []}>
                  <td colspan="7" class="px-2 py-2 text-muted-foreground">
                    No content sources found.
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>
      </div>
    </AgentJidoWeb.Jido.AdminNav.admin_shell>
    """
  end

  @impl true
  def handle_event("refresh_status", _params, socket) do
    {:noreply, load_status(socket)}
  end

  def handle_event("ingest_all", _params, socket) do
    trigger_ingest(socket, :ingest_all, nil)
  end

  def handle_event("ingest_needs_refresh", _params, socket) do
    trigger_ingest(socket, :ingest_needs_refresh, nil)
  end

  def handle_event("ingest_source", %{"source-id" => source_id}, socket) do
    trigger_ingest(socket, :ingest_source, source_id)
  end

  def handle_event("sync_ecosystem_docs", _params, socket) do
    case ecosystem_docs_module().sync() do
      :ok ->
        Process.send_after(self(), :refresh_ecosystem_docs_status, ecosystem_docs_poll_interval_ms())
        {:noreply, put_flash(socket, :info, "Package docs crawl started.")}

      {:error, :already_running} ->
        {:noreply, put_flash(socket, :error, "Package docs crawl is already running.")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Could not start package docs crawl: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_info({ref, {:ok, mode, source_id, summary}}, socket) do
    if ref == socket.assigns[@task_ref_key] do
      Process.demonitor(ref, [:flush])
      normalized = normalize_summary(summary)

      socket =
        socket
        |> assign(@running_key, false)
        |> assign(@task_ref_key, nil)
        |> assign(:current_run_label, nil)
        |> assign(:last_ingest_summary, normalized)
        |> assign(:last_ingest_label, run_label(mode, source_id))
        |> load_status()

      flash_type = if normalized.failed_count > 0, do: :error, else: :info
      {:noreply, put_flash(socket, flash_type, run_complete_text(mode, source_id))}
    else
      {:noreply, socket}
    end
  end

  def handle_info({ref, {:error, mode, source_id, reason}}, socket) do
    if ref == socket.assigns[@task_ref_key] do
      Process.demonitor(ref, [:flush])

      {:noreply,
       socket
       |> assign(@running_key, false)
       |> assign(@task_ref_key, nil)
       |> assign(:current_run_label, nil)
       |> put_flash(:error, "#{run_label(mode, source_id)} failed: #{reason}")}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, socket) do
    if ref == socket.assigns[@task_ref_key] do
      {:noreply,
       socket
       |> assign(@running_key, false)
       |> assign(@task_ref_key, nil)
       |> assign(:current_run_label, nil)
       |> put_flash(:error, "Ingestion task crashed: #{inspect(reason)}")}
    else
      {:noreply, socket}
    end
  end

  def handle_info(:refresh_ecosystem_docs_status, socket) do
    socket =
      socket
      |> load_ecosystem_docs_status()
      |> maybe_schedule_ecosystem_docs_refresh()

    {:noreply, socket}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  defp trigger_ingest(socket, mode, source_id) do
    if socket.assigns[@running_key] do
      {:noreply, put_flash(socket, :error, "An ingestion task is already running.")}
    else
      with {:ok, socket} <- ensure_task_supervisor(socket),
           {:ok, opts} <- ingest_opts(mode, source_id, socket),
           {:ok, ref} <- start_ingest_task(socket, mode, source_id, opts) do
        {:noreply,
         socket
         |> assign(@running_key, true)
         |> assign(@task_ref_key, ref)
         |> assign(:current_run_label, run_label(mode, source_id))
         |> put_flash(:info, "#{run_label(mode, source_id)} started.")}
      else
        {:error, reason} ->
          {:noreply, put_flash(socket, :error, reason)}
      end
    end
  end

  defp ensure_task_supervisor(socket) do
    case socket.assigns[@task_supervisor_key] do
      pid when is_pid(pid) ->
        if Process.alive?(pid), do: {:ok, socket}, else: start_task_supervisor(socket)

      _other ->
        start_task_supervisor(socket)
    end
  end

  defp start_task_supervisor(socket) do
    case Task.Supervisor.start_link() do
      {:ok, pid} -> {:ok, assign(socket, @task_supervisor_key, pid)}
      {:error, reason} -> {:error, "Could not start ingestion task supervisor: #{inspect(reason)}"}
    end
  end

  defp start_ingest_task(socket, mode, source_id, opts) do
    supervisor = socket.assigns[@task_supervisor_key]
    ingest_module = ingest_module()

    task =
      Task.Supervisor.async_nolink(supervisor, fn ->
        try do
          {:ok, mode, source_id, ingest_module.sync(opts)}
        rescue
          error -> {:error, mode, source_id, Exception.message(error)}
        catch
          kind, reason -> {:error, mode, source_id, "#{kind}: #{inspect(reason)}"}
        end
      end)

    {:ok, task.ref}
  rescue
    error ->
      {:error, "Failed to start ingestion task: #{Exception.message(error)}"}
  end

  defp ingest_opts(:ingest_all, _source_id, _socket), do: {:ok, [dry_run: false]}

  defp ingest_opts(:ingest_needs_refresh, _source_id, socket) do
    source_lookup = socket.assigns.source_lookup

    source_ids =
      socket.assigns.audit_rows
      |> Enum.filter(&(&1.status != :ok and &1.refreshable?))
      |> Enum.map(& &1.source_id)
      |> Enum.uniq()

    sources =
      source_ids
      |> Enum.map(&Map.get(source_lookup, &1))
      |> Enum.filter(&is_map/1)

    if sources == [] do
      {:error, "No out-of-date rows are directly refreshable."}
    else
      {:ok,
       [
         dry_run: false,
         reconcile_stale: false,
         sources: sources,
         managed_collections: sources |> Enum.map(& &1.collection) |> Enum.uniq()
       ]}
    end
  end

  defp ingest_opts(:ingest_source, source_id, socket) do
    case Map.get(socket.assigns.source_lookup, source_id) do
      nil ->
        {:error, "Could not find source #{source_id} in current inventory."}

      source ->
        {:ok,
         [
           dry_run: false,
           reconcile_stale: false,
           sources: [source],
           managed_collections: [source.collection]
         ]}
    end
  end

  defp ingest_opts(_mode, _source_id, _socket), do: {:error, "Unsupported ingestion action."}

  defp run_label(:ingest_all, _source_id), do: "Ingest all sources"
  defp run_label(:ingest_needs_refresh, _source_id), do: "Ingest needs refresh"
  defp run_label(:ingest_source, source_id), do: "Re-ingest #{source_id}"
  defp run_label(_mode, _source_id), do: "Ingestion run"

  defp run_complete_text(:ingest_all, _source_id), do: "Ingest all completed."
  defp run_complete_text(:ingest_needs_refresh, _source_id), do: "Ingest needs refresh completed."
  defp run_complete_text(:ingest_source, source_id), do: "Re-ingest completed for #{source_id}."
  defp run_complete_text(_mode, _source_id), do: "Ingestion completed."

  defp load_status(socket) do
    socket
    |> load_local_status()
    |> load_ecosystem_docs_status()
  end

  defp load_local_status(socket) do
    sources =
      Inventory.build()
      |> Enum.sort_by(&{&1.collection, &1.source_id})

    source_lookup = Enum.into(sources, %{}, &{&1.source_id, &1})
    collection_counts = Enum.frequencies_by(sources, & &1.collection)

    audit_report = audit_module().audit(sources: sources)
    audit_rows = build_audit_rows(Map.get(audit_report, :rows, []), source_lookup)

    socket
    |> assign(:source_lookup, source_lookup)
    |> assign(:collection_counts, collection_counts)
    |> assign(:audit_rows, audit_rows)
    |> assign(:audit_summary, normalize_audit_summary(Map.get(audit_report, :summary, %{})))
    |> assign(:needs_refresh_count, Enum.count(audit_rows, &(&1.status != :ok and &1.refreshable?)))
    |> assign(:orphaned_count, Enum.count(audit_rows, &(&1.status == :orphaned)))
  rescue
    _error ->
      socket
      |> assign(:source_lookup, %{})
      |> assign(:collection_counts, %{})
      |> assign(:audit_rows, [])
      |> assign(:audit_summary, empty_audit_summary())
      |> assign(:needs_refresh_count, 0)
      |> assign(:orphaned_count, 0)
  end

  defp load_ecosystem_docs_status(socket) do
    socket
    |> assign(:ecosystem_docs_status, normalize_ecosystem_docs_status(ecosystem_docs_module().status()))
    |> assign(:ecosystem_docs_snapshot, normalize_ecosystem_docs_snapshot(ecosystem_docs_module().snapshot()))
  rescue
    _error ->
      socket
      |> assign(:ecosystem_docs_status, empty_ecosystem_docs_status())
      |> assign(:ecosystem_docs_snapshot, empty_ecosystem_docs_snapshot())
  end

  defp build_audit_rows(rows, source_lookup) do
    rows
    |> Enum.map(fn row ->
      expected = Map.get(row, :expected)
      ingested = Map.get(row, :ingested)
      source_id = Map.get(row, :source_id, "")
      status = Map.get(row, :status, :ok)
      issues = Map.get(row, :issues, [])

      collection = value(expected, :collection) || value(ingested, :collection) || "—"
      title = value(expected, :title) || value(ingested, :title) || source_id
      path = value(expected, :path) || value(ingested, :path) || "—"
      refreshable? = is_map(expected) and Map.has_key?(source_lookup, source_id)

      %{
        source_id: source_id,
        status: status,
        issues: issues,
        collection: collection,
        title: title,
        path: path,
        refreshable?: refreshable?,
        details: detail_text(issues, ingested)
      }
    end)
    |> Enum.sort_by(&{status_rank(&1.status), &1.source_id})
  end

  defp detail_text(issues, ingested) do
    issue_text = issue_summary(issues)
    chunk_text = count_summary(ingested, :actual_chunk_count, "chunks")
    dup_text = count_summary(ingested, :duplicate_count, "dup")
    error_text = error_summary(ingested)

    [issue_text, chunk_text, dup_text, error_text]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join(" • ")
  end

  defp issue_summary([]), do: "ok"
  defp issue_summary(list) when is_list(list), do: Enum.map_join(list, ", ", &issue_label/1)
  defp issue_summary(_other), do: "unknown"

  defp count_summary(data, key, label) do
    case Map.get(data || %{}, key) do
      count when is_integer(count) -> "#{label}=#{count}"
      _other -> "#{label}=—"
    end
  end

  defp error_summary(%{document_error: error}) when is_binary(error) and error != "", do: "error=#{error}"
  defp error_summary(_ingested), do: ""

  defp value(map, key) when is_map(map), do: Map.get(map, key)
  defp value(_map, _key), do: nil

  defp normalize_summary(summary) when is_map(summary) do
    failed = Map.get(summary, :failed, [])

    %{
      total_sources: Map.get(summary, :total_sources, 0),
      inserted: Map.get(summary, :inserted, 0),
      updated: Map.get(summary, :updated, 0),
      deleted: Map.get(summary, :deleted, 0),
      skipped: Map.get(summary, :skipped, 0),
      failed_count: Map.get(summary, :failed_count, if(is_list(failed), do: length(failed), else: 0))
    }
  end

  defp normalize_summary(_summary) do
    %{total_sources: 0, inserted: 0, updated: 0, deleted: 0, skipped: 0, failed_count: 0}
  end

  defp normalize_audit_summary(summary) when is_map(summary) do
    status_counts = Map.get(summary, :status_counts, %{})

    %{
      expected_count: Map.get(summary, :expected_count, 0),
      ingested_count: Map.get(summary, :ingested_count, 0),
      compared_count: Map.get(summary, :compared_count, 0),
      ok_count: Map.get(summary, :ok_count, Map.get(status_counts, :ok, 0)),
      blocking_count:
        Map.get(
          summary,
          :blocking_count,
          max(Map.get(summary, :compared_count, 0) - Map.get(summary, :ok_count, 0), 0)
        )
    }
  end

  defp normalize_audit_summary(_summary), do: empty_audit_summary()

  defp empty_audit_summary do
    %{expected_count: 0, ingested_count: 0, compared_count: 0, ok_count: 0, blocking_count: 0}
  end

  defp empty_ecosystem_docs_status do
    %{enabled: false, running: false, last_started_at: nil, last_finished_at: nil, last_summary: nil}
  end

  defp empty_ecosystem_docs_snapshot do
    %{total_documents: 0, package_count: 0, latest_crawled_at: nil, packages: []}
  end

  defp normalize_ecosystem_docs_status(status) when is_map(status) do
    %{
      enabled: Map.get(status, :enabled, false),
      running: Map.get(status, :running, false),
      last_started_at: Map.get(status, :last_started_at),
      last_finished_at: Map.get(status, :last_finished_at),
      last_summary: Map.get(status, :last_summary)
    }
  end

  defp normalize_ecosystem_docs_status(_status), do: empty_ecosystem_docs_status()

  defp normalize_ecosystem_docs_snapshot(snapshot) when is_map(snapshot) do
    %{
      total_documents: Map.get(snapshot, :total_documents, 0),
      package_count: Map.get(snapshot, :package_count, 0),
      latest_crawled_at: Map.get(snapshot, :latest_crawled_at),
      packages: Map.get(snapshot, :packages, [])
    }
  end

  defp normalize_ecosystem_docs_snapshot(_snapshot), do: empty_ecosystem_docs_snapshot()

  defp summary_status_text(summary) do
    changed = summary.inserted + summary.updated + summary.deleted

    cond do
      summary.failed_count > 0 ->
        "Run completed with failures. Check logs and retry."

      changed > 0 ->
        "Run completed successfully with #{changed} total content changes."

      true ->
        "Run completed with no content changes."
    end
  end

  defp summary_status_class(summary) do
    if summary.failed_count > 0 do
      "text-xs font-semibold text-accent-red"
    else
      "text-xs font-semibold text-accent-green"
    end
  end

  defp maybe_schedule_ecosystem_docs_refresh(socket) do
    if socket.assigns[:ecosystem_docs_status][:running] do
      Process.send_after(self(), :refresh_ecosystem_docs_status, ecosystem_docs_poll_interval_ms())
    end

    socket
  end

  defp ecosystem_docs_summary_value(summary, key) when is_map(summary), do: Map.get(summary, key, 0)
  defp ecosystem_docs_summary_value(_summary, _key), do: 0

  defp ecosystem_docs_failures(summary) when is_map(summary), do: Map.get(summary, :failed, [])
  defp ecosystem_docs_failures(_summary), do: []

  defp ecosystem_docs_module do
    Application.get_env(:agent_jido, :dashboard_ecosystem_docs_module, EcosystemDocs)
  end

  defp ecosystem_docs_poll_interval_ms do
    interval_ms =
      Application.get_env(:agent_jido, :dashboard_ecosystem_docs_poll_interval_ms, @ecosystem_docs_poll_default_ms)

    case interval_ms do
      value when is_integer(value) and value > 0 -> value
      _other -> @ecosystem_docs_poll_default_ms
    end
  end

  defp format_datetime(nil), do: "—"

  defp format_datetime(%DateTime{} = value) do
    Calendar.strftime(value, "%Y-%m-%d %H:%M:%S UTC")
  end

  defp format_datetime(%NaiveDateTime{} = value) do
    Calendar.strftime(value, "%Y-%m-%d %H:%M:%S")
  end

  defp format_datetime(_value), do: "—"

  defp status_rank(status) do
    Enum.find_index(@status_order, &(&1 == status)) || length(@status_order)
  end

  defp status_badge_class(:ok),
    do: "rounded px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-accent-green bg-accent-green/10 border border-accent-green/30"

  defp status_badge_class(_status),
    do: "rounded px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-accent-red bg-accent-red/10 border border-accent-red/30"

  defp status_label(status) when is_atom(status), do: issue_label(status)
  defp status_label(status), do: to_string(status)

  defp issue_label(issue) when is_atom(issue) do
    issue
    |> Atom.to_string()
    |> String.replace("_", " ")
  end

  defp issue_label(issue) when is_binary(issue), do: String.replace(issue, "_", " ")

  defp ingest_module do
    Application.get_env(:agent_jido, :dashboard_ingest_module, ContentIngest)
  end

  defp audit_module do
    Application.get_env(:agent_jido, :dashboard_content_audit_module, ContentIngest)
  end
end
