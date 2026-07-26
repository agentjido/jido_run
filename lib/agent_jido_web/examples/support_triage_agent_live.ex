defmodule AgentJidoWeb.Examples.SupportTriageAgentLive do
  @moduledoc """
  Interactive demo for the Support Triage Agent example.

  Uses the real `AgentJido.Demos.SupportTriage` with `Jido.Agent.cmd/2` to show
  a support-triage workflow on the Jido runtime: load an inbound customer
  message, run a typed ClassifyIntent action that scores real keyword signals,
  run a typed AssessUrgency action that flags angry or deadline-driven messages,
  and run a typed Respond action that drafts a routed reply. No LLM provider is
  called -- the triage is deterministic pattern matching, so the demo needs no
  API key.
  """

  use AgentJidoWeb, :live_view

  alias AgentJido.Demos.SupportTriage

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:agent, SupportTriage.new())
     |> assign(:history, [])}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="support-triage-demo" class="rounded-lg border border-border bg-card p-6 space-y-6">
      <%!-- Header --%>
      <div class="flex items-center justify-between gap-4">
        <div>
          <div class="text-sm font-semibold text-foreground">Support Triage Agent</div>
          <div class="text-[11px] text-muted-foreground">
            Real Jido runtime · deterministic classify / assess / respond · no LLM required
          </div>
        </div>
        <div class="text-[10px] text-muted-foreground font-mono bg-elevated px-2 py-0.5 rounded border border-border">
          id: {@agent.id |> String.slice(0..7)}…
        </div>
      </div>

      <%!-- Controls --%>
      <div class="flex flex-wrap gap-3">
        <button
          phx-click="load_billing"
          class="px-4 py-2 rounded-md bg-primary/10 border border-primary/30 text-primary hover:bg-primary/20 transition-colors text-sm font-semibold"
        >
          Load billing
        </button>
        <button
          phx-click="load_bug"
          class="px-4 py-2 rounded-md bg-primary/10 border border-primary/30 text-primary hover:bg-primary/20 transition-colors text-sm font-semibold"
        >
          Load bug report
        </button>
        <button
          phx-click="load_howto"
          class="px-4 py-2 rounded-md bg-primary/10 border border-primary/30 text-primary hover:bg-primary/20 transition-colors text-sm font-semibold"
        >
          Load how-to
        </button>
        <button
          phx-click="classify"
          class="px-4 py-2 rounded-md bg-accent-cyan/10 border border-accent-cyan/30 text-accent-cyan hover:bg-accent-cyan/20 transition-colors text-sm font-semibold"
        >
          Classify
        </button>
        <button
          phx-click="assess"
          class="px-4 py-2 rounded-md bg-accent-yellow/10 border border-accent-yellow/30 text-accent-yellow hover:bg-accent-yellow/20 transition-colors text-sm font-semibold"
        >
          Assess urgency
        </button>
        <button
          phx-click="respond"
          class="px-4 py-2 rounded-md bg-emerald-500/10 border border-emerald-500/30 text-emerald-300 hover:bg-emerald-500/20 transition-colors text-sm font-semibold"
        >
          Respond
        </button>
        <button
          phx-click="reset"
          class="px-3 py-2 rounded-md bg-elevated border border-border text-muted-foreground hover:text-foreground hover:border-primary/40 transition-colors text-xs"
        >
          Reset
        </button>
      </div>

      <div class="grid gap-4 lg:grid-cols-2">
        <%!-- Incoming message --%>
        <div class="rounded-md border border-border bg-elevated p-4 space-y-2">
          <div class="flex items-center justify-between">
            <div class="text-[10px] uppercase tracking-wider text-muted-foreground">
              Incoming message
            </div>
            <div class="text-[10px] text-muted-foreground">
              {if @agent.state.incoming_message == "", do: "idle", else: "loaded"}
            </div>
          </div>
          <pre class="text-[12px] text-foreground whitespace-pre-wrap min-h-40 font-mono"><%= if @agent.state.incoming_message == "",
                       do: "Load a billing question, bug report, or how-to question to start the triage.",
                       else: @agent.state.incoming_message %></pre>
        </div>

        <div class="space-y-4">
          <%!-- Intent --%>
          <div class="rounded-md border border-border bg-elevated p-4 space-y-2">
            <div class="flex items-center justify-between">
              <div class="text-[10px] uppercase tracking-wider text-muted-foreground">
                Intent
              </div>
              <div class="text-[10px] text-muted-foreground">
                {if @agent.state.intent == "",
                  do: "not classified",
                  else: @agent.state.intent}
              </div>
            </div>
            <pre class="text-[12px] text-foreground whitespace-pre-wrap min-h-12 font-mono"><%= if @agent.state.intent == "",
                         do: "Classify the loaded message to detect its intent.",
                         else: "intent: #{@agent.state.intent}" %></pre>
          </div>

          <%!-- Urgency --%>
          <div class="rounded-md border border-border bg-elevated p-4 space-y-2">
            <div class="flex items-center justify-between">
              <div class="text-[10px] uppercase tracking-wider text-muted-foreground">
                Urgency
              </div>
              <div class="text-[10px] text-muted-foreground">
                {if @agent.state.urgency == "",
                  do: "not assessed",
                  else: @agent.state.urgency}
              </div>
            </div>
            <pre class="text-[12px] text-foreground whitespace-pre-wrap min-h-12 font-mono"><%= if @agent.state.urgency == "",
                         do: "Assess the loaded message to gauge its urgency.",
                         else: "urgency: #{@agent.state.urgency}" %></pre>
          </div>

          <%!-- Suggested response --%>
          <div class="rounded-md border border-border bg-elevated p-4 space-y-2">
            <div class="text-[10px] uppercase tracking-wider text-muted-foreground">
              Suggested response
            </div>
            <pre class="text-[12px] text-foreground whitespace-pre-wrap min-h-16 font-mono"><%= if @agent.state.response == "",
                         do: "Respond to draft a routed reply for the message.",
                         else: @agent.state.response %></pre>
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
  def handle_event("load_billing", _params, socket) do
    {:noreply, run(socket, "support.load", fn agent -> SupportTriage.load_message(agent, :billing) end, "Loaded billing fixture.")}
  end

  def handle_event("load_bug", _params, socket) do
    {:noreply, run(socket, "support.load", fn agent -> SupportTriage.load_message(agent, :bug) end, "Loaded bug-report fixture.")}
  end

  def handle_event("load_howto", _params, socket) do
    {:noreply, run(socket, "support.load", fn agent -> SupportTriage.load_message(agent, :howto) end, "Loaded how-to fixture.")}
  end

  def handle_event("classify", _params, socket) do
    {:noreply,
     run(socket, "support.classify", &SupportTriage.classify/1, fn agent ->
       "Classified as #{agent.state.intent}."
     end)}
  end

  def handle_event("assess", _params, socket) do
    {:noreply,
     run(socket, "support.assess", &SupportTriage.assess/1, fn agent ->
       "Urgency is #{agent.state.urgency}."
     end)}
  end

  def handle_event("respond", _params, socket) do
    {:noreply, run(socket, "support.respond", &SupportTriage.respond/1, "Drafted a routed reply.")}
  end

  def handle_event("reset", _params, socket) do
    {:noreply,
     socket
     |> assign(:agent, SupportTriage.new())
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
