%{
  title: "BEAM for AI builders",
  category: :features,
  description: "Why Elixir/OTP runtime semantics matter for long-lived AI workflows, including non-LLM workloads.",
  doc_type: :explanation,
  audience: :beginner,
  draft: false,
  order: 50
}
---
If your team is evaluating Jido from Python or TypeScript, this is the core point: Jido is the Elixir framework for long-running agent systems, and its AgentServer and OTP lifecycle give that framework a runtime-first architecture. LLM integration is optional, not foundational.

## At a glance

| Item | Summary |
|---|---|
| Best for | Python/TS evaluators, AI platform teams, architects reviewing runtime tradeoffs |
| Core runtime packages | [jido](/ecosystem/jido), [jido_action](/ecosystem/jido_action), [jido_signal](/ecosystem/jido_signal) |
| Optional intelligence layer | [jido_ai](/ecosystem/jido_ai), [req_llm](/ecosystem/req_llm), [llm_db](/ecosystem/llm_db) |
| Package status | Core packages are Beta; `req_llm` and `llm_db` are Stable; `jido_ai` is Beta |
| First proof path | [Counter Agent](/examples/counter-agent) (non-LLM) -> [First LLM agent](/docs/getting-started/first-llm-agent) (LLM add-on) |

## The runtime argument

As AI workflows become long-lived and multi-step, runtime semantics become more important than model prompt quality alone.

Elixir/OTP gives Jido three practical advantages:

- Process isolation for failure containment.
- Supervision for explicit recovery semantics.
- Concurrency model suited to many long-lived, coordinated workloads.

## Model-agnostic architecture map

| Workload type | Recommended package baseline | Why |
|---|---|---|
| Deterministic, non-LLM orchestration | `jido` + `jido_action` + `jido_signal` | Explicit state, typed actions, event routing |
| Tool-using workflow with optional model calls | baseline + `jido_ai` + `req_llm` | Keep runtime boundaries, add model layer as needed |
| Model-provider flexibility and cost controls | baseline + `req_llm` + `llm_db` | Stable provider abstraction + model metadata |
| Advanced decision orchestration | baseline + `jido_behaviortree` or `jido_runic` | Strategy-level control for specific workflow shapes |

## Proof: non-LLM runtime behavior is first-class

```elixir
alias AgentJido.Demos.DemandTrackerAgent
alias AgentJido.Demos.Demand.HeartbeatAction

schedules = DemandTrackerAgent.plugin_schedules()
Enum.any?(schedules, &(&1.signal_type == "heartbeat.tick"))
#=> true

agent = DemandTrackerAgent.new()
{agent, directives} = DemandTrackerAgent.cmd(agent, HeartbeatAction)

{agent.state.ticks, Enum.any?(directives, &match?(%Jido.Agent.Directive.Emit{}, &1))}
```

Expected result:

```
{1, true}
```

This is runtime coordination and scheduling behavior with no required LLM dependency.

## Tradeoffs and non-goals

- Jido optimizes for operational control, not minimal first-demo code.
- Teams new to Elixir/OTP should budget onboarding time.
- Optional strategy and integration packages have mixed maturity and should be evaluated deliberately.

## What to explore next

- **Architecture contrast:** [Jido vs framework-first stacks](/features/jido-vs-framework-first-stacks)
- **Adoption planning:** [Start small, grow safely](/features/start-small)
- **Build path:** [Mixed-stack integration](/build/mixed-stack-integration)
- **Agent model foundations:** [BEAM-native agent model](/features/beam-native-agent-model)
- **Guides:** [Elixir developers](/docs/getting-started/elixir-developers), [Error handling and recovery](/docs/guides/error-handling-and-recovery)

## Get Building

Start with [Counter Agent](/examples/counter-agent) to validate non-LLM runtime behavior, then add the optional intelligence layer only where it improves a real workload.
