defmodule AgentJido.Demos.LongRunningReference.Supervisor do
  @moduledoc """
  The deployment for the end-to-end reference application (`jido-e07-t29`).

  This supervisor is the "supervision" and "deployment" steps of the linear
  path, together in one place so the two kinds of restart — which the
  architecture spec keeps separate — are distinguishable against the same agent:

    * **Supervision (process restart).** The `Jido.AgentServer` child runs
      `:permanent` (its child spec sets `restart: :permanent`). Kill the agent
      process and *this supervisor*, which survives, restarts a fresh one. That
      is the same recovery `AgentJido.Demos.FailureDrill.Supervisor` shows.
    * **Deployment restart.** Stopping this supervisor with `Supervisor.stop/1`
      tears the **whole** tree down — the supervisor and the agent both die, as
      in a deploy, a release upgrade, or a node restart. There is no surviving
      parent. Booting a second supervisor models a new deployment.

  The agent id is stable across boots when the caller passes the same
  `:agent_id`, so a redeploy can present the *same logical identity* behind a
  *new process*. Pass `:storage` and a checkpointed agent through `:agent` to
  turn a safe restart into a **resume**: the new deployment boots from the
  rehydrated state rather than the initial state. That is the persistence +
  deployment interaction the reference app exists to make observable.
  """

  use Supervisor

  alias AgentJido.Demos.LongRunningReferenceAgent

  @doc """
  Boots a deployment. Linked to the caller.

  ## Options

    * `:agent_id` — pins the logical agent identity across a redeploy. Defaults
      to a unique id per mount so several demo instances never collide.
    * `:agent` — a pre-built `LongRunningReferenceAgent` struct to boot from
      (e.g. one rehydrated with `Persistence.restore/2`). When omitted, a fresh
      agent is built from the module defaults.
  """
  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    agent_id =
      Keyword.get_lazy(opts, :agent_id, fn ->
        "long-running-reference-#{System.unique_integer([:positive])}"
      end)

    # `is_struct/1` (not a struct pattern) avoids a compile-time dependency on
    # the agent's generated struct, which `use Jido.Agent` defines lazily.
    server_opts =
      case Keyword.get(opts, :agent) do
        restored when is_struct(restored) ->
          # Resume: boot the new deployment from rehydrated state. Pass
          # agent_module so the AgentServer keeps calling this module's
          # callbacks; the struct's id reclaims the same logical identity.
          [
            jido: AgentJido.Jido,
            agent: restored,
            agent_module: LongRunningReferenceAgent,
            id: agent_id
          ]

        _fresh ->
          # Fresh deployment: boot from module defaults. The AgentServer child
          # spec is :permanent, so this supervisor restarts a crashed process.
          [jido: AgentJido.Jido, agent: LongRunningReferenceAgent, id: agent_id]
      end

    children = [{Jido.AgentServer, server_opts}]

    Supervisor.init(children,
      strategy: :one_for_one,
      max_restarts: 1000,
      max_seconds: 1
    )
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
