defmodule AgentJidoWeb.Examples.DataPipelineAgentLive do
  @moduledoc """
  Interactive demo for the Data Pipeline Agent example.

  Uses the real `AgentJido.Demos.DataPipeline` with `Jido.Agent.cmd/2` to show a
  collect → validate → transform → load → summarize ETL pipeline on the Jido
  runtime: collect records from one or more fixture sources, run a typed
  ValidateRecords action that checks each source's schema, run a typed
  TransformRecords action that normalizes and de-duplicates the batch, run a
  typed LoadRecords action that writes the batch and produces a stable checksum,
  and run a typed Summarize action that rolls the run up. No LLM provider is
  called -- the pipeline is deterministic record logic, so the demo needs no API
  key and no network.
  """

  use AgentJidoWeb, :live_view

  alias AgentJido.Demos.DataPipeline

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:agent, DataPipeline.new())
     |> assign(:history, [])}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="data-pipeline-demo" class="rounded-lg border border-border bg-card p-6 space-y-6">
      <%!-- Header --%>
      <div class="flex items-center justify-between gap-4">
        <div>
          <div class="text-sm font-semibold text-foreground">Data Pipeline Agent</div>
          <div class="text-[11px] text-muted-foreground">
            Real Jido runtime · deterministic collect / validate / transform / load · no LLM required
          </div>
        </div>
        <div class="text-[10px] text-muted-foreground font-mono bg-elevated px-2 py-0.5 rounded border border-border">
          id: {@agent.id |> String.slice(0..7)}…
        </div>
      </div>

      <%!-- Controls --%>
      <div class="flex flex-wrap gap-3">
        <button
          phx-click="ingest_orders"
          class="px-4 py-2 rounded-md bg-primary/10 border border-primary/30 text-primary hover:bg-primary/20 transition-colors text-sm font-semibold"
        >
          Collect orders
        </button>
        <button
          phx-click="ingest_users"
          class="px-4 py-2 rounded-md bg-primary/10 border border-primary/30 text-primary hover:bg-primary/20 transition-colors text-sm font-semibold"
        >
          Collect users
        </button>
        <button
          phx-click="ingest_events"
          class="px-4 py-2 rounded-md bg-primary/10 border border-primary/30 text-primary hover:bg-primary/20 transition-colors text-sm font-semibold"
        >
          Collect events
        </button>
        <button
          phx-click="ingest_all"
          class="px-4 py-2 rounded-md bg-primary/10 border border-primary/30 text-primary hover:bg-primary/20 transition-colors text-sm font-semibold"
        >
          Collect all sources
        </button>
        <button
          phx-click="validate"
          class="px-4 py-2 rounded-md bg-accent-cyan/10 border border-accent-cyan/30 text-accent-cyan hover:bg-accent-cyan/20 transition-colors text-sm font-semibold"
        >
          Validate
        </button>
        <button
          phx-click="transform"
          class="px-4 py-2 rounded-md bg-accent-yellow/10 border border-accent-yellow/30 text-accent-yellow hover:bg-accent-yellow/20 transition-colors text-sm font-semibold"
        >
          Transform
        </button>
        <button
          phx-click="load"
          class="px-4 py-2 rounded-md bg-emerald-500/10 border border-emerald-500/30 text-emerald-300 hover:bg-emerald-500/20 transition-colors text-sm font-semibold"
        >
          Load
        </button>
        <button
          phx-click="summarize"
          class="px-4 py-2 rounded-md bg-accent-green/10 border border-accent-green/30 text-accent-green hover:bg-accent-green/20 transition-colors text-sm font-semibold"
        >
          Summarize
        </button>
        <button
          phx-click="reset"
          class="px-3 py-2 rounded-md bg-elevated border border-border text-muted-foreground hover:text-foreground hover:border-primary/40 transition-colors text-xs"
        >
          Reset
        </button>
      </div>

      <div class="grid gap-4 lg:grid-cols-2">
        <%!-- Collected batch --%>
        <div class="rounded-md border border-border bg-elevated p-4 space-y-2">
          <div class="flex items-center justify-between">
            <div class="text-[10px] uppercase tracking-wider text-muted-foreground">
              Collected batch
            </div>
            <div class="text-[10px] text-muted-foreground">
              {length(@agent.state.ingested)} record{if length(@agent.state.ingested) != 1, do: "s"}
            </div>
          </div>
          <pre class="text-[12px] text-foreground whitespace-pre-wrap min-h-40 font-mono"><%= batch_snapshot(@agent) %></pre>
        </div>

        <div class="space-y-4">
          <%!-- Validation --%>
          <div class="rounded-md border border-border bg-elevated p-4 space-y-2">
            <div class="flex items-center justify-between">
              <div class="text-[10px] uppercase tracking-wider text-muted-foreground">
                Validation
              </div>
              <div class="text-[10px] text-muted-foreground">
                {length(@agent.state.valid)} valid · {length(@agent.state.rejected)} rejected
              </div>
            </div>
            <pre class="text-[12px] text-foreground whitespace-pre-wrap min-h-12 font-mono"><%= validation_snapshot(@agent) %></pre>
          </div>

          <%!-- Transform --%>
          <div class="rounded-md border border-border bg-elevated p-4 space-y-2">
            <div class="flex items-center justify-between">
              <div class="text-[10px] uppercase tracking-wider text-muted-foreground">
                Transform
              </div>
              <div class="text-[10px] text-muted-foreground">
                {length(@agent.state.transformed)} canonical record{if length(@agent.state.transformed) != 1, do: "s"}
              </div>
            </div>
            <pre class="text-[12px] text-foreground whitespace-pre-wrap min-h-12 font-mono"><%= transform_snapshot(@agent) %></pre>
          </div>

          <%!-- Load --%>
          <div class="rounded-md border border-border bg-elevated p-4 space-y-2">
            <div class="flex items-center justify-between">
              <div class="text-[10px] uppercase tracking-wider text-muted-foreground">
                Load
              </div>
              <div class="text-[10px] text-muted-foreground">
                {if @agent.state.destination_checksum == "",
                  do: "not loaded",
                  else: @agent.state.destination_checksum}
              </div>
            </div>
            <pre class="text-[12px] text-foreground whitespace-pre-wrap min-h-12 font-mono"><%= if @agent.state.loaded_count == 0 and @agent.state.destination_checksum == "",
                         do: "Load to write the transformed batch and produce a checksum.",
                         else: "loaded #{@agent.state.loaded_count} records → #{@agent.state.destination_checksum}" %></pre>
          </div>
        </div>
      </div>

      <%!-- Run report --%>
      <div class="rounded-md border border-border bg-elevated p-4 space-y-2">
        <div class="text-[10px] uppercase tracking-wider text-muted-foreground">
          Run report
        </div>
        <pre class="text-[12px] text-foreground whitespace-pre-wrap min-h-8 font-mono"><%= if @agent.state.report == "",
                     do: "Summarize to roll the run up into one report.",
                     else: @agent.state.report %></pre>
      </div>

      <%!-- Action history --%>
      <div :if={@history != []} class="border-t border-border pt-4">
        <div class="flex items-center justify-between mb-2">
          <div class="text-[10px] uppercase tracking-wider text-muted-foreground">
            Action history
          </div>
          <div class="text-[10px] text-muted-foreground">
            {length(@history)} step{if length(@history) != 1, do: "s"}
          </div>
        </div>
        <div class="space-y-1 max-h-44 overflow-y-auto">
          <%= for entry <- Enum.take(@history, 20) do %>
            <div class="flex items-start gap-2 text-xs font-mono py-1 px-2 rounded bg-elevated/50">
              <span class="text-primary shrink-0">{entry.signal_type}</span>
              <span class="text-muted-foreground">{entry.detail}</span>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # ── Event Handlers ──────────────────────────────────────────

  @impl true
  def handle_event("ingest_orders", _params, socket) do
    {:noreply, run(socket, "data.ingest", fn agent -> DataPipeline.ingest(agent, :orders) end, "Collected orders source.")}
  end

  def handle_event("ingest_users", _params, socket) do
    {:noreply, run(socket, "data.ingest", fn agent -> DataPipeline.ingest(agent, :users) end, "Collected users source.")}
  end

  def handle_event("ingest_events", _params, socket) do
    {:noreply, run(socket, "data.ingest", fn agent -> DataPipeline.ingest(agent, :events) end, "Collected events source.")}
  end

  def handle_event("ingest_all", _params, socket) do
    {:noreply, run(socket, "data.ingest", &DataPipeline.ingest_all/1, "Collected all sources.")}
  end

  def handle_event("validate", _params, socket) do
    {:noreply,
     run(socket, "data.validate", &DataPipeline.validate_records/1, fn agent ->
       "#{length(agent.state.valid)} valid, #{length(agent.state.rejected)} rejected."
     end)}
  end

  def handle_event("transform", _params, socket) do
    {:noreply,
     run(socket, "data.transform", &DataPipeline.transform_records/1, fn agent ->
       "#{length(agent.state.transformed)} canonical records."
     end)}
  end

  def handle_event("load", _params, socket) do
    {:noreply,
     run(socket, "data.load", &DataPipeline.load_records/1, fn agent ->
       "Loaded #{agent.state.loaded_count} records (#{agent.state.destination_checksum})."
     end)}
  end

  def handle_event("summarize", _params, socket) do
    {:noreply, run(socket, "data.summarize", &DataPipeline.summarize_run/1, "Summarized the run.")}
  end

  def handle_event("reset", _params, socket) do
    {:noreply,
     socket
     |> assign(:agent, DataPipeline.new())
     |> assign(:history, [
       %{signal_type: "reset", detail: "Cleared agent state and history."} | socket.assigns.history
     ])}
  end

  # ── Helpers ─────────────────────────────────────────────────

  defp run(socket, signal_type, action_fun, detail) do
    {new_agent, _directives} = action_fun.(socket.assigns.agent)

    entry = %{
      signal_type: signal_type,
      detail: detail_fun(detail, new_agent),
      at: DateTime.utc_now()
    }

    socket
    |> assign(:agent, new_agent)
    |> assign(:history, [entry | socket.assigns.history])
  end

  defp detail_fun(detail, agent) when is_function(detail, 1), do: detail.(agent)
  defp detail_fun(detail, _agent), do: detail

  defp batch_snapshot(agent) do
    sources =
      agent.state.sources_loaded
      |> Enum.map_join(", ", & &1)

    if agent.state.ingested == [] do
      "Collect orders, users, or events to start the pipeline."
    else
      records =
        agent.state.ingested
        |> Enum.take(8)
        |> Enum.map_join("\n", fn r -> "  #{r.source} ##{r[:id]} #{inspect(Map.delete(r, :source))}" end)

      more = if length(agent.state.ingested) > 8, do: "\n  …#{length(agent.state.ingested) - 8} more", else: ""

      "sources: [#{sources}]\n#{records}#{more}"
    end
  end

  defp validation_snapshot(agent) do
    valid = length(agent.state.valid)
    rejected = length(agent.state.rejected)

    cond do
      agent.state.ingested == [] and valid == 0 and rejected == 0 ->
        "Collect a source, then Validate to check each record against its schema."

      valid == 0 and rejected == 0 ->
        "Validate to partition the batch into valid and rejected records."

      true ->
        reasons =
          agent.state.rejected
          |> Enum.map_join("\n", fn r -> "  reject: #{r.reason}" end)

        "#{valid} valid, #{rejected} rejected\n#{reasons}"
    end
  end

  defp transform_snapshot(agent) do
    if agent.state.transformed == [] do
      "Transform to normalize and de-duplicate the valid batch."
    else
      agent.state.transformed
      |> Enum.take(6)
      |> Enum.map_join("\n", fn r -> "  #{r.source} ##{r[:id]} #{inspect(Map.delete(r, :source))}" end)
    end
  end
end
