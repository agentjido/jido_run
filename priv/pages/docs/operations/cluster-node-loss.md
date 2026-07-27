%{
  description: "A worked example of cluster-node loss: a node that owns keyed Jido agent instances leaves a connected cluster, its work is orphaned, routing fails with a defined result, and a conservative rebalance re-homes only the lost node's keys onto the survivors.",
  title: "Cluster node loss",
  category: :docs,
  legacy_paths: [],
  tags: [:docs, :operations],
  order: 368,
  draft: false
}
---
# Cluster Node Loss

[Deployment restart](/docs/operations/deployment-restart) tears down *one* node's whole supervised tree and brings it back. [Process crash and restart](/docs/operations/process-crash-and-restart) loses *one* process and lets its supervisor rebuild it. **Cluster-node loss** is one scope larger: a whole BEAM node — one member of a *connected, multi-node* cluster — is gone, and it took the keyed agent instances it owned with it. There is no surviving parent on that node to restart anything. Recovery here is not supervision; it is **re-homing**: the work the lost node owned has to be placed somewhere else, deterministically, and the work in flight when the node died has to fail with a defined result.

This is the failure case that only exists once you run more than one node. A single-node deployment never sees it — which is exactly why it is documented separately, with its own scope, topology, and limitations, rather than folded into the single-node restart story.

> **`jido_cluster` is experimental and unreleased.** The distributed runtime package ([Jido Cluster](/ecosystem/jido_cluster)) is `experimental`, `unreleased`, and pre-1.0 ("distributed runtime and storage APIs are unstable"). It is not a dependency of this workbench and is not loaded here. The example on this page is therefore a **tested in-process model** of the placement and node-loss rule `jido_cluster` describes — not a real multi-node BEAM run. See [Limitations](#what-this-example-does-and-does-not-cover) for the full boundary.

## The scope

Cluster-node loss means **one node leaving a connected cluster**. The example covers exactly that scope and names what it does not:

| In scope on this page | Out of scope (application-owned) |
|---|---|
| One node gone from a *connected* cluster — a crash, a scale-down, an operator stop | A network **partition** / split-brain (two live sub-clusters that cannot see each other) |
| The keyed instances that node *owned* losing their owner | **Full-cluster loss** (every node gone — recovered from durable state on a fresh node, not by rebalancing) |
| Routing at the dead node failing with a defined result | Byzantine or slow nodes (alive but wrong) |
| Conservative re-homing of orphaned keys onto survivors | Cross-node **state reconstruction** — rebuilding an instance's state after its node died |

The dividing line is: this page covers **re-homing ownership** of keyed instances when their owner disappears. It does not cover reconstructing the *contents* of those instances, surviving a partition, or recovering from total cluster loss. Those are separate duties — durable state is covered on [Scheduling and event input](/docs/operations/scheduling-and-event-input), and the failure drill for them lives with the [Incident playbooks](/docs/operations/incident-playbooks).

## The tested topology

The runnable example is a single module, `AgentJido.Demos.ClusterNodeLoss`, that models a cluster in one process so the topology is observable in a test. A `Cluster` holds the live and lost node sets and a placement map (`key → owner node`); each node has a host process whose death is the direct observable of node loss. Placement uses **rendezvous hashing** (highest-random-weight, the deterministic placement rule `jido_cluster` describes): the owner of a key is the live node with the highest `:erlang.phash2({node, key})`.

Three properties make the topology testable, and the example makes each one observable:

### 1. Placement is deterministic

The same key on the same live node set always resolves to the same owner. Placement is a pure function of the key and the *current* live set — nothing else:

```elixir
# The owner is the live node with the highest hash of {node, key}.
AgentJido.Demos.ClusterNodeLoss.owner_for("agent-1", [:a, :b, :c])   # => :b
AgentJido.Demos.ClusterNodeLoss.owner_for("agent-1", [:a, :b, :c])   # => :b  (same answer)

{:ok, cluster} = AgentJido.Demos.ClusterNodeLoss.start_link(nodes: [:a, :b, :c])
{:ok, owner} = AgentJido.Demos.ClusterNodeLoss.place(cluster, "agent-1")   # => {:ok, :b}
AgentJido.Demos.ClusterNodeLoss.owner(cluster, "agent-1")                  # => :b
```

### 2. Node loss is observable, and stranded work fails with a defined result

Losing a node stops its host process (the node process is gone), removes it from the live set, and orphans the keys it owned. In the **loss window** — after the node is gone but before rebalance re-homes — routing a key whose owner was the lost node returns a defined failure, not a hang:

```elixir
AgentJido.Demos.ClusterNodeLoss.lose_node(cluster, :c)
AgentJido.Demos.ClusterNodeLoss.node_pid(cluster, :c) |> Process.alive?()   # => false
:c in AgentJido.Demos.ClusterNodeLoss.live_nodes(cluster)                   # => false
AgentJido.Demos.ClusterNodeLoss.lost_nodes(cluster)                         # => [:c]

# A key :c owned is orphaned. Routing it fails explicitly — the caller learns
# the owner is gone, it does not wait forever.
AgentJido.Demos.ClusterNodeLoss.route(cluster, orphan_key)   # => {:error, {:node_lost, :c}}
```

A key whose owner is a survivor keeps routing fine through the same window — only the lost node's work is affected.

### 3. Rebalance is minimal — only the lost node's keys move

Re-homing is a separate, conservative step (the rebalance loop `jido_cluster` runs periodically with configurable migration limits). It re-derives an owner for every orphaned key over the surviving set. Rendezvous hashing guarantees the minimal-move property here: **removing a node can only change the owner of the keys that node held.** A survivor's key is never disturbed:

```elixir
{:ok, report} = AgentJido.Demos.ClusterNodeLoss.rebalance(cluster)

# Exactly the keys :c held moved, each to a survivor; nothing on :a or :b moved.
Enum.map(report.moved, fn {_key, old, _new} -> old end)   # => [:c, :c, ...]
Enum.all?(report.moved, fn {_key, _old, new} -> new in [:a, :b] end)   # => true

# After rebalance, a re-homed key routes to its new live owner.
AgentJido.Demos.ClusterNodeLoss.route(cluster, orphan_key)   # => {:ok, :a}
```

The `:stranded` field of the report lists keys that could not be re-homed because **no live node remains** — full-cluster loss. That is the bounded scope: the model re-homes up to N−1 node losses; total loss strands work, and recovering from it is an application-owned duty (rebuild from durable state), not a rebalance.

## What this example does and does not cover

This example makes the topology and the node-loss rule directly observable: placement is deterministic, a lost node orphans its keys and routes fail with a defined result, and a conservative rebalance re-homes only the lost node's keys.

It does **not**, and the limitations are the point of documenting this separately:

- **Run a real distributed BEAM.** This is a single-process, in-process model. It does not start multiple OS processes or BEAM nodes, does not form a real distributed Erlang cluster, and does not exercise `:nodedown`, `Node.monitor/1`, or distributed process registries. `jido_cluster` is unreleased and not loaded here; wiring the real package is the tracked follow-up below.
- **Handle a network partition.** A partition leaves nodes alive but unreachable — two sub-clusters that each think the other is gone. Detecting and resolving that (quorum, fencing, lease/lock revocation) is an application-owned distributed-systems duty, distinct from the clean "node is gone" case modeled here.
- **Reconstruct instance state.** Re-homing re-places *ownership* of a keyed instance; it does not rebuild the instance's accumulated state. State lost with the node is recovered the same way as in a [deployment restart](/docs/operations/deployment-restart) — from durable storage, by replaying a Signal Journal — not by the cluster layer. See [Scheduling and event input](/docs/operations/scheduling-and-event-input).
- **Survive full-cluster loss.** When every node is gone there is nothing to rebalance onto. Recovery then means booting a fresh node and restoring from durable state — out of scope for a rebalance, which is why `rebalance/1` reports those keys as `:stranded`.
- **Replace supervision.** A crashed `AgentServer` on a *surviving* node is still restarted by its local supervisor — see [Supervision and failure boundaries](/docs/operations/supervision-and-failure-boundaries). Cluster-node loss is what supervision *cannot* fix, because the supervisor lived on the node that died.

## Run it yourself

The example ships with a test that encodes the acceptance — placement is deterministic (the same key on the same live set resolves to the same owner); the minimal-move guarantee holds (removing a node only moves the keys it held); node loss is observable (the host process dies, the node leaves the live set); stranded work fails with a defined result in the loss window; and rebalance re-homes only the lost node's keys onto survivors:

```
mix test test/agent_jido/demos/cluster_node_loss_test.exs
```

The source is at `lib/agent_jido/demos/cluster_node_loss/cluster_node_loss.ex`.

> The end-to-end long-running reference application (`jido-e07-t29`) is the tracked follow-up that will fold this cluster-node-loss path into one runnable app, and open question `cluster-node-loss example needs a tested reference` closes against it. Until it lands — and until `jido_cluster` ships — the example on this page is the tested reference: a self-contained, tested in-process model of the topology and node-loss rule, the same pattern the [process crash](/docs/operations/process-crash-and-restart), [deployment restart](/docs/operations/deployment-restart), and [poison work](/docs/operations/poison-work-and-dead-letter) worked examples use.

## Next steps

- Start one scope down: [Deployment restart](/docs/operations/deployment-restart) tears down one node's tree and brings it back — the single-node case this page generalizes.
- See what supervision *does* recover versus what it cannot: [Supervision and failure boundaries](/docs/operations/supervision-and-failure-boundaries).
- Understand how state survives a node loss at all: durable storage and the Signal Journal on [Scheduling and event input](/docs/operations/scheduling-and-event-input).
- Read the package this example models — its scope, maturity, and the rebalance loop — on the [Jido Cluster](/ecosystem/jido_cluster) ecosystem page.
- Confirm your cluster failure plan against the [Production Readiness Checklist](/docs/operations/production-readiness-checklist) and practice it with the [Incident playbooks](/docs/operations/incident-playbooks).
