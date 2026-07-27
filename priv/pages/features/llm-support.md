%{
  title: "Any model, any provider",
  category: :features,
  description: "Jido works with OpenAI, Anthropic, Google, Mistral, and local models through the req_llm abstraction.",
  doc_type: :explanation,
  audience: :beginner,
  draft: false,
  order: 15
}
---
Jido does not lock you into a model provider. The `req_llm` package gives you a single interface to OpenAI, Anthropic, Google, Mistral, and local models. Swap providers by changing configuration, not code.

## At a glance

| Item | Summary |
|---|---|
| Best for | Teams evaluating model options, anyone building provider-agnostic agents |
| Core packages | [jido_ai](/ecosystem/jido_ai), [req_llm](/ecosystem/req_llm), [llm_db](/ecosystem/llm_db) |
| Supported providers | OpenAI, Anthropic, Google Gemini, Mistral, local models (Ollama, LM Studio) |
| Package status | `req_llm` (Stable), `llm_db` (Stable), `jido_ai` (Beta) |
| Key idea | Your agent code stays the same. The model is configuration, not architecture. |

## Supported providers

| Provider | Adapter | Status |
|---|---|---|
| OpenAI | `ReqLLM.Adapters.OpenAI` | Stable |
| Anthropic | `ReqLLM.Adapters.Anthropic` | Stable |
| Google Gemini | `ReqLLM.Adapters.Google` | Stable |
| Mistral | `ReqLLM.Adapters.Mistral` | Stable |
| Local (Ollama, LM Studio) | `ReqLLM.Adapters.OpenAI` (compatible API) | Stable |

All adapters implement the same interface. Your agent code does not change when you switch providers.

## Provider-agnostic code with req_llm

`req_llm` wraps provider differences behind a consistent request/response contract:

```elixir
# Works with any provider. Just change the model string.
{:ok, response} = ReqLLM.chat(:my_client, [
  %{role: "user", content: "Summarize this support ticket"}
], model: "anthropic/claude-sonnet-4-20250514")

# Same code, different provider
{:ok, response} = ReqLLM.chat(:my_client, [
  %{role: "user", content: "Summarize this support ticket"}
], model: "openai/gpt-4o")
```

No adapter swapping, no interface changes. The model string determines the provider.

## Swap models without changing agent code

Define your agent once. Change the model in configuration:

```elixir
defmodule MyApp.SupportAgent do
  use Jido.AI.Agent,
    name: "support_agent",
    description: "Customer support agent",
    tools: [MyApp.Tools.OrderLookup],
    system_prompt: "You help customers with order questions."
end

# Production: use Anthropic
config :my_app, MyApp.SupportAgent,
  model: "anthropic/claude-sonnet-4-20250514"

# Development: use a local model
config :my_app, MyApp.SupportAgent,
  model: "ollama/llama3"
```

Your agent logic, tools, and system prompt stay identical. Only the model changes.

## Model capability tracking with llm_db

`llm_db` maintains a database of model metadata: context windows, pricing, supported features. Use it to make runtime decisions about which model to use:

```elixir
# Find models that support function calling with at least 100k context
models = LlmDB.list(
  capabilities: [:function_calling],
  min_context: 100_000
)
```

This is useful when you need to route requests to different models based on task requirements or cost constraints.

## What to explore next

- **Agent foundations:** [How Jido agents work](/features/how-agents-work)
- **Tools:** [Give agents tools](/features/tools)
- **Coordination:** [Agents that work together](/features/multi-agent-coordination)
- **BEAM advantages:** [BEAM for AI builders](/features/beam-for-ai-builders)

## Get Building

Pick a provider, configure `req_llm`, and connect it to an agent. Then read [Give agents tools](/features/tools) to give your agent capabilities beyond conversation.
