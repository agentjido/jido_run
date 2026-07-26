%{
  title: "Getting started",
  description: "Choose the right path into Jido based on your background and start building.",
  category: :docs,
  legacy_paths: [],
  tags: [:docs, :getting_started],
  order: 10,
  menu_label: "Get Started",
  draft: false
}
---

## What you need

Jido runs on the Elixir/OTP platform. To build with Jido you need:

- **Elixir 1.18+** and **OTP 27+** ([install Elixir](https://elixir-lang.org/install.html))
- **A Mix project** - either a new one (`mix new my_app`) or an existing Elixir application
- **An LLM API key** (OpenAI, Anthropic, or similar) - only needed when you add AI features

Phoenix is not required. Jido works in any Elixir project. If you want to build web interfaces for your agents, Phoenix LiveView integrates naturally - but the core tutorials work with plain `iex` sessions.

## Compatible versions

Each recommended starting stack — Core, AI, and Operate — ships an explicit supported package range, so you do not have to infer which versions work together. The [stack compatibility matrix](/ecosystem#stack-compatibility) lists the installable range for every package in each stack, derived from the registry: a Hex major pin (`~> X.0`) for published packages and a `github:` pin for unreleased ones. Check it before you pin versions in `mix.exs`.

## Choose your path

Pick the track that matches your background. The first two paths lead to the same onboarding tutorials - they differ in how much context they provide before you start building. The third path is for builders who want a running Phoenix application instead of starting from a blank Mix project.

### [I'm new to Elixir](/docs/getting-started/new-to-elixir)

You're coming from Python, TypeScript, Java, or another stack. You found Jido because you need reliable agent infrastructure. This path gives you the essential Elixir context you need to follow the tutorials and read Jido code confidently.

### [I know Elixir](/docs/getting-started/elixir-developers)

You've built OTP applications. You're comfortable with GenServer, supervision trees, and Mix. This path maps Jido's architecture to patterns you already know, then gets you into the tutorials fast.

### [Use the Phoenix starter](/docs/getting-started/phoenix-starter)

You want to explore Jido inside a real, running Phoenix app instead of building from a blank project. This path points you at the Jido PHX Starter and states its Postgres and provider-key requirements up front.

## Where this takes you

Both paths feed into the same four-step onboarding ladder:

1. **[Installation and setup](/docs/getting-started/installation)** - add Jido to a project, configure dependencies, verify everything compiles
2. **[Your first agent](/docs/getting-started/first-agent)** - define an agent with typed state and actions, no LLM required
3. **[Your first LLM agent](/docs/getting-started/first-llm-agent)** - wire up an LLM so your agent can reason about instructions
4. **[Build your first workflow](/docs/learn/first-workflow)** - compose actions into a multi-step workflow that runs as a single unit

Each tutorial builds on the last.

## Controls and identity

These tutorials focus on getting an agent running. A few things to know up front:

- **Tools and supervision are built in.** Actions are typed and validated, and agents run under OTP supervision.
- **Identity and authorization are yours to supply.** Agent, Signal, and request IDs are correlation metadata, not authenticated principals. A fail-closed authorization hook (`prepare_action/3`) is there when you need it, but Jido is not an IAM system.
- **Telemetry is not an audit log.** Jido emits telemetry for understanding your system; durable history needs a configured Signal Journal.

See [Security and governance](/docs/operations/security-and-governance) when you move toward production.

When you are ready to govern agent work - authorization, policy, durable history, and telemetry - the [Add operational controls](/docs/getting-started/operational-controls) lane picks up where your first agent leaves off. It is an optional path that follows the first working agent; none of it is required to run a basic agent.

## After getting started

Once you finish the onboarding path:

- **[Concepts](/docs/concepts)** - the most comprehensive section of the docs. Authoritative explanations of every Jido primitive: Agents, Actions, Signals, Directives, Strategies, and more. Read these alongside or after the tutorials.
- **[Learn](/docs/learn)** - structured training modules that go deeper on specific topics
- **[Guides](/docs/guides)** - task-oriented recipes for production patterns

## Next steps

- [I'm new to Elixir](/docs/getting-started/new-to-elixir) - get the Elixir foundations first
- [I know Elixir](/docs/getting-started/elixir-developers) - jump in with OTP context
- [Use the Phoenix starter](/docs/getting-started/phoenix-starter) - run a complete demo app
- [Add operational controls](/docs/getting-started/operational-controls) - the optional authorization, policy, and observability path
- [Explore core concepts](/docs/concepts) - understand the architecture before you build
