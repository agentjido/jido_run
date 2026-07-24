%{
  title: "Failure Drill Agent",
  description: "A supervised Jido AgentServer you can crash on purpose. Watch OTP supervision restart the process and observe exactly what is recovered — and what is lost without persistence.",
  tags: ["supervision", "restart", "reliability", "ops-governance", "l2"],
  category: :production,
  emoji: "🧯",
  related_resources: [
    %{
      path: "/docs/concepts/persistence",
      kind: "Next",
      description: "Recover state across restarts with snapshots, journals, and rehydration."
    },
    %{
      path: "/features/start-small",
      kind: "Concept",
      description: "Add one supervised agent to an existing Elixir application."
    },
    %{
      path: "/docs/getting-started/first-agent",
      kind: "Guide",
      description: "Define typed state and run your first command.",
      include_livebook: true
    }
  ],
  source_files: [
    "lib/agent_jido/demos/failure_drill/failure_drill_agent.ex",
    "lib/agent_jido/demos/failure_drill/actions/tick_action.ex",
    "lib/agent_jido/demos/failure_drill/supervisor.ex",
    "lib/agent_jido_web/examples/failure_drill_agent_live.ex"
  ],
  live_view_module: "AgentJidoWeb.Examples.FailureDrillAgentLive",
  difficulty: :intermediate,
  status: :live,
  sort_order: 11,
  scenario_cluster: :ops_governance,
  wave: :l2,
  journey_stage: :evaluation,
  content_intent: :tutorial,
  capability_theme: :reliability_architecture,
  evidence_surface: :runnable_example,
  demo_mode: :real,
  outcome: "A supervised AgentServer that crashes on demand and is restarted by OTP supervision.",
  packages: ["jido"],
  package_maturity: "Beta",
  prerequisites: ["Elixir 1.18+", "OTP 27+", "Jido installed"],
  expected_result: "Crashing the process restarts it; the in-memory tick counter resets to 0. No API key required.",
  run_command: "Run the interactive demo on /examples/failure-drill-agent, or: mix test test/agent_jido/demos/failure_drill_agent_test.exs"
}
---

## What you'll learn

- How an `AgentServer` runs under OTP supervision
- What happens when a supervised AgentServer process is terminated
- What OTP supervision restarts (a fresh process) and what it does not (in-memory state)
- Why persistence and idempotent Actions matter for work that must survive a restart

## How it works

An **Agent** is immutable data; an **AgentServer** is the process that runs it.
This example starts an `AgentServer` under a supervisor with a `:permanent`
restart strategy, then lets you crash that process on purpose.

### The supervised process

The supervisor starts the AgentServer as a `:permanent` child. Because
`Jido.AgentServer.child_spec/1` sets `restart: :permanent`, OTP supervision
automatically starts a replacement whenever the process dies:

```elixir
children = [
  {Jido.AgentServer, jido: AgentJido.Jido, agent: FailureDrillAgent, id: agent_id}
]

Supervisor.init(children, strategy: :one_for_one, max_restarts: 1000, max_seconds: 1)
```

### The drill

The agent keeps a `ticks` counter in process state. Tick it a few times, then
crash it. The drill terminates the process directly — the kind of process-level
failure (a bug in a non-action callback, an OOM, a linked port dying) that OTP
supervision exists to recover from. The supervisor restarts the AgentServer and
the counter resets to `0`.

> Jido isolates Action errors. A raise inside an Action's `run/2` is caught and
> returned as `{:error, _}` — it does not crash the AgentServer. This drill
> instead terminates the process so you can see supervision recover it.

## Key concepts

**Supervision is a boundary.** OTP restarts the *process*, not its memory. State
that lived only in the process is gone. The restart counter you see is observed
by the LiveView — a *different* process — so it survives the crash.

**Durability is a separate decision.** When work must survive a restart, snapshot
agent state and make Actions idempotent. See the persistence concept page for
checkpoints, journals, and rehydration.
