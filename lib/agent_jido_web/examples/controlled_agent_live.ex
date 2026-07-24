defmodule AgentJidoWeb.Examples.ControlledAgentLive do
  @moduledoc """
  Interactive demo for the integrated controlled-Agent example (jido-e04-t41).

  Runs a real `Jido.AgentServer` under an OTP supervisor. The server's Actions
  pass through the fail-closed `AuthorizationPlugin`, so only an allowed
  principal can run the protected `work.approve` Action. Visitors run the
  allowed path (alice), the denied path (mallory), and crash the process to
  watch supervision recover it — proving the complete control path in one
  screen: who initiated work, what was allowed, what happened, and how failure
  was handled.
  """

  use AgentJidoWeb, :live_view

  alias AgentJido.Demos.ControlledAgent.Supervisor, as: ControlledSupervisor
  alias Jido.AgentServer
  alias Jido.Signal

  @allowed_principal "alice"
  @denied_principal "mallory"
  @poll_interval_ms 500

  @impl true
  def mount(_params, _session, socket) do
    # A fallback agent for the static (disconnected) render, before the
    # supervised runtime is started.
    fallback_agent = AgentJido.Demos.ControlledAgent.new(id: "controlled-agent-preview")

    socket =
      socket
      |> assign(:allowed_principal, @allowed_principal)
      |> assign(:denied_principal, @denied_principal)
      |> assign(:sup_pid, nil)
      |> assign(:server_pid, nil)
      |> assign(:agent, fallback_agent)
      |> assign(:restart_count, 0)
      |> assign(:last_result, nil)
      |> assign(:log_entries, [])
      |> assign(:last_error, nil)

    socket =
      if connected?(socket) do
        case start_runtime() do
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
    <div id="controlled-agent-demo" class="rounded-lg border border-border bg-card p-6 space-y-6">
      <div class="flex items-center justify-between">
        <div class="flex items-center gap-2">
          <div class="h-2 w-2 rounded-full bg-accent-green animate-pulse" />
          <div class="text-sm font-semibold text-foreground">Controlled Agent</div>
        </div>
        <div class="text-[10px] text-muted-foreground font-mono bg-elevated px-2 py-0.5 rounded border border-border">
          pid: {format_pid(@server_pid)}
        </div>
      </div>

      <div :if={@last_error} class="rounded-md border border-red-400/30 bg-red-400/10 px-3 py-2 text-xs text-red-300">
        {@last_error}
      </div>

      <div class="grid sm:grid-cols-3 gap-3">
        <div class="rounded-md border border-border bg-elevated p-3 text-center">
          <div class="text-[10px] uppercase tracking-wider text-muted-foreground">Allowed principals</div>
          <div id="controlled-agent-allowlist" class="text-sm font-semibold text-accent-green mt-2 font-mono">
            [{@allowed_principal}]
          </div>
        </div>
        <div class="rounded-md border border-border bg-elevated p-3 text-center">
          <div class="text-[10px] uppercase tracking-wider text-muted-foreground">Approved work</div>
          <div id="controlled-agent-approved" class="text-2xl font-bold text-foreground mt-1 tabular-nums">
            {@agent.state.approved_count}
          </div>
        </div>
        <div class="rounded-md border border-border bg-elevated p-3 text-center">
          <div class="text-[10px] uppercase tracking-wider text-muted-foreground">Restarts observed</div>
          <div id="controlled-agent-restarts" class="text-2xl font-bold text-accent-yellow mt-1 tabular-nums">
            {@restart_count}
          </div>
        </div>
      </div>

      <div class="grid gap-3 sm:grid-cols-3">
        <button
          id="controlled-agent-approve-allowed"
          phx-click="approve_allowed"
          class="rounded-md border border-accent-green/40 bg-accent-green/10 p-3 text-left hover:bg-accent-green/20 transition-colors"
        >
          <div class="text-[10px] uppercase tracking-wider text-muted-foreground">call: work.approve</div>
          <div class="text-sm text-accent-green mt-1 font-semibold">Run as {@allowed_principal}</div>
          <div class="text-[10px] text-muted-foreground mt-1">allowed principal</div>
        </button>

        <button
          id="controlled-agent-approve-denied"
          phx-click="approve_denied"
          class="rounded-md border border-accent-red/40 bg-accent-red/10 p-3 text-left hover:bg-accent-red/20 transition-colors"
        >
          <div class="text-[10px] uppercase tracking-wider text-muted-foreground">call: work.approve</div>
          <div class="text-sm text-accent-red mt-1 font-semibold">Run as {@denied_principal}</div>
          <div class="text-[10px] text-muted-foreground mt-1">denied before it runs</div>
        </button>

        <button
          id="controlled-agent-crash"
          phx-click="crash"
          class="rounded-md border border-accent-yellow/40 bg-accent-yellow/10 p-3 text-left hover:bg-accent-yellow/20 transition-colors"
        >
          <div class="text-[10px] uppercase tracking-wider text-muted-foreground">drill: kill process</div>
          <div class="text-sm text-accent-yellow mt-1 font-semibold">Crash the AgentServer</div>
          <div class="text-[10px] text-muted-foreground mt-1">supervision restarts it</div>
        </button>
      </div>

      <div :if={@last_result} class="rounded-md border border-border bg-elevated/60 px-3 py-2 text-xs">
        <span class="font-semibold text-foreground">{@last_result.action}</span>
        <span class="text-muted-foreground ml-2">{@last_result.detail}</span>
      </div>

      <div class="rounded-md border border-border bg-elevated/40 px-3 py-2 text-[11px] text-muted-foreground leading-relaxed">
        The <strong class="text-foreground">AuthorizationPlugin</strong> runs <strong class="text-foreground">before</strong> the Action
        (<code class="text-foreground">prepare_action/3</code>). Only the allowed
        principal reaches the effect — an unauthorized principal is denied, the
        counter never moves, and the rejected work is logged. Crashing the
        AgentServer terminates the process; OTP supervision restarts it with
        fresh state, so approved work resets — exactly the lifecycle boundary
        the failure question is about.
      </div>

      <div class="border-t border-border pt-4">
        <div class="text-[10px] uppercase tracking-wider text-muted-foreground mb-2">Control Log</div>
        <div :if={@log_entries == []} class="text-xs text-muted-foreground">
          Run the allowed path, the denied path, or crash the process to observe each control.
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
  def handle_event("approve_allowed", _params, socket) do
    dispatch(socket, @allowed_principal)
  end

  def handle_event("approve_denied", _params, socket) do
    dispatch(socket, @denied_principal)
  end

  def handle_event("crash", _params, socket) do
    case fetch_server_pid(socket) do
      {:ok, pid} ->
        Process.exit(pid, :kill)

        socket =
          socket
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
             |> assign(:last_error, nil)
             |> assign(:last_result, %{
               action: "restart",
               detail: "pid #{format_pid(pid)} -> #{format_pid(new_pid)}; approved work reset to #{agent.state.approved_count}"
             })
             |> update(:restart_count, &(&1 + 1))
             |> append_log(
               "restart",
               "pid #{format_pid(pid)} -> #{format_pid(new_pid)}; approved work reset to #{agent.state.approved_count}"
             )}
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

  defp dispatch(socket, principal) do
    signal = Signal.new!("work.approve", %{note: "demo"}, source: principal)

    with {:ok, pid} <- fetch_server_pid(socket),
         result <- AgentServer.call(pid, signal) do
      case result do
        {:ok, agent} ->
          {:noreply,
           socket
           |> assign(:agent, agent)
           |> assign(:last_error, nil)
           |> assign(:last_result, %{
             action: "approved",
             detail: "principal '#{principal}' allowed; approved work -> #{agent.state.approved_count}"
           })
           |> append_log("approved", "principal '#{principal}' allowed; approved work -> #{agent.state.approved_count}")}

        {:error, reason} ->
          approved = socket.assigns.agent.state.approved_count

          {:noreply,
           socket
           |> assign(:last_error, nil)
           |> assign(:last_result, %{
             action: "denied",
             detail: "principal '#{principal}' denied (#{inspect(reason)}); approved work stays at #{approved}"
           })
           |> append_log(
             "denied",
             "principal '#{principal}' denied (#{inspect(reason)}); approved work stays at #{approved}"
           )}
      end
    else
      {:error, reason} ->
        {:noreply, assign(socket, :last_error, inspect(reason))}
    end
  end

  defp start_runtime do
    with {:ok, sup_pid} <- ControlledSupervisor.start_link([]),
         pid when is_pid(pid) <- ControlledSupervisor.agent_server_pid(sup_pid),
         agent <- read_agent!(pid) do
      {:ok, sup_pid, pid, agent}
    else
      {:error, reason} -> {:error, reason}
      nil -> {:error, :agent_server_not_started}
    end
  end

  defp sync_from_supervisor(socket) do
    case ControlledSupervisor.agent_server_pid(socket.assigns.sup_pid) do
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
          |> append_log("restart", "pid -> #{format_pid(pid)}; approved work reset to #{agent.state.approved_count}")
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
    case ControlledSupervisor.agent_server_pid(sup_pid) do
      pid when is_pid(pid) and pid != old_pid ->
        pid

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
end
