%{
  description: "Glossary, configuration, telemetry events, and API documentation links for the Jido ecosystem.",
  title: "Reference",
  category: :docs,
  legacy_paths: [],
  tags: [:docs, :reference],
  order: 40
}
---

## Reference pages

- [Behavior-first architecture](/docs/reference/behavior-first-architecture) - design rationale for Jido's core contracts and why the runtime is organized around behaviors instead of implementation style
- [Configuration](/docs/reference/configuration) - all config keys with defaults and examples for `jido` and `jido_ai`
- [Telemetry and observability](/docs/reference/telemetry-and-observability) - every telemetry event, metric definition, and log level control
- [ReqLLM and LLMDB](/docs/reference/req-llm-and-llmdb) - provider-agnostic LLM client and model metadata database
- [Migrations and Upgrade Paths](/docs/reference/migrations-and-upgrade-paths) - the supported upgrade range for `jido`, `jido_ai`, and `req_llm`, the cross-package constraint each move must satisfy, and the order to upgrade in
- [Glossary](/docs/reference/glossary) - canonical definitions for every Jido term

## API documentation (HexDocs)

Full module docs, typespecs, and function references live on HexDocs:

| Package | Description | Docs |
| --- | --- | --- |
| `jido` | Core agent framework — agents, actions, signals, directives, runtime | [hexdocs.pm/jido](https://hexdocs.pm/jido) |
| `jido_ai` | LLM integration — model aliases, reasoning strategies, tool management | [hexdocs.pm/jido_ai](https://hexdocs.pm/jido_ai) |
| `jido_action` | Standalone action framework — schema-validated composable operations | [hexdocs.pm/jido_action](https://hexdocs.pm/jido_action) |
| `jido_signal` | CloudEvents-based signal system — typed event envelopes and routing | [hexdocs.pm/jido_signal](https://hexdocs.pm/jido_signal) |
| `jido_browser` | Browser automation — navigation, extraction, forms, and screenshots | [hexdocs.pm/jido_browser](https://hexdocs.pm/jido_browser) |
| `req_llm` | HTTP client for LLM providers — retries, rate limiting, streaming | [hexdocs.pm/req_llm](https://hexdocs.pm/req_llm) |
| `llmdb` | LLM model metadata database — capabilities, pricing, and context limits | [llmdb.xyz](https://llmdb.xyz) |

For package overviews and installation instructions, see the [Ecosystem page](/ecosystem).

## Next steps

- [Concepts](/docs/concepts) - understand the mental models behind Jido's primitives
- [Guides](/docs/guides) - step-by-step walkthroughs for common tasks
