defmodule AgentJidoWeb.ContentAssistantModalComponent do
  @moduledoc """
  Unified content assistant modal for retrieval-grounded search.
  """
  use AgentJidoWeb, :live_component

  alias AgentJido.Analytics
  alias AgentJido.Analytics.PostHog
  alias AgentJido.ContentAssistant
  alias AgentJido.ContentAssistant.Response
  alias AgentJido.QueryLogs
  alias Phoenix.LiveView.JS

  import AgentJidoWeb.ContentAssistantSupport,
    only: [
      analytics_value: 1,
      analytics_metadata: 2,
      filter_chip_class: 1,
      filter_citations_by_type: 2,
      llm_enabled?: 1,
      llm_request_outcome: 1,
      maybe_apply_search_response_mode: 2,
      maybe_wait_for_progressive_dwell: 1,
      monotonic_ms: 0,
      normalize_feedback_note: 1,
      normalize_feedback_value: 1,
      normalize_result_type_filter: 1,
      package_label: 1,
      page_kind_label: 1,
      provider_label: 1,
      content_type_label: 1,
      proof_level_label: 1,
      normalize_query: 1,
      query_latency_ms: 1,
      external_result?: 1,
      require_turnstile?: 0,
      reset_turnstile_widget: 1,
      result_filter_analytics: 1,
      result_rel: 1,
      result_target: 1,
      result_type_facets: 1,
      search_response_mode: 0,
      search_retrieval_mode: 0,
      source_label: 1,
      turnstile_input_id: 1,
      turnstile_retry_id: 1,
      turnstile_site_key: 0,
      turnstile_status_id: 1,
      turnstile_submit_id: 1,
      turnstile_widget_id: 1
    ]

  @default_citation_limit 6
  @default_thread_limit 3

  @type assistant_status :: :idle | :loading | :answer | :empty | :error

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(assigns, socket) do
    component_id = component_id(socket, assigns)

    socket =
      socket
      |> assign_new(:query, fn -> "" end)
      |> assign_new(:status, fn -> :idle end)
      |> assign_new(:response, fn -> nil end)
      |> assign_new(:assistant_ref, fn -> nil end)
      |> assign_new(:assistant_started_at, fn -> nil end)
      |> assign_new(:enhancement_ref, fn -> nil end)
      |> assign_new(:enhancement_status, fn -> :idle end)
      |> assign_new(:query_log_id, fn -> nil end)
      |> assign_new(:last_query_log_id, fn -> nil end)
      |> assign_new(:thread, fn -> [] end)
      |> assign_new(:feedback_value, fn -> nil end)
      |> assign_new(:feedback_note, fn -> "" end)
      |> assign_new(:feedback_submitted, fn -> false end)
      |> assign_new(:result_filter, fn -> nil end)
      |> assign_new(:turnstile_token, fn -> "" end)
      |> assign_new(:current_scope, fn -> nil end)
      |> assign_new(:analytics_identity, fn -> %{visitor_id: nil, session_id: nil, referrer_host: nil, path: nil} end)
      |> assign(Map.drop(assigns, [:assistant_complete, :assistant_enhancement_complete]))
      |> assign(:turnstile_required, require_turnstile?())
      |> assign(:turnstile_site_key, turnstile_site_key())
      |> assign(:turnstile_widget_id, turnstile_widget_id(component_id))
      |> assign(:turnstile_input_id, turnstile_input_id(component_id))
      |> assign(:turnstile_submit_id, turnstile_submit_id(component_id))
      |> assign(:turnstile_status_id, turnstile_status_id(component_id))
      |> assign(:turnstile_retry_id, turnstile_retry_id(component_id))
      |> maybe_hydrate_recent_thread()
      |> maybe_apply_assistant_complete(assigns)
      |> maybe_apply_assistant_enhancement_complete(assigns)

    {:ok, socket}
  end

  @impl true
  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("submit", %{"assistant" => params}, socket) do
    query = normalize_query(Map.get(params, "q"))
    turnstile_token = normalize_query(Map.get(params, "turnstile_token"))

    if query == "" do
      {:noreply,
       socket
       |> assign(
         query: "",
         status: :idle,
         response: nil,
         assistant_ref: nil,
         assistant_started_at: nil,
         enhancement_ref: nil,
         enhancement_status: :idle,
         query_log_id: nil,
         last_query_log_id: nil,
         feedback_value: nil,
         feedback_note: "",
         feedback_submitted: false,
         result_filter: nil,
         turnstile_token: ""
       )
       |> reset_turnstile_widget()}
    else
      {:noreply, begin_assistant_query(socket, query, turnstile_token)}
    end
  end

  def handle_event("thread_select", %{"q" => query}, socket) do
    normalized_query = normalize_query(query)

    if normalized_query == "" do
      {:noreply, socket}
    else
      {:noreply, begin_assistant_query(socket, normalized_query, "")}
    end
  end

  # Result-type filter (jido-e10-t07). A visitor narrows the displayed
  # citations to one source surface (Docs, Examples, Ecosystem, Blog, Skills).
  # The filter is a display facet over the retrieved citations, so selecting it
  # only re-renders. `"all"` and unknown values clear the filter so a bad value
  # can never empty the list.
  def handle_event("select_result_filter", %{"type" => type}, socket) do
    {:noreply, assign(socket, :result_filter, normalize_result_type_filter(type))}
  end

  def handle_event("reference_click", params, socket) do
    rank = normalize_rank(Map.get(params, "rank"))
    target_url = normalize_query(Map.get(params, "url"))
    response = socket.assigns.response

    metadata =
      analytics_metadata(response, %{
        surface: "content_assistant_modal",
        external: Map.get(params, "external") == "true",
        provider: normalize_query(Map.get(params, "provider")),
        package_id: normalize_query(Map.get(params, "package_id")),
        package_version: normalize_query(Map.get(params, "package_version")),
        page_kind: normalize_query(Map.get(params, "page_kind"))
      })

    analytics_module().track_event_safe(socket.assigns.current_scope, %{
      event: "content_assistant_reference_clicked",
      source: "content_assistant",
      channel: "content_assistant_modal",
      path: socket.assigns.analytics_identity[:path] || "/",
      target_url: target_url,
      rank: rank,
      query_log_id: socket.assigns.last_query_log_id,
      visitor_id: socket.assigns.analytics_identity[:visitor_id],
      session_id: socket.assigns.analytics_identity[:session_id],
      metadata: metadata
    })

    {:noreply, socket}
  end

  def handle_event("submit_feedback", %{"feedback" => feedback_params}, socket) do
    feedback_value = normalize_feedback_value(Map.get(feedback_params, "value"))

    feedback_note =
      if feedback_value == "not_helpful" do
        normalize_feedback_note(Map.get(feedback_params, "note"))
      else
        nil
      end

    if feedback_value in ["helpful", "not_helpful"] do
      response = socket.assigns.response
      channel = if socket.assigns.status == :empty, do: "content_assistant_no_results", else: "content_assistant_modal"

      analytics_module().track_feedback_safe(socket.assigns.current_scope, %{
        event: "feedback_submitted",
        source: "content_assistant",
        channel: channel,
        path: socket.assigns.analytics_identity[:path] || "/",
        feedback_value: feedback_value,
        feedback_note: feedback_note,
        query_log_id: socket.assigns.last_query_log_id,
        visitor_id: socket.assigns.analytics_identity[:visitor_id],
        session_id: socket.assigns.analytics_identity[:session_id],
        metadata: analytics_metadata(response, %{surface: "content_assistant"})
      })

      {:noreply,
       assign(socket,
         feedback_value: feedback_value,
         feedback_note: "",
         feedback_submitted: true
       )}
    else
      {:noreply, socket}
    end
  end

  def handle_event("feedback_select", %{"value" => value}, socket) do
    case normalize_feedback_value(value) do
      "helpful" ->
        {:noreply, assign(socket, feedback_value: "helpful", feedback_note: "", feedback_submitted: false)}

      "not_helpful" ->
        {:noreply, assign(socket, feedback_value: "not_helpful", feedback_submitted: false)}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("new_topic", _params, socket) do
    {:noreply,
     socket
     |> assign(
       query: "",
       status: :idle,
       response: nil,
       assistant_ref: nil,
       assistant_started_at: nil,
       enhancement_ref: nil,
       enhancement_status: :idle,
       query_log_id: nil,
       last_query_log_id: nil,
       thread: [],
       feedback_value: nil,
       feedback_note: "",
       feedback_submitted: false,
       result_filter: nil,
       turnstile_token: ""
     )
     |> reset_turnstile_widget()}
  end

  def handle_event("reset", _params, socket) do
    {:noreply,
     socket
     |> assign(
       query: "",
       status: :idle,
       response: nil,
       assistant_ref: nil,
       assistant_started_at: nil,
       enhancement_ref: nil,
       enhancement_status: :idle,
       query_log_id: nil,
       last_query_log_id: nil,
       feedback_value: nil,
       feedback_note: "",
       feedback_submitted: false,
       result_filter: nil,
       turnstile_token: ""
     )
     |> reset_turnstile_widget()}
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id={"#{@id}-root"}>
      <.phx_modal id={@id} on_cancel={JS.push("reset", target: @myself)}>
        <:title>Search</:title>
        <:subtitle>Search docs, blog posts, and ecosystem packages with citations.</:subtitle>

        <div class="mt-6 space-y-4">
          <.form for={%{}} as={:assistant} phx-submit="submit" phx-target={@myself} class="ph-no-capture ph-sensitive">
            <div class="space-y-3">
              <input
                id={@turnstile_input_id}
                name="assistant[turnstile_token]"
                type="text"
                value={@turnstile_token}
                class="hidden"
                autocomplete="off"
                aria-hidden="true"
              />

              <div class="flex flex-col gap-3 sm:flex-row">
                <input
                  id={"#{@id}-input"}
                  name="assistant[q]"
                  type="search"
                  value={@query}
                  placeholder="Search docs, blog, and ecosystem..."
                  class="w-full rounded-xl border border-border bg-background px-4 py-3 text-sm text-foreground placeholder:text-muted-foreground focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary/25"
                  autocomplete="off"
                />
                <button
                  id={@turnstile_submit_id}
                  type="submit"
                  class="rounded-xl bg-primary px-5 py-3 text-sm font-semibold text-primary-foreground transition hover:bg-primary/90"
                >
                  Search
                </button>
              </div>

              <div :if={@turnstile_required and is_binary(@turnstile_site_key) and @turnstile_site_key != ""}>
                <div
                  id={@turnstile_widget_id}
                  phx-hook="ContentAssistantTurnstile"
                  data-site-key={@turnstile_site_key}
                  data-input-id={@turnstile_input_id}
                  data-appearance="interaction-only"
                  data-size="invisible"
                  data-execution="execute"
                  data-modal-id={@id}
                  data-load-trigger="modal-open"
                  data-submit-id={@turnstile_submit_id}
                  data-status-id={@turnstile_status_id}
                  data-retry-id={@turnstile_retry_id}
                  class="h-0 overflow-hidden"
                >
                </div>
                <p id={@turnstile_status_id} class="mt-1 text-xs text-muted-foreground" data-state="loading">
                  Verification runs in the background and only prompts when risk is detected.
                </p>
                <button
                  id={@turnstile_retry_id}
                  type="button"
                  class="mt-2 hidden rounded-md border border-border bg-background px-3 py-2 text-xs font-semibold text-foreground hover:border-primary/50"
                >
                  Retry verification
                </button>
              </div>
            </div>
          </.form>

          <div :if={@status == :idle} id={"#{@id}-idle"} class="text-sm text-muted-foreground">
            Enter a query to see grounded citations.
          </div>

          <div
            :if={@status == :loading}
            id={"#{@id}-loading"}
            class="rounded-xl border border-border bg-background/70 p-4"
          >
            <div class="assistant-loading-indicator text-sm text-foreground">
              <span class="assistant-loading-dots" aria-hidden="true">
                <span></span>
                <span></span>
                <span></span>
              </span>
              <span>Working on "<span class="ph-mask font-semibold">{@query}</span>"...</span>
            </div>
            <div class="mt-3 space-y-2">
              <div class="h-2 w-full rounded bg-primary/20 animate-pulse"></div>
              <div class="h-2 w-5/6 rounded bg-primary/15 animate-pulse"></div>
              <div class="h-2 w-2/3 rounded bg-primary/10 animate-pulse"></div>
            </div>
          </div>

          <div :if={@status == :answer and is_map(@response)} id={"#{@id}-answer"} class="space-y-4">
            <div
              :if={fallback_banner(@response)}
              class="rounded-lg border border-accent-yellow/30 bg-accent-yellow/10 p-3 text-xs font-semibold text-accent-yellow"
            >
              {fallback_banner(@response)}
            </div>

            <div class="rounded-xl border border-border bg-background/70 p-4">
              <div class="prose prose-sm content-assistant-prose max-w-none text-foreground prose-headings:text-foreground prose-p:text-foreground prose-li:text-foreground prose-a:text-primary">
                {Phoenix.HTML.raw(@response.answer_html || "")}
              </div>
            </div>

            <div
              :if={@enhancement_status == :running}
              id={"#{@id}-enhancing"}
              class="rounded-lg border border-primary/30 bg-primary/5 p-3 text-xs text-foreground"
            >
              <div class="assistant-loading-indicator">
                <span class="assistant-loading-dots" aria-hidden="true">
                  <span></span>
                  <span></span>
                  <span></span>
                </span>
                <span>Improving this answer with the LLM...</span>
              </div>
            </div>

            <div class="space-y-2">
              <div class="flex flex-wrap items-center justify-between gap-2">
                <p class="text-xs font-semibold uppercase tracking-wide text-primary">Citations</p>

                <div
                  :if={result_type_facets(@response.citations || []) != []}
                  class="flex flex-wrap items-center gap-1.5"
                  role="group"
                  aria-label="Filter citations by type"
                >
                  <button
                    type="button"
                    phx-click="select_result_filter"
                    phx-target={@myself}
                    phx-value-type="all"
                    aria-pressed={to_string(is_nil(@result_filter))}
                    class={filter_chip_class(is_nil(@result_filter))}
                  >
                    All
                  </button>
                  <%= for {type, label, count} <- result_type_facets(@response.citations || []) do %>
                    <button
                      type="button"
                      phx-click="select_result_filter"
                      phx-target={@myself}
                      phx-value-type={type}
                      aria-pressed={to_string(@result_filter == type)}
                      class={filter_chip_class(@result_filter == type)}
                    >
                      {label}<span class="ml-1 text-[10px] font-normal opacity-70">{count}</span>
                    </button>
                  <% end %>
                </div>
              </div>
              <div class="search-modal-scrollbar max-h-[34vh] overflow-y-auto pr-1 space-y-2">
                <%= for {citation, rank} <- Enum.with_index(filter_citations_by_type(@response.citations || [], @result_filter), 1) do %>
                  <div class="rounded-lg border border-border bg-background/70 p-3">
                    <div class="mb-2 flex flex-wrap items-center gap-2">
                      <p class="text-xs font-semibold uppercase tracking-wide text-primary">
                        {source_label(citation.source_type)}
                      </p>
                      <span
                        :if={provider_label(citation.provider)}
                        class="rounded-full border border-border px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-muted-foreground"
                      >
                        {provider_label(citation.provider)}
                      </span>
                      <span
                        :if={page_kind_label(citation.page_kind)}
                        class="rounded-full border border-border px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-muted-foreground"
                      >
                        {page_kind_label(citation.page_kind)}
                      </span>
                      <span
                        :if={content_type_label(citation.content_type)}
                        class="rounded-full border border-primary/30 bg-primary/5 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-primary"
                      >
                        {content_type_label(citation.content_type)}
                      </span>
                      <span
                        :if={proof_level_label(citation.proof_level)}
                        class="rounded-full border border-border px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-muted-foreground"
                        title="Strength of evidence behind this result"
                      >
                        {proof_level_label(citation.proof_level)}
                      </span>
                    </div>
                    <p class="text-sm font-medium text-foreground">{citation.title}</p>
                    <p class="mt-1 text-xs text-muted-foreground">{citation.snippet}</p>
                    <p :if={reference_meta(citation) != []} class="mt-2 text-[11px] text-muted-foreground">
                      {Enum.join(reference_meta(citation), " • ")}
                    </p>
                    <div class="mt-3 flex flex-wrap items-center gap-2">
                      <a
                        href={citation.url}
                        target={result_target(citation)}
                        rel={result_rel(citation)}
                        phx-click={
                          JS.push("reference_click",
                            target: @myself,
                            value: %{
                              url: citation.url,
                              rank: rank,
                              external: if(external_result?(citation), do: "true", else: "false"),
                              provider: analytics_value(citation.provider),
                              package_id: citation.package_id,
                              package_version: citation.package_version,
                              page_kind: analytics_value(citation.page_kind)
                            }
                          )
                          |> hide_modal(@id)
                        }
                        class="inline-flex items-center rounded-md border border-border bg-card px-3 py-2 text-xs font-semibold text-foreground transition hover:border-primary/50"
                      >
                        {primary_action_label(citation)}
                      </a>
                      <a
                        :if={is_binary(citation.secondary_url) and citation.secondary_url != ""}
                        href={citation.secondary_url}
                        class="inline-flex items-center rounded-md border border-border bg-transparent px-3 py-2 text-xs font-semibold text-muted-foreground transition hover:border-primary/50 hover:text-foreground"
                      >
                        About Package
                      </a>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>

            <.feedback_prompt
              id={"#{@id}-feedback"}
              form_id={"#{@id}-feedback-form"}
              title="Was this answer helpful?"
              value={@feedback_value}
              note={@feedback_note}
              submitted={@feedback_submitted}
              select_event="feedback_select"
              submit_event="submit_feedback"
              target={@myself}
              note_placeholder="What would make this answer better?"
            />
          </div>

          <div :if={@status == :empty} id={"#{@id}-empty"} class="space-y-3 text-sm text-muted-foreground">
            <p>No relevant content found for "<span class="ph-mask font-semibold">{@query}</span>".</p>

            <.feedback_prompt
              id={"#{@id}-no-results-feedback"}
              form_id={"#{@id}-no-results-feedback-form"}
              title="Was this result helpful?"
              value={@feedback_value}
              note={@feedback_note}
              submitted={@feedback_submitted}
              select_event="feedback_select"
              submit_event="submit_feedback"
              target={@myself}
              note_placeholder="What were you trying to find?"
            />
          </div>

          <div :if={@status == :error} id={"#{@id}-error"} class="text-sm text-destructive">
            Content assistant is temporarily unavailable right now. Please try again in a moment.
          </div>

          <div :if={@thread != []} class="space-y-2 border-t border-border pt-4">
            <p class="text-xs font-semibold uppercase tracking-wide text-muted-foreground">Recent thread</p>
            <div class="search-modal-scrollbar max-h-[22vh] overflow-y-auto space-y-2 pr-1">
              <%= for turn <- @thread do %>
                <button
                  type="button"
                  phx-click="thread_select"
                  phx-value-q={turn.query}
                  phx-target={@myself}
                  class="ph-mask ph-no-capture w-full rounded-md border border-border bg-background/70 p-2 text-left transition hover:border-primary/50"
                >
                  <p class="text-xs font-semibold text-foreground">{turn.query}</p>
                  <p class="mt-1 text-[11px] text-muted-foreground">
                    {turn.mode_label} • {turn.citations_count} reference{if turn.citations_count == 1, do: "", else: "s"}
                  </p>
                </button>
              <% end %>
            </div>
          </div>
        </div>
      </.phx_modal>
    </div>
    """
  end

  @spec maybe_apply_assistant_complete(Phoenix.LiveView.Socket.t(), map()) :: Phoenix.LiveView.Socket.t()
  defp maybe_apply_assistant_complete(socket, %{assistant_complete: {assistant_ref, query, response}}) do
    if socket.assigns.assistant_ref == assistant_ref do
      response = maybe_prepare_progressive_fast_response(socket, response)
      apply_assistant_response(socket, query, response)
    else
      socket
    end
  end

  defp maybe_apply_assistant_complete(socket, _assigns), do: socket

  @spec maybe_apply_assistant_enhancement_complete(Phoenix.LiveView.Socket.t(), map()) :: Phoenix.LiveView.Socket.t()
  defp maybe_apply_assistant_enhancement_complete(socket, %{assistant_enhancement_complete: {enhancement_ref, _query, response}}) do
    if socket.assigns.enhancement_ref == enhancement_ref do
      apply_enhancement_response(socket, response)
    else
      socket
    end
  end

  defp maybe_apply_assistant_enhancement_complete(socket, _assigns), do: socket

  @spec apply_assistant_response(Phoenix.LiveView.Socket.t(), String.t(), Response.t()) :: Phoenix.LiveView.Socket.t()
  defp apply_assistant_response(socket, query, %Response{} = response) do
    latency_ms = query_latency_ms(socket.assigns.assistant_started_at)

    {status, query_status, results_count} =
      case response.answer_mode do
        :error -> {:error, "error", 0}
        :no_results -> {:empty, "no_results", 0}
        _mode -> {:answer, "success", length(response.citations || [])}
      end

    finalize_query_log(socket.assigns.query_log_id, query_status, results_count, latency_ms)
    capture_posthog_query_outcome(socket, response, socket.assigns.query_log_id, latency_ms)
    track_llm_request_outcome(socket, response)
    track_no_results_event(socket, response, socket.assigns.query_log_id)

    assign(socket,
      query: query,
      status: status,
      response: response,
      assistant_ref: nil,
      assistant_started_at: nil,
      enhancement_ref: nil,
      enhancement_status: :idle,
      query_log_id: nil,
      last_query_log_id: socket.assigns.query_log_id,
      result_filter: nil,
      thread: append_thread(socket.assigns.thread, response),
      turnstile_token: ""
    )
    |> reset_turnstile_widget()
    |> maybe_start_progressive_enhancement(query, response)
  end

  defp apply_assistant_response(socket, query, _response) do
    latency_ms = query_latency_ms(socket.assigns.assistant_started_at)
    finalize_query_log(socket.assigns.query_log_id, "error", 0, latency_ms)
    capture_posthog_query_error(socket, query, socket.assigns.query_log_id, latency_ms)
    track_llm_request_outcome(socket, nil)

    assign(socket,
      query: query,
      status: :error,
      response: nil,
      assistant_ref: nil,
      assistant_started_at: nil,
      enhancement_ref: nil,
      enhancement_status: :idle,
      query_log_id: nil,
      last_query_log_id: socket.assigns.query_log_id,
      turnstile_token: ""
    )
    |> reset_turnstile_widget()
  end

  defp run_content_assistant(module, query, query_log_id, opts) when is_atom(module) do
    case module.respond(query, Keyword.put(opts, :query_log_id, query_log_id)) do
      {:ok, %Response{} = response} ->
        response

      {:ok, _other} ->
        error_response(query, query_log_id)

      _other ->
        error_response(query, query_log_id)
    end
  rescue
    _ -> error_response(query, query_log_id)
  end

  defp run_content_assistant(_module, query, query_log_id, _opts), do: error_response(query, query_log_id)

  defp begin_assistant_query(socket, query, turnstile_token) do
    assistant_ref = System.unique_integer([:positive, :monotonic])
    component_id = socket.assigns.id
    live_view_pid = socket.root_pid || self()
    query_log_id = track_query_id(query, socket)
    assistant_module = content_assistant_module()
    assistant_opts = assistant_opts(socket, turnstile_token, :fast)

    Task.start(fn ->
      response = run_content_assistant(assistant_module, query, query_log_id, assistant_opts)
      send_update(live_view_pid, __MODULE__, id: component_id, assistant_complete: {assistant_ref, query, response})
    end)

    assign(socket,
      query: query,
      status: :loading,
      response: nil,
      assistant_ref: assistant_ref,
      assistant_started_at: System.monotonic_time(),
      enhancement_ref: nil,
      enhancement_status: :idle,
      query_log_id: query_log_id,
      last_query_log_id: nil,
      feedback_value: nil,
      feedback_note: "",
      feedback_submitted: false,
      turnstile_token: turnstile_token
    )
  end

  defp error_response(query, query_log_id) do
    %Response{
      query: query,
      answer_markdown: "",
      answer_html: "",
      answer_mode: :error,
      citations: [],
      retrieval_status: :failure,
      llm_attempted?: false,
      llm_enhanced?: false,
      enhancement_blocked_reason: nil,
      query_log_id: query_log_id
    }
  end

  defp maybe_prepare_progressive_fast_response(socket, %Response{} = response) do
    enhancement_opts = assistant_opts(socket, "", :enhancement)

    if should_start_progressive_enhancement?(response, enhancement_opts) do
      %Response{
        response
        | enhancement_blocked_reason: nil
      }
    else
      response
    end
  end

  defp maybe_prepare_progressive_fast_response(_socket, response), do: response

  defp maybe_start_progressive_enhancement(socket, query, %Response{} = response) do
    enhancement_opts = assistant_opts(socket, "", :enhancement)

    if should_start_progressive_enhancement?(response, enhancement_opts) do
      enhancement_ref = System.unique_integer([:positive, :monotonic])
      component_id = socket.assigns.id
      live_view_pid = socket.root_pid || self()
      assistant_module = content_assistant_module()

      Task.start(fn ->
        enhancement_started_at_ms = monotonic_ms()
        enhancement_response = run_content_assistant(assistant_module, query, nil, enhancement_opts)
        maybe_wait_for_progressive_dwell(enhancement_started_at_ms)

        send_update(
          live_view_pid,
          __MODULE__,
          id: component_id,
          assistant_enhancement_complete: {enhancement_ref, query, enhancement_response}
        )
      end)

      assign(socket, enhancement_ref: enhancement_ref, enhancement_status: :running)
    else
      assign(socket, enhancement_ref: nil, enhancement_status: :idle)
    end
  end

  defp maybe_start_progressive_enhancement(socket, _query, _response), do: assign(socket, enhancement_ref: nil, enhancement_status: :idle)

  defp apply_enhancement_response(socket, %Response{answer_mode: :llm} = response) do
    assign(socket,
      response: response,
      result_filter: nil,
      thread: replace_latest_thread_entry(socket.assigns.thread, response),
      enhancement_ref: nil,
      enhancement_status: :complete
    )
  end

  defp apply_enhancement_response(socket, _response) do
    assign(socket, enhancement_ref: nil, enhancement_status: :failed)
  end

  defp should_start_progressive_enhancement?(%Response{} = response, enhancement_opts) when is_list(enhancement_opts) do
    citations = response.citations || []

    progressive_mode?() and
      response.answer_mode != :llm and
      citations != [] and
      llm_enabled?(enhancement_opts)
  end

  defp should_start_progressive_enhancement?(_response, _enhancement_opts), do: false

  defp assistant_opts(socket, turnstile_token, stage) do
    retrieval_opts = [mode: search_retrieval_mode(), graph: true]

    default_opts =
      [
        citation_limit: @default_citation_limit,
        turnstile_token: turnstile_token,
        surface: "content_assistant_modal",
        metadata: %{surface: "content_assistant_modal"},
        retrieval_opts: retrieval_opts
      ]
      |> maybe_apply_search_response_mode(stage)

    session_opts =
      case socket.assigns[:assistant_opts] do
        opts when is_list(opts) -> opts
        _ -> []
      end

    default_opts
    |> Keyword.merge(session_opts)
    |> Keyword.put(:llm, nil)
    |> Keyword.put(:require_turnstile, false)
  end

  defp append_thread(thread, %Response{} = response) do
    item = %{
      query: response.query,
      mode_label: mode_label(response.answer_mode),
      citations_count: length(response.citations || [])
    }

    thread = List.wrap(thread)

    case thread do
      [%{query: query} | rest] when query == item.query ->
        [item | rest]

      _ ->
        [item | thread]
    end
    |> Enum.take(@default_thread_limit)
  end

  defp append_thread(thread, _response), do: List.wrap(thread)

  defp maybe_hydrate_recent_thread(%{assigns: %{thread: thread}} = socket) when is_list(thread) and thread != [],
    do: socket

  defp maybe_hydrate_recent_thread(socket) do
    thread =
      socket.assigns.analytics_identity
      |> QueryLogs.list_recent_identity_query_logs(@default_thread_limit)
      |> Enum.map(&thread_item_from_query_log/1)
      |> Enum.reject(&is_nil/1)

    assign(socket, :thread, thread)
  rescue
    _ -> assign(socket, :thread, [])
  end

  defp thread_item_from_query_log(query_log) when is_map(query_log) do
    query = Map.get(query_log, :query)
    status = Map.get(query_log, :status)
    results_count = Map.get(query_log, :results_count)

    if is_binary(query) and String.trim(query) != "" do
      %{
        query: query,
        mode_label: thread_mode_label(status),
        citations_count: normalize_results_count(results_count)
      }
    end
  end

  defp thread_item_from_query_log(_query_log), do: nil

  defp thread_mode_label("success"), do: "Deterministic"
  defp thread_mode_label("no_results"), do: "No results"
  defp thread_mode_label("submitted"), do: "Pending"
  defp thread_mode_label("challenge"), do: "Challenge"
  defp thread_mode_label("error"), do: "Error"
  defp thread_mode_label(_status), do: "Unknown"

  defp normalize_results_count(value) when is_integer(value) and value >= 0, do: value
  defp normalize_results_count(_value), do: 0

  defp replace_latest_thread_entry([_latest | rest], %Response{} = response) do
    [
      %{
        query: response.query,
        mode_label: mode_label(response.answer_mode),
        citations_count: length(response.citations || [])
      }
      | rest
    ]
  end

  defp replace_latest_thread_entry(thread, _response), do: thread

  defp reference_meta(citation) do
    [
      package_label(citation),
      package_version_label(citation),
      if(external_result?(citation), do: "Opens in new tab", else: nil)
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp package_version_label(%{package_version: version}) when is_binary(version) and version != "",
    do: "v#{version}"

  defp package_version_label(_citation), do: nil

  defp primary_action_label(citation) do
    if external_result?(citation), do: "Open in HexDocs", else: "Open"
  end

  defp fallback_banner(%Response{answer_mode: :quota_fallback}) do
    "LLM quota or rate limits are active. Showing citation-grounded fallback."
  end

  defp fallback_banner(%Response{answer_mode: :deterministic_fallback}) do
    "LLM response is temporarily unavailable. Showing citation-grounded fallback."
  end

  defp fallback_banner(%Response{enhancement_blocked_reason: :turnstile}) do
    "Verification challenge was incomplete. Showing deterministic citation-grounded response."
  end

  defp fallback_banner(%Response{enhancement_blocked_reason: :budget}) do
    "LLM enhancement is currently budget-limited. Showing deterministic citation-grounded response."
  end

  defp fallback_banner(%Response{enhancement_blocked_reason: :llm_unconfigured}) do
    "LLM enhancement is not configured. Showing deterministic citation-grounded response."
  end

  defp fallback_banner(_response), do: nil

  defp mode_label(:llm), do: "LLM"
  defp mode_label(:deterministic), do: "Deterministic"
  defp mode_label(:deterministic_fallback), do: "Deterministic fallback"
  defp mode_label(:quota_fallback), do: "Quota fallback"
  defp mode_label(:no_results), do: "No results"
  defp mode_label(:error), do: "Error"

  defp mode_label(mode) when is_atom(mode), do: mode |> Atom.to_string() |> String.replace("_", " ")
  defp mode_label(_mode), do: "Unknown"

  defp normalize_rank(value) when is_integer(value) and value > 0, do: value

  defp normalize_rank(value) when is_binary(value) do
    case Integer.parse(value) do
      {rank, ""} when rank > 0 -> rank
      _ -> nil
    end
  end

  defp normalize_rank(_value), do: nil

  defp track_query_id(query, socket) when is_binary(query) do
    query_log_id =
      case QueryLogs.track_query_safe(socket.assigns.current_scope, socket.assigns.analytics_identity, %{
             source: "content_assistant",
             channel: "content_assistant_modal",
             query: query,
             status: "submitted",
             path: socket.assigns.analytics_identity[:path],
             referrer_host: socket.assigns.analytics_identity[:referrer_host],
             metadata: %{surface: "content_assistant_modal"}
           }) do
        %{id: id} -> id
        _ -> nil
      end

    analytics_module().track_event_safe(socket.assigns.current_scope, %{
      event: "content_assistant_submitted",
      source: "content_assistant",
      channel: "content_assistant_modal",
      path: socket.assigns.analytics_identity[:path] || "/",
      query_log_id: query_log_id,
      visitor_id: socket.assigns.analytics_identity[:visitor_id],
      session_id: socket.assigns.analytics_identity[:session_id],
      metadata: %{surface: "content_assistant_modal", query: query}
    })

    capture_posthog_query_submitted(socket, query, query_log_id)
    query_log_id
  end

  defp capture_posthog_query_submitted(socket, query, query_log_id) do
    PostHog.capture_event_safe(socket.assigns.current_scope, "content_assistant_query_submitted", %{
      visitor_id: socket.assigns.analytics_identity[:visitor_id],
      session_id: socket.assigns.analytics_identity[:session_id],
      source: "content_assistant",
      channel: "content_assistant_modal",
      path: socket.assigns.analytics_identity[:path] || "/",
      query_log_id: query_log_id,
      query_length: String.length(query),
      metadata: %{surface: "content_assistant_modal", origin: "submit"}
    })
  end

  defp capture_posthog_query_outcome(socket, %Response{} = response, query_log_id, latency_ms) do
    event_name =
      case response.answer_mode do
        :error -> "content_assistant_query_error"
        :no_results -> "content_assistant_query_no_results"
        _mode -> "content_assistant_query_completed"
      end

    PostHog.capture_event_safe(socket.assigns.current_scope, event_name, %{
      visitor_id: socket.assigns.analytics_identity[:visitor_id],
      session_id: socket.assigns.analytics_identity[:session_id],
      source: "content_assistant",
      channel: "content_assistant_modal",
      path: socket.assigns.analytics_identity[:path] || "/",
      query_log_id: query_log_id || response.query_log_id,
      query_length: String.length(response.query || ""),
      results_count: length(response.citations || []),
      latency_ms: max(latency_ms, 0),
      metadata: analytics_metadata(response, %{surface: "content_assistant_modal", origin: "submit"})
    })
  end

  defp capture_posthog_query_error(socket, query, query_log_id, latency_ms) do
    PostHog.capture_event_safe(socket.assigns.current_scope, "content_assistant_query_error", %{
      visitor_id: socket.assigns.analytics_identity[:visitor_id],
      session_id: socket.assigns.analytics_identity[:session_id],
      source: "content_assistant",
      channel: "content_assistant_modal",
      path: socket.assigns.analytics_identity[:path] || "/",
      query_log_id: query_log_id,
      query_length: String.length(query || ""),
      results_count: 0,
      latency_ms: max(latency_ms, 0),
      metadata: %{surface: "content_assistant_modal", origin: "submit", retrieval_status: "failure", answer_mode: "error"}
    })
  end

  # Categorized first-LLM-request outcome (jido-e12-t24). Mirrors the page
  # LiveView: records the categorized outcome/reason for a visitor's content
  # assistant query so provider setup problems stay distinct from a generic
  # error. A nil `response` (task crash) categorizes as `error`.
  defp track_llm_request_outcome(socket, response) do
    %{outcome: outcome, reason: reason} = llm_request_outcome(response)

    analytics_module().track_event_safe(socket.assigns.current_scope, %{
      event: "llm_request_outcome",
      source: "content_assistant",
      channel: "content_assistant_modal",
      path: socket.assigns.analytics_identity[:path] || "/",
      query_log_id: socket.assigns.query_log_id,
      visitor_id: socket.assigns.analytics_identity[:visitor_id],
      session_id: socket.assigns.analytics_identity[:session_id],
      metadata: %{
        surface: "content_assistant_modal",
        outcome: outcome,
        reason: reason
      }
    })
  end

  defp finalize_query_log(query_log_id, status, results_count, latency_ms)
       when is_binary(status) and is_integer(results_count) do
    QueryLogs.finalize_query_safe(query_log_id, %{
      status: status,
      results_count: max(results_count, 0),
      latency_ms: max(latency_ms, 0)
    })
  end

  # First-party no-result analytics (jido-e10-t06). Mirrors the page LiveView:
  # records a discrete `content_assistant_query_no_results` event with no raw
  # query text — the query is referenced by `query_log_id` (redacted + hashed
  # row) and summarized as `query_length`, and the active search `filters` and
  # `path` (route) are recorded. `filters` now carries the result-type filter a
  # visitor had active when the query ran, so a no-result query can be
  # attributed to that filter (jido-e10-t07). It runs before the filter is reset
  # in `apply_assistant_response`, so the submit-time filter is what is recorded.
  defp track_no_results_event(socket, %Response{answer_mode: :no_results} = response, query_log_id) do
    analytics_module().track_event_safe(socket.assigns.current_scope, %{
      event: "content_assistant_query_no_results",
      source: "content_assistant",
      channel: "content_assistant_modal",
      path: socket.assigns.analytics_identity[:path] || "/",
      query_log_id: query_log_id || response.query_log_id,
      visitor_id: socket.assigns.analytics_identity[:visitor_id],
      session_id: socket.assigns.analytics_identity[:session_id],
      metadata:
        analytics_metadata(response, %{
          surface: "content_assistant_modal",
          query_length: String.length(response.query || ""),
          results_count: length(response.citations || []),
          filters: result_filter_analytics(socket.assigns.result_filter)
        })
    })
  end

  defp track_no_results_event(_socket, _response, _query_log_id), do: :ok

  defp component_id(socket, assigns) do
    Map.get(assigns, :id) || Map.get(socket.assigns, :id) || "primary-nav-content-assistant-modal"
  end

  defp content_assistant_module do
    Application.get_env(:agent_jido, :content_assistant_module, ContentAssistant)
  end

  defp progressive_mode?, do: search_response_mode() == :progressive

  defp analytics_module do
    Application.get_env(:agent_jido, :analytics_module, Analytics)
  end
end
