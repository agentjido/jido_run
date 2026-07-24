defmodule AgentJido.Demos.ControlledAgent.Supervisor do
  @moduledoc """
  Demo supervisor for the integrated controlled-Agent example (jido-e04-t41).

  Starts a single `Jido.AgentServer` running `AgentJido.Demos.ControlledAgent`
  as a `:permanent` child. Because `Jido.AgentServer.child_spec/1` sets
  `restart: :permanent`, OTP supervision automatically restarts the process
  when it is killed — which is the recovery the "how failure was handled"
  control question rests on, made visible in the example's crash-and-restart
  drill.

  Generous `max_restarts` / `max_seconds` keep the supervisor from giving up
  while a visitor repeatedly triggers the drill.
  """

  use Supervisor

  alias AgentJido.Demos.ControlledAgent

  @doc """
  Starts the controlled-agent supervisor. Linked to the caller (the LiveView
  owns it and stops it in `terminate/2`). Each instance gets a unique agent id
  so several LiveView mounts never collide.
  """
  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    agent_id =
      Keyword.get_lazy(opts, :agent_id, fn ->
        "controlled-agent-#{System.unique_integer([:positive])}"
      end)

    children = [
      {Jido.AgentServer, jido: AgentJido.Jido, agent: ControlledAgent, id: agent_id}
    ]

    Supervisor.init(children,
      strategy: :one_for_one,
      max_restarts: 1000,
      max_seconds: 1
    )
  end

  @doc """
  Returns the pid of the supervised AgentServer child, or `nil` if it is
  between a crash and a restart.
  """
  @spec agent_server_pid(Supervisor.supervisor()) :: pid() | nil
  def agent_server_pid(supervisor) when is_pid(supervisor) do
    case Supervisor.which_children(supervisor) do
      [{_, pid, :worker, _} | _] when is_pid(pid) -> pid
      _ -> nil
    end
  end
end
