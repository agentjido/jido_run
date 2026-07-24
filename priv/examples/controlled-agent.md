%{
  title: "Controlled Agent",
  description: "One supervised Jido Agent that proves the complete control path in a single run: who initiated work, what was allowed, what happened, and how failure was handled.",
  tags: ["authorization", "control", "supervision", "ops-governance", "governance", "l2"],
  category: :production,
  emoji: "🛡",
  related_resources: [
    %{
      path: "/docs/operations/security-and-governance",
      kind: "Next",
      description: "The full operational-control model and where each boundary lives."
    },
    %{
      path: "/examples/failure-drill-agent",
      kind: "Concept",
      description: "Focus on the supervised restart boundary in isolation."
    },
    %{
      path: "/docs/concepts/persistence",
      kind: "Guide",
      description: "Recover approved state across a restart with snapshots and journals."
    }
  ],
  source_files: [
    "lib/agent_jido/demos/controlled_agent/controlled_agent.ex",
    "lib/agent_jido/demos/controlled_agent/approve_action.ex",
    "lib/agent_jido/demos/controlled_agent/authorization_plugin.ex",
    "lib/agent_jido/demos/controlled_agent/supervisor.ex",
    "lib/agent_jido_web/examples/controlled_agent_live.ex"
  ],
  live_view_module: "AgentJidoWeb.Examples.ControlledAgentLive",
  difficulty: :intermediate,
  status: :live,
  sort_order: 12,
  scenario_cluster: :ops_governance,
  wave: :l2,
  journey_stage: :evaluation,
  content_intent: :tutorial,
  capability_theme: :reliability_architecture,
  evidence_surface: :runnable_example,
  demo_mode: :real,
  outcome: "One supervised agent proves the complete control path — who initiated work, what was allowed, what happened, and how failure was handled — in a single run.",
  packages: ["jido"],
  package_maturity: "Beta",
  prerequisites: ["Elixir 1.18+", "OTP 27+", "Jido installed"],
  expected_result: "An allowed principal runs the protected Action; an unauthorized principal is denied before it runs; crashing the process restarts it under supervision. No API key required.",
  run_command: "Run the interactive demo on /examples/controlled-agent, or: mix test test/agent_jido/demos/controlled_agent_test.exs"
}
---

## What you'll learn

- How one supervised `AgentServer` answers all four control questions in a single run
- How a fail-closed `prepare_action/3` hook denies unauthorized work **before** it runs
- How incoming Signals carry the principal that initiated each piece of work
- How OTP supervision contains a process crash and restarts the agent

## How it works

This is the integrated controlled-Agent example the home operational-control
section routes to. Each control question the section asks — *who initiated
work, what was allowed, what happened, how failure was handled* — is answered by
one part of this single agent, which you can run in the interactive demo above.

### The complete control path

The agent holds an `approved_count` counter that only a fail-closed
authorization hook can advance. Run the demo and follow each step to the
control question it proves:

| Control question | What this example proves |
|---|---|
| **Who initiated work** | Every `work.approve` Signal carries a `source` principal. The hook inspects it, so each piece of work is attributable to the caller, not the agent. |
| **What was allowed** | `AuthorizationPlugin.prepare_action/3` is fail-closed: the Action runs only when the principal is in the allowlist (`["alice"]`). Run as `mallory` and the Action never executes. |
| **What happened** | The counter and the control log record exactly what ran — approved work increments, denied work is rejected with a reason — and Signals carry correlation IDs you can follow. |
| **How failure was handled** | The `AgentServer` runs under an OTP supervisor with a `:permanent` restart strategy. Crash it and supervision restarts a fresh process; the counter resets, showing exactly what supervision recovers (the process) and what it does not (in-memory state). |

### The fail-closed hook

The authorization hook runs before the Action. A missing or unknown principal
returns `{:error, :unauthorized}` and the protected effect is never reached:

```elixir
@impl Jido.Plugin
def prepare_action(%Signal{source: source}, _action_arg, context) do
  allowed = allowed_principals(context)

  if is_binary(source) and source in allowed do
    {:ok, %{}}
  else
    {:error, :unauthorized}
  end
end
```

### The supervised lifecycle

The supervisor starts the AgentServer as a `:permanent` child, so OTP
supervision restarts the process whenever it dies — the recovery the failure
question rests on:

```elixir
children = [
  {Jido.AgentServer, jido: AgentJido.Jido, agent: ControlledAgent, id: agent_id}
]

Supervisor.init(children, strategy: :one_for_one, max_restarts: 1000, max_seconds: 1)
```

## Key concepts

**The hook is an integration point, not an IAM product.** Jido does not
authenticate callers. Verified identity is established at the authentication
and IAM boundary you put in front of Jido, and the principal it issues is what
each incoming Signal carries. The hook decides whether that principal may run
the Action — your application supplies the policy decision. See the
[security and governance](/docs/operations/security-and-governance) page for the
full model.

**Restart restores the process, not application state.** Approved work lives in
process memory, so a crash resets the counter. When work must survive a
restart, persist agent state and make Actions idempotent — see
[persistence](/docs/concepts/persistence).
