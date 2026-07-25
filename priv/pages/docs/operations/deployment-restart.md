%{
  description: "A worked example of a deployment restart: the whole supervised tree is torn down and rebuilt, and the workflow safely restarts at a stated state — or resumes, when the application owns persistence.",
  title: "Deployment Restart",
  category: :docs,
  legacy_paths: [],
  tags: [:docs, :operations],
  order: 363,
  draft: false
}
---
# Deployment Restart

[Supervision and Failure Boundaries](/docs/operations/supervision-and-failure-boundaries) recovers a single crashed `AgentServer` process. [Process Crash and Restart](/docs/operations/process-crash-and-restart) is the worked example for that: a process dies, a *surviving parent supervisor* restarts it. This page is the worked example for the next level up — a **deployment restart** — where the *entire* supervised tree is torn down and rebuilt. A deploy, a release upgrade, a node restart, or an application crash all look like this. There is no surviving parent; the whole deployment is replaced.

The question a deployment restart forces is the one in the acceptance: **does the workflow resume, or does it safely restart?** Those are different outcomes, and the answer is not something Jido decides. It is an application-owned choice that depends on whether state was persisted and can be replayed on boot. This example makes both outcomes concrete: it shows the default — the workflow **safely restarts** at its initial state — and states the condition under which it would instead **resume**.

## What a deployment restart is (and is not)

A deployment restart is the entire supervisor tree — the supervisor *and* its agent children — stopping and a fresh tree booting. Every process from the old deployment is gone. The new deployment starts a new supervisor, which starts new agent processes.

It is not the same as a process crash. The distinction matters because the recovery mechanism is different:

- **A process crash** is recovered by OTP supervision. A surviving parent supervisor restarts the crashed child. The supervisor itself never went down. See [Process Crash and Restart](/docs/operations/process-crash-and-restart).
- **A deployment restart** has no surviving parent. The supervisor is gone too. Recovery is *boot*: the new deployment's supervisor starts the agent fresh, under the same restart semantics you shipped (`restart: :permanent` from `Jido.AgentServer.child_spec/1`).

Because the whole tree is replaced, the only thing that can carry state from the old deployment to the new one is a store that lives *outside* the BEAM — a database, a durable file, or a durable Signal Journal on a disc-backed adapter. Anything that lived only in process memory is gone. That is the decision this example makes observable.

## The example deployment

The runnable example is a single agent, `AgentJido.Demos.DeploymentRestartAgent`, that holds an `events` counter incremented through a validated Action. The counter lives only in process state, so what a deployment restart keeps and drops is exactly observable:

```elixir
defmodule AgentJido.Demos.DeploymentRestartAgent do
  alias AgentJido.Demos.DeploymentRestart.RecordEvent

  use Jido.Agent,
    name: "deployment_restart_agent",
    schema: [events: [type: :integer, default: 0]],
    signal_routes: [{"deployment_restart.record", RecordEvent}]
end
```

It runs as a `:permanent` child of a dedicated top-level supervisor — the same shape you would ship as the root of a release:

```elixir
children = [
  {Jido.AgentServer, jido: AgentJido.Jido, agent: DeploymentRestartAgent, id: agent_id}
]

Supervisor.init(children, strategy: :one_for_one)
```

## The whole deployment is replaced

Boot a deployment, grab the supervisor and its agent, and accumulate some state:

```elixir
{:ok, deploy1} = AgentJido.Demos.DeploymentRestart.Supervisor.start_link(agent_id: "orders-agent")

agent1 = AgentJido.Demos.DeploymentRestart.Supervisor.agent_server_pid(deploy1)

Enum.each(1..3, fn _ ->
  {:ok, _agent} =
    Jido.AgentServer.call(
      agent1,
      Jido.Signal.new!("deployment_restart.record", %{by: 1}, source: "/ops")
    )
end)
```

Now restart the deployment. `Supervisor.stop/1` tears the whole tree down — the supervisor and the agent both terminate:

```elixir
:ok = Supervisor.stop(deploy1)

Process.alive?(deploy1)  # => false — the old deployment is gone, supervisor included
Process.alive?(agent1)   # => false — the agent died with it
```

A new deployment boots a fresh supervisor and a fresh agent:

```elixir
{:ok, deploy2} = AgentJido.Demos.DeploymentRestart.Supervisor.start_link(agent_id: "orders-agent")

agent2 = AgentJido.Demos.DeploymentRestart.Supervisor.agent_server_pid(deploy2)

deploy2 != deploy1   # => true — a brand-new supervisor
agent2  != agent1    # => true — a brand-new agent process
Process.alive?(deploy2)  # => true — and it is running
```

The old deployment's supervisor is dead, and so is its agent. Contrast this with [Process Crash and Restart](/docs/operations/process-crash-and-restart), where the supervisor stays up and only the child pid changes. Here the parent is replaced too — that is what makes it a deployment restart.

The agent id can be the same across both boots, so a redeploy presents the **same logical identity** behind a **new process**. The registry makes the rebind observable — after the stop the old process freed the id, and after the redeploy the new process claims it:

```elixir
{:ok, status} = Jido.AgentServer.status(agent2)
status.agent_id  # => "orders-agent" — the identity carried, the process did not

# Before the redeploy, the stop freed the id:
AgentJido.Jido.whereis("orders-agent")   # => nil  (between deployments)

# After the redeploy, the same id resolves to the new process:
AgentJido.Jido.whereis("orders-agent")   # => agent2
```

## Stated semantics: safely restart, not resume

After a deployment restart you observe the new deployment's state explicitly through the `AgentServer` API. With no persistence wired in, the result is the agent's **initial** state:

```elixir
{:ok, %{agent: agent_after}} = Jido.AgentServer.state(agent2)
agent_after.state.events   # => 0
```

The counter that read `3` before the deploy reads `0` after it. That is the stated semantics for the default case: **the workflow safely restarts.** The new deployment is live and serving from a known initial state; the work that was in-flight when the old deployment stopped was dropped. This is a safe, deterministic outcome — but it is *not* a resume.

**Resuming** — reconstructing the pre-deploy state so the workflow picks up where it left off — is a different outcome, and it is application-owned. To make a deployment *resume*, your application must do one of these before the agent serves real work:

- **Persist agent state** to an external store and seed the agent with it on boot.
- **Replay a durable Signal Journal** from a disc-backed adapter so the agent re-derives its state from causal history. See what survives a restart and how to choose an adapter on the [Operational controls](/docs/getting-started/operational-controls) onboarding lane.

In both cases the mechanism that survives the deploy lives *outside* the BEAM. Jido's supervision restarts the process; it does not recover state. The same rule applies at the process level on [Process Crash and Restart](/docs/operations/process-crash-and-restart) — a deployment restart just removes the surviving parent that a process crash still had.

State explicitly what each agent class does on a deploy, so an operator is never guessing:

| Outcome | When it happens | What the application owns |
|---|---|---|
| **Safely restarts** | No persistence wired in (this example) | Decide what in-flight work is dropped, and which external sources re-drive it idempotently |
| **Resumes** | State persisted and replayed on boot | The store, the replay path, and idempotent Actions so redelivered Signals do not double-apply |

Either outcome is legitimate. What is not legitimate is leaving it unstated — an operator who assumes "resume" when the system "safely restarts" will lose in-flight work on every deploy.

## What this example shows and what it does not

This example proves one thing directly: when an entire deployment is torn down and rebuilt, the new deployment boots a fresh agent under supervision, and you can observe the new tree, its process, and its post-deploy state explicitly through the `AgentServer` API.

It does not, by itself:

- **Recover state.** A deployment restart rebuilds the tree with a fresh agent. Resuming is an application choice — wiring an external store, an idempotent replay, or a durable Signal Journal is separate work. See [Operational controls](/docs/getting-started/operational-controls).
- **Re-deliver in-flight work.** Work that was in a mailbox or mid-call when the old deployment stopped is gone. An external source that must re-drive it needs idempotent Actions and durable intent — see [Scheduling and Event Input](/docs/operations/scheduling-and-event-input).
- **Serve as an audit trail.** Observing post-deploy state is an operational check, not a tamper-evident record — see [Security and governance](/docs/operations/security-and-governance).

## Run it yourself

The example ships with a test that encodes the acceptance condition — the whole deployment is replaced (old supervisor and agent dead, new ones live), and the workflow safely restarts at its initial state (the counter that read `3` reads `0` after the redeploy), with resume stated as the application-owned alternative:

```
mix test test/agent_jido/demos/deployment_restart_test.exs
```

The source is under `lib/agent_jido/demos/deployment_restart/` — the agent, its `RecordEvent` Action, and the top-level supervisor that models the deployment.

> The end-to-end long-running reference application is a tracked follow-up (jido-e07-t29). When it lands, this deployment-restart path folds into it so the same observed result can be reproduced against the full reference app rather than the standalone demo. The open note on this task — "deployment-restart example needs the reference app" — is handled the same way the process-crash example handled its own: as a self-contained, tested demo today, with the reference app named as the tracked follow-up.

## Next steps

- Read the failure-boundary framework this builds on — topology, restart strategy, and restart intensity — on [Supervision and Failure Boundaries](/docs/operations/supervision-and-failure-boundaries).
- See the *process*-level version of this recovery on [Process Crash and Restart](/docs/operations/process-crash-and-restart); a deployment restart removes the surviving parent a process crash still had.
- Add this to your go-live drill alongside an `AgentServer` crash and a tool error — the [Production Readiness Checklist](/docs/operations/production-readiness-checklist) asks you to record the observed recovery behavior for an application restart and a deploy.
- Decide what survives a deploy and choose an adapter on the [Operational controls](/docs/getting-started/operational-controls) onboarding lane.
