defmodule AgentJido.ContentOps.Chat.DiscordChannel do
  @moduledoc """
  Discord adapter used by the ContentOps chat integration.
  """

  use Jido.Chat.Adapter

  require Logger

  @impl true
  def channel_type, do: :discord

  @impl true
  def capabilities do
    %{
      send_message: :native,
      edit_message: :native,
      verify_webhook: :fallback,
      parse_event: :fallback,
      format_webhook_response: :fallback
    }
  end

  @impl true
  def transform_incoming(%Nostrum.Struct.Message{} = msg) do
    {:ok,
     %{
       external_room_id: msg.channel_id,
       external_user_id: get_user_id(msg),
       text: msg.content,
       media: [],
       username: get_username(msg),
       display_name: get_display_name(msg),
       external_message_id: msg.id,
       timestamp: msg.timestamp,
       chat_type: parse_chat_type(msg),
       chat_title: nil,
       raw: Map.from_struct(msg)
     }}
  end

  def transform_incoming(%{channel_id: channel_id} = msg) when is_map(msg) do
    transform_message_map(msg, channel_id)
  end

  def transform_incoming(%{"channel_id" => channel_id} = msg) when is_map(msg) do
    transform_message_map(msg, channel_id)
  end

  def transform_incoming(_msg) do
    {:error, :unsupported_message_type}
  end

  @impl true
  def send_message(channel_id, text, opts \\ []) do
    channel_id = to_integer(channel_id)
    message_opts = Keyword.merge([content: text], Keyword.take(opts, [:tts, :embeds, :components]))

    case Nostrum.Api.Message.create(channel_id, message_opts) do
      {:ok, sent_message} ->
        {:ok,
         %{
           message_id: sent_message.id,
           channel_id: sent_message.channel_id,
           timestamp: sent_message.timestamp
         }}

      {:error, reason} ->
        Logger.warning("[ContentOps.Discord] send_message failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @impl true
  def edit_message(channel_id, message_id, text, opts \\ []) do
    edit_opts = Keyword.merge([content: text], Keyword.take(opts, [:embeds, :components]))

    case Nostrum.Api.Message.edit(to_integer(channel_id), message_id, edit_opts) do
      {:ok, edited_message} ->
        {:ok,
         %{
           message_id: edited_message.id,
           channel_id: edited_message.channel_id,
           timestamp: edited_message.edited_timestamp || edited_message.timestamp
         }}

      {:error, reason} ->
        Logger.warning("[ContentOps.Discord] edit_message failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp transform_message_map(msg, channel_id) do
    author = get_map_value(msg, [:author, "author"]) || %{}

    {:ok,
     %{
       external_room_id: channel_id,
       external_user_id: get_map_value(author, [:id, "id"]),
       text: get_map_value(msg, [:content, "content"]),
       media: [],
       username: get_map_value(author, [:username, "username"]),
       display_name: get_map_value(author, [:global_name, "global_name"]) || get_map_value(author, [:username, "username"]),
       external_message_id: get_map_value(msg, [:id, "id"]),
       timestamp: get_map_value(msg, [:timestamp, "timestamp"]),
       chat_type: parse_map_chat_type(msg),
       chat_title: nil,
       raw: msg
     }}
  end

  defp get_user_id(%{author: %{id: id}}), do: id
  defp get_user_id(_), do: nil

  defp get_username(%{author: %{username: username}}), do: username
  defp get_username(_), do: nil

  defp get_display_name(%{author: %{global_name: global_name}}) when not is_nil(global_name), do: global_name
  defp get_display_name(%{author: %{username: username}}), do: username
  defp get_display_name(_), do: nil

  defp get_map_value(map, keys) when is_map(map), do: Enum.find_value(keys, &Map.get(map, &1))
  defp get_map_value(_map, _keys), do: nil

  defp parse_chat_type(%{guild_id: nil}), do: :dm
  defp parse_chat_type(%{guild_id: _}), do: :guild
  defp parse_chat_type(_), do: :unknown

  defp parse_map_chat_type(msg) when is_map(msg) do
    if get_map_value(msg, [:guild_id, "guild_id"]), do: :guild, else: :dm
  end

  defp to_integer(value) when is_integer(value), do: value
  defp to_integer(value) when is_binary(value), do: String.to_integer(value)
  defp to_integer(value), do: value
end
