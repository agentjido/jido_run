%{
  title: "How Jido agents work",
  category: :features,
  description: "The mental model: agents are structs with state, actions, and tools, running inside supervised processes.",
  doc_type: :explanation,
  audience: :beginner,
  draft: false,
  order: 5
}
---
An agent in Jido is a struct that holds state, declares actions it can perform, and lists the tools it can use. That struct runs inside a supervised BEAM process (`Jido.AgentServer`) that manages its lifecycle: start, crash recovery, shutdown.

## At a glance

| Item | Summary |
|---|---|
| Best for | Developers new to Jido, anyone building their first agent |
| Core packages | [jido](/ecosystem/jido), [jido_ai](/ecosystem/jido_ai) |
| Package status | `jido` (Beta), `jido_ai` (Beta) |
| First proof path | Define an agent → start it supervised → send it a message |
| Key idea | Agents are data (structs), not magic. The runtime is separate from the logic. |

## Define an agent, start it, use it

```elixir
defmodule MyApp.SupportAgent do
  use Jido.AI.Agent,
    name: "support_agent",
    description: "Customer support agent",
    tools: [MyApp.Tools.KnowledgeBase, MyApp.Tools.TicketSystem],
    system_prompt: "You help customers resolve product issues."
end

# Start supervised
{:ok, pid} = Jido.AgentServer.start(agent: MyApp.SupportAgent)

# Ask it a question
MyApp.SupportAgent.ask(pid, "My order hasn't arrived")
```

That is the full lifecycle: define, supervise, interact.

## What an agent is made of

| Component | Role |
|---|---|
| **State** | A map of data the agent carries between transitions. You define the shape; Jido holds it. |
| **Actions** | Typed modules that transform agent state. Each action declares input/output schemas validated before execution. |
| **Tools** | Actions exposed to an LLM so it can decide when to call them. Tools are just actions with metadata. |

State, actions, and tools are declared at definition time. The agent struct is immutable between transitions, so you always know what you are inspecting.

## How the runtime fits

The agent struct holds logic and data. `Jido.AgentServer` handles everything else:

- **Supervision.** Each agent runs in its own BEAM process under OTP. If it crashes, the supervisor restarts it.
- **Message handling.** Signals arrive at the process, get routed to the right action, and produce state updates plus directives.
- **Isolation.** One agent crashing never affects another. Processes share nothing.

You write decision logic. The runtime handles lifecycle.

## How the pieces connect

```
┌─────────────────────────────────────┐
│           OTP Supervisor            │
│                                     │
│  ┌─────────────┐ ┌─────────────┐   │
│  │ AgentServer  │ │ AgentServer  │  │
│  │              │ │              │  │
│  │ ┌──────────┐ │ │ ┌──────────┐ │  │
│  │ │  Agent   │ │ │ │  Agent   │ │  │
│  │ │  struct  │ │ │ │  struct  │ │  │
│  │ │          │ │ │ │          │ │  │
│  │ │ • state  │ │ │ │ • state  │ │  │
│  │ │ • actions│ │ │ │ • actions│ │  │
│  │ │ • tools  │ │ │ │ • tools  │ │  │
│  │ └──────────┘ │ │ └──────────┘ │  │
│  └─────────────┘ └─────────────┘   │
└─────────────────────────────────────┘
```

Each `AgentServer` process owns exactly one agent struct. The supervisor watches all of them. State transitions happen inside the process. Side effects are expressed as directives, not inline calls.

## What to explore next

- **Tools in depth:** [Give agents tools](/features/tools)
- **Coordination:** [Agents that work together](/features/multi-agent-coordination)
- **Fault tolerance:** [Agents that self-heal](/features/agents-that-self-heal)
- **Model support:** [Any model, any provider](/features/llm-support)
- **Hands-on:** [Agent fundamentals](/docs/learn/agent-fundamentals)

## Get Building

Define your first agent, start it under a supervisor, and send it a message. Then read [Give agents tools](/features/tools) to expand what it can do.
