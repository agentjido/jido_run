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

  That is the **deployment** restart boundary. The **node** restart boundary is
  one level up again: the whole BEAM dies, so the in-memory (ETS) store dies
  with it — ETS is process-owned and "all data is lost when the BEAM stops"
  (`Jido.Storage.ETS`). State only bridges a node restart when the store is
  durable, i.e. lives outside any node. `storage_config/1` exposes both media
  (`:memory` vs `:durable`) so the reference app can show the boundary, and
  `simulate_node_restart/1` makes the loss observable for the recovery-boundary
  matrix (`jido-e07-t33`).
  """

  alias AgentJido.Demos.LongRunningReferenceAgent
  alias Jido.Persist
  alias Jido.Storage.ETS
  alias Jido.Storage.File, as: DurableFile

  @type storage_kind :: :memory | :durable

  @doc """
  Returns a fresh, collision-free in-memory (ETS) storage config for one
  reference run.

  Each call derives a unique table name, so parallel test runs and repeated
  demo mounts never collide. The tables are created lazily by the ETS adapter
  on the first `checkpoint/2`. Equivalent to `storage_config(:memory)`.
  """
  @spec storage_config() :: {module(), keyword()}
  def storage_config, do: storage_config(:memory)

  @doc """
  Returns a fresh, collision-free storage config for one reference run, keyed
  by the recovery boundary it serves.

    * `:memory` — an ETS store. Fast, in-memory, and survives a *deployment*
      restart (the owning process lives in `Jido.Supervisor`), but is lost on a
      *node* restart because the BEAM and its process-owned tables die together.
    * `:durable` — a `Jido.Storage.File` store in a unique tmp directory. Lives
      on disk, independent of any process or node, so it survives a node
      restart. The directory is created lazily by the File adapter on the first
      `checkpoint/2`; clean it up with `cleanup/1`.
  """
  @spec storage_config(storage_kind()) :: {module(), keyword()}
  def storage_config(:memory) do
    table = String.to_atom("reference_persist_#{System.unique_integer([:positive])}")
    {ETS, table: table}
  end

  def storage_config(:durable) do
    path =
      Path.join(System.tmp_dir!(), "reference_persist_#{System.unique_integer([:positive])}")

    {DurableFile, path: path}
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

  @doc """
  Simulates a node restart against `storage` and reports what survives.

  A node restart tears the whole BEAM down — every process and every
  process-owned table — with no surviving parent. That is one recovery boundary
  up from a deployment restart: a deployment restart leaves the `Jido.Supervisor`
  owner (and so the in-memory store) alive, but a node restart does not. The
  reference app's in-memory (ETS) store is process-owned, so a node restart
  empties it; a disk-backed (File) store is independent of any node, so it is
  untouched.

  Returns `:lost` for an in-memory store (a checkpoint written before the
  restart is gone afterward — `restore/2` then yields `{:error, :not_found}`)
  and `:survived` for a durable store (the checkpoint is still there).

  This makes the node recovery boundary observable in a single test process
  (`jido-e07-t33`): it is the boundary the durable store exists to cross.
  """
  @spec simulate_node_restart({module(), keyword()}) :: :lost | :survived
  def simulate_node_restart({ETS, opts}) do
    base = Keyword.fetch!(opts, :table)

    # A node restart frees every ETS table (owned by a process; no heir
    # survives a node loss). This store's tables carry a unique base name, so
    # destroying them touches nothing else. The next access lazily recreates an
    # empty store, which is exactly what a fresh node boots.
    Enum.each([:checkpoints, :threads, :thread_meta], fn suffix ->
      :ets.delete(:"#{base}_#{suffix}")
    end)

    :lost
  rescue
    ArgumentError -> :lost
  end

  def simulate_node_restart({_durable, _opts}), do: :survived

  @doc """
  Removes any on-disk artifacts for `storage`; a no-op for in-memory stores.

  Call from a test's `on_exit/1` so a durable store's tmp directory does not
  leak between runs.
  """
  @spec cleanup({module(), keyword()}) :: :ok
  def cleanup({DurableFile, opts}) do
    if path = Keyword.get(opts, :path), do: File.rm_rf(path)
    :ok
  end

  def cleanup(_memory), do: :ok
end
