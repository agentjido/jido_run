defmodule AgentJidoWeb.ContentAssistantLive do
  @moduledoc """
  Public LiveView for unified content assistant interactions.
  """
  use AgentJidoWeb, :live_view

  alias AgentJido.Analytics
  alias AgentJido.Analytics.PostHog
  alias AgentJido.ContentAssistant
  alias AgentJido.ContentAssistant.PageResponseCache
  alias AgentJido.ContentAssistant.Response
  alias AgentJido.QueryLogs

  import AgentJidoWeb.Jido.MarketingLayouts

  import AgentJidoWeb.ContentAssistantSupport,
    only: [
      analytics_value: 1,
      analytics_metadata: 2,
      config_value: 3,
      content_assistant_config: 0,
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
      turnstile_site_key: 0
    ]

  require Logger

  @default_thread_limit 8
  @default_query_max_length 500
  @default_assistant_timeout_ms 12_000
  @default_citation_limit 6
  @assistant_task_supervisor AgentJido.ContentAssistant.TaskSupervisor

  @telemetry_issued_event [:agent_jido, :content_assistant, :query, :issued]
  @telemetry_success_event [:agent_jido, :content_assistant, :query, :success]
  @telemetry_failure_event [:agent_jido, :content_assistant, :query, :failure]

  @impl true
  def mount(params, session, socket) do
    query = initial_query(params)

    socket =
      socket
      |> assign(:page_title, "Search")
      |> assign(:query, query)
      |> assign(:query_error, nil)
      |> assign(:url_query, query)
      |> assign(:status, :idle)
      |> assign(:response, nil)
      |> assign(:assistant_task_ref, nil)
      |> assign(:assistant_task_pid, nil)
      |> assign(:assistant_timeout_ref, nil)
      |> assign(:assistant_started_at, nil)
      |> assign(:enhancement_task_ref, nil)
      |> assign(:enhancement_task_pid, nil)
      |> assign(:enhancement_timeout_ref, nil)
      |> assign(:enhancement_status, :idle)
      |> assign(:assistant_query_log_id, nil)
      |> assign(:assistant_origin, nil)
      |> assign(:assistant_cache_key, nil)
      |> assign(:pending_submit_query, nil)
      |> assign(:last_query_log_id, nil)
      |> assign(:feedback_value, nil)
      |> assign(:feedback_note, "")
      |> assign(:feedback_submitted, false)
      |> assign(:result_filter, nil)
      |> assign(:thread, [])
      |> assign(:turnstile_token, "")
      |> assign(:content_assistant_module, resolve_content_assistant_module(session))
      |> assign(:assistant_opts, resolve_assistant_opts(session))
      |> assign(:turnstile_required, require_turnstile?())
      |> assign(:turnstile_site_key, turnstile_site_key())
      |> assign(:turnstile_widget_id, "content-assistant-page-turnstile")
      |> assign(:turnstile_input_id, "content-assistant-page-turnstile-token")
      |> assign(:turnstile_submit_id, "content-assistant-page-submit")
      |> assign(:turnstile_status_id, "content-assistant-page-turnstile-status")
      |> assign(:turnstile_retry_id, "content-assistant-page-turnstile-retry")

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    turnstile_available =
      assigns.turnstile_required and
        is_binary(assigns.turnstile_site_key) and
        String.trim(assigns.turnstile_site_key) != ""

    assigns = assign(assigns, :turnstile_available, turnstile_available)

    ~H"""
    <.marketing_layout
      current_path="/search"
      layout_class="content-assistant-layout"
      current_scope={@current_scope}
      analytics_identity={@analytics_identity}
    >
      <div id="content-assistant-page" class="content-assistant-page container max-w-[1000px] mx-auto px-6 py-8 sm:py-10">
        <section class="assistant-hero-card rounded-2xl border border-border bg-card p-6 shadow-sm sm:p-8">
          <div class="flex flex-wrap items-start justify-between gap-3">
            <div>
              <p class="text-xs font-semibold uppercase tracking-[0.24em] text-muted-foreground">Content Assistant</p>
              <h1 class="mt-3 text-3xl font-semibold tracking-tight text-foreground sm:text-4xl">Search</h1>
              <p class="mt-3 max-w-3xl text-sm text-muted-foreground sm:text-base">
                Search docs, blog posts, and ecosystem packages with grounded citations.
              </p>
            </div>

            <button
              type="button"
              phx-click="new_topic"
              class="rounded-md border border-border bg-background px-3 py-2 text-xs font-semibold text-foreground hover:border-primary/50"
            >
              New topic
            </button>
          </div>

          <.form
            id="content-assistant-form"
            for={%{}}
            as={:assistant}
            phx-submit="submit"
            class="mt-6 space-y-3 ph-no-capture ph-sensitive"
          >
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
                id="content-assistant-input"
                name="assistant[q]"
                type="search"
                value={@query}
                placeholder="Search docs, blog, and ecosystem..."
                class="w-full rounded-xl border border-border bg-background px-4 py-3 text-sm text-foreground placeholder:text-muted-foreground focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary/25"
              />
              <button
                id={@turnstile_submit_id}
                type="submit"
                class="rounded-xl bg-primary px-5 py-3 text-sm font-semibold text-primary-foreground transition hover:bg-primary/90"
              >
                Search
              </button>
            </div>

            <p :if={is_binary(@query_error) and @query_error != ""} class="text-xs font-medium text-destructive">
              {@query_error}
            </p>

            <div :if={@turnstile_available}>
              <div
                id={@turnstile_widget_id}
                phx-hook="ContentAssistantTurnstile"
                data-site-key={@turnstile_site_key}
                data-input-id={@turnstile_input_id}
                data-appearance="interaction-only"
                data-size="invisible"
                data-execution="execute"
                data-load-trigger="mount"
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
          </.form>
        </section>

        <section
          :if={@status == :idle}
          id="content-assistant-idle-state"
          class="assistant-state-card rounded-2xl border border-dashed border-border bg-background/80 p-6 text-sm text-muted-foreground"
        >
          Enter a question to start.
        </section>

        <section
          :if={@status == :loading}
          id="content-assistant-loading-state"
          class="assistant-state-card rounded-2xl border border-border bg-card p-6 text-sm text-foreground"
        >
          <div class="assistant-loading-indicator">
            <span class="assistant-loading-dots" aria-hidden="true">
              <span></span>
              <span></span>
              <span></span>
            </span>
            <span>Working on "<span class="ph-mask font-semibold">{@query}</span>"...</span>
          </div>
          <p class="mt-2 text-xs text-muted-foreground">Retrieving references and citations.</p>
        </section>

        <section
          :if={@status == :answer and is_map(@response)}
          id="content-assistant-answer-state"
          class="assistant-answer-card space-y-4 rounded-2xl border border-border bg-card p-6"
        >
          <div
            :if={fallback_banner(@response, @turnstile_available)}
            class="rounded-lg border border-accent-yellow/30 bg-accent-yellow/10 p-3 text-xs font-semibold text-accent-yellow"
          >
            {fallback_banner(@response, @turnstile_available)}
          </div>

          <div class="rounded-md border border-border bg-background/70 p-3 text-xs text-muted-foreground">
            <p class="font-semibold text-foreground">{mode_title(@response)}</p>
            <details class="mt-1">
              <summary class="cursor-pointer">Why this answer mode?</summary>
              <p class="mt-2">{mode_reason(@response, @turnstile_available)}</p>
            </details>
          </div>

          <div
            :if={@enhancement_status == :running}
            id="content-assistant-enhancing-state"
            class="rounded-md border border-primary/30 bg-primary/5 p-3 text-xs text-foreground"
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

          <div
            class="prose content-assistant-prose max-w-none text-foreground prose-headings:text-foreground prose-p:text-foreground prose-li:text-foreground prose-a:text-primary"
            data-analytics-query-log-id={@last_query_log_id}
          >
            {Phoenix.HTML.raw(@response.answer_html || "")}
          </div>

          <div class="space-y-2">
            <div class="flex flex-wrap items-center justify-between gap-2">
              <p class="text-xs font-semibold uppercase tracking-wide text-primary">References</p>

              <div
                :if={result_type_facets(@response.citations || []) != []}
                id="content-assistant-result-type-filter"
                class="flex flex-wrap items-center gap-1.5"
                role="group"
                aria-label="Filter references by type"
              >
                <button
                  type="button"
                  phx-click="select_result_filter"
                  phx-value-type="all"
                  aria-pressed={to_string(is_nil(@result_filter))}
                  class={filter_chip_class(is_nil(@result_filter))}
                >
                  All
                </button>
                <button
                  :for={{type, label, count} <- result_type_facets(@response.citations || [])}
                  type="button"
                  phx-click="select_result_filter"
                  phx-value-type={type}
                  aria-pressed={to_string(@result_filter == type)}
                  class={filter_chip_class(@result_filter == type)}
                >
                  {label}<span class="ml-1 text-[10px] font-normal opacity-70">{count}</span>
                </button>
              </div>
            </div>
            <div class="assistant-references-grid space-y-2">
              <div
                :for={{citation, rank} <- Enum.with_index(filter_citations_by_type(@response.citations || [], @result_filter), 1)}
                class="assistant-reference-card rounded-lg border border-border bg-background/70 p-3"
              >
                <div class="mb-2 flex flex-wrap items-center gap-2">
                  <p class="text-xs font-semibold uppercase tracking-wide text-primary">[{rank}] {source_label(citation.source_type)}</p>
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
                    data-analytics-event="content_assistant_reference_clicked"
                    data-analytics-source="content_assistant"
                    data-analytics-channel="content_assistant_page"
                    data-analytics-rank={rank}
                    data-analytics-target-url={citation.url}
                    data-analytics-query-log-id={@last_query_log_id}
                    data-analytics-external={if external_result?(citation), do: "true", else: "false"}
                    data-analytics-provider={analytics_value(citation.provider)}
                    data-analytics-package-id={citation.package_id}
                    data-analytics-package-version={citation.package_version}
                    data-analytics-page-kind={analytics_value(citation.page_kind)}
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
            </div>
          </div>

          <.feedback_prompt
            id="content-assistant-feedback"
            form_id="content-assistant-feedback-form"
            title="Was this answer helpful?"
            value={@feedback_value}
            note={@feedback_note}
            submitted={@feedback_submitted}
            select_event="feedback_select"
            submit_event="submit_feedback"
            note_placeholder="What would make this answer better?"
          />
        </section>

        <section
          :if={@status == :empty}
          id="content-assistant-no-results-state"
          class="assistant-state-card space-y-3 rounded-2xl border border-border bg-card p-6 text-sm text-muted-foreground"
        >
          <p>No relevant content found for "<span class="ph-mask font-semibold text-foreground">{@query}</span>".</p>

          <div :if={related_queries(@response) != []} class="space-y-2">
            <p class="text-xs font-semibold uppercase tracking-wide text-primary">Try one of these</p>
            <div class="flex flex-wrap gap-2">
              <button
                :for={suggestion <- related_queries(@response)}
                type="button"
                phx-click="suggest_query"
                phx-value-q={suggestion}
                class="rounded-full border border-border bg-background px-3 py-1 text-xs text-foreground hover:border-primary/50"
              >
                {suggestion}
              </button>
            </div>
          </div>

          <.feedback_prompt
            id="content-assistant-no-results-feedback"
            form_id="content-assistant-no-results-feedback-form"
            title="Was this result helpful?"
            value={@feedback_value}
            note={@feedback_note}
            submitted={@feedback_submitted}
            select_event="feedback_select"
            submit_event="submit_feedback"
            note_placeholder="What were you trying to find?"
          />
        </section>

        <section
          :if={@status == :error}
          id="content-assistant-error-state"
          class="assistant-state-card rounded-2xl border border-accent-yellow/40 bg-accent-yellow/30 p-6 text-sm text-foreground"
        >
          Content assistant is temporarily unavailable right now. Please try again in a moment.
        </section>

        <section
          :if={@thread != []}
          id="content-assistant-thread"
          class="assistant-thread-card rounded-2xl border border-border bg-card p-6"
        >
          <h2 class="text-sm font-semibold uppercase tracking-[0.14em] text-muted-foreground">Recent thread</h2>
          <div class="mt-3 space-y-2">
            <div :for={turn <- @thread} class="assistant-thread-item rounded-lg border border-border bg-background/70 p-3">
              <p class="ph-mask text-sm font-semibold text-foreground">{turn.query}</p>
              <p class="mt-1 text-xs text-muted-foreground">
                {turn.mode_label} • {turn.citations_count} reference{if turn.citations_count == 1, do: "", else: "s"}
              </p>
            </div>
          </div>
        </section>
      </div>
    </.marketing_layout>
    """
  end

  @impl true
  def handle_params(params, _uri, socket) do
    query = initial_query(params)
    socket = assign(socket, :url_query, query)

    cond do
      query == "" ->
        {:noreply, clear_query_state(socket)}

      connected?(socket) and should_run_query?(socket, query) ->
        {socket, origin} = consume_query_origin(socket, query)
        turnstile_token = if origin == :user_submit, do: socket.assigns.turnstile_token, else: ""
        {:noreply, begin_assistant(socket, query, origin, turnstile_token)}

      true ->
        {:noreply, assign(socket, query: query, query_error: nil)}
    end
  end

  @impl true
  def handle_event("submit", %{"assistant" => params}, socket) do
    raw_query = Map.get(params, "q")
    turnstile_token = normalize_query(Map.get(params, "turnstile_token"))

    case validate_query(raw_query, query_max_length()) do
      {:error, message, query} ->
        {:noreply, assign(socket, query: query, query_error: message)}

      {:ok, ""} ->
        socket =
          socket
          |> cancel_inflight()
          |> clear_query_state()

        if socket.assigns.url_query == "" do
          {:noreply, socket}
        else
          {:noreply, push_patch(socket, to: "/search")}
        end

      {:ok, query} ->
        if socket.assigns.url_query == query do
          socket = assign(socket, :pending_submit_query, nil)
          {:noreply, begin_assistant(socket, query, :user_submit, turnstile_token)}
        else
          {:noreply,
           socket
           |> assign(:turnstile_token, turnstile_token)
           |> assign(:pending_submit_query, query)
           |> push_patch(to: search_path(query))}
        end
    end
  end

  @impl true
  def handle_event("suggest_query", %{"q" => query}, socket) do
    normalized = normalize_query(query)

    if normalized == "" do
      {:noreply, socket}
    else
      {:noreply, push_patch(socket, to: search_path(normalized))}
    end
  end

  # Result-type filter (jido-e10-t07). A visitor narrows the displayed
  # references to one source surface (Docs, Examples, Ecosystem, Blog, Skills).
  # The filter is a display facet over the retrieved citations, so selecting it
  # only re-renders. `"all"` and unknown values clear the filter so a bad value
  # can never empty the list.
  @impl true
  def handle_event("select_result_filter", %{"type" => type}, socket) do
    {:noreply, assign(socket, :result_filter, normalize_result_type_filter(type))}
  end

  @impl true
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

  @impl true
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
      channel = if socket.assigns.status == :empty, do: "content_assistant_no_results", else: "content_assistant_page"

      analytics_module().track_feedback_safe(socket.assigns.current_scope, %{
        event: "feedback_submitted",
        source: "content_assistant",
        channel: channel,
        path: socket.assigns.analytics_identity[:path] || "/search",
        feedback_value: feedback_value,
        feedback_note: feedback_note,
        query_log_id: socket.assigns.last_query_log_id,
        visitor_id: socket.assigns.analytics_identity[:visitor_id],
        session_id: socket.assigns.analytics_identity[:session_id],
        metadata: analytics_metadata(response, %{surface: "content_assistant"})
      })

      {:noreply, assign(socket, feedback_note: "", feedback_value: feedback_value, feedback_submitted: true)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("new_topic", _params, socket) do
    socket =
      socket
      |> cancel_inflight()
      |> reset_topic_state()

    if socket.assigns.url_query == "" do
      {:noreply, socket}
    else
      {:noreply, push_patch(socket, to: "/search")}
    end
  end

  @impl true
  def handle_info({ref, response}, %{assigns: %{assistant_task_ref: ref}} = socket) do
    Process.demonitor(ref, [:flush])
    cancel_timeout_timer(socket.assigns.assistant_timeout_ref)
    turnstile_token = socket.assigns.turnstile_token

    assistant_response = normalize_response(response, socket.assigns.query)
    assistant_response = maybe_prepare_progressive_fast_response(socket, assistant_response, turnstile_token)

    socket =
      socket
      |> maybe_finalize_query_log(assistant_response)
      |> maybe_emit_query_outcome(assistant_response)
      |> maybe_cache_response(assistant_response)
      |> maybe_track_restore(assistant_response, false)
      |> apply_response(assistant_response)
      |> maybe_start_progressive_enhancement(assistant_response, turnstile_token)

    {:noreply, socket}
  end

  @impl true
  def handle_info({ref, response}, %{assigns: %{enhancement_task_ref: ref}} = socket) do
    Process.demonitor(ref, [:flush])
    cancel_timeout_timer(socket.assigns.enhancement_timeout_ref)
    enhancement_response = normalize_response(response, socket.assigns.query)

    socket =
      socket
      |> apply_enhancement_response(enhancement_response)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, reason}, %{assigns: %{assistant_task_ref: ref}} = socket) do
    case reason do
      :normal ->
        {:noreply, socket}

      _ ->
        cancel_timeout_timer(socket.assigns.assistant_timeout_ref)
        response = error_response(socket.assigns.query)

        socket =
          socket
          |> maybe_finalize_query_log(response)
          |> maybe_emit_query_outcome(response)
          |> maybe_track_restore(response, false)
          |> apply_response(response)

        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, reason}, %{assigns: %{enhancement_task_ref: ref}} = socket) do
    case reason do
      :normal ->
        {:noreply, socket}

      _ ->
        cancel_timeout_timer(socket.assigns.enhancement_timeout_ref)
        {:noreply, clear_enhancement_state(socket, :failed)}
    end
  end

  @impl true
  def handle_info({:assistant_timeout, ref}, %{assigns: %{assistant_task_ref: ref}} = socket) do
    if is_pid(socket.assigns.assistant_task_pid) do
      Process.exit(socket.assigns.assistant_task_pid, :kill)
    end

    response = timeout_fallback_response(socket)

    socket =
      socket
      |> maybe_finalize_query_log(response)
      |> maybe_emit_query_outcome(response)
      |> maybe_track_restore(response, false)
      |> apply_response(response)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:assistant_enhancement_timeout, ref}, %{assigns: %{enhancement_task_ref: ref}} = socket) do
    if is_pid(socket.assigns.enhancement_task_pid) do
      Process.exit(socket.assigns.enhancement_task_pid, :kill)
    end

    {:noreply, clear_enhancement_state(socket, :failed)}
  end

  @impl true
  def handle_info(_message, socket), do: {:noreply, socket}

  defp begin_assistant(socket, query, origin, turnstile_token) do
    socket = socket |> cancel_inflight() |> assign(query_error: nil, query: query, turnstile_token: turnstile_token)
    assistant_opts = assistant_opts(socket, turnstile_token, :fast)
    cache_key = response_cache_key(query, socket.assigns.content_assistant_module, assistant_opts)

    case maybe_restore_from_cache(socket, query, origin, cache_key) do
      {:restored, restored_socket} ->
        restored_socket

      :miss ->
        start_assistant_run(socket, query, origin, assistant_opts, cache_key, turnstile_token)
    end
  end

  defp ensure_assistant_task_supervisor do
    case Process.whereis(@assistant_task_supervisor) do
      pid when is_pid(pid) ->
        :ok

      nil ->
        case Task.Supervisor.start_link(name: @assistant_task_supervisor) do
          {:ok, _pid} -> :ok
          {:error, {:already_started, _pid}} -> :ok
          {:error, reason} -> {:error, reason}
        end
    end
  end

  defp maybe_restore_from_cache(socket, query, :url_restore, cache_key) do
    case PageResponseCache.get(cache_key) do
      {:ok, %Response{} = response} ->
        updated_response = %{response | query: query}

        socket =
          socket
          |> maybe_track_restore(updated_response, true)
          |> apply_response(updated_response)

        {:restored, socket}

      :miss ->
        :miss
    end
  end

  defp maybe_restore_from_cache(_socket, _query, _origin, _cache_key), do: :miss

  defp cancel_inflight(socket) do
    if is_reference(socket.assigns.assistant_task_ref) do
      Process.demonitor(socket.assigns.assistant_task_ref, [:flush])
    end

    if is_pid(socket.assigns.assistant_task_pid) do
      Process.exit(socket.assigns.assistant_task_pid, :kill)
    end

    cancel_timeout_timer(socket.assigns.assistant_timeout_ref)

    if is_reference(socket.assigns.enhancement_task_ref) do
      Process.demonitor(socket.assigns.enhancement_task_ref, [:flush])
    end

    if is_pid(socket.assigns.enhancement_task_pid) do
      Process.exit(socket.assigns.enhancement_task_pid, :kill)
    end

    cancel_timeout_timer(socket.assigns.enhancement_timeout_ref)

    assign(socket,
      assistant_task_ref: nil,
      assistant_task_pid: nil,
      assistant_timeout_ref: nil,
      assistant_started_at: nil,
      enhancement_task_ref: nil,
      enhancement_task_pid: nil,
      enhancement_timeout_ref: nil,
      enhancement_status: :idle,
      assistant_query_log_id: nil,
      assistant_origin: nil,
      assistant_cache_key: nil
    )
  end

  defp cancel_timeout_timer(nil), do: :ok

  defp cancel_timeout_timer(ref) when is_reference(ref) do
    Process.cancel_timer(ref)
    :ok
  end

  defp cancel_timeout_timer(_ref), do: :ok

  defp run_assistant(content_assistant_module, query, opts, query_log_id) do
    response =
      content_assistant_module.respond(
        query,
        opts
        |> Keyword.put(:query_log_id, query_log_id)
        |> Keyword.put(:surface, "content_assistant_page")
      )

    normalize_run_response(response, query, query_log_id)
  rescue
    _ -> error_response(query)
  end

  defp normalize_run_response({:ok, %Response{} = response}, _query, _query_log_id), do: response
  defp normalize_run_response(_response, query, _query_log_id), do: error_response(query)

  defp normalize_response(%Response{} = response, _query), do: response
  defp normalize_response(_response, query), do: error_response(query)

  defp timeout_fallback_response(socket) do
    query = socket.assigns.query

    try do
      assistant_opts = assistant_opts(socket, "")

      response =
        socket.assigns.content_assistant_module.respond(
          query,
          assistant_opts
          |> Keyword.put(:llm, nil)
          |> Keyword.put(:require_turnstile, false)
          |> Keyword.put(:query_log_id, socket.assigns.assistant_query_log_id)
          |> Keyword.put(:surface, "content_assistant_page")
        )

      case response do
        {:ok, %Response{} = assistant_response} -> assistant_response
        _ -> error_response(query)
      end
    rescue
      _ -> error_response(query)
    end
  end

  defp apply_response(socket, %Response{} = response) do
    status = status_from_response(response)

    socket
    |> assign(
      status: status,
      response: response,
      assistant_task_ref: nil,
      assistant_task_pid: nil,
      assistant_timeout_ref: nil,
      assistant_started_at: nil,
      enhancement_task_ref: nil,
      enhancement_task_pid: nil,
      enhancement_timeout_ref: nil,
      assistant_query_log_id: nil,
      assistant_origin: nil,
      assistant_cache_key: nil,
      enhancement_status: :idle,
      feedback_value: nil,
      feedback_note: "",
      feedback_submitted: false,
      result_filter: nil,
      thread: append_thread(socket.assigns.thread, response),
      query: response.query,
      turnstile_token: ""
    )
    |> reset_turnstile_widget()
  end

  defp maybe_cache_response(socket, %Response{} = response) do
    if cacheable_response?(response) and socket.assigns.assistant_cache_key do
      PageResponseCache.put(socket.assigns.assistant_cache_key, %{response | query_log_id: nil})
    end

    socket
  end

  defp cacheable_response?(%Response{answer_mode: :error}), do: false
  defp cacheable_response?(%Response{}), do: true

  defp maybe_track_restore(socket, %Response{} = response, cache_hit?) do
    if socket.assigns.assistant_origin == :url_restore or cache_hit? do
      analytics_module().track_event_safe(socket.assigns.current_scope, %{
        event: "content_assistant_restored",
        source: "content_assistant",
        channel: "content_assistant_page",
        path: socket.assigns.analytics_identity[:path] || "/search",
        visitor_id: socket.assigns.analytics_identity[:visitor_id],
        session_id: socket.assigns.analytics_identity[:session_id],
        metadata: %{
          surface: "content_assistant_page",
          cache_hit: cache_hit?,
          answer_mode: response.answer_mode,
          retrieval_status: response.retrieval_status
        }
      })
    end

    socket
  end

  defp maybe_finalize_query_log(socket, %Response{} = response) do
    if is_binary(socket.assigns.assistant_query_log_id) do
      QueryLogs.finalize_query_safe(socket.assigns.assistant_query_log_id, %{
        status: query_status_from_response(response),
        results_count: length(response.citations || []),
        latency_ms: elapsed_since_query_start(socket)
      })
    end

    assign(socket, :last_query_log_id, socket.assigns.assistant_query_log_id)
  end

  defp maybe_emit_query_outcome(socket, %Response{} = response) do
    if socket.assigns.assistant_origin == :user_submit do
      latency_ms = elapsed_since_query_start(socket)
      emit_query_outcome(response, response.query, latency_ms)
      capture_posthog_query_outcome(socket, response, latency_ms)
      track_llm_request_outcome(socket, response)
      track_no_results_event(socket, response)
    end

    socket
  end

  # First-party no-result analytics (jido-e10-t06). Records a discrete
  # `content_assistant_query_no_results` event so zero-hit searches are
  # measurable in the first-party store alongside PostHog and the query log.
  # The event carries no raw query text: the query is referenced by
  # `query_log_id` (whose row stores a redacted + hashed query) and summarized
  # as `query_length`, and the active search `filters` and `path` (route) are
  # recorded. `filters` now carries the result-type filter a visitor had active
  # when the query ran, so a no-result query can be attributed to that filter
  # (jido-e10-t07). It runs before `apply_response` resets the filter, so the
  # submit-time filter is what is recorded.
  defp track_no_results_event(socket, %Response{answer_mode: :no_results} = response) do
    analytics_module().track_event_safe(socket.assigns.current_scope, %{
      event: "content_assistant_query_no_results",
      source: "content_assistant",
      channel: "content_assistant_page",
      path: socket.assigns.analytics_identity[:path] || "/search",
      query_log_id: socket.assigns.last_query_log_id || response.query_log_id,
      visitor_id: socket.assigns.analytics_identity[:visitor_id],
      session_id: socket.assigns.analytics_identity[:session_id],
      metadata:
        analytics_metadata(response, %{
          surface: "content_assistant_page",
          query_length: String.length(response.query || ""),
          results_count: length(response.citations || []),
          filters: result_filter_analytics(socket.assigns.result_filter)
        })
    })
  end

  defp track_no_results_event(_socket, _response), do: :ok

  defp elapsed_since_query_start(socket) do
    case Map.get(socket.assigns, :assistant_started_at) do
      started_at when is_integer(started_at) ->
        System.monotonic_time()
        |> Kernel.-(started_at)
        |> System.convert_time_unit(:native, :millisecond)

      _ ->
        0
    end
  end

  defp maybe_prepare_progressive_fast_response(socket, %Response{} = response, turnstile_token) do
    enhancement_opts = assistant_opts(socket, turnstile_token, :enhancement)

    if should_start_progressive_enhancement?(socket, response, enhancement_opts) do
      %Response{
        response
        | enhancement_blocked_reason: nil
      }
    else
      response
    end
  end

  defp maybe_prepare_progressive_fast_response(_socket, response, _turnstile_token), do: response

  defp maybe_start_progressive_enhancement(socket, %Response{} = response, turnstile_token) do
    enhancement_opts = assistant_opts(socket, turnstile_token, :enhancement)

    if should_start_progressive_enhancement?(socket, response, enhancement_opts) do
      with :ok <- ensure_assistant_task_supervisor(),
           task <- start_enhancement_task(socket, response, enhancement_opts) do
        assign_enhancement_task(socket, task)
      else
        _ -> clear_enhancement_state(socket, :failed)
      end
    else
      clear_enhancement_state(socket, :idle)
    end
  end

  defp maybe_start_progressive_enhancement(socket, _response, _turnstile_token), do: clear_enhancement_state(socket, :idle)

  defp apply_enhancement_response(socket, %Response{answer_mode: :llm} = response) do
    socket
    |> assign(
      response: response,
      result_filter: nil,
      thread: replace_latest_thread_entry(socket.assigns.thread, response)
    )
    |> clear_enhancement_state(:complete)
  end

  defp apply_enhancement_response(socket, _response), do: clear_enhancement_state(socket, :failed)

  defp clear_enhancement_state(socket, status) do
    assign(socket,
      enhancement_task_ref: nil,
      enhancement_task_pid: nil,
      enhancement_timeout_ref: nil,
      enhancement_status: status
    )
  end

  defp should_start_progressive_enhancement?(socket, %Response{} = response, enhancement_opts) when is_list(enhancement_opts) do
    citations = response.citations || []

    progressive_mode?() and
      status_from_response(response) == :answer and
      response.answer_mode != :llm and
      citations != [] and
      llm_enabled?(enhancement_opts) and
      not is_reference(socket.assigns.enhancement_task_ref)
  end

  defp should_start_progressive_enhancement?(_socket, _response, _enhancement_opts), do: false

  defp maybe_track_query_id(:user_submit, query, socket), do: track_query_id(query, socket)
  defp maybe_track_query_id(_origin, _query, _socket), do: nil

  defp maybe_emit_query_issued(:user_submit, query), do: emit_query_issued(query)
  defp maybe_emit_query_issued(_origin, _query), do: :ok

  defp start_assistant_run(socket, query, origin, assistant_opts, cache_key, turnstile_token) do
    query_log_id = maybe_track_query_id(origin, query, socket)
    maybe_emit_query_issued(origin, query)

    with :ok <- ensure_assistant_task_supervisor(),
         task <-
           Task.Supervisor.async_nolink(@assistant_task_supervisor, fn ->
             run_assistant(socket.assigns.content_assistant_module, query, assistant_opts, query_log_id)
           end) do
      build_loading_socket(socket, task, query_log_id, origin, cache_key)
    else
      {:error, reason} ->
        fallback_assistant_run(socket, reason, query, assistant_opts, query_log_id, origin, cache_key, turnstile_token)
    end
  end

  defp build_loading_socket(socket, task, query_log_id, origin, cache_key) do
    timeout_ref = Process.send_after(self(), {:assistant_timeout, task.ref}, assistant_timeout_ms())

    assign(socket,
      status: :loading,
      response: nil,
      assistant_task_ref: task.ref,
      assistant_task_pid: task.pid,
      assistant_timeout_ref: timeout_ref,
      assistant_started_at: System.monotonic_time(),
      assistant_query_log_id: query_log_id,
      assistant_origin: origin,
      assistant_cache_key: cache_key,
      last_query_log_id: nil,
      feedback_value: nil,
      feedback_note: "",
      feedback_submitted: false,
      enhancement_task_ref: nil,
      enhancement_task_pid: nil,
      enhancement_timeout_ref: nil,
      enhancement_status: :idle
    )
  end

  defp fallback_assistant_run(socket, reason, query, assistant_opts, query_log_id, origin, cache_key, turnstile_token) do
    Logger.warning("content assistant task supervisor unavailable; falling back to inline execution: #{inspect(reason)}")

    socket_for_run =
      assign(socket,
        assistant_started_at: System.monotonic_time(),
        assistant_query_log_id: query_log_id,
        assistant_origin: origin,
        assistant_cache_key: cache_key,
        enhancement_task_ref: nil,
        enhancement_task_pid: nil,
        enhancement_timeout_ref: nil,
        enhancement_status: :idle
      )

    response =
      run_assistant(
        socket.assigns.content_assistant_module,
        query,
        assistant_opts,
        query_log_id
      )
      |> prepare_fast_response_for_fallback(socket_for_run, turnstile_token)

    socket_for_run
    |> maybe_cache_response(response)
    |> maybe_finalize_query_log(response)
    |> maybe_emit_query_outcome(response)
    |> maybe_track_restore(response, false)
    |> apply_response(response)
    |> maybe_start_progressive_enhancement(response, turnstile_token)
  end

  defp prepare_fast_response_for_fallback(response, socket, turnstile_token) do
    maybe_prepare_progressive_fast_response(socket, response, turnstile_token)
  end

  defp start_enhancement_task(socket, response, enhancement_opts) do
    Task.Supervisor.async_nolink(@assistant_task_supervisor, fn ->
      enhancement_started_at_ms = monotonic_ms()

      enhancement_response =
        run_assistant(socket.assigns.content_assistant_module, response.query, enhancement_opts, nil)

      maybe_wait_for_progressive_dwell(enhancement_started_at_ms)
      enhancement_response
    end)
  end

  defp assign_enhancement_task(socket, task) do
    timeout_ref = Process.send_after(self(), {:assistant_enhancement_timeout, task.ref}, assistant_timeout_ms())

    assign(socket,
      enhancement_task_ref: task.ref,
      enhancement_task_pid: task.pid,
      enhancement_timeout_ref: timeout_ref,
      enhancement_status: :running
    )
  end

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

  defp resolve_content_assistant_module(session) do
    case Map.get(session, "content_assistant_module") do
      module when is_atom(module) and not is_nil(module) -> module
      _ -> ContentAssistant
    end
  end

  defp resolve_assistant_opts(session) do
    case Map.get(session, "assistant_opts") do
      opts when is_list(opts) -> opts
      _ -> []
    end
  end

  defp initial_query(params) when is_map(params) do
    params
    |> Map.get("q")
    |> normalize_query()
  end

  defp initial_query(_params), do: ""

  defp should_run_query?(socket, query) when is_binary(query) do
    socket.assigns.status == :idle or socket.assigns.query != query or not is_map(socket.assigns.response)
  end

  defp should_run_query?(_socket, _query), do: false

  defp consume_query_origin(socket, query) do
    if socket.assigns.pending_submit_query == query do
      {assign(socket, :pending_submit_query, nil), :user_submit}
    else
      {assign(socket, :pending_submit_query, nil), :url_restore}
    end
  end

  defp search_path(query) when is_binary(query) do
    "/search?" <> URI.encode_query(%{"q" => query})
  end

  defp clear_query_state(socket) do
    socket
    |> cancel_inflight()
    |> assign(
      query: "",
      query_error: nil,
      url_query: "",
      response: nil,
      status: :idle,
      pending_submit_query: nil,
      last_query_log_id: nil,
      feedback_value: nil,
      feedback_note: "",
      feedback_submitted: false,
      result_filter: nil,
      turnstile_token: ""
    )
    |> reset_turnstile_widget()
  end

  defp reset_topic_state(socket) do
    socket
    |> clear_query_state()
    |> assign(thread: [])
  end

  defp validate_query(query, max_length) when is_integer(max_length) and max_length > 0 do
    normalized = normalize_query(query)

    cond do
      normalized == "" ->
        {:ok, ""}

      String.length(normalized) > max_length ->
        {:error, "Please keep your question under #{max_length} characters.", String.slice(normalized, 0, max_length)}

      true ->
        {:ok, normalized}
    end
  end

  defp validate_query(query, _max_length), do: {:ok, normalize_query(query)}

  defp track_query_id(query, socket) when is_binary(query) do
    query_log_id =
      case QueryLogs.track_query_safe(socket.assigns.current_scope, socket.assigns.analytics_identity, %{
             source: "content_assistant",
             channel: "content_assistant_page",
             query: query,
             status: "submitted",
             path: socket.assigns.analytics_identity[:path] || "/search",
             referrer_host: socket.assigns.analytics_identity[:referrer_host],
             metadata: %{surface: "content_assistant_page", origin: "submit"}
           }) do
        %{id: id} -> id
        _ -> nil
      end

    analytics_module().track_event_safe(socket.assigns.current_scope, %{
      event: "content_assistant_submitted",
      source: "content_assistant",
      channel: "content_assistant_page",
      path: socket.assigns.analytics_identity[:path] || "/search",
      query_log_id: query_log_id,
      visitor_id: socket.assigns.analytics_identity[:visitor_id],
      session_id: socket.assigns.analytics_identity[:session_id],
      metadata: %{surface: "content_assistant_page", query: query}
    })

    capture_posthog_query_submitted(socket, query, query_log_id)
    query_log_id
  end

  defp capture_posthog_query_submitted(socket, query, query_log_id) do
    PostHog.capture_event_safe(socket.assigns.current_scope, "content_assistant_query_submitted", %{
      visitor_id: socket.assigns.analytics_identity[:visitor_id],
      session_id: socket.assigns.analytics_identity[:session_id],
      source: "content_assistant",
      channel: "content_assistant_page",
      path: socket.assigns.analytics_identity[:path] || "/search",
      query_log_id: query_log_id,
      query_length: String.length(query),
      metadata: %{surface: "content_assistant_page", origin: "submit"}
    })
  end

  defp capture_posthog_query_outcome(socket, %Response{} = response, latency_ms) do
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
      channel: "content_assistant_page",
      path: socket.assigns.analytics_identity[:path] || "/search",
      query_log_id: socket.assigns.last_query_log_id || response.query_log_id,
      query_length: String.length(response.query || ""),
      results_count: length(response.citations || []),
      latency_ms: max(latency_ms, 0),
      metadata: analytics_metadata(response, %{surface: "content_assistant_page", origin: "submit"})
    })
  end

  # Categorized first-LLM-request outcome (jido-e12-t24). Records, for a
  # user-initiated content assistant query, whether the request succeeded or
  # failed and a categorized reason — provider setup problems
  # (`provider_unconfigured`/`provider_quota`/`verification_required`) stay
  # distinct from a generic error so the team can see where provider setup
  # blocks a visitor's first LLM request. `outcome` and `reason` come from the
  # shared categorization in `ContentAssistantSupport`.
  defp track_llm_request_outcome(socket, %Response{} = response) do
    %{outcome: outcome, reason: reason} = llm_request_outcome(response)

    analytics_module().track_event_safe(socket.assigns.current_scope, %{
      event: "llm_request_outcome",
      source: "content_assistant",
      channel: "content_assistant_page",
      path: socket.assigns.analytics_identity[:path] || "/search",
      query_log_id: socket.assigns.last_query_log_id || response.query_log_id,
      visitor_id: socket.assigns.analytics_identity[:visitor_id],
      session_id: socket.assigns.analytics_identity[:session_id],
      metadata: %{
        surface: "content_assistant_page",
        outcome: outcome,
        reason: reason
      }
    })
  end

  defp query_status_from_response(%Response{answer_mode: :no_results}), do: "no_results"
  defp query_status_from_response(%Response{answer_mode: :error}), do: "error"
  defp query_status_from_response(%Response{}), do: "success"

  defp status_from_response(%Response{answer_mode: :no_results}), do: :empty
  defp status_from_response(%Response{answer_mode: :error}), do: :error
  defp status_from_response(%Response{}), do: :answer

  defp emit_query_issued(query) do
    :telemetry.execute(@telemetry_issued_event, %{count: 1}, %{query_length: String.length(query)})
  rescue
    _ -> :ok
  end

  defp emit_query_outcome(%Response{answer_mode: :error}, query, latency_ms) do
    :telemetry.execute(
      @telemetry_failure_event,
      %{count: 1, latency_ms: max(latency_ms, 0)},
      %{query_length: String.length(query)}
    )
  rescue
    _ -> :ok
  end

  defp emit_query_outcome(%Response{} = response, query, latency_ms) do
    :telemetry.execute(
      @telemetry_success_event,
      %{count: 1, latency_ms: max(latency_ms, 0)},
      %{query_length: String.length(query), results_count: length(response.citations || [])}
    )
  rescue
    _ -> :ok
  end

  defp append_thread(thread, %Response{} = response) do
    item = %{
      query: response.query,
      mode_label: mode_label(response.answer_mode),
      citations_count: length(response.citations || [])
    }

    [item | List.wrap(thread)]
    |> Enum.take(@default_thread_limit)
  end

  defp append_thread(thread, _response), do: List.wrap(thread)

  defp fallback_banner(%Response{answer_mode: :quota_fallback}, _turnstile_available) do
    "LLM limits are active right now. Showing grounded mode with citations only."
  end

  defp fallback_banner(%Response{answer_mode: :deterministic_fallback}, _turnstile_available) do
    "Enhanced generation is temporarily unavailable. Showing grounded mode with citations only."
  end

  defp fallback_banner(%Response{enhancement_blocked_reason: :turnstile}, true) do
    "Complete verification to enable LLM enhancement. Showing grounded mode with citations only."
  end

  defp fallback_banner(%Response{enhancement_blocked_reason: :turnstile}, false) do
    "Verification configuration is unavailable right now. Showing grounded mode with citations only."
  end

  defp fallback_banner(%Response{enhancement_blocked_reason: :budget}, _turnstile_available) do
    "LLM enhancement is budget-limited right now. Showing grounded mode with citations only."
  end

  defp fallback_banner(%Response{enhancement_blocked_reason: :llm_unconfigured}, _turnstile_available) do
    "LLM enhancement is not configured. Showing grounded mode with citations only."
  end

  defp fallback_banner(_response, _turnstile_available), do: nil

  defp mode_title(%Response{answer_mode: :llm}), do: "Enhanced mode (LLM + citations)"
  defp mode_title(%Response{}), do: "Grounded mode (citations only)"

  defp mode_reason(%Response{answer_mode: :llm}, _turnstile_available) do
    "The answer was enhanced by the configured LLM and grounded with retrieved references."
  end

  defp mode_reason(%Response{enhancement_blocked_reason: :turnstile}, true) do
    "Verification was required for LLM enhancement, so the assistant returned a deterministic citation-grounded response."
  end

  defp mode_reason(%Response{enhancement_blocked_reason: :budget}, _turnstile_available) do
    "The budget guard blocked LLM enhancement, so deterministic grounded mode was used."
  end

  defp mode_reason(%Response{enhancement_blocked_reason: :llm_unconfigured}, _turnstile_available) do
    "No LLM provider is configured, so deterministic grounded mode was used."
  end

  defp mode_reason(%Response{}, _turnstile_available) do
    "This response was generated directly from retrieved citations without LLM enhancement."
  end

  defp related_queries(%Response{related_queries: related_queries}) when is_list(related_queries), do: related_queries
  defp related_queries(_response), do: []

  defp mode_label(:llm), do: "LLM"
  defp mode_label(:deterministic), do: "Grounded"
  defp mode_label(:deterministic_fallback), do: "Grounded fallback"
  defp mode_label(:quota_fallback), do: "Quota fallback"
  defp mode_label(:no_results), do: "No results"
  defp mode_label(:error), do: "Error"

  defp mode_label(mode) when is_atom(mode), do: mode |> Atom.to_string() |> String.replace("_", " ")
  defp mode_label(_mode), do: "Unknown"

  defp error_response(query) do
    %Response{
      query: query,
      answer_markdown: "",
      answer_html: "",
      answer_mode: :error,
      citations: [],
      related_queries: [],
      retrieval_status: :failure,
      llm_attempted?: false,
      llm_enhanced?: false,
      enhancement_blocked_reason: nil,
      query_log_id: nil
    }
  end

  defp assistant_opts(socket, turnstile_token, stage \\ :default) do
    retrieval_opts = [mode: search_retrieval_mode(), graph: true]

    default_opts =
      [
        citation_limit: @default_citation_limit,
        turnstile_token: turnstile_token,
        surface: "content_assistant_page",
        metadata: %{surface: "content_assistant_page"},
        assistant_timeout_ms: assistant_timeout_ms(),
        query_max_length: query_max_length(),
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

  defp response_cache_key(query, content_assistant_module, opts) do
    model_id =
      case Keyword.fetch(opts, :llm) do
        {:ok, llm} -> llm
        :error -> Application.get_env(:arcana, :llm)
      end

    fingerprint =
      opts
      |> Keyword.drop([:query_log_id, :turnstile_token, :remote_ip, :metadata])
      |> Enum.sort()
      |> :erlang.phash2()

    {query, content_assistant_module, "content_assistant_page", model_id, fingerprint}
  end

  defp assistant_timeout_ms do
    case content_assistant_config() |> config_value(:assistant_timeout_ms, @default_assistant_timeout_ms) do
      value when is_integer(value) and value > 0 -> value
      _ -> @default_assistant_timeout_ms
    end
  end

  defp query_max_length do
    case content_assistant_config() |> config_value(:query_max_length, @default_query_max_length) do
      value when is_integer(value) and value > 0 -> value
      _ -> @default_query_max_length
    end
  end

  defp progressive_mode?, do: search_response_mode() == :progressive

  defp analytics_module do
    Application.get_env(:agent_jido, :analytics_module, Analytics)
  end
end
