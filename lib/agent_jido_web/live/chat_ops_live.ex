defmodule AgentJidoWeb.ChatOpsLive do
  @moduledoc """
  Admin ChatOps console shell.
  """
  use AgentJidoWeb, :live_view

  alias AgentJido.ContentOps.Chat.{ActionTimeline, Guardrails, MessageTimeline, RoomInventory}

  @default_message_timeline_limit 50
  @default_action_timeline_limit 30

  @impl true
  def mount(_params, session, socket) do
    socket =
      socket
      |> assign(:inventory_provider, resolve_inventory_provider(session))
      |> assign(:message_provider, resolve_message_provider(session))
      |> assign(:action_timeline_provider, resolve_action_timeline_provider(session))
      |> assign(:guardrail_provider, resolve_guardrail_provider(session))
      |> assign(:message_timeline_limit, resolve_message_timeline_limit(session))
      |> assign(:action_timeline_limit, resolve_action_timeline_limit(session))
      |> assign(:room_inventory, [])
      |> assign(:inventory_error, nil)
      |> assign(:inventory_refreshed_at, nil)
      |> assign(:recent_messages, [])
      |> assign(:message_error, nil)
      |> assign(:message_refreshed_at, nil)
      |> assign(:action_timeline, [])
      |> assign(:action_timeline_error, nil)
      |> assign(:action_timeline_refreshed_at, nil)
      |> assign(:guardrails, default_guardrail_state())
      |> assign(:guardrail_error, nil)
      |> assign(:guardrail_refreshed_at, nil)
      |> refresh_inventory()
      |> refresh_recent_messages()
      |> refresh_action_timeline()
      |> refresh_guardrails()

    {:ok, socket}
  end

  @impl true
  def handle_event("refresh_inventory", _params, socket) do
    {:noreply, refresh_inventory(socket)}
  end

  @impl true
  def handle_event("refresh_messages", _params, socket) do
    {:noreply, refresh_recent_messages(socket)}
  end

  @impl true
  def handle_event("refresh_action_timeline", _params, socket) do
    {:noreply, refresh_action_timeline(socket)}
  end

  @impl true
  def handle_event("refresh_guardrails", _params, socket) do
    {:noreply, refresh_guardrails(socket)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <AgentJidoWeb.Jido.AdminNav.admin_shell current_path="/dashboard/chatops">
      <div class="container mx-auto max-w-6xl space-y-8 px-6 py-12">
        <header class="space-y-2">
          <p class="text-xs font-semibold uppercase tracking-[0.2em] text-primary">Admin Control Plane</p>
          <h1 class="text-3xl font-semibold text-foreground">ChatOps Console</h1>
          <p class="max-w-3xl text-sm text-muted-foreground">
            Operational shell for monitoring room state, chat activity, and execution safeguards.
          </p>
        </header>

        <section class="grid gap-4 lg:grid-cols-2">
          <article id="chatops-room-inventory-panel" class="space-y-4 rounded-lg border border-border bg-card p-6">
            <div class="flex items-start justify-between gap-4">
              <div class="space-y-1">
                <h2 class="text-lg font-semibold text-foreground">Room Inventory</h2>
                <p class="text-sm text-muted-foreground">
                  Current room-to-channel bindings for Telegram and Discord.
                </p>
              </div>
              <div class="flex items-center gap-3">
                <span :if={@inventory_refreshed_at} class="text-[10px] font-mono text-muted-foreground">
                  refreshed {format_refreshed_at(@inventory_refreshed_at)}
                </span>
                <button
                  id="chatops-room-inventory-refresh"
                  phx-click="refresh_inventory"
                  class="text-xs text-muted-foreground transition-colors hover:text-foreground"
                >
                  ↻ Refresh
                </button>
              </div>
            </div>

            <div :if={@inventory_error} id="chatops-room-inventory-error" class="text-xs font-mono text-accent-red">
              ⚠ Unable to load room inventory: {@inventory_error}
            </div>

            <div
              :if={@room_inventory == []}
              id="chatops-room-inventory-empty"
              class="rounded-md border border-dashed border-border bg-elevated/40 p-4 text-sm text-muted-foreground"
            >
              No room bindings are currently available.
            </div>

            <div :if={@room_inventory != []} id="chatops-room-inventory-list" class="space-y-3">
              <div :for={room <- @room_inventory} class="space-y-3 rounded-md border border-border bg-elevated/50 p-4">
                <div class="flex items-start justify-between gap-3">
                  <div class="space-y-1">
                    <h3 class="text-sm font-semibold text-foreground">{room.room_name}</h3>
                    <p class="text-xs font-mono text-muted-foreground">{room.room_id}</p>
                  </div>
                  <span class="text-[10px] uppercase tracking-wider text-muted-foreground">
                    {length(room.bindings)} binding(s)
                  </span>
                </div>

                <div :if={room.bindings == []} class="text-xs text-muted-foreground">
                  No channel bindings configured.
                </div>

                <ul :if={room.bindings != []} class="space-y-2">
                  <li :for={binding <- room.bindings} class="flex flex-wrap items-center gap-2 text-xs">
                    <span class="rounded-full border border-border bg-card px-2 py-0.5 font-semibold text-foreground">
                      {binding_channel_label(binding.channel)}
                    </span>
                    <span class="font-mono text-foreground">{binding.external_room_id || "—"}</span>
                    <span class="text-muted-foreground">
                      instance: <span class="font-mono text-foreground">{binding.instance_id || "—"}</span>
                    </span>
                  </li>
                </ul>
              </div>
            </div>
          </article>

          <article id="chatops-message-timeline-panel" class="space-y-4 rounded-lg border border-border bg-card p-6">
            <div class="flex items-start justify-between gap-4">
              <div class="space-y-1">
                <h2 class="text-lg font-semibold text-foreground">Recent Messages</h2>
                <p class="text-sm text-muted-foreground">
                  Recent chat activity across bound room channels.
                </p>
                <p class="text-[10px] font-mono uppercase tracking-wider text-muted-foreground">
                  showing latest {@message_timeline_limit} messages
                </p>
              </div>
              <div class="flex items-center gap-3">
                <span :if={@message_refreshed_at} class="text-[10px] font-mono text-muted-foreground">
                  refreshed {format_refreshed_at(@message_refreshed_at)}
                </span>
                <button
                  id="chatops-message-timeline-refresh"
                  phx-click="refresh_messages"
                  class="text-xs text-muted-foreground transition-colors hover:text-foreground"
                >
                  ↻ Refresh
                </button>
              </div>
            </div>

            <div :if={@message_error} id="chatops-message-timeline-error" class="text-xs font-mono text-accent-red">
              ⚠ Unable to load recent messages: {@message_error}
            </div>

            <div
              :if={@recent_messages == []}
              id="chatops-message-timeline-empty"
              class="rounded-md border border-dashed border-border bg-elevated/40 p-4 text-sm text-muted-foreground"
            >
              No recent messages are available.
            </div>

            <ol :if={@recent_messages != []} id="chatops-message-timeline-list" class="space-y-3">
              <li
                :for={{message, index} <- Enum.with_index(@recent_messages)}
                id={"chatops-message-row-#{index}"}
                class="space-y-2 rounded-md border border-border bg-elevated/50 p-4"
              >
                <div class="flex items-start justify-between gap-3">
                  <span class="text-[10px] font-mono uppercase tracking-wider text-muted-foreground">
                    {format_message_timestamp(message)}
                  </span>
                  <span class="rounded-full border border-border bg-card px-2 py-0.5 text-[10px] font-semibold text-foreground">
                    {message_channel_label(message)}
                  </span>
                </div>

                <div class="flex flex-wrap items-center gap-x-4 gap-y-1 text-xs text-muted-foreground">
                  <p>
                    room: <span class="font-mono text-foreground">{message_room_id(message)}</span>
                  </p>
                  <p>
                    actor: <span class="font-mono text-foreground">{message_actor(message)}</span>
                  </p>
                </div>

                <p class="text-sm leading-relaxed text-foreground">{message_snippet(message)}</p>
              </li>
            </ol>
          </article>

          <article id="chatops-action-timeline-panel" class="space-y-4 rounded-lg border border-border bg-card p-6">
            <div class="flex items-start justify-between gap-4">
              <div class="space-y-1">
                <h2 class="text-lg font-semibold text-foreground">Action/Run Timeline</h2>
                <p class="text-sm text-muted-foreground">
                  Run requests, policy outcomes, and completed ContentOps runs.
                </p>
                <p class="text-[10px] font-mono uppercase tracking-wider text-muted-foreground">
                  showing latest {@action_timeline_limit} events
                </p>
              </div>
              <div class="flex items-center gap-3">
                <span :if={@action_timeline_refreshed_at} class="text-[10px] font-mono text-muted-foreground">
                  refreshed {format_refreshed_at(@action_timeline_refreshed_at)}
                </span>
                <button
                  id="chatops-action-timeline-refresh"
                  phx-click="refresh_action_timeline"
                  class="text-xs text-muted-foreground transition-colors hover:text-foreground"
                >
                  ↻ Refresh
                </button>
              </div>
            </div>

            <div :if={@action_timeline_error} id="chatops-action-timeline-error" class="text-xs font-mono text-accent-red">
              ⚠ Unable to load action timeline: {@action_timeline_error}
            </div>

            <div
              :if={@action_timeline == []}
              id="chatops-action-timeline-empty"
              class="rounded-md border border-dashed border-border bg-elevated/40 p-4 text-sm text-muted-foreground"
            >
              No ChatOps actions or runs have been recorded yet.
            </div>

            <ol :if={@action_timeline != []} id="chatops-action-timeline-list" class="space-y-3">
              <li
                :for={{entry, index} <- Enum.with_index(@action_timeline)}
                id={"chatops-action-row-#{index}"}
                class={action_timeline_row_class(entry)}
              >
                <div class="flex flex-wrap items-center justify-between gap-2">
                  <span class="text-[10px] font-mono uppercase tracking-wider text-muted-foreground">
                    {format_action_timestamp(entry)}
                  </span>
                  <div class="flex items-center gap-2">
                    <span class={entry_type_badge_class(entry)}>
                      {action_entry_type_label(entry)}
                    </span>
                    <span class={entry_outcome_badge_class(entry)}>
                      {action_entry_outcome_label(entry)}
                    </span>
                  </div>
                </div>

                <p class="text-sm font-semibold text-foreground">{action_entry_label(entry)}</p>

                <div class="flex flex-wrap items-center gap-x-4 gap-y-1 text-xs text-muted-foreground">
                  <p>
                    actor: <span class="font-mono text-foreground">{action_entry_actor(entry)}</span>
                  </p>
                  <p>
                    authz:
                    <span class={action_entry_authz_class(entry)}>
                      {action_entry_authz_label(entry)}
                    </span>
                  </p>
                  <p>
                    mutation-enabled:
                    <span class={action_entry_mutation_class(entry)}>
                      {action_entry_mutation_label(entry)}
                    </span>
                  </p>
                </div>

                <p :if={action_entry_details(entry)} class="text-xs text-muted-foreground">
                  {action_entry_details(entry)}
                </p>
              </li>
            </ol>
          </article>

          <article id="chatops-guardrails-panel" class="space-y-4 rounded-lg border border-border bg-card p-6">
            <div class="flex items-start justify-between gap-4">
              <div class="space-y-1">
                <h2 class="text-lg font-semibold text-foreground">Guardrails</h2>
                <p class="text-sm text-muted-foreground">
                  Mutation safety and actor authorization outcomes.
                </p>
              </div>
              <div class="flex items-center gap-3">
                <span :if={@guardrail_refreshed_at} class="text-[10px] font-mono text-muted-foreground">
                  refreshed {format_refreshed_at(@guardrail_refreshed_at)}
                </span>
                <button
                  id="chatops-guardrails-refresh"
                  phx-click="refresh_guardrails"
                  class="text-xs text-muted-foreground transition-colors hover:text-foreground"
                >
                  ↻ Refresh
                </button>
              </div>
            </div>

            <div :if={@guardrail_error} id="chatops-guardrails-error" class="text-xs font-mono text-accent-red">
              ⚠ Unable to load guardrails: {@guardrail_error}
            </div>

            <div class="grid gap-3 sm:grid-cols-2">
              <div class="space-y-1 rounded-md border border-border bg-elevated/40 p-4">
                <p class="text-[10px] font-mono uppercase tracking-wider text-muted-foreground">Mutation Tools</p>
                <p id="chatops-guardrail-mutation-state" class={guardrail_mutation_class(@guardrails)}>
                  {guardrail_mutation_label(@guardrails)}
                </p>
              </div>

              <div class="space-y-1 rounded-md border border-border bg-elevated/40 p-4">
                <p class="text-[10px] font-mono uppercase tracking-wider text-muted-foreground">Latest Actor Authz Outcome</p>
                <p id="chatops-guardrail-authz-status" class={guardrail_authz_class(@guardrails)}>
                  {guardrail_authz_label(@guardrails)}
                </p>
              </div>
            </div>

            <div class="grid gap-3 sm:grid-cols-4 text-xs">
              <div class="rounded-md border border-border bg-elevated/40 p-3">
                <p class="text-[10px] uppercase tracking-wider text-muted-foreground">Authorized</p>
                <p id="chatops-guardrail-count-authorized" class="font-mono text-foreground">
                  {guardrail_count(@guardrails, :authorized)}
                </p>
              </div>
              <div class="rounded-md border border-border bg-elevated/40 p-3">
                <p class="text-[10px] uppercase tracking-wider text-muted-foreground">Unauthorized</p>
                <p id="chatops-guardrail-count-unauthorized" class="font-mono text-accent-red">
                  {guardrail_count(@guardrails, :unauthorized)}
                </p>
              </div>
              <div class="rounded-md border border-border bg-elevated/40 p-3">
                <p class="text-[10px] uppercase tracking-wider text-muted-foreground">Mutations Disabled</p>
                <p id="chatops-guardrail-count-mutations-disabled" class="font-mono text-accent-yellow">
                  {guardrail_count(@guardrails, :mutations_disabled)}
                </p>
              </div>
              <div class="rounded-md border border-border bg-elevated/40 p-3">
                <p class="text-[10px] uppercase tracking-wider text-muted-foreground">Blocked Actions</p>
                <p id="chatops-guardrail-count-blocked-actions" class="font-mono text-foreground">
                  {guardrail_blocked_actions(@guardrails)}
                </p>
              </div>
            </div>
          </article>
        </section>
      </div>
    </AgentJidoWeb.Jido.AdminNav.admin_shell>
    """
  end

  defp refresh_inventory(socket) do
    case fetch_inventory(socket.assigns.inventory_provider) do
      {:ok, room_inventory} ->
        socket
        |> assign(:room_inventory, room_inventory)
        |> assign(:inventory_error, nil)
        |> assign(:inventory_refreshed_at, DateTime.utc_now())

      {:error, reason} ->
        socket
        |> assign(:room_inventory, [])
        |> assign(:inventory_error, format_error(reason))
        |> assign(:inventory_refreshed_at, DateTime.utc_now())
    end
  end

  defp refresh_recent_messages(socket) do
    limit = socket.assigns.message_timeline_limit

    case fetch_recent_messages(socket.assigns.message_provider, limit: limit) do
      {:ok, recent_messages} ->
        socket
        |> assign(:recent_messages, Enum.take(recent_messages, limit))
        |> assign(:message_error, nil)
        |> assign(:message_refreshed_at, DateTime.utc_now())

      {:error, reason} ->
        socket
        |> assign(:recent_messages, [])
        |> assign(:message_error, format_error(reason))
        |> assign(:message_refreshed_at, DateTime.utc_now())
    end
  end

  defp refresh_action_timeline(socket) do
    limit = socket.assigns.action_timeline_limit

    case fetch_action_timeline(socket.assigns.action_timeline_provider, limit: limit) do
      {:ok, entries} ->
        socket
        |> assign(:action_timeline, normalize_action_timeline(entries, limit))
        |> assign(:action_timeline_error, nil)
        |> assign(:action_timeline_refreshed_at, DateTime.utc_now())

      {:error, reason} ->
        socket
        |> assign(:action_timeline, [])
        |> assign(:action_timeline_error, format_error(reason))
        |> assign(:action_timeline_refreshed_at, DateTime.utc_now())
    end
  end

  defp refresh_guardrails(socket) do
    case fetch_guardrails(socket.assigns.guardrail_provider) do
      {:ok, guardrails} ->
        socket
        |> assign(:guardrails, normalize_guardrails(guardrails))
        |> assign(:guardrail_error, nil)
        |> assign(:guardrail_refreshed_at, DateTime.utc_now())

      {:error, reason} ->
        socket
        |> assign(:guardrails, default_guardrail_state())
        |> assign(:guardrail_error, format_error(reason))
        |> assign(:guardrail_refreshed_at, DateTime.utc_now())
    end
  end

  defp fetch_inventory(provider) when is_atom(provider) do
    response =
      cond do
        function_exported?(provider, :fetch, 0) ->
          provider.fetch()

        function_exported?(provider, :fetch_room_inventory, 0) ->
          provider.fetch_room_inventory()

        true ->
          {:error, :invalid_inventory_provider}
      end

    case response do
      {:ok, inventory} when is_list(inventory) ->
        {:ok, normalize_inventory(inventory)}

      {:error, reason} ->
        {:error, reason}

      _other ->
        {:error, :invalid_inventory_response}
    end
  rescue
    error ->
      {:error, {:inventory_exception, Exception.message(error)}}
  catch
    :exit, reason ->
      {:error, {:inventory_exit, reason}}
  end

  defp fetch_inventory(_provider), do: {:error, :invalid_inventory_provider}

  defp fetch_recent_messages(provider, opts) when is_atom(provider) and is_list(opts) do
    case invoke_provider(provider, [{:fetch_recent_messages, opts}, {:fetch, opts}], :invalid_message_provider) do
      {:ok, recent_messages} when is_list(recent_messages) ->
        {:ok, recent_messages}

      recent_messages when is_list(recent_messages) ->
        {:ok, recent_messages}

      {:error, reason} ->
        {:error, reason}

      _other ->
        {:error, :invalid_messages_response}
    end
  rescue
    error ->
      {:error, {:messaging_exception, Exception.message(error)}}
  catch
    :exit, reason ->
      {:error, {:messaging_exit, reason}}
  end

  defp fetch_recent_messages(_provider, _opts), do: {:error, :invalid_message_provider}

  defp fetch_action_timeline(provider, opts) when is_atom(provider) and is_list(opts) do
    case invoke_provider(
           provider,
           [{:fetch_action_timeline, opts}, {:fetch, opts}],
           :invalid_action_timeline_provider
         ) do
      {:ok, entries} when is_list(entries) ->
        {:ok, entries}

      entries when is_list(entries) ->
        {:ok, entries}

      {:error, reason} ->
        {:error, reason}

      _other ->
        {:error, :invalid_action_timeline_response}
    end
  rescue
    error ->
      {:error, {:action_timeline_exception, Exception.message(error)}}
  catch
    :exit, reason ->
      {:error, {:action_timeline_exit, reason}}
  end

  defp fetch_action_timeline(_provider, _opts), do: {:error, :invalid_action_timeline_provider}

  defp fetch_guardrails(provider) when is_atom(provider) do
    response =
      cond do
        function_exported?(provider, :fetch_guardrails, 0) ->
          provider.fetch_guardrails()

        function_exported?(provider, :fetch, 0) ->
          provider.fetch()

        true ->
          {:error, :invalid_guardrail_provider}
      end

    case response do
      {:ok, guardrails} when is_map(guardrails) ->
        {:ok, guardrails}

      guardrails when is_map(guardrails) ->
        {:ok, guardrails}

      {:error, reason} ->
        {:error, reason}

      _other ->
        {:error, :invalid_guardrail_response}
    end
  rescue
    error ->
      {:error, {:guardrail_exception, Exception.message(error)}}
  catch
    :exit, reason ->
      {:error, {:guardrail_exit, reason}}
  end

  defp fetch_guardrails(_provider), do: {:error, :invalid_guardrail_provider}

  defp normalize_inventory(inventory) do
    inventory
    |> Enum.map(&normalize_room/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(& &1.room_id)
  end

  defp normalize_room(room) when is_map(room) do
    room_id =
      Map.get(room, :room_id) ||
        Map.get(room, "room_id") ||
        Map.get(room, :id) ||
        Map.get(room, "id")

    if is_binary(room_id) and String.trim(room_id) != "" do
      %{
        room_id: room_id,
        room_name:
          normalize_string(
            Map.get(room, :room_name) ||
              Map.get(room, "room_name") ||
              Map.get(room, :name) ||
              Map.get(room, "name"),
            room_id
          ),
        bindings:
          room
          |> Map.get(:bindings, Map.get(room, "bindings", []))
          |> normalize_bindings()
      }
    else
      nil
    end
  end

  defp normalize_room(_room), do: nil

  defp normalize_bindings(bindings) when is_list(bindings) do
    bindings
    |> Enum.map(&normalize_binding/1)
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_bindings(_bindings), do: []

  defp normalize_binding(binding) when is_map(binding) do
    %{
      channel:
        normalize_string(
          channel_to_string(Map.get(binding, :channel) || Map.get(binding, "channel")),
          "unknown"
        ),
      external_room_id:
        normalize_string(
          Map.get(binding, :external_room_id) || Map.get(binding, "external_room_id"),
          nil
        ),
      instance_id: normalize_string(Map.get(binding, :instance_id) || Map.get(binding, "instance_id"), nil)
    }
  end

  defp normalize_binding(_binding), do: nil

  defp normalize_action_timeline(entries, limit) when is_list(entries) and is_integer(limit) do
    entries
    |> Enum.map(&normalize_action_entry/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(&action_sort_key/1, :desc)
    |> Enum.take(limit)
  end

  defp normalize_action_timeline(_entries, _limit), do: []

  defp normalize_action_entry(entry) when is_map(entry) do
    %{
      id: normalize_string(entry_value(entry, :id), nil),
      timestamp: normalize_datetime(entry_value(entry, :timestamp)),
      type: normalize_entry_type(entry_value(entry, :type)),
      label: normalize_string(entry_value(entry, :label), "ChatOps event"),
      outcome: normalize_outcome(entry_value(entry, :outcome)),
      authz_status: normalize_authz_status(entry_value(entry, :authz_status)),
      mutation_enabled: normalize_optional_boolean(entry_value(entry, :mutation_enabled)),
      actor: normalize_action_actor(entry_value(entry, :actor)),
      details: normalize_string(entry_value(entry, :details) || entry_value(entry, :message), nil)
    }
  end

  defp normalize_action_entry(_entry), do: nil

  defp normalize_guardrails(guardrails) when is_map(guardrails) do
    counts =
      guardrails
      |> Map.get(:authz_counts, Map.get(guardrails, "authz_counts", %{}))
      |> normalize_guardrail_counts()

    %{
      mutation_enabled: normalize_optional_boolean(Map.get(guardrails, :mutation_enabled, Map.get(guardrails, "mutation_enabled"))) == true,
      latest_authz_status: normalize_authz_status(Map.get(guardrails, :latest_authz_status, Map.get(guardrails, "latest_authz_status"))),
      authz_counts: counts,
      blocked_actions:
        normalize_integer(
          Map.get(guardrails, :blocked_actions, Map.get(guardrails, "blocked_actions")),
          0
        )
    }
  end

  defp invoke_provider(provider, [{fun, opts} | rest], invalid_reason) do
    cond do
      function_exported?(provider, fun, 1) -> apply(provider, fun, [opts])
      function_exported?(provider, fun, 0) -> apply(provider, fun, [])
      true -> invoke_provider(provider, rest, invalid_reason)
    end
  end

  defp invoke_provider(_provider, [], invalid_reason), do: {:error, invalid_reason}

  defp entry_value(entry, key), do: Map.get(entry, key) || Map.get(entry, Atom.to_string(key))

  defp normalize_guardrail_counts(counts) when is_map(counts) do
    %{
      authorized: normalize_integer(Map.get(counts, :authorized, Map.get(counts, "authorized")), 0),
      unauthorized: normalize_integer(Map.get(counts, :unauthorized, Map.get(counts, "unauthorized")), 0),
      mutations_disabled:
        normalize_integer(
          Map.get(counts, :mutations_disabled, Map.get(counts, "mutations_disabled")),
          0
        ),
      unknown: normalize_integer(Map.get(counts, :unknown, Map.get(counts, "unknown")), 0)
    }
  end

  defp normalize_guardrail_counts(_counts),
    do: %{authorized: 0, unauthorized: 0, mutations_disabled: 0, unknown: 0}

  defp default_guardrail_state do
    %{
      mutation_enabled: false,
      latest_authz_status: nil,
      authz_counts: %{authorized: 0, unauthorized: 0, mutations_disabled: 0, unknown: 0},
      blocked_actions: 0
    }
  end

  defp action_sort_key(%{timestamp: %DateTime{} = timestamp}) do
    DateTime.to_unix(timestamp, :microsecond)
  end

  defp action_sort_key(_entry), do: -1

  defp normalize_entry_type(:run), do: :run
  defp normalize_entry_type("run"), do: :run
  defp normalize_entry_type(_type), do: :action

  defp normalize_outcome(:accepted), do: :accepted
  defp normalize_outcome(:succeeded), do: :succeeded
  defp normalize_outcome(:blocked), do: :blocked
  defp normalize_outcome(:failed), do: :failed
  defp normalize_outcome("accepted"), do: :accepted
  defp normalize_outcome("succeeded"), do: :succeeded
  defp normalize_outcome("blocked"), do: :blocked
  defp normalize_outcome("failed"), do: :failed
  defp normalize_outcome(_outcome), do: :unknown

  defp normalize_authz_status(:authorized), do: :authorized
  defp normalize_authz_status(:unauthorized), do: :unauthorized
  defp normalize_authz_status(:mutations_disabled), do: :mutations_disabled
  defp normalize_authz_status("authorized"), do: :authorized
  defp normalize_authz_status("unauthorized"), do: :unauthorized
  defp normalize_authz_status("mutations_disabled"), do: :mutations_disabled
  defp normalize_authz_status(nil), do: nil
  defp normalize_authz_status(_status), do: :unknown

  defp normalize_optional_boolean(true), do: true
  defp normalize_optional_boolean(false), do: false
  defp normalize_optional_boolean(_value), do: nil

  defp normalize_action_actor(actor) when is_map(actor) do
    channel =
      actor
      |> Map.get(:channel, Map.get(actor, "channel"))
      |> channel_to_string()
      |> normalize_string(nil)

    external_user_id =
      normalize_string(
        Map.get(actor, :external_user_id) || Map.get(actor, "external_user_id"),
        ""
      )

    %{
      channel: channel,
      external_user_id: external_user_id
    }
  end

  defp normalize_action_actor(_actor), do: nil

  defp channel_to_string(channel) when is_atom(channel), do: Atom.to_string(channel)
  defp channel_to_string(channel) when is_binary(channel), do: channel
  defp channel_to_string(channel), do: to_string(channel)

  defp normalize_string(nil, default), do: default

  defp normalize_string(value, default) when is_binary(value) do
    case String.trim(value) do
      "" -> default
      normalized -> normalized
    end
  end

  defp normalize_string(value, default), do: value |> to_string() |> normalize_string(default)

  defp normalize_integer(value, _default) when is_integer(value), do: value

  defp normalize_integer(value, default) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {parsed, ""} -> parsed
      _other -> default
    end
  end

  defp normalize_integer(_value, default), do: default

  defp normalize_datetime(%DateTime{} = value), do: value

  defp normalize_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, parsed, _offset} -> parsed
      _other -> nil
    end
  end

  defp normalize_datetime(_value), do: nil

  defp binding_channel_label("telegram"), do: "Telegram"
  defp binding_channel_label("discord"), do: "Discord"

  defp binding_channel_label(channel) when is_binary(channel) do
    channel
    |> String.replace("_", " ")
    |> Phoenix.Naming.humanize()
  end

  defp binding_channel_label(_channel), do: "Unknown"

  defp message_room_id(message) when is_map(message) do
    normalize_string(
      Map.get(message, :room_id) ||
        Map.get(message, "room_id"),
      "unknown"
    )
  end

  defp message_room_id(_message), do: "unknown"

  defp message_actor(message) when is_map(message) do
    normalize_string(
      Map.get(message, :actor) ||
        Map.get(message, "actor") ||
        Map.get(message, :username) ||
        Map.get(message, "username"),
      "unknown"
    )
  end

  defp message_actor(_message), do: "unknown"

  defp message_channel_label(message) when is_map(message) do
    message
    |> Map.get(:channel, Map.get(message, "channel"))
    |> channel_to_string()
    |> binding_channel_label()
  end

  defp message_channel_label(_message), do: "Unknown"

  defp message_snippet(message) when is_map(message) do
    normalize_string(
      Map.get(message, :snippet) ||
        Map.get(message, "snippet") ||
        Map.get(message, :text) ||
        Map.get(message, "text"),
      "—"
    )
  end

  defp message_snippet(_message), do: "—"

  defp format_action_timestamp(entry) when is_map(entry) do
    entry
    |> Map.get(:timestamp, Map.get(entry, "timestamp"))
    |> format_timestamp_value()
  end

  defp format_action_timestamp(_entry), do: "unknown time"

  defp action_timeline_row_class(entry) do
    "space-y-2 rounded-md border p-4 " <> action_row_color(entry)
  end

  defp action_row_color(%{outcome: :succeeded}), do: "border-accent-green/40 bg-accent-green/20"
  defp action_row_color(%{outcome: :blocked}), do: "border-accent-red/50 bg-accent-red/20"
  defp action_row_color(%{outcome: :accepted}), do: "border-accent-yellow/40 bg-accent-yellow/20"
  defp action_row_color(%{outcome: :failed}), do: "border-accent-red/40 bg-accent-red/15"
  defp action_row_color(_entry), do: "border-border bg-elevated/50"

  defp entry_type_badge_class(entry) do
    "rounded-full border px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wider " <>
      entry_type_color(entry)
  end

  defp entry_type_color(%{type: :run}),
    do: "border-accent-green/60 bg-accent-green/40 text-accent-green"

  defp entry_type_color(_entry), do: "border-border bg-card text-foreground"

  defp entry_outcome_badge_class(entry) do
    "rounded-full border px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wider " <>
      outcome_color(entry)
  end

  defp outcome_color(%{outcome: :succeeded}),
    do: "border-accent-green/60 bg-accent-green/40 text-accent-green"

  defp outcome_color(%{outcome: :blocked}), do: "border-accent-red/70 bg-accent-red/40 text-accent-red"

  defp outcome_color(%{outcome: :accepted}),
    do: "border-accent-yellow/60 bg-accent-yellow/40 text-accent-yellow"

  defp outcome_color(%{outcome: :failed}), do: "border-accent-red/60 bg-accent-red/40 text-accent-red"
  defp outcome_color(_entry), do: "border-border bg-card text-foreground"

  defp action_entry_type_label(%{type: :run}), do: "Run"
  defp action_entry_type_label(_entry), do: "Action"

  defp action_entry_outcome_label(%{outcome: :succeeded}), do: "Succeeded"
  defp action_entry_outcome_label(%{outcome: :blocked}), do: "Blocked"
  defp action_entry_outcome_label(%{outcome: :accepted}), do: "Accepted"
  defp action_entry_outcome_label(%{outcome: :failed}), do: "Failed"
  defp action_entry_outcome_label(_entry), do: "Unknown"

  defp action_entry_label(entry) when is_map(entry) do
    normalize_string(
      Map.get(entry, :label) || Map.get(entry, "label"),
      "ChatOps event"
    )
  end

  defp action_entry_label(_entry), do: "ChatOps event"

  defp action_entry_actor(entry) when is_map(entry) do
    actor = Map.get(entry, :actor) || Map.get(entry, "actor")

    if is_map(actor) do
      channel =
        actor
        |> Map.get(:channel, Map.get(actor, "channel"))
        |> normalize_string("unknown")

      external_user_id =
        normalize_string(
          Map.get(actor, :external_user_id) || Map.get(actor, "external_user_id"),
          ""
        )

      if external_user_id == "" do
        channel
      else
        channel <> ":" <> external_user_id
      end
    else
      "system"
    end
  end

  defp action_entry_actor(_entry), do: "system"

  defp action_entry_authz_label(%{authz_status: :authorized}), do: "Authorized"
  defp action_entry_authz_label(%{authz_status: :unauthorized}), do: "Unauthorized"
  defp action_entry_authz_label(%{authz_status: :mutations_disabled}), do: "Mutations Disabled"
  defp action_entry_authz_label(%{authz_status: :unknown}), do: "Unknown"
  defp action_entry_authz_label(_entry), do: "N/A"

  defp action_entry_authz_class(%{authz_status: :authorized}),
    do: "font-semibold text-accent-green"

  defp action_entry_authz_class(%{authz_status: :unauthorized}), do: "font-semibold text-accent-red"

  defp action_entry_authz_class(%{authz_status: :mutations_disabled}),
    do: "font-semibold text-accent-yellow"

  defp action_entry_authz_class(%{authz_status: :unknown}),
    do: "font-semibold text-muted-foreground"

  defp action_entry_authz_class(_entry), do: "font-semibold text-muted-foreground"

  defp action_entry_mutation_label(entry) when is_map(entry) do
    case Map.get(entry, :mutation_enabled, Map.get(entry, "mutation_enabled")) do
      true -> "Enabled"
      false -> "Disabled"
      _other -> "Unknown"
    end
  end

  defp action_entry_mutation_label(_entry), do: "Unknown"

  defp action_entry_mutation_class(entry) when is_map(entry) do
    case Map.get(entry, :mutation_enabled, Map.get(entry, "mutation_enabled")) do
      true -> "font-semibold text-accent-green"
      false -> "font-semibold text-accent-red"
      _other -> "font-semibold text-muted-foreground"
    end
  end

  defp action_entry_mutation_class(_entry), do: "font-semibold text-muted-foreground"

  defp action_entry_details(entry) when is_map(entry) do
    normalize_string(
      Map.get(entry, :details) || Map.get(entry, "details"),
      nil
    )
  end

  defp action_entry_details(_entry), do: nil

  defp guardrail_mutation_label(guardrails) when is_map(guardrails) do
    if Map.get(guardrails, :mutation_enabled, false), do: "Enabled", else: "Disabled"
  end

  defp guardrail_mutation_label(_guardrails), do: "Disabled"

  defp guardrail_mutation_class(guardrails) when is_map(guardrails) do
    if Map.get(guardrails, :mutation_enabled, false),
      do: "text-sm font-semibold text-accent-green",
      else: "text-sm font-semibold text-accent-red"
  end

  defp guardrail_mutation_class(_guardrails), do: "text-sm font-semibold text-accent-red"

  defp guardrail_authz_label(guardrails) when is_map(guardrails) do
    case Map.get(guardrails, :latest_authz_status) do
      :authorized -> "Authorized"
      :unauthorized -> "Unauthorized"
      :mutations_disabled -> "Mutations Disabled"
      :unknown -> "Unknown"
      _other -> "No data"
    end
  end

  defp guardrail_authz_label(_guardrails), do: "No data"

  defp guardrail_authz_class(guardrails) when is_map(guardrails) do
    case Map.get(guardrails, :latest_authz_status) do
      :authorized -> "text-sm font-semibold text-accent-green"
      :unauthorized -> "text-sm font-semibold text-accent-red"
      :mutations_disabled -> "text-sm font-semibold text-accent-yellow"
      :unknown -> "text-sm font-semibold text-muted-foreground"
      _other -> "text-sm font-semibold text-muted-foreground"
    end
  end

  defp guardrail_authz_class(_guardrails), do: "text-sm font-semibold text-muted-foreground"

  defp guardrail_count(guardrails, key) when is_map(guardrails) and is_atom(key) do
    guardrails
    |> Map.get(:authz_counts, %{})
    |> Map.get(key, 0)
  end

  defp guardrail_count(_guardrails, _key), do: 0

  defp guardrail_blocked_actions(guardrails) when is_map(guardrails) do
    Map.get(guardrails, :blocked_actions, 0)
  end

  defp guardrail_blocked_actions(_guardrails), do: 0

  defp format_message_timestamp(message) when is_map(message) do
    message
    |> Map.get(:timestamp, Map.get(message, "timestamp"))
    |> format_timestamp_value()
  end

  defp format_message_timestamp(_message), do: "unknown time"

  defp format_timestamp_value(%DateTime{} = timestamp) do
    Calendar.strftime(timestamp, "%Y-%m-%d %H:%M:%S UTC")
  end

  defp format_timestamp_value(timestamp) when is_binary(timestamp) do
    case DateTime.from_iso8601(timestamp) do
      {:ok, value, _offset} -> format_timestamp_value(value)
      _other -> normalize_string(timestamp, "unknown time")
    end
  end

  defp format_timestamp_value(_timestamp), do: "unknown time"

  defp format_refreshed_at(%DateTime{} = refreshed_at) do
    Calendar.strftime(refreshed_at, "%Y-%m-%d %H:%M:%S UTC")
  end

  defp format_refreshed_at(_), do: "unknown"

  defp resolve_inventory_provider(session) when is_map(session) do
    case Map.get(session, "chatops_inventory_provider") ||
           Map.get(session, :chatops_inventory_provider) do
      module when is_atom(module) -> module
      _other -> RoomInventory
    end
  end

  defp resolve_inventory_provider(_session), do: RoomInventory

  defp resolve_message_provider(session) when is_map(session) do
    case Map.get(session, "chatops_message_provider") ||
           Map.get(session, :chatops_message_provider) do
      module when is_atom(module) -> module
      _other -> MessageTimeline
    end
  end

  defp resolve_message_provider(_session), do: MessageTimeline

  defp resolve_action_timeline_provider(session) when is_map(session) do
    case Map.get(session, "chatops_action_timeline_provider") ||
           Map.get(session, :chatops_action_timeline_provider) do
      module when is_atom(module) -> module
      _other -> ActionTimeline
    end
  end

  defp resolve_action_timeline_provider(_session), do: ActionTimeline

  defp resolve_guardrail_provider(session) when is_map(session) do
    case Map.get(session, "chatops_guardrail_provider") ||
           Map.get(session, :chatops_guardrail_provider) do
      module when is_atom(module) -> module
      _other -> Guardrails
    end
  end

  defp resolve_guardrail_provider(_session), do: Guardrails

  defp resolve_message_timeline_limit(session) when is_map(session) do
    case Map.get(session, "chatops_message_limit") || Map.get(session, :chatops_message_limit) do
      limit when is_integer(limit) and limit > 0 -> limit
      _other -> @default_message_timeline_limit
    end
  end

  defp resolve_message_timeline_limit(_session), do: @default_message_timeline_limit

  defp resolve_action_timeline_limit(session) when is_map(session) do
    case Map.get(session, "chatops_action_timeline_limit") ||
           Map.get(session, :chatops_action_timeline_limit) do
      limit when is_integer(limit) and limit > 0 -> limit
      _other -> @default_action_timeline_limit
    end
  end

  defp resolve_action_timeline_limit(_session), do: @default_action_timeline_limit

  defp format_error({:inventory_exception, message}), do: message
  defp format_error({:messaging_exception, message}), do: message
  defp format_error({:action_timeline_exception, message}), do: message
  defp format_error({:guardrail_exception, message}), do: message
  defp format_error({:inventory_exit, reason}), do: inspect(reason)
  defp format_error({:messaging_exit, reason}), do: inspect(reason)
  defp format_error({:action_timeline_exit, reason}), do: inspect(reason)
  defp format_error({:guardrail_exit, reason}), do: inspect(reason)
  defp format_error(reason), do: inspect(reason)
end
