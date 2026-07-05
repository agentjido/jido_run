defmodule AgentJido.ContentOps.Chat.TelegramHandler do
  @moduledoc """
  Telegram ingress handler for ContentOps chat.
  """

  alias AgentJido.ContentOps.Chat.Router
  alias AgentJido.ContentOps.Chat.TelegramChannel
  alias Jido.Messaging.{Deliver, Ingest}

  use Telegex.Polling.GenHandler

  require Logger

  @messaging_module AgentJido.ContentOps.Messaging
  @instance_id to_string(__MODULE__)

  @impl true
  def on_boot do
    case Telegex.get_me() do
      {:ok, bot_user} ->
        Logger.info("[ContentOps.Telegram] Bot @#{bot_user.username} connected")
        Telegex.delete_webhook()

      {:error, reason} ->
        Logger.error("[ContentOps.Telegram] Failed to connect: #{inspect(reason)}")
    end

    %Telegex.Polling.Config{}
  end

  @impl true
  def on_update(update) do
    process_update(update)
    polling_result()
  end

  @doc false
  def process_update(update) do
    case TelegramChannel.transform_incoming(update) do
      {:ok, incoming} ->
        case Ingest.ingest_incoming(@messaging_module, TelegramChannel, @instance_id, incoming) do
          {:ok, message, context} -> handle_message_callback(message, context)
          {:ok, :duplicate} -> :ok
          {:error, reason} -> Logger.warning("[ContentOps.Telegram] Ingest failed: #{inspect(reason)}")
        end

      {:error, :no_message} ->
        :ok

      {:error, reason} ->
        Logger.debug("[ContentOps.Telegram] Skipping update: #{inspect(reason)}")
    end

    :ok
  end

  @doc false
  def send_message(chat_id, text), do: TelegramChannel.send_message(chat_id, text, [])

  @doc false
  def send_message(chat_id, text, opts), do: TelegramChannel.send_message(chat_id, text, opts)

  @doc false
  def edit_message(chat_id, message_id, text, opts \\ []), do: TelegramChannel.edit_message(chat_id, message_id, text, opts)

  @doc false
  def channel_type, do: TelegramChannel.channel_type()

  defp handle_message_callback(message, context) do
    case Router.handle_message(message, context) do
      {:reply, text} when is_binary(text) ->
        Deliver.deliver_outgoing(@messaging_module, message, text, context)

      :noreply ->
        :ok
    end
  end

  defp polling_result do
    case :persistent_term.get({__MODULE__, :polling_result}, :ok) do
      {:done, %{payload: _payload}} = result -> result
      _other -> :ok
    end
  end
end
