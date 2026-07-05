defmodule AgentJido.ContentOps.Chat.DiscordHandler do
  @moduledoc """
  Discord ingress handler for ContentOps chat.
  """

  alias AgentJido.ContentOps.Chat.DiscordChannel
  alias AgentJido.ContentOps.Chat.Router
  alias Jido.Messaging.{Deliver, Ingest}

  use Nostrum.Consumer

  require Logger

  @messaging_module AgentJido.ContentOps.Messaging
  @instance_id to_string(__MODULE__)

  @impl Nostrum.Consumer
  def handle_event({:READY, _data, _ws_state}) do
    Logger.info("[ContentOps.Discord] Bot connected and ready")
    :ok
  end

  @impl Nostrum.Consumer
  def handle_event({:MESSAGE_CREATE, msg, _ws_state}) do
    unless msg.author.bot do
      process_update(msg)
    end

    :ok
  end

  @impl Nostrum.Consumer
  def handle_event(_event), do: :ok

  @doc false
  def process_update(msg) do
    case DiscordChannel.transform_incoming(msg) do
      {:ok, incoming} ->
        case Ingest.ingest_incoming(@messaging_module, DiscordChannel, @instance_id, incoming) do
          {:ok, message, context} -> handle_message_callback(message, context)
          {:ok, :duplicate} -> :ok
          {:error, reason} -> Logger.warning("[ContentOps.Discord] Ingest failed: #{inspect(reason)}")
        end

      {:error, reason} ->
        Logger.debug("[ContentOps.Discord] Skipping message: #{inspect(reason)}")
    end

    :ok
  end

  @doc false
  def send_message(channel_id, text), do: DiscordChannel.send_message(channel_id, text, [])

  @doc false
  def send_message(channel_id, text, opts), do: DiscordChannel.send_message(channel_id, text, opts)

  @doc false
  def edit_message(channel_id, message_id, text, opts \\ []), do: DiscordChannel.edit_message(channel_id, message_id, text, opts)

  @doc false
  def channel_type, do: DiscordChannel.channel_type()

  defp handle_message_callback(message, context) do
    case Router.handle_message(message, context) do
      {:reply, text} when is_binary(text) ->
        Deliver.deliver_outgoing(@messaging_module, message, text, context)

      :noreply ->
        :ok
    end
  end
end
