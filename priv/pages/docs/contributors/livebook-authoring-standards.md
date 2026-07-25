%{
  title: "Livebook Authoring Standards",
  description: "Canonical format for contributor-authored runnable Livebook docs, including setup cells, runtime pattern, metadata, and drift tests.",
  category: :docs,
  legacy_paths: [],
  tags: [:docs, :contributors, :livebook, :quality],
  order: 12,
  menu_label: "Livebook Standards",
  audience: :beginner,
  doc_type: :reference
}
---

Use this page as the canonical standard when writing or reviewing `.livemd` tutorials, cookbook recipes, and other runnable docs notebooks in Jido. [Package Quality Standards](/docs/contributors/package-quality-standards) defines the package bar. This page defines the notebook bar.

## Fast Path Checklist

- [ ] The notebook is self-contained and runnable without requiring another guide for setup
- [ ] The first runnable cells include `Mix.install(...)` and `Logger.configure(level: :warning)`
- [ ] Every docs Livebook includes the temporary `Code.put_compiler_option(:docs, false)` compatibility line until the upstream Jido generated-doc fix ships
- [ ] Provider credentials are checked in a dedicated cell with a beginner-safe fallback
- [ ] Livebook runtime setup uses `Jido.start()` and `Jido.start_agent(Jido.default_instance(), ...)`
- [ ] The main path uses stable public APIs only
- [ ] The first example shows success before inspection or debugging
- [ ] Runnable notebooks include `livebook:` metadata and a matching drift test under `test/livebooks/docs`
- [ ] Runnable notebooks declare `tested_with` package/version pairs so version context renders on the page

## Canonical Notebook Shape

For beginner-friendly notebooks, use this sequence:

1. Frontmatter metadata
2. Setup cell
3. Credentials cell
4. Runtime start cell
5. Module definition cell
6. One success example
7. One inspection or verification example
8. Advanced internals only after the main path works

Do not make readers learn strategy internals before they can run the first successful example.

## Setup Cell

Every runnable notebook should start with a complete dependency cell:

```elixir
Mix.install([
  {{mix_dep:jido}},
  {{mix_dep:jido_ai}},
  {{mix_dep:req_llm}}
])

Logger.configure(level: :warning)

# Livebook imports can execute generated docs as doctests.
# Disable compiler docs until the current Jido Hex release drops the invalid signal_types/0 example.
Code.put_compiler_option(:docs, false)
```

If the notebook needs more packages, add them here rather than assuming previous setup cells from another notebook.

This is a temporary site-wide compatibility rule. Keep it in every `.livemd` page on the docs site until the upstream `jido` fix for generated doctest-style docs is released and adopted.

## Credentials Cell

For provider-backed beginner notebooks, prefer a friendly `configured?` gate instead of crashing immediately:

```elixir
openai_key = System.get_env("LB_OPENAI_API_KEY") || System.get_env("OPENAI_API_KEY")

configured? =
  if is_binary(openai_key) do
    ReqLLM.put_key(:openai_api_key, openai_key)
    true
  else
    IO.puts("Set OPENAI_API_KEY as a Livebook Secret or environment variable to run this notebook.")
    false
  end
```

This pattern keeps the notebook readable for beginners who are still wiring credentials. Use a hard failure only when the notebook is explicitly external-only or advanced enough that a partial run is not useful.

## Runtime Pattern For Livebook

For beginner notebooks, prefer the default Jido runtime:

```elixir
{:ok, _} = Jido.start()

runtime = Jido.default_instance()
agent_id = "chat-demo-#{System.unique_integer([:positive])}"

{:ok, pid} = Jido.start_agent(
  runtime,
  MyApp.ChatAgent,
  id: agent_id
)
```

This is the canonical Livebook pattern because it is rerunnable and avoids named-runtime confusion. `Jido.AgentServer.start_link/1` is still fine in application code and targeted tests, but beginner notebooks should not depend on the reader understanding custom runtime naming first.

## Main Path APIs

Use stable public APIs in the main path:

- `Jido.Exec.run/2` for action recipes
- `ask/3`, `await/2`, and `ask_sync/3` for agent tutorials
- `Jido.AgentServer.status/1` for inspection and verification

Keep these out of the critical path unless the notebook is explicitly advanced:

- strategy command atoms such as `:ai_react_start`
- lifecycle hooks like `on_before_cmd/2` and `on_after_cmd/3`
- `request_transformer`
- manual prompt-history reconstruction
- LiveView integration
- raw internal state layouts beyond a narrow inspection example

The rule is simple: readers should get one successful run before they are asked to learn internals.

## Success First, Inspection Second

The first runnable example should prove the notebook works. Only after that should the notebook show state inspection or debugging.

For an AI chat notebook, the first two cells after setup should usually be:

1. start one agent
2. ask one or two questions on the same `pid`

Then add one inspection cell, for example:

```elixir
{:ok, status} = Jido.AgentServer.status(pid)

status.snapshot.details.conversation
```

That demonstrates multi-turn state without forcing the reader to intercept lifecycle hooks first.

## Livebook Metadata

Runnable notebooks should include Livebook-oriented metadata in the frontmatter:

```elixir
%{
  tags: [:docs, :guides, :livebook],
  tested_with: %{jido: "2.3.2", jido_ai: "2.2.0", req_llm: "1.17.1"},
  livebook: %{
    runnable: true,
    required_env_vars: ["OPENAI_API_KEY"],
    requires_network: true,
    setup_instructions: "Set OPENAI_API_KEY or LB_OPENAI_API_KEY before running the request cell."
  }
}
```

Use `required_env_vars` and `setup_instructions` to make external requirements explicit instead of burying them deep in the prose.

`tested_with` is a map of package/version pairs the notebook was validated against. List every package the notebook installs (commonly `jido`, `jido_ai`, and `req_llm`) and pin the exact resolved version from `mix.lock`, not the version constraint. The docs shell renders it as "Tested with" in the page header so a reader can tell whether a notebook matches the packages they already have. Pair it with a `last_validated` ISO date when you record a validation run.

## Drift Tests

Every runnable notebook should have one matching drift test under `test/livebooks/docs`.

Use `AgentJido.LivebookCase` and keep the test small:

```elixir
defmodule AgentJido.Livebooks.Docs.MyNotebookLivebookTest do
  use AgentJido.LivebookCase,
    livebook: "priv/pages/docs/learn/my-notebook.livemd",
    timeout: 120_000,
    external: true,
    required_any_env: ["OPENAI_API_KEY", "LB_OPENAI_API_KEY"]

  test "runs cleanly" do
    assert :ok = run_livebook()
  end
end
```

The standard is one runnable notebook, one drift test.

## Non-Runnable Docs

Some docs pages may remain explanatory rather than runnable. If a notebook is not meant to run end to end:

- mark it explicitly with `livebook: %{runnable: false}`
- keep it in the reference-only coverage list until it is promoted to runnable
- say so clearly in the prose when that helps the reader
- still include the temporary compiler-docs compatibility line somewhere near the top of the page if it may be imported into Livebook
- do not present it as a beginner tutorial
- do not add a drift test that implies full runnability

Explanatory pages are acceptable. Ambiguous pages are not.

## Next Steps

- [Contributing](/docs/contributors/contributing) - see where docs and example work fits into the contribution flow
- [Package Quality Standards](/docs/contributors/package-quality-standards) - pair notebook standards with the broader contributor quality bar
- [Community](/community) - discuss gaps and proposed notebook changes in public
