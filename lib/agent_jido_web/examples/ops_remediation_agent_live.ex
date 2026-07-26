defmodule AgentJidoWeb.Examples.OpsRemediationAgentLive do
  @moduledoc """
  Interactive demo for the Operations Remediation Agent example.

  Uses the real `AgentJido.Demos.OpsRemediation` with `Jido.Agent.cmd/2` to show
  a watch → diagnose → remediate → verify operations workflow on the Jido
  runtime: load a system metric snapshot, run a typed DetectAnomaly action that
  checks the real SLO thresholds, run a typed Diagnose action that picks the
  dominant issue, run a typed ApplyRemediation action that selects the playbook
  entry, and run a typed VerifyRecovery action that confirms the system
  recovered. No LLM provider is called -- the workflow is deterministic
  threshold and playbook logic, so the demo needs no API key.
  """

  use AgentJidoWeb, :live_view

  alias AgentJido.Demos.OpsRemediation

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:agent, OpsRemediation.new())
     |> assign(:history, [])}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="ops-remediation-demo" class="rounded-lg border border-border bg-card p-6 space-y-6">
      <%!-- Header --%>
      <div class="flex items-center justify-between gap-4">
        <div>
          <div class="text-sm font-semibold text-foreground">Operations Remediation Agent</div>
          <div class="text-[11px] text-muted-foreground">
            Real Jido runtime · deterministic detect / diagnose / remediate / verify · no LLM required
          </div>
        </div>
        <div class="text-[10px] text-muted-foreground font-mono bg-elevated px-2 py-0.5 rounded border border-border">
          id: {@agent.id |> String.slice(0..7)}…
        </div>
      </div>

      <%!-- Controls --%>
      <div class="flex flex-wrap gap-3">
        <button
          phx-click="load_healthy"
          class="px-4 py-2 rounded-md bg-primary/10 border border-primary/30 text-primary hover:bg-primary/20 transition-colors text-sm font-semibold"
        >
          Load healthy
        </button>
        <button
          phx-click="load_latency"
          class="px-4 py-2 rounded-md bg-primary/10 border border-primary/30 text-primary hover:bg-primary/20 transition-colors text-sm font-semibold"
        >
          Load latency spike
        </button>
        <button
          phx-click="load_errors"
          class="px-4 py-2 rounded-md bg-primary/10 border border-primary/30 text-primary hover:bg-primary/20 transition-colors text-sm font-semibold"
        >
          Load error spike
        </button>
        <button
          phx-click="load_saturation"
          class="px-4 py-2 rounded-md bg-primary/10 border border-primary/30 text-primary hover:bg-primary/20 transition-colors text-sm font-semibold"
        >
          Load CPU saturation
        </button>
        <button
          phx-click="detect"
          class="px-4 py-2 rounded-md bg-accent-cyan/10 border border-accent-cyan/30 text-accent-cyan hover:bg-accent-cyan/20 transition-colors text-sm font-semibold"
        >
          Detect
        </button>
        <button
          phx-click="diagnose"
          class="px-4 py-2 rounded-md bg-accent-yellow/10 border border-accent-yellow/30 text-accent-yellow hover:bg-accent-yellow/20 transition-colors text-sm font-semibold"
        >
          Diagnose
        </button>
        <button
          phx-click="remediate"
          class="px-4 py-2 rounded-md bg-emerald-500/10 border border-emerald-500/30 text-emerald-300 hover:bg-emerald-500/20 transition-colors text-sm font-semibold"
        >
          Remediate
        </button>
        <button
          phx-click="verify"
          class="px-4 py-2 rounded-md bg-accent-green/10 border border-accent-green/30 text-accent-green hover:bg-accent-green/20 transition-colors text-sm font-semibold"
        >
          Verify
        </button>
        <button
          phx-click="reset"
          class="px-3 py-2 rounded-md bg-elevated border border-border text-muted-foreground hover:text-foreground hover:border-primary/40 transition-colors text-xs"
        >
          Reset
        </button>
      </div>

      <div class="grid gap-4 lg:grid-cols-2">
        <%!-- Metric snapshot --%>
        <div class="rounded-md border border-border bg-elevated p-4 space-y-2">
          <div class="flex items-center justify-between">
            <div class="text-[10px] uppercase tracking-wider text-muted-foreground">
              Metric snapshot
            </div>
            <div class="text-[10px] text-muted-foreground">
              {if metric_loaded?(@agent), do: "ingested", else: "idle"}
            </div>
          </div>
          <pre class="text-[12px] text-foreground whitespace-pre-wrap min-h-40 font-mono"><%= metric_snapshot(@agent) %></pre>
        </div>

        <div class="space-y-4">
          <%!-- Status --%>
          <div class="rounded-md border border-border bg-elevated p-4 space-y-2">
            <div class="flex items-center justify-between">
              <div class="text-[10px] uppercase tracking-wider text-muted-foreground">
                Status
              </div>
              <div class="text-[10px] text-muted-foreground">
                {if @agent.state.status == "",
                  do: "not detected",
                  else: @agent.state.status}
              </div>
            </div>
            <pre class="text-[12px] text-foreground whitespace-pre-wrap min-h-12 font-mono"><%= if @agent.state.status == "",
                         do: "Detect to check the snapshot against the SLO thresholds.",
                         else: "status: #{@agent.state.status}" %></pre>
          </div>

          <%!-- Diagnosis --%>
          <div class="rounded-md border border-border bg-elevated p-4 space-y-2">
            <div class="flex items-center justify-between">
              <div class="text-[10px] uppercase tracking-wider text-muted-foreground">
                Diagnosis
              </div>
              <div class="text-[10px] text-muted-foreground">
                {if @agent.state.diagnosis == "",
                  do: "not diagnosed",
                  else: @agent.state.diagnosis}
              </div>
            </div>
            <pre class="text-[12px] text-foreground whitespace-pre-wrap min-h-12 font-mono"><%= if @agent.state.diagnosis == "",
                         do: "Diagnose to pick the dominant issue from the breaches.",
                         else: "diagnosis: #{@agent.state.diagnosis}" %></pre>
          </div>

          <%!-- Remediation --%>
          <div class="rounded-md border border-border bg-elevated p-4 space-y-2">
            <div class="text-[10px] uppercase tracking-wider text-muted-foreground">
              Remediation
            </div>
            <pre class="text-[12px] text-foreground whitespace-pre-wrap min-h-12 font-mono"><%= if @agent.state.remediation == "",
                         do: "Remediate to apply the playbook entry for the diagnosis.",
                         else: @agent.state.remediation %></pre>
          </div>

          <%!-- Verification --%>
          <div class="rounded-md border border-border bg-elevated p-4 space-y-2">
            <div class="text-[10px] uppercase tracking-wider text-muted-foreground">
              Verification
            </div>
            <pre class="text-[12px] text-foreground whitespace-pre-wrap min-h-12 font-mono"><%= if @agent.state.verification == "",
                         do: "Verify to confirm the system recovered after remediation.",
                         else: @agent.state.verification %></pre>
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
  def handle_event("load_healthy", _params, socket) do
    {:noreply, run(socket, "ops.ingest", fn agent -> OpsRemediation.ingest(agent, :healthy) end, "Loaded healthy snapshot.")}
  end

  def handle_event("load_latency", _params, socket) do
    {:noreply, run(socket, "ops.ingest", fn agent -> OpsRemediation.ingest(agent, :latency) end, "Loaded latency-spike snapshot.")}
  end

  def handle_event("load_errors", _params, socket) do
    {:noreply, run(socket, "ops.ingest", fn agent -> OpsRemediation.ingest(agent, :errors) end, "Loaded error-spike snapshot.")}
  end

  def handle_event("load_saturation", _params, socket) do
    {:noreply, run(socket, "ops.ingest", fn agent -> OpsRemediation.ingest(agent, :saturation) end, "Loaded CPU-saturation snapshot.")}
  end

  def handle_event("detect", _params, socket) do
    {:noreply,
     run(socket, "ops.detect", &OpsRemediation.detect/1, fn agent ->
       "Status is #{agent.state.status}."
     end)}
  end

  def handle_event("diagnose", _params, socket) do
    {:noreply,
     run(socket, "ops.diagnose", &OpsRemediation.diagnose/1, fn agent ->
       "Diagnosed as #{agent.state.diagnosis}."
     end)}
  end

  def handle_event("remediate", _params, socket) do
    {:noreply, run(socket, "ops.remediate", &OpsRemediation.remediate/1, "Applied the playbook remediation.")}
  end

  def handle_event("verify", _params, socket) do
    {:noreply, run(socket, "ops.verify", &OpsRemediation.verify/1, "Verified post-remediation recovery.")}
  end

  def handle_event("reset", _params, socket) do
    {:noreply,
     socket
     |> assign(:agent, OpsRemediation.new())
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

  defp metric_loaded?(agent) do
    agent.state.p95_latency_ms != 0 or agent.state.cpu_pct != 0
  end

  defp metric_snapshot(agent) do
    if metric_loaded?(agent) do
      """
      p95 latency:   #{agent.state.p95_latency_ms} ms
      error rate:    #{:erlang.float_to_binary(agent.state.error_rate_pct, decimals: 1)}%
      cpu:           #{agent.state.cpu_pct}%
      """
    else
      "Load a healthy, latency-spike, error-spike, or CPU-saturation snapshot to start the workflow."
    end
  end
end
