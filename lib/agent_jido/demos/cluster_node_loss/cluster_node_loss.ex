defmodule AgentJido.Demos.ClusterNodeLoss do
  @moduledoc """
  A worked example of cluster-node loss for the "Cluster node loss" operations
  page (`jido-e07-t18`).

  Acceptance: "Scope, tested topology, and limitations are clear."

  When a BEAM node that owns keyed Jido agent instances leaves a connected
  cluster — a crash, a scale-down, a network loss — the work it owned has to go
  somewhere. In a Jido cluster (`jido_cluster`), ownership of a keyed instance
  is placed deterministically (rendezvous hashing) onto one node, and when that
  node is lost its keys are re-homed onto the surviving set. This example models
  that topology and the node-loss rule in a single process so the three things
  the acceptance asks for are observable: the **scope** (one node leaving a
  connected cluster), the **tested topology** (deterministic placement, minimal
  rebalance, a defined failure for work routed at the lost node), and the
  **limitations** (this is an in-process model, not a real distributed BEAM
  test; `jido_cluster` is experimental and unreleased; durable state, network
  partitions, and full-cluster loss are application-owned and out of scope).

  `jido_cluster` is not a dependency of this workbench and is not loaded here —
  it is unreleased (`priv/ecosystem/jido_cluster.md`). This demo is therefore a
  faithful, **tested in-process model** of the placement and node-loss rule, not
  a multi-node BEAM run. The end-to-end long-running reference application
  (`jido-e07-t29`) is the tracked follow-up that will fold this path into one
  runnable app; until it lands, the example ships as a self-contained, tested
  demo — the same pattern the process-crash, deployment-restart, and poison-work
  worked examples use.

  The example makes the topology observable:

    * **placement is deterministic** — the same key on the same live node set
      resolves to the same owner (rendezvous hashing);
    * **node loss is observable** — a lost node leaves the live set, its host
      process dies, and the keys it owned are orphaned;
    * **rebalance is minimal** — only the lost node's keys move, because
      rendezvous hashing guarantees removing a node can only change the owner of
      the keys that node held;
    * **stranded work fails with a defined result** — routing a key whose owner
      is lost returns `{:error, {:node_lost, node}}` in the loss window, not a
      hang.

  See `priv/pages/docs/operations/cluster-node-loss.md` and the acceptance test
  `test/agent_jido/demos/cluster_node_loss_test.exs`.
  """

  alias __MODULE__.Cluster

  @type cluster :: pid()
  @type node_name :: atom()

  @doc """
  Boots a cluster over `nodes` (default `[:a, :b, :c]`). Each node is given a
  host process; `place/2` assigns each keyed instance to exactly one owner via
  rendezvous hashing.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []), do: Cluster.start_link(opts)

  @doc """
  Ensures `key` has a live owner.

  Placing a new key assigns it to its deterministic owner; placing a key whose
  owner is still live is idempotent (the key does not move); placing a key whose
  owner was lost re-derives a live owner (it re-homes a single orphan). Returns
  `{:error, :no_live_nodes}` when the cluster has no live nodes to place onto.
  """
  @spec place(cluster(), term()) :: {:ok, node_name()} | {:error, :no_live_nodes}
  def place(cluster, key), do: Cluster.place(cluster, key)

  @doc """
  Returns the current owner node for `key`, or `nil` if it has not been placed.
  After `rebalance/1`, this is the *new* (re-homed) owner for a key whose
  original owner was lost.
  """
  @spec owner(cluster(), term()) :: node_name() | nil
  def owner(cluster, key), do: Cluster.owner(cluster, key)

  @doc """
  Returns the keys currently owned by `node` (derived from the placement map).
  A lost node owns nothing after `rebalance/1` re-homes its keys.
  """
  @spec keys_on(cluster(), node_name()) :: [term()]
  def keys_on(cluster, node), do: Cluster.keys_on(cluster, node)

  @doc """
  Returns the pid of `node`'s host process, or `nil` for a lost/unknown node.
  Losing a node stops this process — `Process.alive?/1` on it is the direct
  observable of node loss.
  """
  @spec node_pid(cluster(), node_name()) :: pid() | nil
  def node_pid(cluster, node), do: Cluster.node_pid(cluster, node)

  @doc """
  Lists the live (still-present) node names, sorted.
  """
  @spec live_nodes(cluster()) :: [node_name()]
  def live_nodes(cluster), do: Cluster.live_nodes(cluster)

  @doc """
  Lists the lost node names, in the order they were lost.
  """
  @spec lost_nodes(cluster()) :: [node_name()]
  def lost_nodes(cluster), do: Cluster.lost_nodes(cluster)

  @doc """
  Marks `node` as lost: its host process is stopped (the node process is gone)
  and the node leaves the live set. Keys it owned are now *orphaned* — their
  owner is a lost node — until `rebalance/1` re-homes them.

  This is the **detection** phase. It does not move any keys; it makes the loss
  observable (the node process is dead, the node is in `lost_nodes/1`) and
  leaves routing of orphaned keys to return a defined failure in the loss
  window. Returns `{:error, :not_live}` if `node` is not a live member.
  """
  @spec lose_node(cluster(), node_name()) :: :ok | {:error, :not_live}
  def lose_node(cluster, node), do: Cluster.lose_node(cluster, node)

  @doc """
  Re-homes every orphaned key (any key whose owner is lost) onto the surviving
  node set, and returns a report of what moved.

  The report carries:

    * `:moved` — `{key, old_owner, new_owner}` for each re-homed key;
    * `:stranded` — keys that could not be re-homed because no live node
      remains (the cluster has lost every node).

  Only orphaned keys move. A key whose owner is still live is never touched —
  rendezvous hashing guarantees removal of a node can only change the owner of
  the keys that node held, so rebalancing a lost node never disturbs survivors.
  """
  @spec rebalance(cluster()) ::
          {:ok, %{moved: [{term(), node_name(), node_name()}], stranded: [term()]}}
  def rebalance(cluster), do: Cluster.rebalance(cluster)

  @doc """
  Routes `key` to its owner.

  Returns `{:ok, owner}` when the owner is live; `{:error, {:node_lost,
  owner}}` when the owner is a lost node (the key is orphaned, pre-rebalance);
  and `{:error, :not_placed}` when the key has not been placed.

  The `{:node_lost}` result is the **defined failure** callers see in the loss
  window: work routed at a dead node fails explicitly, it does not hang.
  """
  @spec route(cluster(), term()) ::
          {:ok, node_name()} | {:error, {:node_lost, node_name()}} | {:error, :not_placed}
  def route(cluster, key), do: Cluster.route(cluster, key)

  @doc """
  The deterministic owner of `key` over `live_nodes` (rendezvous hashing: the
  node with the highest `:erlang.phash2({node, key})`).

  Pure — the same key on the same live set always resolves to the same owner,
  and removing a node can only move the keys that node owned. Returns `nil` for
  an empty node set. Exposed so placement determinism and the minimal-move
  guarantee are testable on their own, apart from the cluster state.
  """
  @spec owner_for(term(), [node_name()]) :: node_name() | nil
  def owner_for(key, live_nodes) do
    Enum.max_by(live_nodes, fn node -> :erlang.phash2({node, key}) end, fn -> nil end)
  end

  # --- the cluster topology ---------------------------------------------------

  defmodule Cluster do
    @moduledoc false

    use GenServer

    alias AgentJido.Demos.ClusterNodeLoss, as: Demo
    alias AgentJido.Demos.ClusterNodeLoss.NodeHost

    defstruct nodes: %{}, live: MapSet.new(), lost: [], placements: %{}
    # nodes:      %{name => NodeHost pid}
    # live:       MapSet of live node names
    # lost:       list of lost node names, in loss order
    # placements: %{key => owner_name}

    def start_link(opts) do
      names = opts |> Keyword.get(:nodes, [:a, :b, :c]) |> Enum.uniq()
      GenServer.start_link(__MODULE__, names)
    end

    def place(cluster, key), do: GenServer.call(cluster, {:place, key})
    def owner(cluster, key), do: GenServer.call(cluster, {:owner, key})
    def keys_on(cluster, node), do: GenServer.call(cluster, {:keys_on, node})
    def node_pid(cluster, node), do: GenServer.call(cluster, {:node_pid, node})
    def live_nodes(cluster), do: GenServer.call(cluster, :live_nodes)
    def lost_nodes(cluster), do: GenServer.call(cluster, :lost_nodes)
    def lose_node(cluster, node), do: GenServer.call(cluster, {:lose_node, node})
    def rebalance(cluster), do: GenServer.call(cluster, :rebalance)
    def route(cluster, key), do: GenServer.call(cluster, {:route, key})

    @impl true
    def init(names) do
      nodes =
        Enum.into(names, %{}, fn name ->
          {:ok, pid} = NodeHost.start_link(name)
          {name, pid}
        end)

      {:ok, %__MODULE__{nodes: nodes, live: MapSet.new(names), lost: [], placements: %{}}}
    end

    @impl true
    def handle_call({:place, key}, _from, %{placements: placements} = state) do
      case Map.fetch(placements, key) do
        {:ok, owner} ->
          if is_live?(state, owner) do
            # Idempotent: a live key stays where it is.
            {:reply, {:ok, owner}, state}
          else
            # An orphan whose owner was lost — (re)derive a live owner.
            place_fresh(state, key)
          end

        :error ->
          # New key — derive a live owner.
          place_fresh(state, key)
      end
    end

    @impl true
    def handle_call({:owner, key}, _from, %{placements: placements} = state) do
      {:reply, Map.get(placements, key), state}
    end

    @impl true
    def handle_call({:keys_on, node}, _from, state) do
      keys = for {key, owner} <- state.placements, owner == node, do: key
      {:reply, Enum.sort(keys), state}
    end

    @impl true
    def handle_call({:node_pid, node}, _from, state) do
      {:reply, Map.get(state.nodes, node), state}
    end

    @impl true
    def handle_call(:live_nodes, _from, state) do
      {:reply, state.live |> MapSet.to_list() |> Enum.sort(), state}
    end

    @impl true
    def handle_call(:lost_nodes, _from, state) do
      {:reply, state.lost, state}
    end

    @impl true
    def handle_call({:lose_node, node}, _from, state) do
      cond do
        not MapSet.member?(state.live, node) ->
          {:reply, {:error, :not_live}, state}

        true ->
          # Stop the node's host process — the node process is gone, the most
          # direct observable of node loss. A :normal exit does not crash this
          # cluster, so the topology survives to rebalance.
          stop_safely(state.nodes[node])

          state = %{
            state
            | live: MapSet.delete(state.live, node),
              lost: state.lost ++ [node]
          }

          {:reply, :ok, state}
      end
    end

    @impl true
    def handle_call(:rebalance, _from, state) do
      live = MapSet.to_list(state.live)

      {moved, stranded, placements} =
        Enum.reduce(state.placements, {[], [], state.placements}, fn {key, owner}, {mv, st, p} ->
          if MapSet.member?(state.live, owner) do
            # Still live — never touch a survivor's key.
            {mv, st, p}
          else
            case Demo.owner_for(key, live) do
              nil ->
                # No live node left — the key is stranded (full-cluster loss).
                {mv, [key | st], p}

              new_owner ->
                {[{key, owner, new_owner} | mv], st, Map.put(p, key, new_owner)}
            end
          end
        end)

      report = %{moved: Enum.reverse(moved), stranded: Enum.reverse(stranded)}
      {:reply, {:ok, report}, %{state | placements: placements}}
    end

    @impl true
    def handle_call({:route, key}, _from, state) do
      case Map.fetch(state.placements, key) do
        :error ->
          {:reply, {:error, :not_placed}, state}

        {:ok, owner} ->
          if MapSet.member?(state.live, owner) do
            {:reply, {:ok, owner}, state}
          else
            # Owner is lost — the key is orphaned in the loss window. Defined
            # failure, not a hang.
            {:reply, {:error, {:node_lost, owner}}, state}
          end
      end
    end

    defp place_fresh(state, key) do
      case Demo.owner_for(key, MapSet.to_list(state.live)) do
        nil ->
          {:reply, {:error, :no_live_nodes}, state}

        owner ->
          state = %{state | placements: Map.put(state.placements, key, owner)}
          {:reply, {:ok, owner}, state}
      end
    end

    defp is_live?(state, node), do: MapSet.member?(state.live, node)

    defp stop_safely(nil), do: :ok

    defp stop_safely(pid) when is_pid(pid) do
      if Process.alive?(pid), do: GenServer.stop(pid, :normal, :infinity)
    rescue
      _ -> :ok
    end
  end

  # --- a node host (a liveness beacon for one cluster member) -----------------

  defmodule NodeHost do
    @moduledoc """
    A minimal stand-in for a BEAM node that hosts the keyed instances assigned
    to it. Its job here is to exist — so node loss is a real process death
    (`Process.alive?/1` on the host flips to `false` when the node is lost),
    paralleling the process-crash worked example. Which keys a node owns is
    derived from the cluster's placement map, not stored here.
    """

    use GenServer

    def start_link(name), do: GenServer.start_link(__MODULE__, name)
    def name(pid), do: GenServer.call(pid, :name)

    @impl true
    def init(name), do: {:ok, name}

    @impl true
    def handle_call(:name, _from, name), do: {:reply, name, name}
  end
end
