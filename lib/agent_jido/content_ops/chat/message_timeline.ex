defmodule AgentJido.ContentOps.Chat.MessageTimeline do
  @moduledoc """
  Loads recent chat messages for the ChatOps console timeline.
  """

  alias AgentJido.ContentOps.Messaging

  @default_limit 50
  @default_rooms_limit 250
  @default_room_message_limit 50
  @max_snippet_length 160

  @type entry :: %{
          id: String.t() | nil,
          timestamp: DateTime.t() | nil,
          room_id: String.t(),
          actor: String.t(),
          channel: String.t(),
          snippet: String.t()
        }

  @doc """
  Returns recent message timeline entries from the ContentOps messaging instance.
  """
  @spec fetch() :: {:ok, [entry()]} | {:error, term()}
  def fetch do
    fetch([])
  end

  @doc """
  Returns recent message timeline entries using the given options.

  ## Options
  - `:messaging` - Messaging module (defaults to `AgentJido.ContentOps.Messaging`)
  - `:limit` - Max number of timeline rows returned (defaults to 50)
  - `:rooms_limit` - Max number of rooms to scan (defaults to 250)
  - `:room_message_limit` - Max messages fetched per room (defaults to 50)
  """
  @spec fetch(keyword()) :: {:ok, [entry()]} | {:error, term()}
  def fetch(opts) when is_list(opts) do
    messaging = Keyword.get(opts, :messaging, Messaging)
    limit = normalize_limit(Keyword.get(opts, :limit, @default_limit), @default_limit)
    rooms_limit = normalize_limit(Keyword.get(opts, :rooms_limit, @default_rooms_limit), @default_rooms_limit)

    room_message_limit =
      normalize_limit(Keyword.get(opts, :room_message_limit, @default_room_message_limit), @default_room_message_limit)

    if runtime_available?(messaging) do
      case safe_messaging_call(fn -> messaging.list_rooms(limit: rooms_limit) end) do
        {:ok, rooms} ->
          entries =
            rooms
            |> Enum.flat_map(&load_room_messages(&1, messaging, room_message_limit))
            |> Enum.map(&normalize_message/1)
            |> Enum.reject(&is_nil/1)
            |> Enum.sort_by(&message_sort_key/1, :desc)
            |> Enum.take(limit)

          {:ok, entries}

        {:error, :messaging_unavailable} ->
          {:ok, []}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:ok, []}
    end
  end

  @doc """
  Returns recent message timeline entries.
  """
  @spec fetch_recent_messages() :: {:ok, [entry()]} | {:error, term()}
  def fetch_recent_messages do
    fetch()
  end

  @doc """
  Returns recent message timeline entries with options.
  """
  @spec fetch_recent_messages(keyword()) :: {:ok, [entry()]} | {:error, term()}
  def fetch_recent_messages(opts) when is_list(opts) do
    fetch(opts)
  end

  defp load_room_messages(%{id: room_id}, messaging, limit) when is_binary(room_id) do
    case safe_messaging_call(fn -> messaging.list_messages(room_id, limit: limit) end) do
      {:ok, messages} when is_list(messages) -> messages
      _other -> []
    end
  end

  defp load_room_messages(_room, _messaging, _limit), do: []

  defp normalize_message(message) when is_map(message) do
    room_id =
      Map.get(message, :room_id) ||
        Map.get(message, "room_id")

    if is_binary(room_id) and String.trim(room_id) != "" do
      metadata =
        message
        |> Map.get(:metadata, Map.get(message, "metadata", %{}))
        |> normalize_map()

      sender_id = Map.get(message, :sender_id) || Map.get(message, "sender_id")

      %{
        id: normalize_string(Map.get(message, :id) || Map.get(message, "id"), nil),
        timestamp:
          normalize_datetime(
            Map.get(message, :inserted_at) ||
              Map.get(message, "inserted_at") ||
              Map.get(message, :updated_at) ||
              Map.get(message, "updated_at")
          ),
        room_id: room_id,
        actor: normalize_actor(metadata, sender_id),
        channel: normalize_channel(metadata),
        snippet:
          message
          |> Map.get(:content, Map.get(message, "content", []))
          |> extract_snippet()
      }
    else
      nil
    end
  end

  defp normalize_message(_message), do: nil

  defp normalize_actor(metadata, sender_id) do
    normalize_string(
      metadata_value(metadata, :username) ||
        metadata_value(metadata, :actor) ||
        metadata_value(metadata, :display_name) ||
        metadata_value(metadata, :sender) ||
        sender_id,
      "unknown"
    )
  end

  defp normalize_channel(metadata) do
    metadata
    |> metadata_value(:channel, :source, :origin)
    |> channel_to_string()
    |> normalize_string("unknown")
  end

  defp extract_snippet(content) when is_list(content) do
    snippet =
      content
      |> Enum.map(&content_text/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.join(" ")
      |> normalize_string(nil)

    case snippet do
      nil -> "—"
      value -> truncate(value, @max_snippet_length)
    end
  end

  defp extract_snippet(_content), do: "—"

  defp content_text(%{text: text}) when is_binary(text), do: text
  defp content_text(%{"text" => text}) when is_binary(text), do: text
  defp content_text(text) when is_binary(text), do: text
  defp content_text(_content), do: nil

  defp truncate(value, max_length) when is_binary(value) and byte_size(value) > max_length do
    value
    |> binary_part(0, max_length)
    |> String.trim_trailing()
    |> Kernel.<>("...")
  end

  defp truncate(value, _max_length), do: value

  defp message_sort_key(%{timestamp: %DateTime{} = timestamp}) do
    DateTime.to_unix(timestamp, :microsecond)
  end

  defp message_sort_key(_message), do: -1

  defp normalize_limit(value, _default) when is_integer(value) and value > 0, do: value
  defp normalize_limit(_value, default), do: default

  defp normalize_datetime(%DateTime{} = value), do: value

  defp normalize_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, parsed, _offset} -> parsed
      _other -> nil
    end
  end

  defp normalize_datetime(_value), do: nil

  defp normalize_map(value) when is_map(value), do: value
  defp normalize_map(_value), do: %{}

  defp metadata_value(metadata, key) when is_atom(key) do
    Map.get(metadata, key) || Map.get(metadata, Atom.to_string(key))
  end

  defp metadata_value(metadata, first_key, second_key, third_key) do
    metadata_value(metadata, first_key) ||
      metadata_value(metadata, second_key) ||
      metadata_value(metadata, third_key)
  end

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

  defp runtime_available?(messaging) do
    function_exported?(messaging, :__jido_messaging__, 1) and
      messaging
      |> runtime_name()
      |> runtime_running?()
  rescue
    _ -> false
  end

  defp runtime_name(messaging), do: messaging.__jido_messaging__(:runtime)
  defp runtime_running?(runtime) when is_atom(runtime), do: not is_nil(Process.whereis(runtime))
  defp runtime_running?(_runtime), do: false

  defp safe_messaging_call(fun) when is_function(fun, 0) do
    fun.()
  rescue
    error ->
      {:error, {:messaging_exception, Exception.message(error)}}
  catch
    :exit, {:noproc, _details} ->
      {:error, :messaging_unavailable}

    :exit, {:normal, _details} ->
      {:error, :messaging_unavailable}

    :exit, reason ->
      {:error, {:messaging_exit, reason}}
  end
end
