defmodule AgentJido.Demos.AgentServerCrash.Supervisor do
  @moduledoc """
  Demo supervisor for the **Process crash and restart** example (`jido-e07-t12`).

  Starts a single `Jido.AgentServer` as a `:permanent` child. Because
  `Jido.AgentServer.child_spec/1` sets `restart: :permanent`, OTP supervision
  automatically restarts the process when it is killed — which is exactly the
  recovery the example documents: the process restarts.

  Generous `max_restarts` / `max_seconds` keep the supervisor from giving up
  while the example repeatedly triggers the crash.
  """

  use Supervisor

  alias AgentJido.Demos.AgentServerCrashAgent

  @doc """
  Starts the example supervisor. Linked to the caller. Each instance gets a
  unique agent id so several mounts never collide.
  """
  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    agent_id =
      Keyword.get_lazy(opts, :agent_id, fn ->
        "agent-server-crash-#{System.unique_integer([:positive])}"
      end)

    children = [
      {Jido.AgentServer, jido: AgentJido.Jido, agent: AgentServerCrashAgent, id: agent_id}
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
