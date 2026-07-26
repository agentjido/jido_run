defmodule AgentJidoWeb.Examples.CodingAssistantLive do
  @moduledoc """
  Interactive demo for the Coding Assistant example.

  Uses the real `AgentJido.Demos.CodingAssistant` with `Jido.Agent.cmd/2` to
  show the coding-agent workflow on the Jido runtime: read a fixture module,
  run a typed AnalyzeCode action that detects a nil-handling defect, and run a
  typed ProposePatch action that builds a guarded patch. No LLM provider is
  called -- the analysis is deterministic static scanning, so the demo needs no
  API key.
  """

  use AgentJidoWeb, :live_view

  alias AgentJido.Demos.CodingAssistant

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:agent, CodingAssistant.new())
     |> assign(:history, [])}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="coding-assistant-demo" class="rounded-lg border border-border bg-card p-6 space-y-6">
      <%!-- Header --%>
      <div class="flex items-center justify-between gap-4">
        <div>
          <div class="text-sm font-semibold text-foreground">Coding Assistant Agent</div>
          <div class="text-[11px] text-muted-foreground">
            Real Jido runtime · deterministic static analysis · no LLM required
          </div>
        </div>
        <div class="text-[10px] text-muted-foreground font-mono bg-elevated px-2 py-0.5 rounded border border-border">
          id: {@agent.id |> String.slice(0..7)}…
        </div>
      </div>

      <%!-- Controls --%>
      <div class="flex flex-wrap gap-3">
        <button
          phx-click="read_source"
          class="px-4 py-2 rounded-md bg-primary/10 border border-primary/30 text-primary hover:bg-primary/20 transition-colors text-sm font-semibold"
        >
          Read fixture
        </button>
        <button
          phx-click="analyze"
          class="px-4 py-2 rounded-md bg-accent-cyan/10 border border-accent-cyan/30 text-accent-cyan hover:bg-accent-cyan/20 transition-colors text-sm font-semibold"
        >
          Analyze code
        </button>
        <button
          phx-click="propose_patch"
          class="px-4 py-2 rounded-md bg-emerald-500/10 border border-emerald-500/30 text-emerald-300 hover:bg-emerald-500/20 transition-colors text-sm font-semibold"
        >
          Propose patch
        </button>
        <button
          phx-click="reset"
          class="px-3 py-2 rounded-md bg-elevated border border-border text-muted-foreground hover:text-foreground hover:border-primary/40 transition-colors text-xs"
        >
          Reset
        </button>
      </div>

      <div class="grid gap-4 lg:grid-cols-2">
        <%!-- Loaded source --%>
        <div class="rounded-md border border-border bg-elevated p-4 space-y-2">
          <div class="flex items-center justify-between">
            <div class="text-[10px] uppercase tracking-wider text-muted-foreground">
              Loaded source
            </div>
            <div class="text-[10px] text-muted-foreground">
              {if @agent.state.source == "", do: "idle", else: "fixture parser"}
            </div>
          </div>
          <pre class="text-[12px] text-foreground whitespace-pre-wrap min-h-40 font-mono"><%= if @agent.state.source == "",
                       do: "Read the fixture to load the parser module into agent state.",
                       else: @agent.state.source %></pre>
        </div>

        <div class="space-y-4">
          <%!-- Findings --%>
          <div class="rounded-md border border-border bg-elevated p-4 space-y-2">
            <div class="flex items-center justify-between">
              <div class="text-[10px] uppercase tracking-wider text-muted-foreground">
                Findings
              </div>
              <div class="text-[10px] text-muted-foreground">
                {finding_count(@agent.state.findings)}
              </div>
            </div>
            <pre class="text-[12px] text-foreground whitespace-pre-wrap min-h-20 font-mono"><%= if @agent.state.findings == "",
                         do: "Analyze the loaded source to detect nil-handling defects.",
                         else: @agent.state.findings %></pre>
          </div>

          <%!-- Proposed patch --%>
          <div class="rounded-md border border-border bg-elevated p-4 space-y-2">
            <div class="text-[10px] uppercase tracking-wider text-muted-foreground">
              Proposed patch
            </div>
            <pre class="text-[12px] text-foreground whitespace-pre-wrap min-h-24 font-mono"><%= if @agent.state.patch == "",
                         do: "Propose a patch to build a guarded replacement and a unit test.",
                         else: @agent.state.patch %></pre>
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
  def handle_event("read_source", _params, socket) do
    {:noreply, run(socket, "coding.read_source", &CodingAssistant.read_source/1, "Loaded fixture parser source.")}
  end

  def handle_event("analyze", _params, socket) do
    {:noreply,
     run(socket, "coding.analyze", &CodingAssistant.analyze/1, fn agent ->
       "Detected #{finding_count(agent.state.findings)}."
     end)}
  end

  def handle_event("propose_patch", _params, socket) do
    {:noreply, run(socket, "coding.propose_patch", &CodingAssistant.propose_patch/1, "Built a guarded patch and unit test.")}
  end

  def handle_event("reset", _params, socket) do
    {:noreply,
     socket
     |> assign(:agent, CodingAssistant.new())
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

  defp finding_count(""), do: "0 findings"
  defp finding_count(findings), do: "#{findings |> String.split("\n", trim: true) |> length()} finding(s)"
end
