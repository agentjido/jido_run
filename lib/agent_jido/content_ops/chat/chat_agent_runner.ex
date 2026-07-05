defmodule AgentJido.ContentOps.Chat.ChatAgentRunner do
  @moduledoc """
  Manages the ChatAgent lifecycle and provides a handler for AgentRunner.
  """

  use GenServer

  require Logger

  alias AgentJido.ContentOps.Chat.ChatAgent

  defstruct [:agent_pid]

  @agent_name "AgentJido"

  @doc "Returns an agent_config map for use with `Jido.Messaging.AgentRunner`."
  @spec agent_config(keyword()) :: Jido.Messaging.AgentRunner.agent_config()
  def agent_config(opts \\ []) do
    %{
      agent_id: Keyword.get(opts, :agent_id, "chat_agent"),
      name: Keyword.get(opts, :name, @agent_name),
      trigger: :mention,
      handler: &handle_message/2
    }
  end

  @doc "Starts the ChatAgentRunner."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Returns the ChatAgent pid."
  @spec get_agent_pid() :: pid()
  def get_agent_pid do
    GenServer.call(__MODULE__, :get_agent_pid)
  end

  # Handler called by AgentRunner on triggered messages
  defp handle_message(message, _context) do
    text = extract_text(message)
    source = message.metadata[:channel] || message.metadata["channel"] || "unknown"
    user = message.metadata[:username] || message.metadata["username"] || "unknown"

    prompt = "[#{source} #{user}] #{text}"

    case get_agent_pid_safe() do
      {:ok, agent_pid} ->
        case ChatAgent.chat(agent_pid, prompt, timeout: 30_000) do
          {:ok, response} ->
            Logger.info("[ChatAgentRunner] Response: #{String.slice(response, 0, 100)}")
            {:reply, response}

          {:error, reason} ->
            Logger.warning("[ChatAgentRunner] Chat failed: #{inspect(reason)}")
            {:reply, "Sorry, I encountered an error. Please try again."}
        end

      {:error, :not_running} ->
        {:reply, "I'm still waking up... try again in a moment!"}
    end
  end

  defp get_agent_pid_safe do
    {:ok, get_agent_pid()}
  catch
    :exit, _ -> {:error, :not_running}
  end

  defp extract_text(%{content: content}) when is_list(content) do
    Enum.find_value(content, "", fn
      %{text: text} when is_binary(text) -> text
      %Jido.Chat.Content.Text{text: text} -> text
      _ -> nil
    end)
  end

  defp extract_text(_), do: ""

  # GenServer callbacks

  @impl true
  def init(opts) do
    jido_name = Keyword.get(opts, :jido_name, AgentJido.Jido)

    case Jido.start_agent(jido_name, ChatAgent) do
      {:ok, agent_pid} ->
        Logger.info("[ChatAgentRunner] Started ChatAgent: #{inspect(agent_pid)}")
        {:ok, %__MODULE__{agent_pid: agent_pid}}

      {:error, reason} ->
        Logger.error("[ChatAgentRunner] Failed to start ChatAgent: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def handle_call(:get_agent_pid, _from, state) do
    {:reply, state.agent_pid, state}
  end

  @impl true
  def terminate(_reason, state) do
    if state.agent_pid && Process.alive?(state.agent_pid) do
      GenServer.stop(state.agent_pid, :normal)
    end

    :ok
  end
end
