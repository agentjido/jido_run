# Livebook Drift Tests

Dedicated ExUnit tests for docs livebooks live under `test/livebooks/docs`.

## Run all livebook tests

```bash
mix test test/livebooks --only livebook
```

## Run one livebook test file

```bash
mix test test/livebooks/docs/weather_tool_response_livebook_test.exs
```

## External livebooks

Tests tagged with `:livebook_external` require environment configuration.
For the external OpenAI Livebooks, set one of:

- `OPENAI_API_KEY`
- `LB_OPENAI_API_KEY`

If neither env var is present, the test is skipped.

Run the first LLM tutorial release gate locally with:

```bash
INCLUDE_LIVEBOOK_TESTS=true mix test \
  test/livebooks/docs/first_llm_agent_external_test.exs \
  --only livebook_external
```

The scheduled `External Livebook release gate` workflow runs the same test
with the `OPENAI_API_KEY` Actions secret. A configured provider error fails the
notebook and the workflow.

## Convention for new docs livebooks

For each new file in `priv/pages/docs/**/*.livemd`, add one matching
`*_livebook_test.exs` file under `test/livebooks/docs` with:

- `@moduletag :livebook`
- `use AgentJido.LivebookCase, livebook: "..."`
- one `"runs cleanly"` test using `run_livebook/0`
