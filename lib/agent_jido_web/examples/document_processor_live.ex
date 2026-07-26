defmodule AgentJidoWeb.Examples.DocumentProcessorLive do
  @moduledoc """
  Interactive demo for the Document Processor example.

  Uses the real `AgentJido.Demos.DocumentProcessor` with `Jido.Agent.cmd/2` to
  show the document-processing workflow on the Jido runtime: load an inbound
  document, run a typed ClassifyDocument action that scores real keyword
  signals, run a typed ExtractFields action that pulls structured fields from the
  text, and run a typed RouteDocument action that picks a destination queue. No
  LLM provider is called -- the analysis is deterministic pattern matching, so
  the demo needs no API key.
  """

  use AgentJidoWeb, :live_view

  alias AgentJido.Demos.DocumentProcessor

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:agent, DocumentProcessor.new())
     |> assign(:history, [])}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="document-processor-demo" class="rounded-lg border border-border bg-card p-6 space-y-6">
      <%!-- Header --%>
      <div class="flex items-center justify-between gap-4">
        <div>
          <div class="text-sm font-semibold text-foreground">Document Processor Agent</div>
          <div class="text-[11px] text-muted-foreground">
            Real Jido runtime · deterministic classify / extract / route · no LLM required
          </div>
        </div>
        <div class="text-[10px] text-muted-foreground font-mono bg-elevated px-2 py-0.5 rounded border border-border">
          id: {@agent.id |> String.slice(0..7)}…
        </div>
      </div>

      <%!-- Controls --%>
      <div class="flex flex-wrap gap-3">
        <button
          phx-click="load_invoice"
          class="px-4 py-2 rounded-md bg-primary/10 border border-primary/30 text-primary hover:bg-primary/20 transition-colors text-sm font-semibold"
        >
          Load invoice
        </button>
        <button
          phx-click="load_contract"
          class="px-4 py-2 rounded-md bg-primary/10 border border-primary/30 text-primary hover:bg-primary/20 transition-colors text-sm font-semibold"
        >
          Load contract
        </button>
        <button
          phx-click="load_ticket"
          class="px-4 py-2 rounded-md bg-primary/10 border border-primary/30 text-primary hover:bg-primary/20 transition-colors text-sm font-semibold"
        >
          Load ticket
        </button>
        <button
          phx-click="classify"
          class="px-4 py-2 rounded-md bg-accent-cyan/10 border border-accent-cyan/30 text-accent-cyan hover:bg-accent-cyan/20 transition-colors text-sm font-semibold"
        >
          Classify
        </button>
        <button
          phx-click="extract"
          class="px-4 py-2 rounded-md bg-accent-yellow/10 border border-accent-yellow/30 text-accent-yellow hover:bg-accent-yellow/20 transition-colors text-sm font-semibold"
        >
          Extract fields
        </button>
        <button
          phx-click="route"
          class="px-4 py-2 rounded-md bg-emerald-500/10 border border-emerald-500/30 text-emerald-300 hover:bg-emerald-500/20 transition-colors text-sm font-semibold"
        >
          Route
        </button>
        <button
          phx-click="reset"
          class="px-3 py-2 rounded-md bg-elevated border border-border text-muted-foreground hover:text-foreground hover:border-primary/40 transition-colors text-xs"
        >
          Reset
        </button>
      </div>

      <div class="grid gap-4 lg:grid-cols-2">
        <%!-- Incoming document --%>
        <div class="rounded-md border border-border bg-elevated p-4 space-y-2">
          <div class="flex items-center justify-between">
            <div class="text-[10px] uppercase tracking-wider text-muted-foreground">
              Incoming document
            </div>
            <div class="text-[10px] text-muted-foreground">
              {if @agent.state.incoming_document == "", do: "idle", else: "loaded"}
            </div>
          </div>
          <pre class="text-[12px] text-foreground whitespace-pre-wrap min-h-40 font-mono"><%= if @agent.state.incoming_document == "",
                       do: "Load an invoice, contract, or support ticket to start the pipeline.",
                       else: @agent.state.incoming_document %></pre>
        </div>

        <div class="space-y-4">
          <%!-- Classification --%>
          <div class="rounded-md border border-border bg-elevated p-4 space-y-2">
            <div class="flex items-center justify-between">
              <div class="text-[10px] uppercase tracking-wider text-muted-foreground">
                Classification
              </div>
              <div class="text-[10px] text-muted-foreground">
                {if @agent.state.classification == "",
                  do: "not classified",
                  else: @agent.state.classification}
              </div>
            </div>
            <pre class="text-[12px] text-foreground whitespace-pre-wrap min-h-12 font-mono"><%= if @agent.state.classification == "",
                         do: "Classify the loaded document to detect its type.",
                         else: "type: #{@agent.state.classification}" %></pre>
          </div>

          <%!-- Extracted fields --%>
          <div class="rounded-md border border-border bg-elevated p-4 space-y-2">
            <div class="text-[10px] uppercase tracking-wider text-muted-foreground">
              Extracted fields
            </div>
            <pre class="text-[12px] text-foreground whitespace-pre-wrap min-h-16 font-mono"><%= if @agent.state.extracted_fields == "",
                         do: "Extract structured fields from the classified document.",
                         else: @agent.state.extracted_fields %></pre>
          </div>

          <%!-- Routing --%>
          <div class="rounded-md border border-border bg-elevated p-4 space-y-2">
            <div class="text-[10px] uppercase tracking-wider text-muted-foreground">
              Routing destination
            </div>
            <pre class="text-[12px] text-foreground whitespace-pre-wrap min-h-12 font-mono"><%= if @agent.state.routing == "",
                         do: "Route the document to a destination queue.",
                         else: @agent.state.routing %></pre>
          </div>
        </div>
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
  def handle_event("load_invoice", _params, socket) do
    {:noreply, run(socket, "document.load", fn agent -> DocumentProcessor.load_document(agent, :invoice) end, "Loaded invoice fixture.")}
  end

  def handle_event("load_contract", _params, socket) do
    {:noreply, run(socket, "document.load", fn agent -> DocumentProcessor.load_document(agent, :contract) end, "Loaded contract fixture.")}
  end

  def handle_event("load_ticket", _params, socket) do
    {:noreply, run(socket, "document.load", fn agent -> DocumentProcessor.load_document(agent, :ticket) end, "Loaded support-ticket fixture.")}
  end

  def handle_event("classify", _params, socket) do
    {:noreply,
     run(socket, "document.classify", &DocumentProcessor.classify/1, fn agent ->
       "Classified as #{agent.state.classification}."
     end)}
  end

  def handle_event("extract", _params, socket) do
    {:noreply, run(socket, "document.extract", &DocumentProcessor.extract/1, "Extracted fields from the document.")}
  end

  def handle_event("route", _params, socket) do
    {:noreply,
     run(socket, "document.route", &DocumentProcessor.route/1, fn agent ->
       "Routed to #{agent.state.routing}."
     end)}
  end

  def handle_event("reset", _params, socket) do
    {:noreply,
     socket
     |> assign(:agent, DocumentProcessor.new())
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
end
