# LLM DB Builder Notes

## Use This Reference For

- Distilling provider and model metadata into an application-facing selector.
- Checking whether a task belongs in the catalog layer or in the inference client.
- Building examples that combine model lookup with later Jido or ReqLLM steps.

## Source Highlights

- The package positions itself as a database of LLMs, provider metadata, capabilities, and pricing.
- The useful builder workflow is selection and normalization, not chat orchestration.
- The package is a natural upstream source for routing decisions in `req_llm`, `jido`, or `jido_ai`.

## Implementation Heuristics

- Normalize once at the boundary, then keep internal lookups stable.
- Prefer explicit filter structs, maps, or typed options over ad hoc condition trees.
- Treat pricing and capability fields as advisory data unless the package documents stronger guarantees.
- Keep ranking logic inspectable so agent code can explain why a model was chosen.

## Narrowing Rules

- If the user asks to call an LLM API, switch to `req-llm` or a higher-level Jido skill after selection is complete.
- If the user asks for prompt strategy, message assembly, or tool calling, use `jido`, `jido_ai`, or package-specific workflow skills.

## Sources

- https://jido.run/ecosystem
- https://hexdocs.pm/llm_db/readme.html
- https://hex.pm/packages/llm_db
- https://github.com/agentjido/llmdb
