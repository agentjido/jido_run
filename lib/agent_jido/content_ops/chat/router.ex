defmodule AgentJido.ContentOps.Chat.Router do
  @moduledoc """
  Command and ReAct router for inbound Telegram/Discord messages.
  """

  require Logger

  alias AgentJido.ContentOps.Chat.{
    Actions,
    ActionStore,
    Authorizer,
    Config,
    OpsAgent,
    OpsService,
    SessionManager
  }

  @doc "Main callback used by channel handlers."
  @spec handle_message(Jido.Messaging.Message.t(), map()) :: {:reply, String.t()} | :noreply
  def handle_message(message, context) do
    text = extract_text(message) |> String.trim()

    if text == "" do
      :noreply
    else
      cfg = Config.load!()

      case routeable_command_text(text, cfg) do
        nil ->
          :noreply

        command_text ->
          handle_command_message(command_text, message, context, cfg)
      end
    end
  end

  @doc "Parses a command from message text."
  @spec parse_command(String.t(), String.t()) ::
          {:ok,
           :help
           | :status
           | :recent_runs
           | :coverage
           | {:run, atom()}
           | {:issue, String.t()}
           | {:note, String.t()}
           | {:ask, String.t()}}
          | {:error, :unknown}
  def parse_command(text, prefix) when is_binary(text) and is_binary(prefix) do
    if command_message?(text, prefix) do
      text
      |> command_args(prefix)
      |> parse_command_args()
    else
      {:error, :unknown}
    end
  end

  defp parse_mode("hourly"), do: {:ok, {:run, :hourly}}
  defp parse_mode("nightly"), do: {:ok, {:run, :nightly}}
  defp parse_mode("weekly"), do: {:ok, {:run, :weekly}}
  defp parse_mode("monthly"), do: {:ok, {:run, :monthly}}
  defp parse_mode(_other), do: {:error, :unknown}

  defp handle_command_message(text, message, context, cfg) do
    text
    |> parse_command(cfg.command_prefix)
    |> command_response(message, context, cfg)
  end

  defp command_args(text, prefix) do
    text
    |> String.trim()
    |> String.trim_leading(prefix)
    |> String.trim()
    |> String.split(~r/\s+/, trim: true)
  end

  defp parse_command_args([]), do: {:ok, :help}
  defp parse_command_args(["help"]), do: {:ok, :help}
  defp parse_command_args(["status"]), do: {:ok, :status}
  defp parse_command_args(["recent-runs"]), do: {:ok, :recent_runs}
  defp parse_command_args(["coverage"]), do: {:ok, :coverage}
  defp parse_command_args(["issue" | rest]) when rest != [], do: {:ok, {:issue, Enum.join(rest, " ")}}
  defp parse_command_args(["note" | rest]) when rest != [], do: {:ok, {:note, Enum.join(rest, " ")}}
  defp parse_command_args(["ask" | rest]) when rest != [], do: {:ok, {:ask, Enum.join(rest, " ")}}
  defp parse_command_args(["run", mode]), do: parse_mode(mode)
  defp parse_command_args(_args), do: {:error, :unknown}

  defp handle_ops_request(prefix, request, message, context, cfg) do
    handle_ops_message(prefix <> request, message, context, cfg)
  end

  defp command_response({:ok, :help}, _message, _context, cfg), do: {:reply, help_text(cfg.command_prefix)}
  defp command_response({:ok, :status}, _message, _context, _cfg), do: {:reply, status_text()}
  defp command_response({:ok, :recent_runs}, _message, _context, _cfg), do: {:reply, recent_runs_text()}
  defp command_response({:ok, :coverage}, _message, _context, _cfg), do: {:reply, coverage_text()}
  defp command_response({:ok, {:run, mode}}, _message, context, _cfg), do: run_command(mode, context)

  defp command_response({:ok, {:issue, request}}, message, context, cfg) do
    handle_ops_request("Create a GitHub issue for this project using this request:\n\n", request, message, context, cfg)
  end

  defp command_response({:ok, {:note, request}}, message, context, cfg) do
    handle_ops_request(
      "Add a documentation note. If a page reference is ambiguous, ask for clarification.\n\n",
      request,
      message,
      context,
      cfg
    )
  end

  defp command_response({:ok, {:ask, prompt}}, message, context, cfg), do: handle_ops_message(prompt, message, context, cfg)
  defp command_response({:error, :unknown}, _message, _context, cfg), do: {:reply, "Unknown command. Try #{cfg.command_prefix} help"}

  defp handle_ops_message(prompt, message, context, cfg) do
    tool_context = build_tool_context(message, context, cfg)

    with {:ok, qa_pid} <- SessionManager.ensure_session(message.room_id),
         {:ok, answer} <- qa_fun().(qa_pid, prompt, tool_context: tool_context) do
      {:reply, answer}
    else
      {:error, reason} ->
        Logger.warning("[ContentOps.Chat.Router] OpsAgent failed: #{inspect(reason)}")
        {:reply, "I couldn't answer that right now. Try again in a moment."}
    end
  end

  defp run_command(mode, context) do
    actor = Authorizer.actor_from_context(context)
    mutation_enabled = mutation_tools_enabled?()

    case ops_service().run(mode, actor) do
      {:ok, result} ->
        record_run_command_event(
          mode,
          actor,
          :accepted,
          :authorized,
          mutation_enabled,
          nil,
          result.message
        )

        {:reply, result.message}

      {:error, :unauthorized} ->
        message = "You are not authorized to run ContentOps operations from chat."

        record_run_command_event(
          mode,
          actor,
          :blocked,
          :unauthorized,
          mutation_enabled,
          :unauthorized,
          message
        )

        {:reply, message}

      {:error, :mutations_disabled} ->
        message = "Chat mutation tools are disabled in this environment."

        record_run_command_event(
          mode,
          actor,
          :blocked,
          :mutations_disabled,
          false,
          :mutations_disabled,
          message
        )

        {:reply, message}

      {:error, :already_running} ->
        message = "ContentOps is already running. Wait for the current run to finish."

        record_run_command_event(
          mode,
          actor,
          :blocked,
          :authorized,
          mutation_enabled,
          :already_running,
          message
        )

        {:reply, message}

      {:error, :orchestrator_unavailable} ->
        message = "ContentOps orchestrator is unavailable right now."

        record_run_command_event(
          mode,
          actor,
          :failed,
          :authorized,
          mutation_enabled,
          :orchestrator_unavailable,
          message
        )

        {:reply, message}

      {:error, reason} ->
        message = "Failed to start ContentOps run: #{inspect(reason)}"

        record_run_command_event(
          mode,
          actor,
          :failed,
          :authorized,
          mutation_enabled,
          reason,
          message
        )

        {:reply, message}
    end
  end

  defp status_text do
    case Actions.GetStatus.run(%{}, %{}) do
      {:ok, %{summary: summary}} ->
        [
          "status: #{summary.status}",
          "total_runs: #{summary.total_runs}",
          "last_run_mode: #{summary.last_run_mode || "n/a"}",
          "last_run_at: #{format_time(summary.last_run_at)}"
        ]
        |> Enum.join("\n")

      {:ok, %{result: result}} ->
        result
    end
  end

  defp recent_runs_text do
    {:ok, %{result: result}} = Actions.GetRecentRuns.run(%{limit: 5}, %{})
    result
  end

  defp coverage_text do
    {:ok, %{result: result}} = Actions.GetCoverage.run(%{}, %{})
    result
  end

  defp help_text(prefix) do
    """
    ContentOps commands:
    - #{prefix} help
    - #{prefix} status
    - #{prefix} run <hourly|nightly|weekly|monthly>
    - #{prefix} recent-runs
    - #{prefix} coverage
    - #{prefix} issue <freeform>
    - #{prefix} note <freeform>
    - #{prefix} ask <freeform>
    """
    |> String.trim()
  end

  defp command_message?(text, prefix) do
    String.starts_with?(String.trim(text), prefix)
  end

  defp routeable_command_text(text, cfg) do
    cond do
      command_message?(text, cfg.command_prefix) ->
        text

      addressed?(text, cfg.bot_name) ->
        stripped = strip_addressing(text, cfg.bot_name)

        if command_message?(stripped, cfg.command_prefix) do
          stripped
        else
          nil
        end

      true ->
        nil
    end
  end

  defp addressed?(text, bot_name) when is_binary(text) and is_binary(bot_name) do
    down = String.downcase(text)
    bot_down = bot_name |> String.trim() |> String.downcase()

    bot_down != "" and
      (String.contains?(down, "@" <> bot_down) or
         String.starts_with?(down, bot_down <> ":") or
         String.starts_with?(down, bot_down <> ",") or
         String.starts_with?(down, bot_down <> " "))
  end

  defp addressed?(_text, _bot_name), do: false

  defp strip_addressing(text, bot_name) when is_binary(text) and is_binary(bot_name) do
    text
    |> String.replace(~r/@#{Regex.escape(bot_name)}/i, "")
    |> String.replace(~r/^#{Regex.escape(bot_name)}[:,]?\s*/i, "")
    |> String.trim()
  end

  defp strip_addressing(text, _bot_name), do: text

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

  defp format_time(nil), do: "n/a"
  defp format_time(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp format_time(other), do: to_string(other)

  defp qa_fun do
    config = Application.get_env(:agent_jido, __MODULE__, [])

    case Keyword.get(config, :qa_fun) do
      fun when is_function(fun, 3) ->
        fun

      fun when is_function(fun, 2) ->
        fn pid, prompt, _opts -> fun.(pid, prompt) end

      _other ->
        fn pid, prompt, opts -> OpsAgent.chat(pid, prompt, opts) end
    end
  end

  defp ops_service do
    config = Application.get_env(:agent_jido, __MODULE__, [])
    Keyword.get(config, :ops_service, OpsService)
  end

  defp mutation_tools_enabled? do
    Config.load!().mutation_tools_enabled == true
  rescue
    _error ->
      false
  end

  defp record_run_command_event(
         mode,
         actor,
         outcome,
         authz_status,
         mutation_enabled,
         reason,
         message
       ) do
    event = %{
      action: :run,
      mode: mode,
      outcome: outcome,
      authz_status: authz_status,
      mutation_enabled: mutation_enabled,
      reason: reason,
      message: message,
      label: "Run #{mode} command",
      actor: actor,
      source: :router,
      timestamp: DateTime.utc_now()
    }

    ActionStore.record(event)
  rescue
    _error ->
      :ok
  catch
    :exit, _reason ->
      :ok
  end

  defp build_tool_context(message, context, cfg) do
    actor = Authorizer.actor_from_context(context)
    source_channel = actor.channel
    source_message_id = to_string(message[:external_id] || message[:id] || "")

    %{
      actor: actor,
      room_id: message[:room_id],
      source_channel: source_channel,
      source_message_id: source_message_id,
      github_owner: cfg.github_owner,
      github_repo: cfg.github_repo
    }
  end
end
