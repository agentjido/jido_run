%{
  title: "Agents that self-heal",
  category: :features,
  description: "Each agent runs in its own BEAM process under OTP supervision. Crashes are recovered automatically.",
  doc_type: :explanation,
  audience: :beginner,
  draft: false,
  order: 25
}
---
Every Jido agent runs in its own BEAM process. If it crashes, OTP restarts it. If one agent fails, no other agent is affected. This is not a feature you configure. It is how the runtime works.

## At a glance

| Item | Summary |
|---|---|
| Best for | Teams building production agent systems that need uptime guarantees |
| Core packages | [jido](/ecosystem/jido), [jido_action](/ecosystem/jido_action), [jido_signal](/ecosystem/jido_signal) |
| Package status | `jido` (Beta), `jido_action` (Beta), `jido_signal` (Beta) |
| First proof path | Start agents under a supervisor → crash one → watch it recover |
| Key idea | Process isolation + OTP supervision = self-healing agents with no custom recovery code |

## Supervise your agents

```elixir
children = [
  {Jido.AgentServer,
   id: :support_agent,
   agent: MyApp.SupportAgent,
   name: :support_agent},

  {Jido.AgentServer,
   id: :billing_agent,
   agent: MyApp.BillingAgent,
   name: :billing_agent}
]

{:ok, _pid} = Supervisor.start_link(children, strategy: :one_for_one)
```

Two agents, each in its own process, both watched by a supervisor. If `:support_agent` crashes, OTP restarts it. `:billing_agent` keeps running, unaware anything happened.

## Process isolation per agent

Each `Jido.AgentServer` is a separate BEAM process with its own:

- **Memory.** No shared heap. A memory issue in one agent cannot corrupt another.
- **Mailbox.** Messages are queued per process. A slow agent does not block a fast one.
- **Failure boundary.** An unhandled error crashes one process, not the system.

This is the same isolation model that lets telecom systems run for years without downtime. Jido inherits it directly from the BEAM.

## Automatic crash recovery

OTP supervision handles recovery without custom code:

| What happens | What OTP does |
|---|---|
| Agent process crashes | Supervisor restarts it with a fresh state |
| Agent crashes repeatedly | Supervisor applies restart intensity limits and can escalate |
| External dependency times out | Agent process stays isolated; other agents are unaffected |
| Supervisor itself crashes | Its parent supervisor restarts the entire subtree |

You define the supervision strategy (`:one_for_one`, `:one_for_all`, `:rest_for_one`). OTP enforces it.

## Failure isolation in practice

Agent systems without process isolation share failure modes:

| Without isolation | With BEAM process isolation |
|---|---|
| One agent's exception crashes the entire pipeline | Exception is contained to one process |
| Memory leak in one agent degrades all agents | Each process has its own heap |
| Slow LLM response blocks other agents | Each process has its own mailbox and execution |
| Recovery requires custom retry/restart logic | OTP supervisor restarts automatically |

Jido's deterministic `cmd/2` model reinforces this: agent state transitions are pure. If a process crashes after `cmd/2` but before directive execution, the agent state is still consistent. The supervisor restarts the process, and work continues.

## What to explore next

- **Agent foundations:** [How Jido agents work](/features/how-agents-work)
- **Coordination:** [Agents that work together](/features/multi-agent-coordination)
- **Observability:** [Observe everything](/features/observe-everything)
- **Adoption path:** [Start small, grow safely](/features/start-small)
- **Reference docs:** [Architecture](/docs/reference/behavior-first-architecture)

## Get Building

Start two agents under a supervisor. Crash one and verify the other is unaffected. Then read [Observe everything](/features/observe-everything) to add telemetry to your agent lifecycle.
