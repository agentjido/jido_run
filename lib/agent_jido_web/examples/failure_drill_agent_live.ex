defmodule AgentJidoWeb.Examples.FailureDrillAgentLive do
  @moduledoc """
  Interactive demo for the **Run a failure drill** example.

  Runs a real `Jido.AgentServer` under an OTP supervisor (`:permanent`
  restart). Visitors tick the agent's counter, then crash the process and
  watch supervision recover it. The counter resets on restart — the drill
  makes the supervision boundary (what OTP restarts) and the durability
  boundary (what is lost without persistence) visible in one screen.
  """

  use AgentJidoWeb, :live_view

  alias AgentJido.Demos.FailureDrill.Supervisor, as: DrillSupervisor
  alias AgentJido.Demos.FailureDrillAgent
  alias Jido.AgentServer
  alias Jido.Signal

  @poll_interval_ms 500

  @impl true
  def mount(_params, _session, socket) do
    fallback_agent = FailureDrillAgent.new(id: "failure-drill-preview")

    socket =
      socket
      |> assign(:sup_pid, nil)
      |> assign(:server_pid, nil)
      |> assign(:agent, fallback_agent)
      |> assign(:restart_count, 0)
      |> assign(:last_crash, nil)
      |> assign(:log_entries, [])
      |> assign(:last_error, nil)

    socket =
      if connected?(socket) do
        case start_drill() do
          {:ok, sup_pid, server_pid, agent} ->
            Process.send_after(self(), :poll_state, @poll_interval_ms)

            socket
            |> assign(:sup_pid, sup_pid)
            |> assign(:server_pid, server_pid)
            |> assign(:agent, agent)

          {:error, reason} ->
            assign(socket, :last_error, "Failed to start runtime: #{inspect(reason)}")
        end
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def terminate(_reason, socket) do
    if sup_pid = socket.assigns[:sup_pid] do
      if Process.alive?(sup_pid), do: Supervisor.stop(sup_pid, :normal)
    end

    :ok
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="failure-drill-demo" class="rounded-lg border border-border bg-card p-6 space-y-6">
      <div class="flex items-center justify-between">
        <div class="flex items-center gap-2">
          <div class="h-2 w-2 rounded-full bg-accent-green animate-pulse" />
          <div class="text-sm font-semibold text-foreground">Failure Drill Agent</div>
        </div>
        <div id="failure-drill-pid" class="text-[10px] text-muted-foreground font-mono bg-elevated px-2 py-0.5 rounded border border-border">
          pid: {format_pid(@server_pid)}
        </div>
      </div>

      <div :if={@last_error} class="rounded-md border border-red-400/30 bg-red-400/10 px-3 py-2 text-xs text-red-300">
        {@last_error}
      </div>

      <div class="grid sm:grid-cols-3 gap-3">
        <div class="rounded-md border border-border bg-elevated p-3 text-center">
          <div class="text-[10px] uppercase tracking-wider text-muted-foreground">Ticks (in-memory state)</div>
          <div id="failure-drill-ticks" class="text-2xl font-bold text-foreground mt-1 tabular-nums">
            {@agent.state.ticks}
          </div>
        </div>
        <div class="rounded-md border border-border bg-elevated p-3 text-center">
          <div class="text-[10px] uppercase tracking-wider text-muted-foreground">Restarts observed</div>
          <div id="failure-drill-restarts" class="text-2xl font-bold text-accent-yellow mt-1 tabular-nums">
            {@restart_count}
          </div>
        </div>
        <div class="rounded-md border border-border bg-elevated p-3 text-center">
          <div class="text-[10px] uppercase tracking-wider text-muted-foreground">Last crash</div>
          <div class="text-xs font-semibold text-foreground mt-2">
            {format_crash(@last_crash)}
          </div>
        </div>
      </div>

      <div class="grid gap-3 sm:grid-cols-2">
        <button
          id="failure-drill-tick-btn"
          phx-click="tick"
          class="rounded-md border border-primary/30 bg-primary/10 p-3 text-left hover:bg-primary/20 transition-colors"
        >
          <div class="text-[10px] uppercase tracking-wider text-muted-foreground">call: failure_drill.tick</div>
          <div class="text-sm text-primary mt-1 font-semibold">Tick the agent (+1)</div>
        </button>

        <button
          id="failure-drill-crash-btn"
          phx-click="crash"
          class="rounded-md border border-accent-red/40 bg-accent-red/10 p-3 text-left hover:bg-accent-red/20 transition-colors"
        >
          <div class="text-[10px] uppercase tracking-wider text-muted-foreground">drill: kill process</div>
          <div class="text-sm text-accent-red mt-1 font-semibold">Crash the AgentServer</div>
        </button>
      </div>

      <div class="rounded-md border border-border bg-elevated/40 px-3 py-2 text-[11px] text-muted-foreground leading-relaxed">
        Crashing terminates the AgentServer process. The supervisor restarts it
        with fresh state, so <strong class="text-foreground">ticks reset to 0</strong> —
        OTP restarts the process, not its memory. Persist state and make Actions
        idempotent when work must survive a restart.
      </div>

      <div class="border-t border-border pt-4">
        <div class="text-[10px] uppercase tracking-wider text-muted-foreground mb-2">Drill Log</div>
        <div :if={@log_entries == []} class="text-xs text-muted-foreground">
          Tick the agent, then crash it to observe the restart.
        </div>
        <div :if={@log_entries != []} class="space-y-1 max-h-56 overflow-y-auto">
          <%= for entry <- @log_entries do %>
            <div class="rounded-md border border-border bg-elevated/60 px-3 py-2 text-xs">
              <span class="font-semibold text-foreground">{entry.action}</span>
              <span class="text-muted-foreground ml-2">{entry.detail}</span>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # ── Event Handlers ──────────────────────────────────────────

  @impl true
  def handle_event("tick", _params, socket) do
    with {:ok, pid} <- fetch_server_pid(socket),
         {:ok, agent} <-
           AgentServer.call(pid, Signal.new!("failure_drill.tick", %{by: 1}, source: "/demo")) do
      {:noreply,
       socket
       |> assign(:agent, agent)
       |> assign(:last_error, nil)
       |> append_log("tick", "ticks -> #{agent.state.ticks}")}
    else
      {:error, reason} ->
        {:noreply, assign(socket, :last_error, inspect(reason))}
    end
  end

  def handle_event("crash", _params, socket) do
    case fetch_server_pid(socket) do
      {:ok, pid} ->
        Process.exit(pid, :kill)

        socket =
          socket
          |> assign(:last_crash, format_pid(pid))
          |> append_log("crash", "killed pid #{format_pid(pid)}")

        case await_restart(socket.assigns.sup_pid, pid) do
          nil ->
            {:noreply, assign(socket, :last_error, "Supervisor did not restart the process in time.")}

          new_pid ->
            agent = read_agent!(new_pid)

            {:noreply,
             socket
             |> assign(:server_pid, new_pid)
             |> assign(:agent, agent)
             |> update(:restart_count, &(&1 + 1))
             |> assign(:last_error, nil)
             |> append_log("restart", "pid #{format_pid(pid)} -> #{format_pid(new_pid)}; ticks reset to #{agent.state.ticks}")}
        end

      {:error, reason} ->
        {:noreply, assign(socket, :last_error, inspect(reason))}
    end
  end

  @impl true
  def handle_info(:poll_state, socket) do
    socket =
      socket
      |> sync_from_supervisor()
      |> schedule_poll()

    {:noreply, socket}
  end

  # ── Helpers ─────────────────────────────────────────────────

  defp start_drill do
    with {:ok, sup_pid} <- DrillSupervisor.start_link([]),
         pid when is_pid(pid) <- DrillSupervisor.agent_server_pid(sup_pid),
         agent <- read_agent!(pid) do
      {:ok, sup_pid, pid, agent}
    else
      {:error, reason} -> {:error, reason}
      nil -> {:error, :agent_server_not_started}
    end
  end

  defp sync_from_supervisor(socket) do
    case DrillSupervisor.agent_server_pid(socket.assigns.sup_pid) do
      nil ->
        socket

      pid ->
        if pid == socket.assigns.server_pid do
          socket
        else
          # Supervisor restarted the process outside a user-triggered crash
          # (e.g. a spontaneous fault). Record it the same way.
          agent = read_agent!(pid)

          socket
          |> assign(:server_pid, pid)
          |> assign(:agent, agent)
          |> update(:restart_count, &(&1 + 1))
          |> append_log("restart", "pid -> #{format_pid(pid)}; ticks reset to #{agent.state.ticks}")
        end
    end
  end

  defp schedule_poll(socket) do
    Process.send_after(self(), :poll_state, @poll_interval_ms)
    socket
  end

  defp fetch_server_pid(socket) do
    case socket.assigns.server_pid do
      pid when is_pid(pid) ->
        if Process.alive?(pid), do: {:ok, pid}, else: {:error, :runtime_not_started}

      _other ->
        {:error, :runtime_not_started}
    end
  end

  # Wait briefly for the supervisor to restart the killed AgentServer. The
  # restart is near-instant; this bounds the wait so the UI/tests can observe
  # the new pid deterministically.
  defp await_restart(_sup_pid, _old_pid, attempts \\ 100)
  defp await_restart(_sup_pid, _old_pid, 0), do: nil

  defp await_restart(sup_pid, old_pid, attempts) do
    case DrillSupervisor.agent_server_pid(sup_pid) do
      pid when is_pid(pid) and pid != old_pid -> pid
      _other ->
        Process.sleep(5)
        await_restart(sup_pid, old_pid, attempts - 1)
    end
  end

  defp read_agent!(pid) do
    {:ok, %{agent: agent}} = AgentServer.state(pid)
    agent
  end

  defp append_log(socket, action, detail) do
    entry = %{action: action, detail: detail, at: DateTime.utc_now()}
    assign(socket, :log_entries, [entry | socket.assigns.log_entries] |> Enum.take(40))
  end

  defp format_pid(nil), do: "—"
  defp format_pid(pid) when is_pid(pid), do: "#" <> (pid |> :erlang.pid_to_list() |> List.to_string())

  defp format_crash(nil), do: "—"
  defp format_crash(label), do: label
end
