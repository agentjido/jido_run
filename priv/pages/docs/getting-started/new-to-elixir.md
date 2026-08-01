%{
  title: "I'm new to Elixir",
  description: "Essential Elixir context for Python, TypeScript, and JVM developers before building with Jido.",
  menu_label: "I'm new to Elixir",
  category: :docs,
  order: 10,
  tags: [:docs, :getting_started, :elixir],
  draft: false
}
---

## Why Jido uses Elixir

Jido chose Elixir for the same reasons telecom systems chose Erlang: agent workloads are long-running, concurrent, and need to recover from failure without downtime.

**Process isolation.** Every agent runs in its own lightweight process. If one agent crashes, nothing else is affected. The BEAM VM supports millions of these processes on a single machine - they are not OS threads.

**Supervision and recovery.** When a process fails, a supervisor automatically restarts it with a known good state. You define recovery policies declaratively. There is no try/catch-everything pattern to maintain.

**Concurrency without locks.** Processes communicate through message passing, never shared memory. There are no mutexes, no race conditions on shared state, and no deadlocks. This model was designed for systems that run continuously under load.

**Hot code upgrades.** You can deploy new code to a running system without dropping connections. For agent workloads that maintain long-lived conversations or state, this matters.

These are not theoretical advantages. The BEAM VM has powered telecom switches, messaging platforms, and real-time systems at scale for over 30 years. Jido inherits all of it.

## Elixir concepts you'll encounter

You don't need to master Elixir before starting. Here are the six concepts you'll see immediately in Jido code.

### Modules and functions

Elixir organizes code into modules. Functions live inside modules. There are no classes, no inheritance, and no `this`/`self`.

```elixir
defmodule MyApp.Greeter do
  def hello(name) do
    "Hello, #{name}!"
  end
end

MyApp.Greeter.hello("world")
#=> "Hello, world!"
```

### Pattern matching

The `=` operator is a match, not assignment. Elixir uses this everywhere - function heads, case statements, and destructuring.

```elixir
{:ok, value} = {:ok, 42}
value
#=> 42

{:ok, value} = {:error, "failed"}
#=> ** (MatchError) - the shapes don't match
```

Jido uses `{:ok, result}` and `{:error, reason}` tuples throughout its API. When you see `{:ok, agent}`, it means the operation succeeded and `agent` holds the result.

### The pipe operator

The `|>` operator passes the result of one expression as the first argument to the next function. It reads top to bottom like a pipeline.

```elixir
"  hello world  "
|> String.trim()
|> String.upcase()
|> String.split(" ")
#=> ["HELLO", "WORLD"]
```

### Structs and maps

Maps are key-value containers. Structs are maps with a fixed set of keys defined by a module.

```elixir
map = %{name: "Jane", role: :admin}
map.name
#=> "Jane"

defmodule User do
  defstruct [:name, :email]
end

user = %User{name: "Jane", email: "jane@example.com"}
```

Jido Agents are structs. When you see `agent.state.count`, you're reading a field from a struct.

### Mix

Mix is Elixir's build tool. It manages dependencies, runs tests, and compiles code. It is comparable to npm, pip, or Maven.

```shell
mix new my_app        # create a new project
mix deps.get          # install dependencies
mix compile           # compile the project
mix test              # run tests
iex -S mix            # start an interactive session with your project loaded
```

### Processes

Elixir processes are lightweight units of concurrency managed by the BEAM VM. You don't need to understand process internals to use Jido - the framework abstracts process management through `AgentServer`. But it helps to know that when Jido "starts" an agent, it spawns a BEAM process that the supervisor can restart on failure.

## Translating from other languages

If you're coming from Python, TypeScript, or a JVM language, this table maps familiar concepts to their Elixir equivalents:

| Your language | Elixir | Notes |
|---|---|---|
| `class MyAgent` | `defmodule MyApp.Agent` | No inheritance; use `use` to pull in behavior |
| `import foo` | `alias MyApp.Foo` | `alias` shortens module names; `use` injects code |
| `try / catch` | `{:ok, _}` / `{:error, _}` | Elixir prefers return tuples over exceptions |
| `this.count` | `agent.state.count` | No mutable `this`; data is always explicit |
| `foo.bar()` | `Foo.bar(foo)` | Functions take data as arguments, not methods on objects |
| `dict` / `object` / `Map` | `%{key: value}` | Elixir maps with atom or string keys |
| `pip` / `npm` / `maven` | `mix` + `hex.pm` | Dependencies declared in `mix.exs`, installed with `mix deps.get` |

The biggest mental shift: data is immutable. You never modify a variable in place. Functions take data in and return new data. Jido's `cmd/2` returns a new agent struct - the original is unchanged.

## Set up your environment

1. **Install Elixir** following the official guide at [elixir-lang.org/install](https://elixir-lang.org/install.html). This installs Elixir, Erlang/OTP, and Mix together.

2. **Verify your installation:**

```shell
elixir --version
```

You should see Elixir 1.18+ and Erlang/OTP 27+.

3. **Create a test project:**

```shell
mix new my_agent_app
cd my_agent_app
mix test
```

If the tests pass, your environment is ready.

## Livebook

The Jido documentation uses [Livebook](https://livebook.dev) notebooks throughout. Livebook is an interactive coding environment for Elixir - similar to Jupyter notebooks for Python. You can run documentation examples directly in your browser, modify code, and see results immediately.

Livebook is optional. Every tutorial also works by pasting code into an `iex` session. But if you're new to Elixir, Livebook's interactive feedback loop can make learning faster. Look for the "Run in Livebook" button on tutorial pages.

## Learning resources

These resources go deeper into Elixir when you're ready:

- [Elixir official getting started guide](https://elixir-lang.org/getting-started/introduction.html) - the canonical introduction, well-paced and thorough
- [Elixir School](https://elixirschool.com) - community-maintained lessons organized by topic
- [Programming Elixir](https://pragprog.com/titles/elixir16/programming-elixir-1-6/) by Dave Thomas - the standard book for developers coming from other languages
- [Exercism Elixir track](https://exercism.org/tracks/elixir) - practice problems with mentor feedback

You do not need to complete any of these before starting with Jido. The tutorials are designed to be followable with the context on this page.

## Your onboarding path

Work through these four tutorials in order. Each builds on the last and takes under fifteen minutes.

1. **[Installation and setup](/docs/getting-started/installation)** - add Jido to your project, configure dependencies, verify everything compiles
2. **[Your first agent](/docs/getting-started/first-agent)** - define an agent with typed state, implement an action, run your first command
3. **[Your first LLM agent](/docs/getting-started/first-llm-agent)** - wire up an LLM provider so your agent can reason about instructions
4. **[Build your first workflow](/docs/learn/first-workflow)** - compose multiple actions into a sequential workflow with shared state

If you get stuck on Elixir syntax during the tutorials, refer back to the concepts section above or check the [Elixir getting started guide](https://elixir-lang.org/getting-started/introduction.html) for the specific topic.

## Understand Jido's building blocks

As you work through the tutorials, the [Concepts](/docs/concepts) section explains each Jido primitive in depth. These pages are the most comprehensive part of the documentation and worth reading alongside the tutorials:

- **[Agents](/docs/concepts/agents)** - the core data model and `cmd/2` contract
- **[Actions](/docs/concepts/actions)** - how Actions drive state transitions
- **[Signals](/docs/concepts/signals)** - typed events for communication between agents
- **[Directives](/docs/concepts/directives)** - how side effects are described and executed

## Next steps

- [Start with installation](/docs/getting-started/installation) - begin the onboarding ladder
- [Concepts](/docs/concepts) - the architectural reference for every Jido primitive
- [Elixir official getting started](https://elixir-lang.org/getting-started/introduction.html) - go deeper on the language
