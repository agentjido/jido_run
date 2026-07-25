%{
  description: "Provider-agnostic LLM HTTP client and model metadata database for the Jido ecosystem.",
  title: "ReqLLM and LLMDB",
  category: :docs,
  legacy_paths: [],
  tags: [:docs, :reference],
  order: 295
}
---

`req_llm` and `llmdb` are standalone packages maintained alongside Jido. They work independently of the agent framework — you can use them in any Elixir project — but they form the LLM infrastructure layer that `jido_ai` builds on.

## ReqLLM

A [Req](https://hexdocs.pm/req) plugin that provides a unified interface for calling LLM APIs across providers. Instead of writing provider-specific HTTP code, you configure a model string like `"anthropic:claude-sonnet-4-20250514"` or `"openai:gpt-4o"` and ReqLLM handles the rest.

**What it handles:**

- **Provider abstraction** — one API for Anthropic, OpenAI, Google, Mistral, Groq, Ollama, and others
- **Automatic retries** — configurable retry logic with exponential backoff for transient failures
- **Rate limiting** — built-in rate limit handling with provider-specific backoff
- **Streaming** — unified streaming interface across providers that support SSE
- **Request/response normalization** — consistent message format regardless of provider quirks

**Basic usage:**

```elixir
# Add to mix.exs
{{mix_dep:req_llm}}

# Make a request
req = Req.new() |> ReqLLM.attach()

{:ok, response} = ReqLLM.chat(req,
  model: "anthropic:claude-sonnet-4-20250514",
  messages: [%{role: "user", content: "Hello"}]
)
```

**In the Jido ecosystem**, `jido_ai` uses ReqLLM under the hood for all LLM communication. Model aliases like `:fast` and `:capable` resolve to ReqLLM model strings. See [Configuration](/docs/reference/configuration) for alias setup.

→ [ReqLLM HexDocs](https://hexdocs.pm/req_llm) · [GitHub](https://github.com/agentjido/req_llm)

## LLMDB

A model metadata database that tracks capabilities, pricing, context window sizes, and feature support across LLM providers. Available as both an Elixir library and a web interface at [llmdb.xyz](https://llmdb.xyz).

**What it provides:**

- **Model lookup** — query models by provider, capability, or feature support
- **Context limits** — max input tokens, max output tokens, and context window sizes
- **Pricing data** — per-token costs for input and output across providers
- **Feature flags** — which models support tool calling, vision, streaming, JSON mode, etc.
- **Regularly updated** — model data is maintained as the provider landscape changes

**Basic usage:**

```elixir
# Add to mix.exs
{:llmdb, "~> 0.1"}

# Look up a model
model = LLMDB.get("anthropic:claude-sonnet-4-20250514")
model.context_window   #=> 200_000
model.max_output        #=> 64_000

# Find models by capability
LLMDB.list(provider: :anthropic, supports: :tool_calling)
```

**In the Jido ecosystem**, LLMDB provides the model metadata that `jido_ai` uses when resolving aliases and validating token budgets.

→ [LLMDB web interface](https://llmdb.xyz) · [GitHub](https://github.com/agentjido/llmdb)

## Control surface

These LLM calls are the surface that `jido_ai` control plugins gate. The table names each AI control point. Jido supplies optional scoped controls — tool allowlists, effect policies, prompt policies, and quotas — but a complete authorization or cost-governance product is an application concern. ReqLLM handles transient transport failure; fallback policy and circuit breakers are an application duty. See [Security and governance](/docs/operations/security-and-governance) for the full control-point map.

| Hook | Input | Decision | Output | Failure behavior | Evidence |
| --- | --- | --- | --- | --- | --- |
| `jido_ai` tool allowlist | tool-call request | Allow or reject the tool | Permitted tool or rejection | A disallowed tool is rejected before it runs | Reject reason; tool never executes |
| `jido_ai` effect policy | proposed effect | Allow or reject the effect | Permitted effect or rejection | Effect rejected before execution | Policy decision |
| `jido_ai` prompt / quota policy | request and token budget | Allow or throttle | Proceed or deny | Request denied when the budget is exceeded | Deny plus remaining budget state |
| ReqLLM retry / backoff | LLM HTTP call | Retry transient failures | Response | Provider failure routes to fallback or circuit breaker (application duty) | Retry and timeout events (transport, not authorization) |

## Next steps

- [Configuration](/docs/reference/configuration) - set up model aliases and LLM defaults
- [Telemetry and observability](/docs/reference/telemetry-and-observability) - monitor LLM call metrics
