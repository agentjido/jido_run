defmodule AgentJido.Demos.ClusterNodeLossTest do
  @moduledoc """
  Runnable proof for the "Cluster node loss" example (`jido-e07-t18`).

  Acceptance: "Scope, tested topology, and limitations are clear."

  These tests pin the three things the acceptance asks for, against a
  deterministic in-process model of a Jido cluster:

    * **topology** — placement is deterministic (rendezvous hashing); the same
      key on the same live set resolves to the same owner;
    * **node loss** — a lost node leaves the live set, its host process dies,
      its keys are orphaned, and routing an orphaned key fails with a defined
      result (not a hang);
    * **rebalance** — only the lost node's keys move (rendezvous hashing
      guarantees it), orphaned keys re-home onto survivors, and routing
      succeeds again;
    * **scope/limits** — losing the last node strands its keys; the model
      exposes the bounded scope the page names (full-cluster loss is the
      application-owned, out-of-scope case).
  """

  use ExUnit.Case, async: false

  alias AgentJido.Demos.ClusterNodeLoss, as: Demo

  describe "placement is deterministic (the tested topology)" do
    test "the same key on the same live set always resolves to the same owner" do
      owner_a = Demo.owner_for("agent-1", [:a, :b, :c])
      owner_b = Demo.owner_for("agent-1", [:a, :b, :c])

      assert owner_a == owner_b
      assert owner_a in [:a, :b, :c]
    end

    test "placing a key records its owner, and re-placing a live key is idempotent" do
      cluster = start_cluster(nodes: [:a, :b, :c])

      assert {:ok, owner} = Demo.place(cluster, "agent-1")
      assert owner in [:a, :b, :c]
      assert Demo.owner(cluster, "agent-1") == owner

      # A live key does not move when re-placed.
      assert {:ok, ^owner} = Demo.place(cluster, "agent-1")

      stop(cluster)
    end

    test "every key lands on exactly one owner, spread across the live set" do
      nodes = [:a, :b, :c]
      cluster = start_cluster(nodes: nodes)
      keys = Enum.map(1..30, &"agent-#{&1}")

      Enum.each(keys, fn k -> assert {:ok, _} = Demo.place(cluster, k) end)

      owners = Enum.map(keys, &Demo.owner(cluster, &1))

      assert Enum.all?(owners, &(&1 in nodes))
      # Rendezvous hashing spreads keys — more than one owner is used.
      assert MapSet.new(owners) |> MapSet.size() > 1
      # Each key has exactly one owner.
      assert length(owners) == length(keys)

      stop(cluster)
    end
  end

  describe "removing a node only moves the keys that node held" do
    # This is the core of the tested topology: rendezvous (HRW) hashing
    # guarantees that removing a node can only change the owner of the keys it
    # held. Keys on survivors never move. The demo's rebalance inherits this
    # guarantee because it re-derives owners with the same function.
    test "owner_for honours the minimal-move guarantee" do
      keys = Enum.map(1..50, &"agent-#{&1}")
      full = [:a, :b, :c]
      survivors = [:a, :b]

      Enum.each(keys, fn key ->
        full_owner = Demo.owner_for(key, full)
        survivor_owner = Demo.owner_for(key, survivors)

        if full_owner == :c do
          # c's keys must move to a survivor.
          assert survivor_owner in survivors
        else
          # Keys not on c keep their owner.
          assert survivor_owner == full_owner
        end
      end)
    end
  end

  describe "node loss is observable" do
    test "losing a node stops its process and moves it from live to lost" do
      cluster = start_cluster(nodes: [:a, :b, :c])
      c_pid = Demo.node_pid(cluster, :c)

      assert Process.alive?(c_pid)
      assert :c in Demo.live_nodes(cluster)
      assert Demo.lost_nodes(cluster) == []

      assert :ok = Demo.lose_node(cluster, :c)

      refute Process.alive?(c_pid)
      refute :c in Demo.live_nodes(cluster)
      assert Demo.lost_nodes(cluster) == [:c]

      stop(cluster)
    end

    test "a key owned by the lost node is orphaned until rebalance" do
      cluster = start_cluster(nodes: [:a, :b, :c])
      orphan = first_key_on(cluster, :c)

      assert orphan != nil
      assert Demo.owner(cluster, orphan) == :c

      assert :ok = Demo.lose_node(cluster, :c)

      # The owner is gone but rebalance has not run — the key is orphaned.
      # Its recorded owner is still c (the dead node); only rebalance re-homes.
      assert Demo.owner(cluster, orphan) == :c

      stop(cluster)
    end
  end

  describe "stranded work fails with a defined result in the loss window" do
    test "routing an orphaned key fails with node_lost; survivors keep routing" do
      cluster = start_cluster(nodes: [:a, :b, :c])
      orphan = first_key_on(cluster, :c)
      survivor_key = first_key_not_on(cluster, :c)
      survivor = Demo.owner(cluster, survivor_key)

      assert {:ok, :c} = Demo.route(cluster, orphan)
      assert {:ok, ^survivor} = Demo.route(cluster, survivor_key)

      assert :ok = Demo.lose_node(cluster, :c)

      # The orphaned key: defined failure, not a hang.
      assert {:error, {:node_lost, :c}} = Demo.route(cluster, orphan)
      # A survivor's key still routes to its live owner.
      assert {:ok, ^survivor} = Demo.route(cluster, survivor_key)

      stop(cluster)
    end

    test "routing an unplaced key is a defined not_placed result" do
      cluster = start_cluster(nodes: [:a, :b, :c])

      assert {:error, :not_placed} = Demo.route(cluster, "never-placed")

      stop(cluster)
    end
  end

  describe "rebalance re-homes only the lost node's keys" do
    test "the lost node's keys move to survivors; everyone else stays put" do
      cluster = start_cluster(nodes: [:a, :b, :c])
      keys = Enum.map(1..50, &"agent-#{&1}")
      Enum.each(keys, fn k -> {:ok, _} = Demo.place(cluster, k) end)

      before = Enum.into(keys, %{}, fn k -> {k, Demo.owner(cluster, k)} end)
      c_keys = for {k, o} <- before, o == :c, do: k
      non_c_keys = for {k, o} <- before, o != :c, do: k

      assert :ok = Demo.lose_node(cluster, :c)
      assert {:ok, report} = Demo.rebalance(cluster)

      # Exactly the keys c held moved, and each moved to a survivor.
      moved_keys = Enum.map(report.moved, fn {k, _old, _new} -> k end)
      assert Enum.sort(moved_keys) == Enum.sort(c_keys)

      Enum.each(report.moved, fn {_k, old, new} ->
        assert old == :c
        assert new in [:a, :b]
      end)

      # Survivors' keys never moved.
      after_map = Enum.into(keys, %{}, fn k -> {k, Demo.owner(cluster, k)} end)
      Enum.each(non_c_keys, fn k -> assert after_map[k] == before[k] end)

      # Nothing was stranded — survivors remained.
      assert report.stranded == []

      # The orphaned keys now route to their new live owner.
      Enum.each(c_keys, fn k ->
        new_owner = Demo.owner(cluster, k)
        assert new_owner in [:a, :b]
        assert {:ok, ^new_owner} = Demo.route(cluster, k)
      end)

      stop(cluster)
    end

    test "rebalance is a no-op when nothing is orphaned" do
      cluster = start_cluster(nodes: [:a, :b, :c])

      Enum.each(["agent-1", "agent-2", "agent-3"], fn k ->
        {:ok, _} = Demo.place(cluster, k)
      end)

      assert {:ok, report} = Demo.rebalance(cluster)
      assert report.moved == []
      assert report.stranded == []

      stop(cluster)
    end
  end

  describe "scope and limitations are bounded (full-cluster loss strands work)" do
    test "losing the last node strands its keys — no survivor to re-home onto" do
      cluster = start_cluster(nodes: [:a, :b])
      assert {:ok, _} = Demo.place(cluster, "agent-1")

      assert :ok = Demo.lose_node(cluster, :a)
      assert :ok = Demo.lose_node(cluster, :b)

      assert Demo.live_nodes(cluster) == []

      # No live node — placing cannot find an owner.
      assert {:error, :no_live_nodes} = Demo.place(cluster, "agent-2")

      # Rebalance cannot re-home; the key is stranded. (A real cluster would
      # recover this from durable state on a fresh node — an application-owned,
      # out-of-scope follow-up the page names.)
      assert {:ok, report} = Demo.rebalance(cluster)
      assert "agent-1" in report.stranded
      assert report.moved == []

      stop(cluster)
    end

    test "losing a non-live node is rejected" do
      cluster = start_cluster(nodes: [:a, :b, :c])

      assert {:error, :not_live} = Demo.lose_node(cluster, :z)
      assert {:error, :not_live} = Demo.lose_node(cluster, :z)

      assert :ok = Demo.lose_node(cluster, :a)
      # :a is already lost — not live.
      assert {:error, :not_live} = Demo.lose_node(cluster, :a)

      stop(cluster)
    end
  end

  # --- helpers ----------------------------------------------------------------

  defp start_cluster(opts) do
    {:ok, pid} = Demo.start_link(opts)
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid, :normal, :infinity) end)
    pid
  end

  defp stop(cluster), do: GenServer.stop(cluster, :normal, :infinity)

  # Place keys one at a time until the first one whose owner is `node`.
  defp first_key_on(cluster, node) do
    Enum.find_value(1..200, fn i ->
      key = "agent-#{i}"
      {:ok, _} = Demo.place(cluster, key)
      if Demo.owner(cluster, key) == node, do: key
    end)
  end

  # Place keys one at a time until the first one whose owner is NOT `node`.
  defp first_key_not_on(cluster, node) do
    Enum.find_value(1..200, fn i ->
      key = "agent-#{i}"
      {:ok, _} = Demo.place(cluster, key)
      owner = Demo.owner(cluster, key)
      if owner != node, do: key
    end)
  end
end
