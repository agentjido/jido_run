defmodule AgentJidoWeb.AdminContentGeneratorLive do
  @moduledoc """
  Admin UI for iterating content-plan entries through generation, diff, verify, and apply flows.
  """

  use AgentJidoWeb, :live_view

  alias AgentJido.ContentGen
  alias AgentJido.ContentGen.PathResolver
  alias AgentJido.ContentPlan
  alias AgentJidoWeb.ContentGenerator.Diff
  alias AgentJidoWeb.ContentGenerator.EntryStatus
  alias AgentJidoWeb.ContentGenerator.RunReportStore

  @task_supervisor_key :content_gen_task_supervisor
  @run_task_ref_key :content_gen_task_ref
  @run_form_key :content_gen_form
  @run_params_key :content_gen_form_params
  @run_store_key :content_gen_run_store
  @running_key :content_gen_running
  @active_command_key :content_gen_active_command
  @run_context_key :content_gen_run_context
  @run_tick_ms 1_000

  @impl true
  def mount(_params, _session, socket) do
    params = default_form_params()
    entries = plan_entries()
    run_store = load_run_store()

    socket =
      socket
      |> assign(:page_title, "Content Generator")
      |> assign(@running_key, false)
      |> assign(@run_task_ref_key, nil)
      |> assign(@task_supervisor_key, nil)
      |> assign(@active_command_key, nil)
      |> assign(@run_context_key, nil)
      |> assign(:entries, entries)
      |> assign(:entry_sections, entries |> Enum.map(& &1.section) |> Enum.uniq() |> Enum.sort())
      |> assign(:entry_plan_statuses, entries |> Enum.map(& &1.status) |> Enum.uniq() |> Enum.sort())
      |> assign(@run_store_key, run_store)
      |> assign(:run_warnings, run_store.warnings)
      |> assign(:plan_filters, default_plan_filters())
      |> assign(:runs_filters, default_runs_filters())
      |> assign(:plan_rows, [])
      |> assign(:filtered_plan_rows, [])
      |> assign(:filtered_runs, [])
      |> assign(:selected_entry, nil)
      |> assign(:selected_entry_detail, nil)
      |> assign(:selected_run, nil)
      |> assign(@run_params_key, params)
      |> assign(@run_form_key, to_form(params, as: :generator))
      |> refresh_plan_rows()
      |> refresh_runs()

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    socket =
      socket
      |> refresh_run_store()
      |> refresh_plan_rows()
      |> refresh_runs()

    case socket.assigns.live_action do
      :plan ->
        {:noreply,
         socket
         |> assign(:page_title, "Content Generator")
         |> assign(:selected_entry, nil)
         |> assign(:selected_entry_detail, nil)
         |> assign(:selected_run, nil)}

      :runs ->
        {:noreply,
         socket
         |> assign(:page_title, "Content Generator Runs")
         |> assign(:selected_entry, nil)
         |> assign(:selected_entry_detail, nil)
         |> assign(:selected_run, nil)}

      :entry ->
        entry_id = decode_entry_id(params["entry_id"])

        case ContentPlan.get_entry(entry_id) do
          nil ->
            {:noreply,
             socket
             |> put_flash(:error, "Unknown content-plan entry #{inspect(entry_id)}.")
             |> push_navigate(to: ~p"/dashboard/content-generator")}

          entry ->
            detail = build_entry_detail(entry, socket.assigns[@run_store_key], socket.assigns[@run_params_key])

            {:noreply,
             socket
             |> assign(:page_title, "Content Entry #{entry.id}")
             |> assign(:selected_entry, entry)
             |> assign(:selected_entry_detail, detail)
             |> assign(:selected_run, nil)}
        end

      :run ->
        run_id = params["run_id"]
        run = RunReportStore.get_run(socket.assigns[@run_store_key], run_id)

        if run do
          {:noreply,
           socket
           |> assign(:page_title, "Content Run #{run_id}")
           |> assign(:selected_entry, nil)
           |> assign(:selected_entry_detail, nil)
           |> assign(:selected_run, run)}
        else
          {:noreply,
           socket
           |> put_flash(:error, "Run #{inspect(run_id)} not found.")
           |> push_navigate(to: ~p"/dashboard/content-generator/runs")}
        end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <AgentJidoWeb.Jido.AdminNav.admin_shell current_path="/dashboard/content-generator">
      <div class="container mx-auto max-w-7xl space-y-6 px-6 py-10">
        <header class="space-y-2">
          <p class="text-xs font-semibold uppercase tracking-[0.2em] text-primary">Admin Control Plane</p>
          <h1 class="text-3xl font-semibold text-foreground">Content Generator</h1>
          <p class="max-w-4xl text-sm text-muted-foreground">
            Iterate one content-plan briefing into generated docs with preview, diff, verify, and apply.
          </p>
          <p class="max-w-4xl text-xs text-muted-foreground">
            `priv/content_plan/**` is hand-authored source. `priv/pages/docs/**` is generated long-form output.
          </p>
        </header>

        <section
          :if={@content_gen_running and is_map(@content_gen_run_context)}
          class="space-y-2 rounded-lg border border-accent-yellow/40 bg-accent-yellow/10 px-4 py-3"
        >
          <div class="flex flex-wrap items-center justify-between gap-2">
            <p class="text-xs font-semibold uppercase tracking-wide text-accent-yellow">
              {run_progress_label(@content_gen_run_context)}
            </p>
            <p class="font-mono text-[11px] text-accent-yellow">
              elapsed {format_elapsed_seconds(@content_gen_run_context.elapsed_seconds)}
            </p>
          </div>
          <p
            :if={is_binary(@content_gen_active_command)}
            class="truncate font-mono text-[11px] text-accent-yellow"
            title={@content_gen_active_command}
          >
            {@content_gen_active_command}
          </p>
        </section>

        <section class="flex flex-wrap items-center justify-between gap-3 rounded-lg border border-border bg-card px-4 py-3">
          <nav class="inline-flex items-center gap-2">
            <.link patch={~p"/dashboard/content-generator"} class={subnav_class(@live_action in [:plan, :entry])}>
              Plan
            </.link>
            <.link patch={~p"/dashboard/content-generator/runs"} class={subnav_class(@live_action in [:runs, :run])}>
              Runs
            </.link>
          </nav>

          <button
            type="button"
            phx-click="refresh_reports"
            class="rounded-md border border-border bg-background px-3 py-1.5 text-xs font-semibold text-foreground hover:border-primary/50"
          >
            Refresh reports
          </button>
        </section>

        <section :if={@run_warnings != []} class="space-y-2 rounded-lg border border-accent-yellow/40 bg-accent-yellow/10 p-4">
          <h2 class="text-sm font-semibold text-accent-yellow">Run report warnings</h2>
          <p :for={warning <- @run_warnings} class="text-xs text-accent-yellow">{warning}</p>
        </section>

        <%= case @live_action do %>
          <% :plan -> %>
            <.plan_page
              form={@content_gen_form}
              params={@content_gen_form_params}
              filters={@plan_filters}
              sections={@entry_sections}
              statuses={@entry_plan_statuses}
              rows={@filtered_plan_rows}
              running={@content_gen_running}
              run_context={@content_gen_run_context}
            />
          <% :entry -> %>
            <.entry_page
              entry={@selected_entry}
              detail={@selected_entry_detail}
              running={@content_gen_running}
              run_context={@content_gen_run_context}
            />
          <% :runs -> %>
            <.runs_page filters={@runs_filters} runs={@filtered_runs} />
          <% :run -> %>
            <.run_page run={@selected_run} />
        <% end %>
      </div>
    </AgentJidoWeb.Jido.AdminNav.admin_shell>
    """
  end

  attr :form, :map, required: true
  attr :params, :map, required: true
  attr :filters, :map, required: true
  attr :sections, :list, required: true
  attr :statuses, :list, required: true
  attr :rows, :list, required: true
  attr :running, :boolean, required: true
  attr :run_context, :map, default: nil

  defp plan_page(assigns) do
    ~H"""
    <div class="space-y-6">
      <section class="grid gap-4 lg:grid-cols-[minmax(0,2fr)_minmax(0,1fr)]">
        <article class="space-y-4 rounded-lg border border-border bg-card p-5">
          <div class="space-y-1">
            <h2 class="text-base font-semibold text-foreground">Run Defaults</h2>
            <p class="text-sm text-muted-foreground">
              These defaults are used for row actions and manual command runs.
            </p>
          </div>

          <.form
            for={@form}
            phx-change="sync_form"
            phx-submit="start_content_run"
            class="grid gap-3 md:grid-cols-2"
          >
            <label class="space-y-1 md:col-span-2">
              <span class="block text-[11px] font-semibold uppercase tracking-wide text-muted-foreground">Entry ID (manual run)</span>
              <input
                type="text"
                name="generator[entry]"
                value={@form[:entry].value}
                placeholder="docs/concepts/agents"
                class="w-full rounded-md border border-border bg-background px-3 py-2 text-sm"
              />
            </label>

            <label class="space-y-1">
              <span class="block text-[11px] font-semibold uppercase tracking-wide text-muted-foreground">Backend</span>
              <select
                name="generator[backend]"
                class="w-full rounded-md border border-border bg-background px-3 py-2 text-sm"
              >
                <option value="req_llm" selected={@form[:backend].value == "req_llm"}>req_llm</option>
              </select>
            </label>

            <label class="space-y-1">
              <span class="block text-[11px] font-semibold uppercase tracking-wide text-muted-foreground">Update Mode</span>
              <select
                name="generator[update_mode]"
                class="w-full rounded-md border border-border bg-background px-3 py-2 text-sm"
              >
                <option value="improve" selected={@form[:update_mode].value == "improve"}>improve</option>
                <option value="regenerate" selected={@form[:update_mode].value == "regenerate"}>regenerate</option>
                <option value="audit_only" selected={@form[:update_mode].value == "audit_only"}>audit_only</option>
              </select>
            </label>

            <label class="space-y-1">
              <span class="block text-[11px] font-semibold uppercase tracking-wide text-muted-foreground">Docs Format</span>
              <select
                name="generator[docs_format]"
                class="w-full rounded-md border border-border bg-background px-3 py-2 text-sm"
              >
                <option value="tag" selected={@form[:docs_format].value == "tag"}>tag</option>
                <option value="livemd" selected={@form[:docs_format].value == "livemd"}>livemd</option>
              </select>
            </label>

            <label class="space-y-1">
              <span class="block text-[11px] font-semibold uppercase tracking-wide text-muted-foreground">Max</span>
              <input
                type="number"
                min="1"
                name="generator[max]"
                value={@form[:max].value}
                class="w-full rounded-md border border-border bg-background px-3 py-2 text-sm"
              />
            </label>

            <label class="space-y-1">
              <span class="block text-[11px] font-semibold uppercase tracking-wide text-muted-foreground">Sections</span>
              <input
                type="text"
                name="generator[sections]"
                value={@form[:sections].value}
                placeholder="docs"
                class="w-full rounded-md border border-border bg-background px-3 py-2 text-sm"
              />
            </label>

            <label class="space-y-1">
              <span class="block text-[11px] font-semibold uppercase tracking-wide text-muted-foreground">Statuses</span>
              <input
                type="text"
                name="generator[statuses]"
                value={@form[:statuses].value}
                placeholder="outline,draft"
                class="w-full rounded-md border border-border bg-background px-3 py-2 text-sm"
              />
            </label>

            <div class="flex flex-wrap items-center gap-4 md:col-span-2">
              <label class="flex items-center gap-2 text-xs text-foreground">
                <input type="hidden" name="generator[apply]" value="false" />
                <input type="checkbox" name="generator[apply]" value="true" checked={truthy?(@form[:apply].value)} /> apply
              </label>

              <label class="flex items-center gap-2 text-xs text-foreground">
                <input type="hidden" name="generator[verify]" value="false" />
                <input type="checkbox" name="generator[verify]" value="true" checked={truthy?(@form[:verify].value)} /> verify
              </label>

              <label class="flex items-center gap-2 text-xs text-foreground">
                <input type="hidden" name="generator[fail_on_audit]" value="false" />
                <input type="checkbox" name="generator[fail_on_audit]" value="true" checked={truthy?(@form[:fail_on_audit].value)} /> fail_on_audit
              </label>
            </div>

            <div class="md:col-span-2">
              <button
                type="submit"
                class="rounded-md bg-primary px-4 py-2 text-xs font-semibold text-primary-foreground disabled:cursor-not-allowed disabled:opacity-60"
                disabled={@running}
              >
                {if @running, do: "Running...", else: "Start content run"}
              </button>
            </div>
          </.form>
        </article>

        <article class="space-y-3 rounded-lg border border-border bg-card p-5">
          <div class="flex items-center justify-between gap-2">
            <h2 class="text-base font-semibold text-foreground">Terminal Command</h2>
            <button type="button" data-copy-button data-content={build_mix_command(@params)} class={copy_button_class()}>
              Copy
            </button>
          </div>
          <p class="text-xs text-muted-foreground">Copy this into your local terminal.</p>
          <pre
            class="overflow-x-auto rounded-md border border-border bg-background px-3 py-2 font-mono text-[11px] text-foreground"
            data-content-gen-command-current
          >{build_mix_command(@params)}</pre>
        </article>
      </section>

      <section class="space-y-4 rounded-lg border border-border bg-card p-5">
        <div class="space-y-1">
          <h2 class="text-base font-semibold text-foreground">Content Plan Queue</h2>
          <p class="text-sm text-muted-foreground">
            One searchable queue for page-bound entries. Open detail for diff/regenerate/apply.
          </p>
        </div>

        <.form for={%{}} as={:filters} phx-change="set_plan_filters" class="grid gap-3 md:grid-cols-5">
          <label class="space-y-1 md:col-span-2">
            <span class="block text-[11px] font-semibold uppercase tracking-wide text-muted-foreground">Search</span>
            <input
              type="text"
              name="filters[q]"
              value={@filters["q"]}
              placeholder="entry id, title, or route"
              class="w-full rounded-md border border-border bg-background px-3 py-2 text-sm"
            />
          </label>

          <label class="space-y-1">
            <span class="block text-[11px] font-semibold uppercase tracking-wide text-muted-foreground">Section</span>
            <select name="filters[section]" class="w-full rounded-md border border-border bg-background px-3 py-2 text-sm">
              <option value="all" selected={@filters["section"] == "all"}>all</option>
              <option :for={section <- @sections} value={section} selected={@filters["section"] == section}>{section}</option>
            </select>
          </label>

          <label class="space-y-1">
            <span class="block text-[11px] font-semibold uppercase tracking-wide text-muted-foreground">Plan Status</span>
            <select
              name="filters[plan_status]"
              class="w-full rounded-md border border-border bg-background px-3 py-2 text-sm"
            >
              <option value="all" selected={@filters["plan_status"] == "all"}>all</option>
              <option
                :for={status <- @statuses}
                value={Atom.to_string(status)}
                selected={@filters["plan_status"] == Atom.to_string(status)}
              >
                {status}
              </option>
            </select>
          </label>

          <label class="space-y-1">
            <span class="block text-[11px] font-semibold uppercase tracking-wide text-muted-foreground">Artifact</span>
            <select
              name="filters[artifact_status]"
              class="w-full rounded-md border border-border bg-background px-3 py-2 text-sm"
            >
              <option value="all" selected={@filters["artifact_status"] == "all"}>all</option>
              <option value="generated" selected={@filters["artifact_status"] == "generated"}>generated</option>
              <option value="stale" selected={@filters["artifact_status"] == "stale"}>stale</option>
              <option value="missing" selected={@filters["artifact_status"] == "missing"}>missing</option>
              <option value="unknown" selected={@filters["artifact_status"] == "unknown"}>unknown</option>
            </select>
          </label>

          <label class="space-y-1">
            <span class="block text-[11px] font-semibold uppercase tracking-wide text-muted-foreground">Verify</span>
            <select
              name="filters[verify_status]"
              class="w-full rounded-md border border-border bg-background px-3 py-2 text-sm"
            >
              <option value="all" selected={@filters["verify_status"] == "all"}>all</option>
              <option value="passed" selected={@filters["verify_status"] == "passed"}>passed</option>
              <option value="failed" selected={@filters["verify_status"] == "failed"}>failed</option>
              <option value="skipped" selected={@filters["verify_status"] == "skipped"}>skipped</option>
              <option value="unknown" selected={@filters["verify_status"] == "unknown"}>unknown</option>
            </select>
          </label>
        </.form>

        <div class="overflow-hidden rounded-md border border-border bg-background">
          <table class="w-full table-fixed text-left text-xs">
            <thead class="bg-elevated text-muted-foreground">
              <tr>
                <th class="w-[30%] px-3 py-2 font-semibold">Entry</th>
                <th class="w-[8%] px-3 py-2 font-semibold">Section</th>
                <th class="w-[8%] px-3 py-2 font-semibold">Plan</th>
                <th class="w-[13%] px-3 py-2 font-semibold">Route</th>
                <th class="w-[8%] px-3 py-2 font-semibold">Artifact</th>
                <th class="w-[8%] px-3 py-2 font-semibold">Verify</th>
                <th class="w-[10%] px-3 py-2 font-semibold">Last Run</th>
                <th class="w-[8%] px-3 py-2 font-semibold">Updated</th>
                <th class="w-[17%] px-3 py-2 font-semibold">Actions</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={row <- @rows} class={"border-t border-border/70 " <> plan_row_class(row.status.entry_health)}>
                <td class="min-w-0 px-3 py-2 align-top">
                  <.link patch={~p"/dashboard/content-generator/entries/#{row.id}"} class="font-semibold text-foreground hover:text-primary">
                    {row.title}
                  </.link>
                  <p class="mt-1 truncate font-mono text-[10px] text-muted-foreground" title={row.id}>{row.id}</p>
                  <p
                    :if={run_entry_active?(@run_context, row.id)}
                    class="mt-1 inline-flex rounded border border-accent-yellow/40 bg-accent-yellow/10 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-accent-yellow"
                  >
                    Running {run_action_short_label(@run_context)}
                  </p>
                  <div class="mt-2 flex items-center gap-1">
                    <code
                      class="block min-w-0 flex-1 truncate rounded border border-border bg-card px-2 py-1 font-mono text-[10px] text-muted-foreground"
                      title={build_entry_action_command(row.entry, :apply, @params)}
                      data-content-gen-command-entry={row.id}
                    >
                      {build_entry_action_command(row.entry, :apply, @params)}
                    </code>
                    <button
                      type="button"
                      data-copy-button
                      data-content={build_entry_action_command(row.entry, :apply, @params)}
                      class={copy_button_class()}
                    >
                      Copy
                    </button>
                  </div>
                </td>
                <td class="whitespace-nowrap px-3 py-2 align-top text-muted-foreground">{row.section}</td>
                <td class="whitespace-nowrap px-3 py-2 align-top">
                  <span class={plan_status_badge_class(row.plan_status)}>{row.plan_status}</span>
                </td>
                <td class="truncate px-3 py-2 align-top text-muted-foreground" title={row.route}>{row.route}</td>
                <td class="whitespace-nowrap px-3 py-2 align-top">
                  <span class={artifact_status_badge_class(row.status.artifact_status)}>{row.status.artifact_status}</span>
                </td>
                <td class="whitespace-nowrap px-3 py-2 align-top">
                  <span class={verify_status_badge_class(row.status.verify_status)}>{row.status.verify_status}</span>
                </td>
                <td class="px-3 py-2 align-top">
                  <%= if row.last_run_id do %>
                    <.link
                      patch={~p"/dashboard/content-generator/runs/#{row.last_run_id}"}
                      class="block truncate font-mono text-[10px] text-primary hover:underline"
                      title={row.last_run_id}
                    >
                      {row.last_run_id}
                    </.link>
                    <p class="mt-1 whitespace-nowrap text-[10px] text-muted-foreground">{format_timestamp(row.last_run_at)}</p>
                  <% else %>
                    <span class="text-muted-foreground">-</span>
                  <% end %>
                </td>
                <td class="whitespace-nowrap px-3 py-2 align-top text-muted-foreground">{format_timestamp(row.status.plan_mtime)}</td>
                <td class="px-3 py-2 align-top">
                  <div class="flex flex-wrap gap-1">
                    <.link
                      patch={~p"/dashboard/content-generator/entries/#{row.id}"}
                      class="rounded border border-border px-2 py-1 text-[10px] font-semibold text-foreground hover:border-primary/50"
                    >
                      Open Detail
                    </.link>
                    <button
                      type="button"
                      phx-click="entry_action"
                      phx-value-entry={row.id}
                      phx-value-action="preview"
                      class="rounded border border-border px-2 py-1 text-[10px] font-semibold text-foreground hover:border-primary/50 disabled:opacity-50"
                      disabled={@running}
                    >
                      {run_button_label(@run_context, row.id, "preview", "Generate Preview")}
                    </button>
                    <button
                      type="button"
                      phx-click="entry_action"
                      phx-value-entry={row.id}
                      phx-value-action="apply"
                      class="rounded border border-primary/40 bg-primary/10 px-2 py-1 text-[10px] font-semibold text-primary hover:bg-primary/20 disabled:opacity-50"
                      disabled={@running}
                    >
                      {run_button_label(@run_context, row.id, "apply", "Apply")}
                    </button>
                    <.link
                      :if={row.last_run_id}
                      patch={~p"/dashboard/content-generator/runs/#{row.last_run_id}"}
                      class="rounded border border-border px-2 py-1 text-[10px] font-semibold text-foreground hover:border-primary/50"
                    >
                      Open Run
                    </.link>
                  </div>
                </td>
              </tr>
              <tr :if={@rows == []}>
                <td colspan="9" class="px-3 py-3 text-muted-foreground">No matching entries.</td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>
    </div>
    """
  end

  attr :entry, :map, required: true
  attr :detail, :map, required: true
  attr :running, :boolean, required: true
  attr :run_context, :map, default: nil

  defp entry_page(assigns) do
    ~H"""
    <div :if={@entry && @detail} class="space-y-6">
      <section class="rounded-lg border border-border bg-card p-5">
        <div class="flex flex-wrap items-start justify-between gap-3">
          <div>
            <p class="text-xs font-semibold uppercase tracking-wide text-muted-foreground">Entry Detail</p>
            <h2 class="mt-1 text-xl font-semibold text-foreground">{@entry.title}</h2>
            <p class="mt-1 font-mono text-xs text-muted-foreground">{@entry.id}</p>
            <p class="mt-1 text-xs text-muted-foreground">Route: {@entry.destination_route}</p>
          </div>
          <div class="flex flex-wrap items-center gap-2">
            <.link
              patch={~p"/dashboard/content-generator"}
              class="rounded border border-border px-3 py-1.5 text-xs font-semibold text-foreground hover:border-primary/50"
            >
              Open in Plan
            </.link>
            <.link
              :if={@detail.candidate.run_id}
              patch={~p"/dashboard/content-generator/runs/#{@detail.candidate.run_id}"}
              class="rounded border border-border px-3 py-1.5 text-xs font-semibold text-foreground hover:border-primary/50"
            >
              Open Run
            </.link>
          </div>
        </div>
      </section>

      <section class="grid gap-4 lg:grid-cols-3">
        <article class="space-y-3 rounded-lg border border-border bg-card p-5 lg:col-span-2">
          <h3 class="text-base font-semibold text-foreground">Brief</h3>
          <div class="grid gap-2 text-xs text-muted-foreground md:grid-cols-2">
            <span>Section: {@entry.section}</span>
            <span>Status: {Atom.to_string(@entry.status)}</span>
            <span>Audience: {@entry.audience}</span>
            <span>Type: {@entry.content_type}</span>
          </div>
          <p class="text-sm text-foreground">{@entry.purpose}</p>
          <p class="text-xs text-muted-foreground">Source: {@entry.path}</p>
          <div class="rounded border border-border bg-background p-3 text-xs text-foreground">
            {@detail.brief_excerpt}
          </div>
        </article>

        <article class="space-y-3 rounded-lg border border-border bg-card p-5">
          <h3 class="text-base font-semibold text-foreground">Actions</h3>
          <p
            :if={run_entry_active?(@run_context, @entry.id)}
            class="rounded border border-accent-yellow/40 bg-accent-yellow/10 px-3 py-2 text-[11px] text-accent-yellow"
          >
            {run_progress_label(@run_context)} ({format_elapsed_seconds(@run_context.elapsed_seconds)})
          </p>
          <div class="flex flex-col gap-2">
            <button
              type="button"
              phx-click="entry_action"
              phx-value-entry={@entry.id}
              phx-value-action="preview"
              class="rounded border border-border px-3 py-2 text-xs font-semibold text-foreground hover:border-primary/50 disabled:opacity-50"
              disabled={@running}
            >
              {run_button_label(@run_context, @entry.id, "preview", "Generate Preview")}
            </button>
            <button
              type="button"
              phx-click="entry_action"
              phx-value-entry={@entry.id}
              phx-value-action="apply"
              class="rounded border border-primary/40 bg-primary/10 px-3 py-2 text-xs font-semibold text-primary hover:bg-primary/20 disabled:opacity-50"
              disabled={@running}
            >
              {run_button_label(@run_context, @entry.id, "apply", "Apply")}
            </button>
            <button
              type="button"
              phx-click="entry_action"
              phx-value-entry={@entry.id}
              phx-value-action="apply_verify"
              class="rounded border border-border px-3 py-2 text-xs font-semibold text-foreground hover:border-primary/50 disabled:opacity-50"
              disabled={@running}
            >
              {run_button_label(@run_context, @entry.id, "apply_verify", "Apply + Verify")}
            </button>
          </div>
        </article>
      </section>

      <section class="grid gap-4 lg:grid-cols-2">
        <article class="space-y-3 rounded-lg border border-border bg-card p-5">
          <h3 class="text-base font-semibold text-foreground">Current Artifact</h3>
          <div class="space-y-1 text-xs text-muted-foreground">
            <p>Status: <span class={artifact_status_badge_class(@detail.status.artifact_status)}>{@detail.status.artifact_status}</span></p>
            <p>Verify: <span class={verify_status_badge_class(@detail.status.verify_status)}>{@detail.status.verify_status}</span></p>
            <p>Target: {@detail.status.target_path || "-"}</p>
            <p>Read: {@detail.status.read_path || "-"}</p>
            <p>Artifact updated: {format_timestamp(@detail.status.artifact_mtime)}</p>
            <p>Plan updated: {format_timestamp(@detail.status.plan_mtime)}</p>
          </div>
        </article>

        <article class="space-y-3 rounded-lg border border-border bg-card p-5">
          <h3 class="text-base font-semibold text-foreground">Candidate</h3>
          <%= if @detail.candidate.available? do %>
            <div class="space-y-1 text-xs text-muted-foreground">
              <p>Run: {@detail.candidate.run_id || "-"}</p>
              <p>Path: {@detail.candidate.path}</p>
              <p>Updated: {format_timestamp(@detail.candidate.updated_at)}</p>
            </div>
          <% else %>
            <p class="text-sm text-muted-foreground">
              No candidate file found for this entry. Generate Preview to create one.
            </p>
          <% end %>
        </article>
      </section>

      <section class="space-y-4 rounded-lg border border-border bg-card p-5">
        <h3 class="text-base font-semibold text-foreground">Diff</h3>
        <%= if @detail.diff do %>
          <div class="grid grid-cols-2 gap-2 text-xs text-muted-foreground md:grid-cols-6">
            <span>added: {@detail.diff.stats.added}</span>
            <span>removed: {@detail.diff.stats.removed}</span>
            <span>context: {@detail.diff.stats.context}</span>
            <span>old lines: {@detail.diff.stats.old_lines}</span>
            <span>new lines: {@detail.diff.stats.new_lines}</span>
            <span>delta: {@detail.diff.stats.delta_lines}</span>
          </div>

          <pre class="max-h-[520px] overflow-auto rounded-md border border-border bg-background p-3 font-mono text-[11px] leading-5">
    <span :for={line <- @detail.diff.lines} class={diff_line_class(line.kind)}>{line.prefix}{line.text}
    </span>
          </pre>

          <p :if={@detail.diff.truncated?} class="text-xs text-muted-foreground">
            Diff truncated to {@detail.diff.max_lines} lines (total {@detail.diff.total_lines}).
          </p>
        <% else %>
          <p class="text-sm text-muted-foreground">Diff unavailable until a candidate preview exists.</p>
        <% end %>
      </section>

      <section class="space-y-3 rounded-lg border border-border bg-card p-5">
        <h3 class="text-base font-semibold text-foreground">Terminal Commands</h3>
        <div class="space-y-3 text-xs">
          <div>
            <div class="mb-1 flex items-center justify-between gap-2">
              <p class="font-semibold text-foreground">Generate Preview</p>
              <button type="button" data-copy-button data-content={@detail.commands.preview} class={copy_button_class()}>
                Copy
              </button>
            </div>
            <pre class="overflow-x-auto rounded border border-border bg-background px-3 py-2 font-mono text-[11px] text-muted-foreground">{@detail.commands.preview}</pre>
          </div>
          <div>
            <div class="mb-1 flex items-center justify-between gap-2">
              <p class="font-semibold text-foreground">Apply</p>
              <button type="button" data-copy-button data-content={@detail.commands.apply} class={copy_button_class()}>
                Copy
              </button>
            </div>
            <pre class="overflow-x-auto rounded border border-border bg-background px-3 py-2 font-mono text-[11px] text-muted-foreground">{@detail.commands.apply}</pre>
          </div>
          <div>
            <div class="mb-1 flex items-center justify-between gap-2">
              <p class="font-semibold text-foreground">Apply + Verify</p>
              <button type="button" data-copy-button data-content={@detail.commands.apply_verify} class={copy_button_class()}>
                Copy
              </button>
            </div>
            <pre class="overflow-x-auto rounded border border-border bg-background px-3 py-2 font-mono text-[11px] text-muted-foreground">{@detail.commands.apply_verify}</pre>
          </div>
        </div>
      </section>
    </div>
    """
  end

  attr :filters, :map, required: true
  attr :runs, :list, required: true

  defp runs_page(assigns) do
    ~H"""
    <div class="space-y-6">
      <section class="space-y-4 rounded-lg border border-border bg-card p-5">
        <div class="space-y-1">
          <h2 class="text-base font-semibold text-foreground">Run History</h2>
          <p class="text-sm text-muted-foreground">
            Persisted runs from `tmp/content_gen/runs/*/report.json`.
          </p>
        </div>

        <.form for={%{}} as={:filters} phx-change="set_runs_filters" class="grid gap-3 md:grid-cols-3">
          <label class="space-y-1">
            <span class="block text-[11px] font-semibold uppercase tracking-wide text-muted-foreground">Search</span>
            <input
              type="text"
              name="filters[q]"
              value={@filters["q"]}
              placeholder="run id or entry id"
              class="w-full rounded-md border border-border bg-background px-3 py-2 text-sm"
            />
          </label>

          <label class="space-y-1">
            <span class="block text-[11px] font-semibold uppercase tracking-wide text-muted-foreground">Status</span>
            <select name="filters[status]" class="w-full rounded-md border border-border bg-background px-3 py-2 text-sm">
              <option value="all" selected={@filters["status"] == "all"}>all</option>
              <option value="completed" selected={@filters["status"] == "completed"}>completed</option>
              <option value="failed" selected={@filters["status"] == "failed"}>failed</option>
            </select>
          </label>

          <label class="space-y-1">
            <span class="block text-[11px] font-semibold uppercase tracking-wide text-muted-foreground">Window</span>
            <select name="filters[window]" class="w-full rounded-md border border-border bg-background px-3 py-2 text-sm">
              <option value="all" selected={@filters["window"] == "all"}>all</option>
              <option value="1" selected={@filters["window"] == "1"}>1 day</option>
              <option value="7" selected={@filters["window"] == "7"}>7 days</option>
              <option value="30" selected={@filters["window"] == "30"}>30 days</option>
            </select>
          </label>
        </.form>

        <div class="overflow-x-auto rounded-md border border-border bg-background">
          <table class="min-w-full text-left text-xs">
            <thead class="bg-elevated text-muted-foreground">
              <tr>
                <th class="px-3 py-2 font-semibold">Run</th>
                <th class="px-3 py-2 font-semibold">Status</th>
                <th class="px-3 py-2 font-semibold">When</th>
                <th class="px-3 py-2 font-semibold">Selected</th>
                <th class="px-3 py-2 font-semibold">Written</th>
                <th class="px-3 py-2 font-semibold">Dry-run</th>
                <th class="px-3 py-2 font-semibold">Audit failed</th>
                <th class="px-3 py-2 font-semibold">Verify failed</th>
                <th class="px-3 py-2 font-semibold">Command</th>
                <th class="px-3 py-2 font-semibold">Open</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={run <- @runs} class="border-t border-border/70">
                <td class="px-3 py-2 font-mono text-[11px] text-foreground">{run.run_id}</td>
                <td class="px-3 py-2"><span class={run_status_class(run.status)}>{run.status}</span></td>
                <td class="whitespace-nowrap px-3 py-2 text-muted-foreground">{format_timestamp(run.generated_at)}</td>
                <td class="px-3 py-2 text-muted-foreground">{run.stats.selected}</td>
                <td class="px-3 py-2 text-muted-foreground">{run.stats.written}</td>
                <td class="px-3 py-2 text-muted-foreground">{run.stats.dry_run_candidates}</td>
                <td class="px-3 py-2 text-muted-foreground">{run.stats.audit_failed}</td>
                <td class="px-3 py-2 text-muted-foreground">{run.stats.verification_failed}</td>
                <td class="max-w-[420px] px-3 py-2">
                  <div class="space-y-1">
                    <button
                      type="button"
                      data-copy-button
                      data-content={build_mix_command_from_options(run.options)}
                      class={copy_button_class()}
                    >
                      Copy
                    </button>
                    <pre class="overflow-x-auto rounded border border-border bg-card px-2 py-1 font-mono text-[10px] text-muted-foreground">{build_mix_command_from_options(run.options)}</pre>
                  </div>
                </td>
                <td class="px-3 py-2">
                  <.link
                    patch={~p"/dashboard/content-generator/runs/#{run.run_id}"}
                    class="rounded border border-border px-2 py-1 text-[10px] font-semibold text-foreground hover:border-primary/50"
                  >
                    Open Run
                  </.link>
                </td>
              </tr>
              <tr :if={@runs == []}>
                <td colspan="10" class="px-3 py-3 text-muted-foreground">No runs found for current filters.</td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>
    </div>
    """
  end

  attr :run, :map, required: true

  defp run_page(assigns) do
    ~H"""
    <div :if={@run} class="space-y-6">
      <section class="space-y-3 rounded-lg border border-border bg-card p-5">
        <div class="flex flex-wrap items-center justify-between gap-3">
          <div>
            <p class="text-xs font-semibold uppercase tracking-wide text-muted-foreground">Run Detail</p>
            <h2 class="mt-1 text-xl font-semibold text-foreground">{@run.run_id}</h2>
          </div>
          <div class="flex items-center gap-2">
            <span class={run_status_class(@run.status)}>{@run.status}</span>
            <.link
              patch={~p"/dashboard/content-generator/runs"}
              class="rounded border border-border px-3 py-1.5 text-xs font-semibold text-foreground hover:border-primary/50"
            >
              Back to Runs
            </.link>
          </div>
        </div>

        <div class="grid gap-2 text-xs text-muted-foreground md:grid-cols-4">
          <span>selected: {@run.stats.selected}</span>
          <span>written: {@run.stats.written}</span>
          <span>dry-run: {@run.stats.dry_run_candidates}</span>
          <span>verify failed: {@run.stats.verification_failed}</span>
        </div>

        <p class="text-xs text-muted-foreground">generated: {format_timestamp(@run.generated_at)}</p>
        <p class="text-xs text-muted-foreground">report: {@run.report_path}</p>

        <div class="space-y-1">
          <button type="button" data-copy-button data-content={build_mix_command_from_options(@run.options)} class={copy_button_class()}>
            Copy
          </button>
          <pre class="overflow-x-auto rounded border border-border bg-background px-3 py-2 font-mono text-[11px] text-muted-foreground">{build_mix_command_from_options(@run.options)}</pre>
        </div>
      </section>

      <section class="space-y-4 rounded-lg border border-border bg-card p-5">
        <h3 class="text-base font-semibold text-foreground">Entries</h3>
        <div class="overflow-x-auto rounded-md border border-border bg-background">
          <table class="min-w-full text-left text-xs">
            <thead class="bg-elevated text-muted-foreground">
              <tr>
                <th class="px-3 py-2 font-semibold">Entry</th>
                <th class="px-3 py-2 font-semibold">Status</th>
                <th class="px-3 py-2 font-semibold">Audit</th>
                <th class="px-3 py-2 font-semibold">Verify</th>
                <th class="px-3 py-2 font-semibold">Diff</th>
                <th class="px-3 py-2 font-semibold">Candidate</th>
                <th class="px-3 py-2 font-semibold">Open</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={entry <- @run.entries} class="border-t border-border/70">
                <td class="max-w-[280px] px-3 py-2">
                  <p class="font-semibold text-foreground">{entry.title || entry.id || "-"}</p>
                  <p class="mt-1 font-mono text-[10px] text-muted-foreground">{entry.id}</p>
                </td>
                <td class="px-3 py-2"><span class={entry_status_badge_class(entry.status)}>{entry.status}</span></td>
                <td class="px-3 py-2 text-muted-foreground">errors: {entry.audit.errors |> List.wrap() |> length()}</td>
                <td class="px-3 py-2">
                  <span class={verify_status_badge_class(verify_status_atom(entry.verification.status))}>{entry.verification.status || "unknown"}</span>
                </td>
                <td class="px-3 py-2 text-muted-foreground">
                  {if entry.diff.changed, do: "changed", else: "no change"} ({entry.diff.delta_lines})
                </td>
                <td class="max-w-[260px] truncate px-3 py-2 font-mono text-[10px] text-muted-foreground" title={entry.candidate_path}>
                  {entry.candidate_path || "-"}
                </td>
                <td class="px-3 py-2">
                  <.link
                    :if={entry.id}
                    patch={~p"/dashboard/content-generator/entries/#{entry.id}"}
                    class="rounded border border-border px-2 py-1 text-[10px] font-semibold text-foreground hover:border-primary/50"
                  >
                    Open Entry
                  </.link>
                </td>
              </tr>
              <tr :if={@run.entries == []}>
                <td colspan="7" class="px-3 py-3 text-muted-foreground">No entries recorded for this run.</td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>
    </div>
    """
  end

  @impl true
  def handle_event("sync_form", %{"generator" => params}, socket) do
    params = normalize_form_params(params)

    {:noreply,
     socket
     |> assign(@run_params_key, params)
     |> assign(@run_form_key, to_form(params, as: :generator))
     |> refresh_selected_entry_detail()}
  end

  @impl true
  def handle_event("set_plan_filters", %{"filters" => params}, socket) do
    filters = normalize_plan_filters(params)

    {:noreply,
     socket
     |> assign(:plan_filters, filters)
     |> refresh_plan_rows()}
  end

  def handle_event("set_runs_filters", %{"filters" => params}, socket) do
    filters = normalize_runs_filters(params)

    {:noreply,
     socket
     |> assign(:runs_filters, filters)
     |> refresh_runs()}
  end

  def handle_event("refresh_reports", _params, socket) do
    {:noreply,
     socket
     |> refresh_run_store()
     |> refresh_plan_rows()
     |> refresh_runs()
     |> refresh_selected_entry_detail()
     |> refresh_selected_run()}
  end

  def handle_event("entry_action", %{"entry" => entry_id, "action" => action}, socket) do
    with %{id: ^entry_id} = entry <- ContentPlan.get_entry(entry_id),
         {:ok, params} <- params_for_entry_action(socket.assigns[@run_params_key], entry, action),
         {:ok, run_opts} <- build_run_opts(params),
         {:ok, socket} <- ensure_task_supervisor(socket),
         {:ok, ref} <- start_content_run_task(socket, run_opts) do
      command = build_mix_command(params)
      run_context = start_run_context(run_opts, action, command)
      schedule_run_tick()

      {:noreply,
       socket
       |> assign(@run_params_key, params)
       |> assign(@run_form_key, to_form(params, as: :generator))
       |> assign(@running_key, true)
       |> assign(@run_task_ref_key, ref)
       |> assign(@active_command_key, command)
       |> assign(@run_context_key, run_context)
       |> put_flash(:info, "Started #{action_label(action)} for #{entry.id}.")}
    else
      nil ->
        {:noreply, put_flash(socket, :error, "Unknown entry #{inspect(entry_id)}.")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, reason)}
    end
  end

  def handle_event("start_content_run", %{"generator" => params}, socket) do
    params = normalize_form_params(params)

    socket =
      socket
      |> assign(@run_params_key, params)
      |> assign(@run_form_key, to_form(params, as: :generator))

    if socket.assigns[@running_key] do
      {:noreply, put_flash(socket, :error, "A content generation run is already in progress.")}
    else
      with {:ok, run_opts} <- build_run_opts(params),
           {:ok, socket} <- ensure_task_supervisor(socket),
           {:ok, ref} <- start_content_run_task(socket, run_opts) do
        command = build_mix_command(params)
        run_context = start_run_context(run_opts, "run", command)
        schedule_run_tick()

        {:noreply,
         socket
         |> assign(@running_key, true)
         |> assign(@run_task_ref_key, ref)
         |> assign(@active_command_key, command)
         |> assign(@run_context_key, run_context)
         |> put_flash(:info, "Content generation run started.")}
      else
        {:error, reason} ->
          {:noreply, put_flash(socket, :error, reason)}
      end
    end
  end

  @impl true
  def handle_info({ref, result}, socket) do
    if ref == socket.assigns[@run_task_ref_key] do
      Process.demonitor(ref, [:flush])

      {flash_type, message, run_id} = result_flash(result)

      {:noreply,
       socket
       |> reset_run_state()
       |> refresh_run_store()
       |> refresh_plan_rows()
       |> refresh_runs()
       |> refresh_selected_entry_detail()
       |> refresh_selected_run(run_id)
       |> put_flash(flash_type, message)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, reason}, socket) do
    if ref == socket.assigns[@run_task_ref_key] do
      {:noreply,
       socket
       |> reset_run_state()
       |> refresh_run_store()
       |> refresh_plan_rows()
       |> refresh_runs()
       |> refresh_selected_entry_detail()
       |> put_flash(:error, "Content generation task crashed: #{inspect(reason)}")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(:content_gen_run_tick, socket) do
    if socket.assigns[@running_key] do
      schedule_run_tick()

      {:noreply,
       update(socket, @run_context_key, fn
         %{started_monotonic: started_monotonic} = context ->
           Map.put(context, :elapsed_seconds, elapsed_seconds_since(started_monotonic))

         other ->
           other
       end)}
    else
      {:noreply, socket}
    end
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  defp refresh_run_store(socket) do
    store = load_run_store()

    socket
    |> assign(@run_store_key, store)
    |> assign(:run_warnings, store.warnings)
  end

  defp refresh_plan_rows(socket) do
    rows = build_plan_rows(socket.assigns.entries, socket.assigns[@run_store_key])

    socket
    |> assign(:plan_rows, rows)
    |> assign(:filtered_plan_rows, filter_plan_rows(rows, socket.assigns.plan_filters))
  end

  defp refresh_runs(socket) do
    socket
    |> assign(:filtered_runs, filter_runs(socket.assigns[@run_store_key].runs, socket.assigns.runs_filters))
  end

  defp refresh_selected_entry_detail(socket) do
    case socket.assigns[:selected_entry] do
      nil ->
        assign(socket, :selected_entry_detail, nil)

      entry ->
        assign(
          socket,
          :selected_entry_detail,
          build_entry_detail(entry, socket.assigns[@run_store_key], socket.assigns[@run_params_key])
        )
    end
  end

  defp refresh_selected_run(socket, run_id \\ nil) do
    selected_run = socket.assigns[:selected_run]

    resolved_run_id =
      cond do
        is_binary(run_id) and run_id != "" -> run_id
        is_map(selected_run) -> selected_run.run_id
        true -> nil
      end

    run = if resolved_run_id, do: RunReportStore.get_run(socket.assigns[@run_store_key], resolved_run_id), else: nil
    assign(socket, :selected_run, run)
  end

  defp build_plan_rows(entries, run_store) do
    page_index = PathResolver.page_index()

    entries
    |> Enum.map(fn entry ->
      latest = RunReportStore.latest_entry(run_store, entry.id)
      status = EntryStatus.derive(entry, latest, page_index: page_index, docs_format: :tag)

      %{
        id: entry.id,
        title: entry.title,
        section: entry.section,
        route: entry.destination_route,
        plan_status: entry.status,
        entry: entry,
        status: status,
        last_run_id: status.last_run_id,
        last_run_at: status.last_run_at
      }
    end)
    |> Enum.sort_by(&{&1.section, &1.entry.order, &1.id})
  end

  defp build_entry_detail(entry, run_store, base_params) do
    latest = RunReportStore.latest_entry(run_store, entry.id)
    status = EntryStatus.derive(entry, latest, docs_format: :tag)

    current_text = read_text(status.read_path)

    candidate =
      case latest do
        %{candidate_path: path} when is_binary(path) ->
          %{available?: File.exists?(path), path: path, run_id: latest.run_id, updated_at: file_mtime(path), text: read_text(path)}

        _other ->
          %{available?: false, path: nil, run_id: nil, updated_at: nil, text: nil}
      end

    diff =
      if candidate.available? and is_binary(candidate.text) do
        Diff.unified(current_text, candidate.text, max_lines: 900)
      else
        nil
      end

    commands = %{
      preview: build_entry_action_command(entry, :preview, base_params),
      apply: build_entry_action_command(entry, :apply, base_params),
      apply_verify: build_entry_action_command(entry, :apply_verify, base_params)
    }

    %{
      status: status,
      candidate: candidate,
      diff: diff,
      commands: commands,
      brief_excerpt: brief_excerpt(entry)
    }
  end

  defp brief_excerpt(entry) do
    entry.body
    |> to_string()
    |> String.replace(~r/<[^>]*>/, " ")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
    |> String.slice(0, 900)
  end

  defp read_text(path) when is_binary(path) do
    case File.read(path) do
      {:ok, text} -> text
      {:error, _reason} -> nil
    end
  end

  defp read_text(_path), do: nil

  defp file_mtime(path) when is_binary(path) do
    case File.stat(path, time: :posix) do
      {:ok, stat} -> DateTime.from_unix!(stat.mtime)
      {:error, _reason} -> nil
    end
  end

  defp filter_plan_rows(rows, filters) do
    q = filters["q"] |> to_string() |> String.trim() |> String.downcase()
    section = filters["section"] || "all"
    plan_status = filters["plan_status"] || "all"
    artifact_status = filters["artifact_status"] || "all"
    verify_status = filters["verify_status"] || "all"

    Enum.filter(rows, &plan_row_matches?(&1, q, section, plan_status, artifact_status, verify_status))
  end

  defp filter_runs(runs, filters) do
    q = filters["q"] |> to_string() |> String.trim() |> String.downcase()
    status_filter = filters["status"] || "all"
    window_days = parse_window_days(filters["window"])
    now = DateTime.utc_now()

    Enum.filter(runs, &run_matches_filters?(&1, q, status_filter, window_days, now))
  end

  defp parse_window_days(nil), do: :all
  defp parse_window_days("all"), do: :all

  defp parse_window_days(raw) do
    case Integer.parse(to_string(raw)) do
      {days, ""} when days > 0 -> days
      _other -> :all
    end
  end

  defp normalize_plan_filters(filters) when is_map(filters) do
    %{
      "q" => Map.get(filters, "q", ""),
      "section" => blank_to_default(Map.get(filters, "section"), "all"),
      "plan_status" => blank_to_default(Map.get(filters, "plan_status"), "all"),
      "artifact_status" => blank_to_default(Map.get(filters, "artifact_status"), "all"),
      "verify_status" => blank_to_default(Map.get(filters, "verify_status"), "all")
    }
  end

  defp normalize_plan_filters(_filters), do: default_plan_filters()

  defp normalize_runs_filters(filters) when is_map(filters) do
    %{
      "q" => Map.get(filters, "q", ""),
      "status" => blank_to_default(Map.get(filters, "status"), "all"),
      "window" => blank_to_default(Map.get(filters, "window"), "all")
    }
  end

  defp normalize_runs_filters(_filters), do: default_runs_filters()

  defp default_plan_filters do
    %{
      "q" => "",
      "section" => "all",
      "plan_status" => "all",
      "artifact_status" => "all",
      "verify_status" => "all"
    }
  end

  defp default_runs_filters do
    %{
      "q" => "",
      "status" => "all",
      "window" => "all"
    }
  end

  defp plan_entries do
    ContentPlan.all_entries()
    |> Enum.filter(&(&1.destination_collection == :pages))
  end

  defp params_for_entry_action(base_params, entry, action) do
    normalized = normalize_form_params(base_params)

    params =
      normalized
      |> Map.put("entry", entry.id)
      |> Map.put("sections", entry.section)
      |> Map.put("statuses", Atom.to_string(entry.status))
      |> Map.put("max", "1")
      |> maybe_default_docs_format(entry)

    case action do
      "preview" ->
        {:ok, params |> Map.put("apply", "false") |> Map.put("verify", "false")}

      "apply" ->
        {:ok, params |> Map.put("apply", "true") |> maybe_default_docs_verify(entry)}

      "apply_verify" ->
        {:ok, params |> Map.put("apply", "true") |> Map.put("verify", "true") |> maybe_default_docs_format(entry)}

      _other ->
        {:error, "Unknown entry action #{inspect(action)}."}
    end
  end

  defp maybe_default_docs_format(params, %{section: "docs"}), do: Map.put(params, "docs_format", "livemd")
  defp maybe_default_docs_format(params, _entry), do: params

  defp maybe_default_docs_verify(params, %{section: "docs"}), do: Map.put(params, "verify", "true")
  defp maybe_default_docs_verify(params, _entry), do: params

  defp build_entry_action_command(entry, action, base_params) do
    case params_for_entry_action(base_params, entry, Atom.to_string(action)) do
      {:ok, params} -> build_mix_command(params)
      {:error, _reason} -> "mix content.plan.generate"
    end
  end

  defp build_mix_command_from_options(options) do
    options
    |> mix_command_params()
    |> build_mix_command()
  end

  defp result_flash({:ok, report}) do
    if selected_count(report) == 0 do
      {:error, "Content generation run completed with 0 selected entries. Check status/section filters for the selected entry.", report.run_id}
    else
      {:info, "Content generation run completed.", report.run_id}
    end
  end

  defp result_flash({:error, report}), do: {:error, blocking_failure_message(report), report.run_id}
  defp result_flash(other), do: {:error, "Unexpected run result: #{inspect(other)}", nil}

  defp reset_run_state(socket) do
    socket
    |> assign(@running_key, false)
    |> assign(@run_task_ref_key, nil)
    |> assign(@active_command_key, nil)
    |> assign(@run_context_key, nil)
  end

  defp plan_row_matches?(row, q, section, plan_status, artifact_status, verify_status) do
    plan_row_matches_query?(row, q) and
      (section == "all" or row.section == section) and
      (plan_status == "all" or Atom.to_string(row.plan_status) == plan_status) and
      (artifact_status == "all" or Atom.to_string(row.status.artifact_status) == artifact_status) and
      (verify_status == "all" or Atom.to_string(row.status.verify_status) == verify_status)
  end

  defp plan_row_matches_query?(_row, ""), do: true

  defp plan_row_matches_query?(row, q) do
    [row.id, row.title, row.route]
    |> Enum.map_join(" ", &to_string/1)
    |> String.downcase()
    |> String.contains?(q)
  end

  defp run_matches_filters?(run, q, status_filter, window_days, now) do
    run_matches_query?(run, q) and
      (status_filter == "all" or Atom.to_string(run.status) == status_filter) and
      run_in_window?(run, window_days, now)
  end

  defp run_matches_query?(_run, ""), do: true

  defp run_matches_query?(run, q) do
    haystack = run.run_id <> " " <> Enum.map_join(run.entries, " ", fn entry -> entry.id || "" end)
    String.contains?(String.downcase(haystack), q)
  end

  defp run_in_window?(_run, :all, _now), do: true

  defp run_in_window?(run, days, now) when is_integer(days) do
    case run.generated_at do
      %DateTime{} = generated_at -> DateTime.diff(now, generated_at, :day) <= days
      _other -> false
    end
  end

  defp mix_command_params(options) do
    defaults = [
      {"entry", options.entry, ""},
      {"sections", Enum.join(options.sections || [], ","), ""},
      {"statuses", Enum.join(options.statuses || [], ","), ""},
      {"max", options.max, 10},
      {"backend", options.backend, "auto"},
      {"docs_format", options.docs_format, "tag"},
      {"update_mode", options.update_mode, "improve"},
      {"source_root", options.source_root, ".."},
      {"report", options.report, ""}
    ]

    defaults
    |> Enum.reduce(%{}, &put_option_param(&2, &1))
    |> Map.put("apply", boolean_string(options.apply))
    |> Map.put("verify", boolean_string(options.verify))
    |> Map.put("fail_on_audit", boolean_string(options.fail_on_audit))
  end

  defp boolean_string(value), do: if(value, do: "true", else: "false")

  defp put_option_param(params, {"max", value, default}) do
    Map.put(params, "max", Integer.to_string(value || default))
  end

  defp put_option_param(params, {key, value, default}) do
    Map.put(params, key, value || default)
  end

  defp build_run_opts(params) do
    entry_id = blank_to_nil(params["entry"])
    verify? = parse_boolean(params["verify"], false)
    docs_format = parse_docs_format(params["docs_format"], entry_id)

    with {:ok, max} <- parse_positive_integer(params["max"] || ""),
         {:ok, statuses} <- parse_statuses(params["statuses"] || ""),
         :ok <- validate_verify_scope(verify?, entry_id) do
      opts =
        %{
          apply: parse_boolean(params["apply"], false),
          max: max,
          sections: parse_csv(params["sections"] || ""),
          entry: entry_id,
          statuses: statuses,
          backend: parse_backend(params["backend"]),
          update_mode: parse_update_mode(params["update_mode"]),
          source_root: blank_to_default(params["source_root"], ".."),
          report: blank_to_nil(params["report"]),
          fail_on_audit: parse_boolean(params["fail_on_audit"], true),
          verify: verify?,
          docs_format: docs_format
        }

      {:ok, opts}
    end
  end

  defp parse_statuses(raw) do
    values =
      parse_csv(raw)
      |> case do
        [] -> Enum.map(ContentGen.default_statuses(), &Atom.to_string/1)
        list -> list
      end

    known_statuses =
      ContentPlan.all_entries()
      |> Enum.map(& &1.status)
      |> Enum.uniq()

    statuses =
      Enum.reduce_while(values, [], fn value, acc ->
        case status_atom(value, known_statuses) do
          {:ok, atom} -> {:cont, [atom | acc]}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)

    case statuses do
      {:error, _} = error -> error
      list -> {:ok, Enum.reverse(list)}
    end
  end

  defp parse_positive_integer(raw) do
    case Integer.parse(to_string(raw)) do
      {value, ""} when value > 0 -> {:ok, value}
      _ -> {:error, "Max entries must be a positive integer."}
    end
  end

  defp parse_backend("codex"), do: :req_llm
  defp parse_backend("req_llm"), do: :req_llm
  defp parse_backend(_), do: :req_llm

  defp parse_update_mode("regenerate"), do: :regenerate
  defp parse_update_mode("audit_only"), do: :audit_only
  defp parse_update_mode(_), do: :improve

  defp parse_docs_format(nil, entry_id) when is_binary(entry_id) do
    if String.starts_with?(entry_id, "docs/"), do: :livemd, else: :tag
  end

  defp parse_docs_format(nil, _entry_id), do: :tag

  defp parse_docs_format(format, _entry_id) when is_binary(format) do
    case format |> String.trim() |> String.downcase() do
      "livemd" -> :livemd
      _ -> :tag
    end
  end

  defp parse_docs_format(_other, _entry_id), do: :tag

  defp parse_csv(raw) do
    raw
    |> to_string()
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp parse_boolean(nil, default), do: default
  defp parse_boolean(value, _default), do: value in ["true", "1", "on", true]

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(value) do
    case String.trim(to_string(value)) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp blank_to_default(nil, default), do: default

  defp blank_to_default(value, default) do
    case String.trim(to_string(value)) do
      "" -> default
      trimmed -> trimmed
    end
  end

  defp decode_entry_id(nil), do: nil

  defp decode_entry_id(value) do
    URI.decode(value)
  rescue
    _ -> value
  end

  defp status_atom(value, known_statuses) do
    normalized = value |> to_string() |> String.trim() |> String.downcase()

    try do
      atom = String.to_existing_atom(normalized)

      if atom in known_statuses do
        {:ok, atom}
      else
        {:error, "Unknown status value: #{value}"}
      end
    rescue
      ArgumentError ->
        {:error, "Unknown status value: #{value}"}
    end
  end

  defp default_form_params do
    %{
      "entry" => "",
      "sections" => "",
      "statuses" => Enum.map_join(ContentGen.default_statuses(), ",", &Atom.to_string/1),
      "max" => Integer.to_string(ContentGen.default_batch_size()),
      "backend" => "req_llm",
      "docs_format" => "tag",
      "update_mode" => "improve",
      "source_root" => "..",
      "report" => "",
      "apply" => "false",
      "verify" => "false",
      "fail_on_audit" => "true"
    }
  end

  defp normalize_form_params(params) when is_map(params), do: Map.merge(default_form_params(), params)

  defp validate_verify_scope(false, _entry_id), do: :ok

  defp validate_verify_scope(true, nil),
    do: {:error, "Verify requires a docs entry id (for example: docs/getting-started)."}

  defp validate_verify_scope(true, entry_id) do
    case ContentPlan.get_entry(entry_id) do
      nil ->
        {:error, "Unknown entry id #{inspect(entry_id)}."}

      %{section: "docs"} ->
        :ok

      %{section: section} ->
        {:error, "Verify is docs-only. Selected entry is in section #{inspect(section)}."}
    end
  end

  defp load_run_store do
    opts =
      case Application.get_env(:agent_jido, :content_gen_report_store_opts, []) do
        value when is_list(value) -> value
        _other -> []
      end

    RunReportStore.load(opts)
  end

  defp start_content_run_task(socket, run_opts) do
    supervisor = socket.assigns[@task_supervisor_key]
    run_module = run_module()
    task = Task.Supervisor.async_nolink(supervisor, fn -> run_module.run(run_opts) end)
    {:ok, task.ref}
  rescue
    error -> {:error, "Failed to start run task: #{Exception.message(error)}"}
  end

  defp ensure_task_supervisor(socket) do
    case socket.assigns[@task_supervisor_key] do
      pid when is_pid(pid) ->
        if Process.alive?(pid), do: {:ok, socket}, else: start_task_supervisor(socket)

      _other ->
        start_task_supervisor(socket)
    end
  end

  defp run_module do
    Application.get_env(:agent_jido, :content_gen_run_module, AgentJido.ContentGen.Run)
  end

  defp start_task_supervisor(socket) do
    case Task.Supervisor.start_link() do
      {:ok, pid} -> {:ok, assign(socket, @task_supervisor_key, pid)}
      {:error, reason} -> {:error, "Could not start task supervisor: #{inspect(reason)}"}
    end
  end

  defp build_mix_command(params) when is_map(params) do
    params = normalize_form_params(params)
    defaults = default_form_params()
    entry = blank_to_nil(params["entry"])
    sections = blank_to_nil(params["sections"])
    statuses = blank_to_nil(params["statuses"])
    max = blank_to_nil(params["max"])
    backend = blank_to_nil(params["backend"])
    update_mode = blank_to_nil(params["update_mode"])
    source_root = blank_to_nil(params["source_root"])
    report = blank_to_nil(params["report"])
    docs_format = blank_to_nil(params["docs_format"])

    opts =
      []
      |> append_opt("--entry", entry)
      |> append_opt_when("--section", sections, include_section_opt?(entry, sections, defaults["sections"]))
      |> append_opt_when("--status", statuses, include_status_opt?(entry, statuses, defaults["statuses"]))
      |> append_opt_when("--max", max, include_max_opt?(entry, max, defaults["max"]))
      |> append_opt_when("--backend", backend, backend not in [nil, defaults["backend"]])
      |> append_opt_when("--update-mode", update_mode, update_mode not in [nil, defaults["update_mode"]])
      |> append_opt_when("--source-root", source_root, source_root not in [nil, defaults["source_root"]])
      |> append_opt_when("--report", report, not is_nil(report))
      |> append_opt_when("--docs-format", docs_format, include_docs_format_opt?(entry, docs_format, defaults["docs_format"]))
      |> append_bool_opt("--apply", truthy?(params["apply"]))
      |> append_bool_opt("--verify", truthy?(params["verify"]))
      |> append_negatable_bool_opt("--fail-on-audit", truthy?(params["fail_on_audit"]))

    Enum.join(["mix content.plan.generate" | opts], " ")
  end

  defp include_section_opt?(entry, _sections, _default) when is_binary(entry), do: false
  defp include_section_opt?(_entry, nil, _default), do: false
  defp include_section_opt?(_entry, sections, default), do: sections != blank_to_nil(default)

  defp include_status_opt?(entry, _statuses, _default) when is_binary(entry), do: false
  defp include_status_opt?(_entry, nil, _default), do: false
  defp include_status_opt?(_entry, statuses, default), do: statuses != blank_to_nil(default)

  defp include_max_opt?(entry, max, _default) when is_binary(entry), do: max not in [nil, "1"]
  defp include_max_opt?(_entry, nil, _default), do: false
  defp include_max_opt?(_entry, max, default), do: max != blank_to_nil(default)

  defp include_docs_format_opt?(entry, docs_format, _default) when is_binary(entry) and docs_format == "livemd" do
    not String.starts_with?(entry, "docs/")
  end

  defp include_docs_format_opt?(_entry, nil, _default), do: false
  defp include_docs_format_opt?(_entry, docs_format, default), do: docs_format != blank_to_nil(default)

  defp append_opt_when(opts, _flag, _value, false), do: opts
  defp append_opt_when(opts, flag, value, true), do: append_opt(opts, flag, value)

  defp append_opt(opts, _flag, nil), do: opts

  defp append_opt(opts, flag, value) when is_binary(value) do
    opts ++ [flag, shell_quote(value)]
  end

  defp append_bool_opt(opts, _flag, false), do: opts
  defp append_bool_opt(opts, flag, true), do: opts ++ [flag]

  defp append_negatable_bool_opt(opts, _flag, true), do: opts

  defp append_negatable_bool_opt(opts, flag, false) do
    negated_flag =
      flag
      |> String.trim_leading("--")
      |> then(&"--no-#{&1}")

    opts ++ [negated_flag]
  end

  defp shell_quote(value) when is_binary(value) do
    if Regex.match?(~r/^[A-Za-z0-9_\/\-\.\:]+$/, value) do
      value
    else
      inspect(value)
    end
  end

  defp truthy?(value), do: parse_boolean(value, false)

  defp action_label("preview"), do: "preview generation"
  defp action_label("apply"), do: "apply"
  defp action_label("apply_verify"), do: "apply+verify"
  defp action_label(_), do: "run"

  defp start_run_context(run_opts, action, command) do
    started_monotonic = System.monotonic_time(:second)

    %{
      action: to_string(action),
      action_label: action_label(action),
      entry_id: Map.get(run_opts, :entry),
      command: command,
      started_monotonic: started_monotonic,
      elapsed_seconds: 0
    }
  end

  defp schedule_run_tick do
    Process.send_after(self(), :content_gen_run_tick, @run_tick_ms)
  end

  defp elapsed_seconds_since(started_monotonic) when is_integer(started_monotonic) do
    current = System.monotonic_time(:second)
    max(current - started_monotonic, 0)
  end

  defp elapsed_seconds_since(_), do: 0

  defp run_progress_label(%{action_label: action_label, entry_id: entry_id}) when is_binary(entry_id) and entry_id != "" do
    "Running #{action_label} for #{entry_id}"
  end

  defp run_progress_label(%{action_label: action_label}) when is_binary(action_label) do
    "Running #{action_label}"
  end

  defp run_progress_label(_context), do: "Run in progress"

  defp run_entry_active?(%{entry_id: entry_id}, row_entry_id)
       when is_binary(entry_id) and is_binary(row_entry_id),
       do: entry_id == row_entry_id

  defp run_entry_active?(_context, _row_entry_id), do: false

  defp run_action_short_label(%{action: "apply_verify"}), do: "apply+verify"
  defp run_action_short_label(%{action: "preview"}), do: "preview"
  defp run_action_short_label(%{action: "apply"}), do: "apply"
  defp run_action_short_label(_), do: "run"

  defp run_button_label(%{entry_id: entry_id, action: action}, row_entry_id, action, _default_label)
       when is_binary(entry_id) and is_binary(row_entry_id) and entry_id == row_entry_id do
    case action do
      "preview" -> "Generating..."
      "apply" -> "Applying..."
      "apply_verify" -> "Applying + Verifying..."
      _ -> "Running..."
    end
  end

  defp run_button_label(_run_context, _row_entry_id, _action, default_label), do: default_label

  defp format_elapsed_seconds(seconds) when is_integer(seconds) and seconds >= 0 do
    minutes = div(seconds, 60)
    rem_seconds = rem(seconds, 60)
    "#{minutes}m #{String.pad_leading(Integer.to_string(rem_seconds), 2, "0")}s"
  end

  defp format_elapsed_seconds(_seconds), do: "0m 00s"

  defp blocking_failure_message(report) do
    base = "Content generation run finished with blocking failures."

    failure =
      report.entries
      |> List.wrap()
      |> Enum.find(&blocking_entry_status?(&1.status))

    case failure do
      %{id: id, status: status, reason: reason} ->
        suffix =
          [id, status_label(status), clean_reason(reason)]
          |> Enum.reject(&(&1 in [nil, ""]))
          |> Enum.join(" | ")

        if suffix == "", do: base, else: base <> " " <> suffix

      _other ->
        base
    end
  end

  defp blocking_entry_status?(status)
       when status in [:generation_failed, :parse_failed, :audit_failed, :verification_failed, :churn_blocked],
       do: true

  defp blocking_entry_status?(_status), do: false

  defp status_label(status) when is_atom(status), do: Atom.to_string(status)
  defp status_label(status) when is_binary(status), do: status
  defp status_label(_status), do: nil

  defp clean_reason(reason) when is_binary(reason), do: String.slice(String.trim(reason), 0, 180)
  defp clean_reason(_reason), do: nil

  defp subnav_class(true),
    do: "rounded-md border border-primary/40 bg-primary/10 px-3 py-1.5 text-xs font-semibold text-primary"

  defp subnav_class(false),
    do: "rounded-md border border-border px-3 py-1.5 text-xs font-semibold text-muted-foreground hover:border-primary/50 hover:text-foreground"

  defp copy_button_class,
    do: "rounded border border-border bg-background px-2 py-1 text-[10px] font-semibold text-foreground hover:border-primary/50"

  defp plan_status_badge_class(status) when status in [:draft, :outline] do
    "inline-flex rounded-full border border-primary/30 bg-primary/10 px-2 py-0.5 text-[10px] font-semibold text-primary"
  end

  defp plan_status_badge_class(status) when status in [:review, :published] do
    "inline-flex rounded-full border border-accent-green/30 bg-accent-green/10 px-2 py-0.5 text-[10px] font-semibold text-accent-green"
  end

  defp plan_status_badge_class(_status) do
    "inline-flex rounded-full border border-border bg-background px-2 py-0.5 text-[10px] font-semibold text-muted-foreground"
  end

  defp artifact_status_badge_class(:generated),
    do: "inline-flex rounded-full border border-accent-green/30 bg-accent-green/10 px-2 py-0.5 text-[10px] font-semibold text-accent-green"

  defp artifact_status_badge_class(:stale),
    do: "inline-flex rounded-full border border-accent-yellow/30 bg-accent-yellow/10 px-2 py-0.5 text-[10px] font-semibold text-accent-yellow"

  defp artifact_status_badge_class(:missing),
    do: "inline-flex rounded-full border border-accent-red/30 bg-accent-red/10 px-2 py-0.5 text-[10px] font-semibold text-accent-red"

  defp artifact_status_badge_class(_status),
    do: "inline-flex rounded-full border border-border bg-background px-2 py-0.5 text-[10px] font-semibold text-muted-foreground"

  defp verify_status_badge_class(:passed),
    do: "inline-flex rounded-full border border-accent-green/30 bg-accent-green/10 px-2 py-0.5 text-[10px] font-semibold text-accent-green"

  defp verify_status_badge_class(:failed),
    do: "inline-flex rounded-full border border-accent-red/30 bg-accent-red/10 px-2 py-0.5 text-[10px] font-semibold text-accent-red"

  defp verify_status_badge_class(:skipped),
    do: "inline-flex rounded-full border border-border bg-background px-2 py-0.5 text-[10px] font-semibold text-muted-foreground"

  defp verify_status_badge_class(:unknown),
    do: "inline-flex rounded-full border border-border bg-background px-2 py-0.5 text-[10px] font-semibold text-muted-foreground"

  defp run_status_class(:completed),
    do: "inline-flex items-center rounded bg-accent-green/10 px-2 py-0.5 text-[11px] font-semibold uppercase tracking-wide text-accent-green"

  defp run_status_class(:failed),
    do: "inline-flex items-center rounded bg-accent-red/10 px-2 py-0.5 text-[11px] font-semibold uppercase tracking-wide text-accent-red"

  defp run_status_class(_),
    do: "inline-flex items-center rounded bg-muted px-2 py-0.5 text-[11px] font-semibold uppercase tracking-wide text-muted-foreground"

  defp entry_status_badge_class(status) when is_atom(status), do: entry_status_badge_class(Atom.to_string(status))

  defp entry_status_badge_class("written"),
    do: "inline-flex rounded-full border border-accent-green/30 bg-accent-green/10 px-2 py-0.5 text-[10px] font-semibold text-accent-green"

  defp entry_status_badge_class("dry_run_candidate"),
    do: "inline-flex rounded-full border border-primary/30 bg-primary/10 px-2 py-0.5 text-[10px] font-semibold text-primary"

  defp entry_status_badge_class("verification_failed"),
    do: "inline-flex rounded-full border border-accent-red/30 bg-accent-red/10 px-2 py-0.5 text-[10px] font-semibold text-accent-red"

  defp entry_status_badge_class("generation_failed"),
    do: "inline-flex rounded-full border border-accent-red/30 bg-accent-red/10 px-2 py-0.5 text-[10px] font-semibold text-accent-red"

  defp entry_status_badge_class(_status),
    do: "inline-flex rounded-full border border-border bg-background px-2 py-0.5 text-[10px] font-semibold text-muted-foreground"

  defp plan_row_class(:critical), do: "bg-accent-red/5"
  defp plan_row_class(:attention), do: "bg-accent-yellow/5"
  defp plan_row_class(_), do: ""

  defp diff_line_class(:add), do: "block bg-accent-green/10 text-accent-green"
  defp diff_line_class(:remove), do: "block bg-accent-red/10 text-accent-red"
  defp diff_line_class(:context), do: "block text-foreground"

  defp verify_status_atom(status) when is_atom(status), do: status

  defp verify_status_atom(status) when is_binary(status) do
    case String.downcase(String.trim(status)) do
      "passed" -> :passed
      "failed" -> :failed
      "skipped" -> :skipped
      _ -> :unknown
    end
  end

  defp verify_status_atom(_status), do: :unknown

  defp format_timestamp(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S UTC")
  defp format_timestamp(_), do: "-"

  defp selected_count(report) when is_map(report) do
    stats = Map.get(report, :stats, %{})
    Map.get(stats, :selected) || Map.get(stats, "selected") || 0
  end

  defp selected_count(_report), do: 0
end
