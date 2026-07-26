defmodule AgentJidoWeb.Examples.CounterAgentLive do
  @moduledoc """
  Interactive demo for the Counter Agent example.

  Uses the real `AgentJido.Demos.CounterAgent` with `Jido.Agent.cmd/2`
  to demonstrate agent state management, actions, signals, and LiveView integration.
  """
  use AgentJidoWeb, :live_view

  alias AgentJido.Demos.Counter.{DecrementAction, IncrementAction, ResetAction}
  alias AgentJido.Demos.CounterAgent

  @impl true
  def mount(_params, _session, socket) do
    agent = CounterAgent.new()

    {:ok,
     socket
     |> assign(:agent, agent)
     |> assign(:history, [])
     |> assign(:increment_by, 1)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      id="counter-agent-demo"
      phx-hook="CoreAgentRun"
      class="rounded-lg border border-border bg-card p-6 space-y-6"
    >
      <%!-- Header --%>
      <div class="flex items-center justify-between">
        <div class="flex items-center gap-2">
          <div class="h-2 w-2 rounded-full bg-emerald-400 animate-pulse" />
          <div class="text-sm font-semibold text-foreground">Counter Agent</div>
        </div>
        <div class="text-[10px] text-muted-foreground font-mono bg-elevated px-2 py-0.5 rounded border border-border">
          id: {@agent.id |> String.slice(0..7)}…
        </div>
      </div>

      <%!-- Counter display --%>
      <div class="flex flex-col items-center py-6">
        <div class="text-6xl font-bold text-primary tabular-nums tracking-tight">
          {@agent.state.count}
        </div>
        <div class="text-xs text-muted-foreground mt-1">current count</div>
      </div>

      <%!-- Controls --%>
      <div class="flex items-center justify-center gap-3">
        <button
          phx-click="decrement"
          class="px-4 py-2 rounded-md bg-elevated border border-border text-foreground hover:border-primary/40 hover:bg-elevated/80 transition-colors text-sm font-semibold"
        >
          − 1
        </button>
        <button
          phx-click="reset"
          class="px-3 py-2 rounded-md bg-elevated border border-border text-muted-foreground hover:text-foreground hover:border-destructive/40 transition-colors text-xs"
        >
          Reset
        </button>
        <button
          phx-click="increment"
          class="px-4 py-2 rounded-md bg-primary/10 border border-primary/30 text-primary hover:bg-primary/20 transition-colors text-sm font-semibold"
        >
          + 1
        </button>
      </div>

      <%!-- Custom increment --%>
      <div class="flex items-center justify-center gap-2">
        <form phx-change="set_increment_by" class="flex items-center gap-2">
          <label class="text-xs text-muted-foreground">Increment by:</label>
          <input
            type="number"
            name="by"
            value={@increment_by}
            class="w-20 px-2 py-1 text-sm rounded-md bg-elevated border border-border text-foreground focus:border-primary/50 focus:ring-1 focus:ring-primary/20 outline-none tabular-nums text-center"
          />
        </form>
        <button
          phx-click="increment_by"
          class="px-3 py-1 rounded-md bg-primary/10 border border-primary/30 text-primary hover:bg-primary/20 transition-colors text-xs font-semibold"
        >
          + {@increment_by}
        </button>
        <button
          phx-click="decrement_by"
          class="px-3 py-1 rounded-md bg-elevated border border-border text-foreground hover:border-primary/40 transition-colors text-xs font-semibold"
        >
          − {@increment_by}
        </button>
      </div>

      <%!-- Action history --%>
      <div :if={@history != []} class="border-t border-border pt-4">
        <div class="flex items-center justify-between mb-2">
          <div class="text-[10px] uppercase tracking-wider text-muted-foreground">
            Action History
          </div>
          <div class="text-[10px] text-muted-foreground">
            {length(@history)} event{if length(@history) != 1, do: "s"}
          </div>
        </div>
        <div class="space-y-1 max-h-44 overflow-y-auto">
          <%= for entry <- Enum.take(@history, 20) do %>
            <div class="flex items-start gap-2 text-xs font-mono py-1 px-2 rounded bg-elevated/50">
              <span class="text-primary shrink-0">{entry.signal_type}</span>
              <span class="text-muted-foreground/60 shrink-0">
                {entry.from} → {entry.to}
              </span>
              <span :if={entry.params != %{}} class="text-muted-foreground/40 ml-auto">
                {inspect(entry.params)}
              </span>
            </div>
          <% end %>
        </div>
      </div>

      <%!-- Raw agent state --%>
      <details class="border-t border-border pt-4 group">
        <summary class="text-[10px] uppercase tracking-wider text-muted-foreground cursor-pointer hover:text-foreground transition-colors select-none">
          Raw Agent State <span class="text-muted-foreground/40 group-open:hidden">▸</span>
          <span class="text-muted-foreground/40 hidden group-open:inline">▾</span>
        </summary>
        <pre class="mt-2 p-3 rounded-md bg-elevated border border-border text-xs text-muted-foreground font-mono overflow-x-auto whitespace-pre-wrap"><%= inspect(@agent, pretty: true, width: 60) %></pre>
      </details>
    </div>
    """
  end

  # ── Event Handlers ──────────────────────────────────────────

  @impl true
  def handle_event("increment", _params, socket) do
    {:noreply, dispatch_action(socket, "counter.increment", IncrementAction, %{by: 1})}
  end

  def handle_event("decrement", _params, socket) do
    {:noreply, dispatch_action(socket, "counter.decrement", DecrementAction, %{by: 1})}
  end

  def handle_event("reset", _params, socket) do
    {:noreply, dispatch_action(socket, "counter.reset", ResetAction, %{})}
  end

  def handle_event("increment_by", _params, socket) do
    amount = socket.assigns.increment_by

    {:noreply, dispatch_action(socket, "counter.increment", IncrementAction, %{by: amount})}
  end

  def handle_event("decrement_by", _params, socket) do
    amount = socket.assigns.increment_by

    {:noreply, dispatch_action(socket, "counter.decrement", DecrementAction, %{by: amount})}
  end

  def handle_event("set_increment_by", %{"by" => by_str}, socket) do
    case Integer.parse(by_str) do
      {val, _} when val >= 1 -> {:noreply, assign(socket, :increment_by, val)}
      _ -> {:noreply, socket}
    end
  end

  # ── Helpers ─────────────────────────────────────────────────

  defp dispatch_action(socket, signal_type, action_module, params) do
    agent = socket.assigns.agent
    old_count = agent.state.count

    # Execute the action via Jido's cmd/2 — the core agent operation
    {new_agent, _directives} = CounterAgent.cmd(agent, {action_module, params})

    new_count = new_agent.state.count

    action_name = action_module |> Module.split() |> List.last()

    entry = %{
      signal_type: signal_type,
      action: action_name,
      params: params,
      from: old_count,
      to: new_count,
      at: DateTime.utc_now()
    }

    # A successful cmd/2 is a real core Agent operation completing — the
    # explicit success signal this demo can prove (jido-e12-t23). The
    # CoreAgentRun hook forwards it to first-party analytics as
    # `agent_run_succeeded` so the team measures first core Agent success,
    # not only page views of the example.
    socket
    |> assign(:agent, new_agent)
    |> assign(:history, [entry | socket.assigns.history])
    |> push_event("agent-run-succeeded", %{example: "counter-agent", action: action_name})
  end
end
