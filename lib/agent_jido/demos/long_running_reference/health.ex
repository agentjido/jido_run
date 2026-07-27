defmodule AgentJido.Demos.LongRunningReference.Health do
  @moduledoc """
  Health checks for the reference application (`jido-e07-t29`).

  The "health check" step of the linear path, implemented exactly as the
  [Health checks and readiness](/docs/operations/health-checks-and-readiness)
  operations page prescribes: three independent axes — process, dependency, and
  work health — because they fail independently. A process-health probe passes
  during a provider outage; a dependency probe passes while the queue grows.

  Jido does not know the agent's dependencies, so this module is application
  code over Jido's supervision, registry, and `Jido.AgentServer.Status` API:

    * `process_health/1` — resolves the registered name to a process and
      confirms it answers `Jido.AgentServer.status/1` within a bounded timeout.
    * `dependency_health/1` — pings the persistence store (the one external
      dependency the reference app wires in) by reading a checkpoint key.
    * `work_health/1` — reads the directive queue length and strategy status
      from `Jido.AgentServer.status/1` and flags a backlog or a stuck
      (`:waiting`) agent.

  Each axis returns `:ok`, `{:warn, reason}`, or `{:error, reason}`, so a
  load balancer or deploy pipeline can set readiness from process + dependency
  health and alert on work health without conflating them.
  """

  alias AgentJido.Demos.LongRunningReference.Persistence
  alias Jido.AgentServer
  alias Jido.AgentServer.Status

  @queue_warn_threshold 1_000

  @type health :: :ok | {:warn, atom()} | {:error, atom()}

  @doc """
  Process health: is the `AgentServer` process up and responsive right now?

  Resolves `name` (pid, registered name, or agent id on the `AgentJido.Jido`
  instance) and confirms it answers `Jido.AgentServer.status/1`. Returns `:ok`
  when alive and responsive, `{:error, :process_down}` when gone.

  A real probe caps the call with a short `GenServer.call` timeout so a wedged
  process also fails. `status/1` answers `{:ok, _}` / `{:error, _}` for a live
  process but *exits* when the process is gone, so this probe bounds the call
  and treats an exit (no process, or no answer within the budget) as down.
  """
  @spec process_health(GenServer.server()) :: health()
  def process_health(name) do
    case safe_status(name) do
      {:ok, _status} -> :ok
      {:error, :invalid_server} -> {:error, :invalid_server}
      {:error, _other} -> {:error, :process_down}
    end
  end

  @doc """
  Dependency health: can the agent reach the persistence store it needs?

  Pings the store by attempting a read of `key`. The reference app's only
  external dependency is its persistence store; a real application adds its LLM
  provider and tool APIs here. Returns `:ok` when the store answers (hit or
  miss), `{:error, :store_unreachable}` when it does not.
  """
  @spec dependency_health({module(), keyword()} | module(), String.t()) :: health()
  def dependency_health(storage, key) do
    case Persistence.restore(storage, key) do
      {:ok, _agent} -> :ok
      {:error, :not_found} -> :ok
      {:error, _reason} -> {:error, :store_unreachable}
    end
  end

  @doc """
  Work health: is the agent draining work and not stuck?

  Reads the directive queue length and strategy status from `status/1`. Flags a
  backlog past `#{@queue_warn_threshold}` queued directives and a `:waiting`
  strategy (often waiting on a response that never comes). A live process with
  live dependencies that is nonetheless stalled is what this axis catches.
  """
  @spec work_health(GenServer.server()) :: health()
  def work_health(name) do
    case safe_status(name) do
      {:ok, status} ->
        cond do
          Status.queue_length(status) > @queue_warn_threshold -> {:warn, :queue_backlog}
          Status.status(status) == :waiting -> {:warn, :waiting}
          true -> :ok
        end

      {:error, :invalid_server} = error ->
        error

      {:error, _other} ->
        {:error, :process_down}
    end
  end

  # Bounds the status probe. `Jido.AgentServer.status/1` returns
  # `{:ok, _} | {:error, _}` for a live process but exits when the process is
  # gone or unresponsive, so convert an exit into a `:process_down` error the
  # caller can treat as "not healthy" rather than letting it crash the checker.
  defp safe_status(name) do
    AgentServer.status(name)
  catch
    :exit, _ -> {:error, :process_down}
  end
end
