%{
  title: "Start small, grow safely",
  category: :features,
  description: "Add one agent to your existing Elixir app. No rewrite, no platform migration. Each package composes without lock-in.",
  doc_type: :explanation,
  audience: :beginner,
  draft: false,
  order: 45
}
---
You do not need to rewrite your application to use Jido. Add one agent to your existing Elixir supervision tree. If it works, expand. If it does not, remove it. Each Jido package composes independently. There is no platform migration.

## At a glance

| Item | Summary |
|---|---|
| Best for | Teams with existing Elixir apps, architects evaluating adoption risk |
| Core packages | [jido](/ecosystem/jido), [jido_action](/ecosystem/jido_action) |
| Package status | `jido` (Beta), `jido_action` (Beta) |
| First proof path | Add one agent to your existing app → validate it works → expand scope |
| Key idea | One agent, one supervision tree, zero rewrite. Expand only after each layer is stable. |

## Add one agent to an existing app

Your application already has a supervision tree. Add an agent to it:

```elixir
# In your existing application.ex
def start(_type, _args) do
  children = [
    # Your existing children
    MyAppWeb.Endpoint,
    MyApp.Repo,

    # Add one Jido agent
    {Jido.AgentServer,
     id: :support_agent,
     agent: MyApp.SupportAgent,
     name: :support_agent}
  ]

  opts = [strategy: :one_for_one, name: MyApp.Supervisor]
  Supervisor.start_link(children, opts)
end
```

That is the entire integration. Your existing application code, database, and web layer are unchanged. The agent runs alongside them under the same supervision tree.

## Composable package architecture

Jido is not one monolithic dependency. Each package adds a specific capability layer, and you adopt them independently:

| Layer | Packages | What it adds |
|---|---|---|
| Core runtime | `jido`, `jido_action`, `jido_signal` | Supervised agents, typed actions, event routing |
| Intelligence | `jido_ai`, `req_llm`, `llm_db` | LLM integration, provider abstraction, model metadata |
| Advanced orchestration | `jido_behaviortree`, `jido_runic` | Strategy-driven decision control |
| Integration bridges | `ash_jido`, `jido_messaging` | Data resource and messaging system bridges |

Start with core runtime. Add intelligence when you need LLM capabilities. Add orchestration when your workflows require it. Each layer works without the ones above it.

## No lock-in

Every architectural decision in Jido is reversible:

| Concern | How Jido avoids lock-in |
|---|---|
| **Agent logic** | Agents are plain Elixir modules with structs. No proprietary runtime required to test them. |
| **Actions** | Actions are standalone modules with `run/2`. They work outside Jido as regular functions. |
| **Model provider** | `req_llm` is a thin HTTP abstraction. Switch providers by changing a config string. |
| **Package scope** | Remove any Jido package and the rest of your app still compiles and runs. |

You can evaluate Jido with a single `mix deps.get` and remove it with a single deletion from `mix.exs`. No migration scripts, no data format changes, no vendor lock.

## What to explore next

- **Agent foundations:** [How Jido agents work](/features/how-agents-work)
- **Tools:** [Give agents tools](/features/tools)
- **Fault tolerance:** [Agents that self-heal](/features/agents-that-self-heal)
- **BEAM advantages:** [BEAM for AI builders](/features/beam-for-ai-builders)
- **Reference docs:** [Architecture](/docs/reference/behavior-first-architecture)

## Get Building

Add one `Jido.AgentServer` to your existing supervision tree. Verify it starts and responds. Then read [How Jido agents work](/features/how-agents-work) to understand the model behind it.
