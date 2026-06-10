defmodule AgentJido.ContentOps.Chat.Bridge do
  @moduledoc """
  Signal-driven bridge that forwards room messages between bound channels.
  """

  use GenServer

  require Logger

  alias AgentJido.ContentOps.Chat.{DiscordHandler, TelegramHandler}
  alias Jido.Messaging.Supervisor, as: MessagingSupervisor
  alias Jido.Signal.Bus

  @type state :: %{
          instance_module: module(),
          telegram_sender: module(),
          discord_sender: module(),
          subscribed: boolean()
        }

  @doc "Starts the bridge process."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(opts) do
    state = %{
      instance_module: Keyword.fetch!(opts, :instance_module),
      telegram_sender: Keyword.get(opts, :telegram_sender, TelegramHandler),
      discord_sender: Keyword.get(opts, :discord_sender, DiscordHandler),
      subscribed: false
    }

    send(self(), :subscribe)

    {:ok, state}
  end

  @impl true
  def handle_info(:subscribe, state) do
    bus_name = MessagingSupervisor.signal_bus_name(state.instance_module)

    case Bus.subscribe(bus_name, "jido.messaging.room.message_added") do
      {:ok, _id} ->
        {:noreply, %{state | subscribed: true}}

      {:error, reason} ->
        Logger.warning("[ContentOps.Chat.Bridge] subscribe failed: #{inspect(reason)}")
        Process.send_after(self(), :subscribe, 250)
        {:noreply, state}
    end
  end

  def handle_info({:signal, %{type: "jido.messaging.room.message_added", data: data}}, state) do
    _ = forward_message(data, state)
    {:noreply, state}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  defp forward_message(%{room_id: room_id, message: message}, state) do
    with {:ok, bindings} <- state.instance_module.list_room_bindings(room_id) do
      origin_channel = get_origin_channel(message)
      text = format_message(message)

      unless text == "" do
        Enum.each(bindings, &maybe_forward_binding(&1, origin_channel, text, state))
      end
    end

    :ok
  end

  defp forward_message(_data, _state), do: :ok

  defp should_forward?(binding, origin_channel) do
    binding.enabled != false and normalize_channel(binding.channel) != origin_channel
  end

  defp maybe_forward_binding(binding, origin_channel, text, state) do
    if should_forward?(binding, origin_channel) do
      send_to_binding(binding, text, state)
    end
  end

  defp send_to_binding(%{channel: :telegram, external_room_id: external_id}, text, state) do
    _ = safe_send(state.telegram_sender, external_id, text)
  end

  defp send_to_binding(%{channel: :discord, external_room_id: external_id}, text, state) do
    _ = safe_send(state.discord_sender, external_id, text)
  end

  defp send_to_binding(_binding, _text, _state), do: :ok

  defp safe_send(sender_module, external_id, text) do
    case sender_module.send_message(external_id, text) do
      {:ok, _} -> :ok
      {:error, reason} -> Logger.warning("[ContentOps.Chat.Bridge] send failed: #{inspect(reason)}")
    end
  rescue
    error ->
      Logger.warning("[ContentOps.Chat.Bridge] send crashed: #{inspect(error)}")
  end

  defp get_origin_channel(%{metadata: metadata}) when is_map(metadata) do
    metadata
    |> Map.get(:channel, Map.get(metadata, "channel"))
    |> normalize_channel()
  end

  defp get_origin_channel(_), do: nil

  defp normalize_channel(:telegram), do: :telegram
  defp normalize_channel(:discord), do: :discord
  defp normalize_channel("telegram"), do: :telegram
  defp normalize_channel("discord"), do: :discord
  defp normalize_channel(_), do: nil

  defp format_message(message) do
    text = extract_text(message)

    if text == "" do
      ""
    else
      source = source_tag(message)
      username = username(message)
      "[#{source} #{username}] #{text}"
    end
  end

  defp source_tag(%{metadata: metadata}) when is_map(metadata) do
    case normalize_channel(Map.get(metadata, :channel, Map.get(metadata, "channel"))) do
      :telegram -> "TG"
      :discord -> "DC"
      _ -> "AG"
    end
  end

  defp source_tag(_), do: "AG"

  defp username(%{metadata: metadata}) when is_map(metadata) do
    metadata[:username] || metadata["username"] || metadata[:display_name] || metadata["display_name"] || "unknown"
  end

  defp username(_), do: "unknown"

  defp extract_text(%{content: content}) when is_list(content) do
    content
    |> Enum.find_value("", fn
      %{text: text} when is_binary(text) -> text
      %{"text" => text} when is_binary(text) -> text
      %Jido.Chat.Content.Text{text: text} -> text
      _ -> nil
    end)
  end

  defp extract_text(_), do: ""
end
