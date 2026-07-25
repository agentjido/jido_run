defmodule AgentJido.Demos.LongRunningReference.Persistence do
  @moduledoc """
  Persistence duties for the reference application (`jido-e07-t29`).

  The "persistence" step of the linear path. This is the application-owned
  decision the architecture spec names explicitly: when work must survive a
  restart, snapshot agent state and replay it on boot. Jido provides
  `Jido.Persist.hibernate/2` and `Jido.Persist.thaw/3`; the application chooses
  the store. This helper wires an ETS-backed store (the same adapter
  `AgentJido.Demos.PersistenceStorageAgent` uses) so a checkpoint outlives any
  one process or deployment.

  The store is the `:jido` application's `Jido.Storage.ETS.Owner` singleton: the
  ETS tables are created in that long-lived process (heir to `Jido.Supervisor`),
  so they survive a reference-deployment teardown. Tear the whole supervised
  tree down, boot a fresh deployment, and `restore/2` rehydrates the agent from
  the checkpoint — the workflow *resumes*, it does not start over. That is the
  contrast the `AgentJido.Demos.DeploymentRestart` demo makes on its own (a
  fresh deployment with no persistence safely restarts at the initial state);
  persistence is what turns a safe restart into a resume.
  """

  alias AgentJido.Demos.LongRunningReferenceAgent
  alias Jido.Persist
  alias Jido.Storage.ETS

  @doc """
  Returns a fresh, collision-free ETS storage config for one reference run.

  Each call derives a unique table name, so parallel test runs and repeated
  demo mounts never collide. The tables are created lazily by the ETS adapter
  on the first `checkpoint/2`.
  """
  @spec storage_config() :: {module(), keyword()}
  def storage_config do
    table = String.to_atom("reference_persist_#{System.unique_integer([:positive])}")
    {ETS, table: table}
  end

  @doc """
  Checkpoints `agent` under its id in `storage`.
  """
  @spec checkpoint({module(), keyword()} | module(), struct()) ::
          :ok | {:error, term()}
  def checkpoint(storage, agent) do
    Persist.hibernate(storage, agent)
  end

  @doc """
  Restores the reference agent with `key` from `storage`, or returns
  `{:error, :not_found}` when no checkpoint exists.
  """
  @spec restore({module(), keyword()} | module(), String.t()) ::
          {:ok, struct()} | {:error, term()}
  def restore(storage, key) do
    Persist.thaw(storage, LongRunningReferenceAgent, key)
  end
end
