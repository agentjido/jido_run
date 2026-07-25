defmodule AgentJido.Demos.DeploymentRestart.Supervisor do
  @moduledoc """
  Top-level supervisor for the **Deployment restart** example (`jido-e07-t14`).

  This supervisor *is* the deployment. Booting it with `start_link/1` brings a
  fresh agent up under supervision; stopping it (with `Supervisor.stop/1`)
  tears the **entire** tree down — the supervisor and the agent both die.
  Booting a second instance models a new deployment: a brand-new supervisor
  with a brand-new agent process.

  That is the difference from a process crash ([Process crash and
  restart](/docs/operations/process-crash-and-restart)): there, a surviving
  parent supervisor restarts a single crashed child. Here, there is no
  surviving parent — the whole tree is replaced. With no persistence wired in,
  the new deployment's agent comes back at its initial state, so the workflow
  **safely restarts** rather than resumes mid-flight.

  The agent id is stable across boots when the caller passes the same
  `:agent_id`, so a redeploy can present the *same logical identity* behind a
  *new process*. The default is a unique id per mount so several demo
  instances never collide.
  """

  use Supervisor

  alias AgentJido.Demos.DeploymentRestartAgent

  @doc """
  Boots a deployment. Linked to the caller. Pass `:agent_id` to pin the
  logical agent identity across a redeploy.
  """
  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    agent_id =
      Keyword.get_lazy(opts, :agent_id, fn ->
        "deployment-restart-#{System.unique_integer([:positive])}"
      end)

    children = [
      {Jido.AgentServer, jido: AgentJido.Jido, agent: DeploymentRestartAgent, id: agent_id}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  Returns the logical agent id this deployment boots the agent under.
  """
  @spec agent_id(Supervisor.supervisor()) :: String.t() | nil
  def agent_id(supervisor) when is_pid(supervisor) do
    case Supervisor.which_children(supervisor) do
      [{_id, pid, :worker, [Jido.AgentServer]} | _] when is_pid(pid) ->
        case Jido.AgentServer.status(pid) do
          {:ok, %{agent_id: agent_id}} -> agent_id
          _ -> nil
        end

      _ ->
        nil
    end
  end

  @doc """
  Returns the pid of the agent this deployment is running, or `nil` while it is
  between a stop and a (re)start.
  """
  @spec agent_server_pid(Supervisor.supervisor()) :: pid() | nil
  def agent_server_pid(supervisor) when is_pid(supervisor) do
    case Supervisor.which_children(supervisor) do
      [{_, pid, :worker, _} | _] when is_pid(pid) -> pid
      _ -> nil
    end
  end
end
