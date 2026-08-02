%{
  title: "Give agents tools",
  category: :features,
  description: "How to define tools as Actions, attach them to agents, and validate tool I/O at execution boundaries.",
  doc_type: :explanation,
  audience: :beginner,
  draft: false,
  order: 12
}
---
Tools in Jido are Actions with metadata. An Action defines a typed input/output contract, and when you attach it to an agent as a tool, the LLM can decide when to call it. Validation happens at the boundary, before execution, not deep in your business logic.

## At a glance

| Item | Summary |
|---|---|
| Best for | Developers adding external capabilities to agents |
| Core packages | [jido](/ecosystem/jido), [jido_action](/ecosystem/jido_action), [jido_ai](/ecosystem/jido_ai) |
| Package status | `jido` (Beta), `jido_action` (Beta), `jido_ai` (Beta) |
| First proof path | Define a tool → attach it to an agent → watch the agent use it |
| Key idea | Tools are typed Actions. The LLM chooses when to call them; schemas enforce what goes in and out. |

## A tool that calls an API

```elixir
defmodule MyApp.Tools.Weather do
  use Jido.Action,
    name: "get_weather",
    description: "Look up current weather for a city",
    schema: [
      city: [type: :string, required: true, doc: "City name to look up"]
    ]

  @impl true
  def run(params, _context) do
    case MyApp.WeatherAPI.fetch(params.city) do
      {:ok, data} -> {:ok, %{temperature: data.temp, conditions: data.summary}}
      {:error, reason} -> {:error, reason}
    end
  end
end
```

The `schema` block declares what the tool accepts. Jido validates inputs against it before `run/2` is called. If the LLM passes `%{city: 123}`, it fails at the boundary with a clear error.

## A tool that queries a database

```elixir
defmodule MyApp.Tools.OrderLookup do
  use Jido.Action,
    name: "lookup_order",
    description: "Find an order by its ID",
    schema: [
      order_id: [type: :string, required: true, doc: "The order identifier"]
    ]

  @impl true
  def run(params, _context) do
    case MyApp.Orders.get(params.order_id) do
      nil -> {:ok, %{found: false}}
      order -> {:ok, %{found: true, status: order.status, eta: order.estimated_delivery}}
    end
  end
end
```

Same pattern: declare inputs, validate at the boundary, return structured output.

## Attaching tools to an agent

Tools are declared when you define the agent:

```elixir
defmodule MyApp.SupportAgent do
  use Jido.AI.Agent,
    name: "support_agent",
    description: "Customer support agent",
    tools: [MyApp.Tools.Weather, MyApp.Tools.OrderLookup],
    system_prompt: "You help customers with order and delivery questions."
end
```

The agent now has two tools. When a user asks about their order, the LLM sees the tool descriptions, picks the right one, and Jido validates the call before executing it.

## Why typed tools matter

| Without typed tools | With typed tools |
|---|---|
| LLM passes malformed data, runtime crashes deep in business logic | Invalid inputs rejected at the schema boundary with clear errors |
| Tool behavior is opaque; you debug by reading prompts | Tool contracts are inspectable and independently testable |
| Adding a tool means hoping the LLM figures out the interface | Tool descriptions and schemas guide the LLM explicitly |

You can test any tool in isolation without running an agent or calling an LLM:

```elixir
{:ok, result} = MyApp.Tools.OrderLookup.run(%{order_id: "ORD-123"}, %{})
assert result.found == true
```

## What to explore next

- **Agent foundations:** [How Jido agents work](/features/how-agents-work)
- **Model support:** [Any model, any provider](/features/llm-support)
- **Coordination:** [Agents that work together](/features/multi-agent-coordination)
- **Hands-on:** [Your first agent](/docs/getting-started/first-agent)

## Get Building

Define one tool as an Action, attach it to an agent, and test it in isolation. Then read [Any model, any provider](/features/llm-support) to connect your agent to an LLM.
