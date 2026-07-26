defmodule AgentJidoWeb.Examples.BrowserDocsScoutAgentLive do
  @moduledoc """
  Interactive docs scout demo powered by `Jido.Browser.Plugin`.
  """

  use AgentJidoWeb, :live_view

  alias AgentJido.Demos.BrowserDocsScout.SimulatedAdapter
  alias AgentJido.Demos.BrowserDocsScoutAgent
  alias Jido.Agent.Directive

  @overview_url SimulatedAdapter.overview_url()

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:agent, BrowserDocsScoutAgent.new())
     |> assign(:history, [])
     |> assign(:overview_url, @overview_url)
     |> assign(:last_error, nil)}
  end

  @impl true
  def render(assigns) do
    browser_state = BrowserDocsScoutAgent.plugin_state(assigns.agent, Jido.Browser.Plugin) || %{}
    session = Map.get(browser_state, :session)
    current_page = assigns.agent.state.current_page
    screenshot = assigns.agent.state.screenshot

    assigns =
      assigns
      |> assign(:browser_state, browser_state)
      |> assign(:session, session)
      |> assign(:current_page, current_page)
      |> assign(:screenshot, screenshot)

    ~H"""
    <div id="browser-docs-scout-demo" class="rounded-lg border border-border bg-card p-6 space-y-6">
      <div class="flex items-center justify-between gap-4">
        <div>
          <div class="text-sm font-semibold text-foreground">Jido Browser Docs Scout Agent</div>
          <div class="text-[11px] text-muted-foreground">
            Plugin-backed browser session using a deterministic simulated adapter
          </div>
        </div>
        <div class="flex flex-col items-end gap-1">
          <div
            id="browser-demo-simulated-label"
            class="text-[10px] px-2 py-1 rounded border border-accent-cyan/30 bg-accent-cyan/10 text-accent-cyan font-semibold uppercase tracking-wider"
            title="This panel replays a deterministic browser trace. No live browser binaries or network calls run here."
          >
            simulated
          </div>
          <div class="text-[10px] font-mono text-muted-foreground bg-elevated px-2 py-1 rounded border border-border">
            {if @session, do: "session: " <> String.slice(@session.id, 0, 8) <> "…", else: "session: idle"}
          </div>
        </div>
      </div>

      <div class="rounded-md border border-border bg-elevated p-4 space-y-2 text-xs text-muted-foreground">
        <div>
          Dependency:
          <code class="font-mono text-foreground">
            {~s({:jido_browser, github: "agentjido/jido_browser", branch: "main"})}
          </code>
        </div>
        <div>
          Adapter today: `AgentJido.Demos.BrowserDocsScout.SimulatedAdapter`
        </div>
        <div>
          Swap to `Jido.Browser.Adapters.Vibium` or `Jido.Browser.Adapters.Web` in your own project.
        </div>
      </div>

      <div class="flex gap-3 flex-wrap">
        <button
          phx-click="open_intro"
          class="px-4 py-2 rounded-md bg-primary/10 border border-primary/30 text-primary hover:bg-primary/20 transition-colors text-sm font-semibold"
        >
          Open Plugin Guide
        </button>
        <button
          phx-click="extract_article"
          class="px-4 py-2 rounded-md bg-emerald-500/10 border border-emerald-500/30 text-emerald-300 hover:bg-emerald-500/20 transition-colors text-sm font-semibold"
        >
          Extract Article
        </button>
        <button
          phx-click="follow_link"
          class="px-4 py-2 rounded-md bg-accent-cyan/10 border border-accent-cyan/30 text-accent-cyan hover:bg-accent-cyan/20 transition-colors text-sm font-semibold"
        >
          Follow Testing Link
        </button>
        <button
          phx-click="capture_screenshot"
          class="px-4 py-2 rounded-md bg-amber-500/10 border border-amber-500/30 text-amber-300 hover:bg-amber-500/20 transition-colors text-sm font-semibold"
        >
          Capture Screenshot
        </button>
        <button
          phx-click="reset_demo"
          class="px-3 py-2 rounded-md bg-elevated border border-border text-muted-foreground hover:text-foreground hover:border-primary/40 transition-colors text-xs"
        >
          Reset
        </button>
      </div>

      <div :if={@last_error} class="rounded-md border border-red-400/30 bg-red-400/10 p-3">
        <div class="text-xs font-semibold text-red-300">{@last_error.summary}</div>
        <div class="text-xs text-red-200/80 mt-1">{@last_error.detail}</div>
      </div>

      <div class="grid gap-4 lg:grid-cols-[1.2fr_0.8fr]">
        <div class="space-y-4">
          <div class="rounded-md border border-border bg-elevated p-4 space-y-2">
            <div class="text-[10px] uppercase tracking-wider text-muted-foreground">Current Page</div>
            <div class="text-sm font-semibold text-foreground">
              {Map.get(@current_page, :title, "No docs page opened yet")}
            </div>
            <div class="text-xs text-muted-foreground break-all">
              {Map.get(@current_page, :url, "Ready to open the simulated plugin guide.")}
            </div>
            <div :if={Map.get(@current_page, :description)} class="text-xs text-muted-foreground">
              {Map.get(@current_page, :description)}
            </div>
          </div>

          <div class="rounded-md border border-border bg-elevated p-4 space-y-2">
            <div class="flex items-center justify-between">
              <div class="text-[10px] uppercase tracking-wider text-muted-foreground">Extracted Content</div>
              <div class="text-[10px] text-muted-foreground">
                {if @agent.state.content_length > 0, do: "#{@agent.state.content_length} chars", else: "idle"}
              </div>
            </div>
            <pre class="text-[12px] text-foreground whitespace-pre-wrap min-h-40 font-mono"><%= if @agent.state.extracted_content == "", do: "Run Extract Article to capture markdown from the active page.", else: @agent.state.extracted_content %></pre>
          </div>
        </div>

        <div class="space-y-4">
          <div class="rounded-md border border-border bg-elevated p-4 space-y-2">
            <div class="text-[10px] uppercase tracking-wider text-muted-foreground">Screenshot</div>
            <div :if={@screenshot == %{}} class="text-xs text-muted-foreground">
              Capture Screenshot to render the deterministic PNG returned by the adapter.
            </div>
            <img
              :if={Map.get(@screenshot, :base64)}
              src={"data:#{Map.get(@screenshot, :mime)};base64,#{Map.get(@screenshot, :base64)}"}
              alt="Simulated browser screenshot"
              class="w-full rounded border border-border bg-background"
            />
            <div :if={Map.get(@screenshot, :size)} class="text-[11px] text-muted-foreground">
              {Map.get(@screenshot, :size)} bytes
            </div>
          </div>

          <div class="rounded-md border border-border bg-elevated p-4">
            <div class="flex items-center justify-between mb-2">
              <div class="text-[10px] uppercase tracking-wider text-muted-foreground">Run History</div>
              <div class="text-[10px] text-muted-foreground">{length(@history)} step(s)</div>
            </div>
            <div :if={@history == []} class="text-xs text-muted-foreground">
              Open the plugin guide to start the deterministic browser flow.
            </div>
            <div :if={@history != []} class="space-y-2 max-h-64 overflow-y-auto">
              <%= for entry <- @history do %>
                <div class="rounded-md border border-border bg-background/70 px-3 py-2">
                  <div class="text-[11px] font-semibold text-foreground">{entry.label}</div>
                  <div class="text-[11px] text-muted-foreground">{entry.detail}</div>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("open_intro", _params, socket) do
    {:noreply,
     run_action(socket, fn agent -> BrowserDocsScoutAgent.open_page(agent, @overview_url) end, fn agent ->
       %{
         label: "Open Plugin Guide",
         detail: "Opened #{Map.get(agent.state.current_page, :title, "the docs guide")} with a simulated browser session."
       }
     end)}
  end

  def handle_event("extract_article", _params, socket) do
    {:noreply,
     run_action(socket, &BrowserDocsScoutAgent.extract_current_page/1, fn agent ->
       %{
         label: "Extract Article",
         detail: "Captured #{agent.state.content_length} characters of #{agent.state.extracted_format} from the active docs page."
       }
     end)}
  end

  def handle_event("follow_link", _params, socket) do
    {:noreply,
     run_action(
       socket,
       fn agent ->
         BrowserDocsScoutAgent.follow_link(agent, "a[data-doc-link='testing']", text: "Testing browser agents")
       end,
       fn agent ->
         %{label: "Follow Testing Link", detail: "Navigated to #{Map.get(agent.state.current_page, :title, "the next docs page")}."}
       end
     )}
  end

  def handle_event("capture_screenshot", _params, socket) do
    {:noreply,
     run_action(socket, &BrowserDocsScoutAgent.capture_screenshot/1, fn agent ->
       size = get_in(agent.state, [:screenshot, :size]) || 0
       %{label: "Capture Screenshot", detail: "Stored a deterministic PNG payload (#{size} bytes)."}
     end)}
  end

  def handle_event("reset_demo", _params, socket) do
    {:noreply,
     run_action(socket, &BrowserDocsScoutAgent.reset_browser/1, fn _agent ->
       %{label: "Reset Browser", detail: "Cleared the browser session and local demo outputs."}
     end)}
  end

  defp run_action(socket, action_fun, entry_fun) do
    {new_agent, directives} = action_fun.(socket.assigns.agent)

    case first_error_message(directives) do
      nil ->
        entry =
          entry_fun.(new_agent)
          |> Map.put(:at, DateTime.utc_now())

        socket
        |> assign(:agent, new_agent)
        |> assign(:last_error, nil)
        |> assign(:history, [entry | socket.assigns.history])

      error_message ->
        entry = %{label: "Action Error", detail: error_message, at: DateTime.utc_now()}

        socket
        |> assign(:agent, new_agent)
        |> assign(:last_error, %{summary: "Browser action failed.", detail: error_message})
        |> assign(:history, [entry | socket.assigns.history])
    end
  end

  defp first_error_message(directives) do
    Enum.find_value(directives, fn
      %Directive.Error{error: %{message: message}} -> message
      %Directive.Error{error: error} -> inspect(error)
      _ -> nil
    end)
  end
end
