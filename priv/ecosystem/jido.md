%{
  name: "jido",
  title: "Jido",
  graph_label: "Jido",
  compare_order: 0,
  version: "2.3.2",
  tagline: "Core agent framework for building long-running, multi-agent systems in Elixir",
  license: "Apache-2.0",
  visibility: :public,
  category: :core,
  atlas_facet: :primitives,
  tier: 1,
  tags: [:agents, :otp, :framework, :beam],
  hex_url: "https://hex.pm/packages/jido",
  hexdocs_url: "https://hexdocs.pm/jido",
  github_url: "https://github.com/agentjido/jido",
  github_org: "agentjido",
  github_repo: "jido",
  tech_lead: "@mikehostetler",
  elixir: "~> 1.17",
  maturity: :stable,
  support_level: :stable,
  hex_status: "2.2.0",
  api_stability: "evolving — 2.0 shipped, but expect continued API refinements across early 2.x",
  stub: false,
  support: :maintained,
  landing_summary: "Jido is the Elixir agent framework for building long-running, long-running, multi-agent systems on OTP and the BEAM.",
  seo: %{
    title: "Jido Elixir agent framework for long-running multi-agent systems",
    description: "Jido is an Elixir agent framework for long-running, deterministic, multi-agent systems on OTP. Learn when to use it, the key modules, and where to start.",
    keywords: [
      "jido",
      "elixir agent framework",
      "otp agents",
      "multi-agent systems",
      "beam agent runtime",
      "Jido.Agent",
      "Jido.AgentServer"
    ],
    og_title: "Jido: Elixir agent framework on OTP",
    og_description: "Build long-running, multi-agent Elixir systems with a deterministic runtime, explicit directives, and BEAM-native supervision."
  },
  limitations: [
    "Early 2.x hardening may still introduce focused breaking changes",
    "Persistence adapters are limited (hibernate/thaw only, no built-in DB adapter)",
    "Distributed multi-node agent coordination requires manual setup"
  ],
  control_capabilities: [
    "Plugin authorization hooks — prepare_signal/2 and prepare_action/3 run before signals and actions execute, and prepare_action/3 is the fail-closed authorization point for the controlled-Agent path.",
    "Action contract validation — Jido.Action schema-validates params before an action runs.",
    "BEAM-native supervision — AgentServer restarts agents under OTP supervision trees with explicit error policies.",
    "Correlated telemetry — Jido.Observe and Jido.Telemetry emit lifecycle, action, and span events for observation."
  ],
  control_limitations: [
    "Does not authenticate principals — Agent, Signal, request, and trace IDs are correlation metadata, not verified identity. The host application supplies the principal and tenant.",
    "Does not ship a built-in IAM or RBAC product — Jido supplies integration points like prepare_action/3, not authorization decisions.",
    "Does not retain tamper-evident audit history by default — durable, replayable history needs a configured durable Signal Journal adapter and a retention policy."
  ],
  ecosystem_deps: ["jido_action", "jido_signal"],
  landing_use_when: [
    "You need long-running, stateful agents that fit naturally into OTP supervision trees.",
    "You want deterministic agent logic with explicit side effects and testable command handling.",
    "You are building multi-agent workflows on the BEAM and need a stronger contract than raw GenServer callbacks."
  ],
  landing_not_for: [
    "You only need a thin wrapper around a single LLM call or request-response helper.",
    "You want a batteries-included end-user product UI rather than a runtime framework.",
    "You need turnkey multi-node distributed coordination without designing those runtime boundaries yourself."
  ],
  landing_resources: [
    %{
      group: :start_here,
      label: "Your first agent",
      href: "/docs/getting-started/first-agent",
      description: "Build a working Jido agent and run cmd/2 end to end."
    },
    %{
      group: :start_here,
      label: "Agents concept guide",
      href: "/docs/concepts/agents",
      description: "Understand the agent contract, state model, and directive loop before scaling out."
    },
    %{
      group: :guides,
      label: "Testing agents and actions",
      href: "/docs/guides/testing-agents-and-actions",
      description: "Write deterministic tests around actions, directives, and runtime behavior."
    },
    %{
      group: :guides,
      label: "Error handling and recovery",
      href: "/docs/guides/error-handling-and-recovery",
      description: "Set error policies and recover safely in long-running agent processes."
    },
    %{
      group: :examples,
      label: "Counter Agent example",
      href: "/examples/counter-agent",
      description: "Study the smallest runnable Jido example for state and action flow."
    },
    %{
      group: :examples,
      label: "Demand Tracker Agent example",
      href: "/examples/demand-tracker-agent",
      description: "See a more realistic stateful workflow built on the runtime."
    },
    %{
      group: :reference,
      label: "Agent runtime",
      href: "/docs/concepts/agent-runtime",
      description: "See how directives, signals, and AgentServer fit together operationally."
    },
    %{
      group: :reference,
      label: "Architecture decision guides",
      href: "/docs/reference/architecture-decision-guides",
      description: "Choose when Jido is the right abstraction versus adjacent BEAM patterns."
    }
  ],
  landing_best_example: %{
    label: "Counter Agent example",
    href: "/examples/counter-agent",
    note: "The smallest runnable Jido agent — proves state, validated actions, and signal routing end to end."
  },
  landing_best_guide: %{
    label: "Your first agent",
    href: "/docs/getting-started/first-agent",
    note: "The maintained first learning path for Jido — build a working agent and run cmd/2 end to end."
  },
  landing_related_packages: [
    %{
      id: "jido_action",
      relationship: :builds_on,
      reason: "Defines the typed action contract that powers cmd/2 and directive-driven execution."
    },
    %{
      id: "jido_signal",
      relationship: :builds_on,
      reason: "Provides the signal envelope and routing surface used for agent communication."
    },
    %{
      id: "jido_ai",
      relationship: :works_with,
      reason: "Adds LLM reasoning, tool use, and higher-level intelligence on top of the runtime."
    },
    %{
      id: "jido_live_dashboard",
      relationship: :works_with,
      reason: "Gives you live operational visibility into running agents during debugging and local ops work."
    },
    %{
      id: "jido_memory",
      relationship: :next_step,
      reason: "Add memory and retrieval when the runtime needs persistent context beyond in-process state."
    },
    %{
      id: "jido_runic",
      relationship: :next_step,
      reason: "Move from single-agent commands to workflow-style orchestration when execution graphs get more complex."
    }
  ],
  landing_faq: [
    %{
      question: "Do I need jido_ai to use Jido?",
      answer: "No. Jido is the runtime and agent framework. You can build deterministic agents, signals, directives, and workflows without any LLM layer, then add jido_ai later if the system needs model-driven reasoning."
    },
    %{
      question: "How is Jido different from a GenServer?",
      answer: "GenServer gives you process primitives. Jido adds an agent contract, validated state, explicit directives, signal routing, and a cleaner separation between decision logic and side effects."
    },
    %{
      question: "Which packages usually come next after jido?",
      answer: "Most stacks start with jido_action and jido_signal as the core runtime companions. From there, jido_ai, jido_memory, jido_browser, and jido_live_dashboard are common additions depending on whether you need reasoning, memory, tools, or observability."
    }
  ],
  landing_install: %{
    label: "Add to mix.exs",
    source: :hex,
    note: "Use the published Hex release for the stable runtime. Add companion packages only when your system needs those capabilities directly.",
    snippet: """
    defp deps do
      [
        {:jido, "~> 2.2.0"}
      ]
    end
    """
  },
  landing_major_components: [
    %{
      name: "Jido.Agent",
      summary: "Defines the core immutable agent contract and cmd/2 lifecycle.",
      docs_url: "https://hexdocs.pm/jido/Jido.Agent.html"
    },
    %{
      name: "Jido.AgentServer",
      summary: "OTP runtime wrapper for production execution, routing, and supervision.",
      docs_url: "https://hexdocs.pm/jido/Jido.AgentServer.html"
    },
    %{
      name: "Jido.Plan",
      summary: "DAG planning primitives for dependency-aware multi-step execution.",
      docs_url: "https://hexdocs.pm/jido/Jido.Plan.html"
    },
    %{
      name: "Jido.Plugin",
      summary: "Composable extension mechanism for capabilities, hooks, and state.",
      docs_url: "https://hexdocs.pm/jido/Jido.Plugin.html"
    },
    %{
      name: "Jido.Discovery",
      summary: "Persistent catalog for discovering actions, agents, plugins, and sensors at runtime.",
      docs_url: "https://hexdocs.pm/jido/Jido.Discovery.html"
    },
    %{
      name: "Jido.Agent.Directive",
      summary: "Typed effect contracts emitted by cmd/2 and executed by runtimes.",
      docs_url: "https://hexdocs.pm/jido/Jido.Agent.Directive.html"
    }
  ],
  key_features: [
    "Pure functional agent architecture — agents are immutable data structures",
    "Elm/Redux-inspired cmd/2 contract — actions in, updated agent + directives out",
    "Schema-validated state with NimbleOptions or Zoi",
    "Directive-based effect system — side effects described, not performed",
    "Pluggable execution strategies (Direct, FSM, custom)",
    "Composable plugin system with isolated state and lifecycle hooks",
    "OTP-native runtime with GenServer-based AgentServer",
    "Parent-child agent hierarchies with lifecycle monitoring",
    "Signal-driven communication with configurable routing",
    "Append-only interaction threads with journal-backed persistence",
    "Agent memory system with named spaces",
    "Hibernate/thaw persistence for checkpoint and restore",
    "Pre-warmed worker pools via Poolboy",
    "Per-agent cron scheduling",
    "Automatic component discovery via persistent_term",
    "Testable without processes — pure cmd/2 enables unit testing"
  ]
}
---
## Overview

Jido (自動, Japanese for "automatic") is the core agent framework for building long-running, multi-agent systems in Elixir. It provides a pure functional agent architecture inspired by Elm/Redux where agents are immutable data structures updated through a single `cmd/2` operation — actions transform state, directives describe side effects, and an OTP-powered runtime executes everything in production. This separation of pure decision logic from effectful execution gives developers deterministic, testable agent behavior with the full power of the BEAM underneath.

As the foundation of the Jido ecosystem, this package formalizes the patterns that raw OTP leaves ad-hoc: standardized signal envelopes replace custom message shapes, reusable actions replace business logic scattered across GenServer callbacks, typed directives replace implicit effects, and built-in parent-child hierarchies replace custom child tracking. The result is a production-grade framework for building single agents, cooperating multi-agent workflows, and long-running agent systems that can be reasoned about, tested without processes, and deployed with confidence.

## Purpose

Jido is the **core package** of the Jido ecosystem. It defines the Agent behaviour, the `cmd/2` contract, the directive system, execution strategies, the plugin architecture, the OTP runtime (AgentServer), and all supporting infrastructure (persistence, observability, scheduling, discovery). Every other package in the ecosystem — `jido_action`, `jido_signal`, `jido_ai` — extends or builds upon the primitives defined here.

## Major Components

### Agent (`Jido.Agent`)
The central abstraction. Agents are immutable structs with schema-validated state, updated exclusively through the `cmd/2` function. Accepts actions as modules, `{Module, params}` tuples, `%Instruction{}` structs, or lists of any of these. Returns `{updated_agent, directives}` — the agent is always fully updated and directives are external effect descriptions only. Supports lifecycle hooks (`on_before_cmd/2`, `on_after_cmd/3`).

### AgentServer (`Jido.AgentServer`)
GenServer-based OTP runtime that wraps an Agent for production deployment. Owns signal routing, executes directives through a non-blocking internal queue with drain loop, manages parent-child agent hierarchies with lifecycle monitoring, and provides sync (`call/3`) and async (`cast/2`) signal processing.

### Strategies (`Jido.Agent.Strategy`)
Pluggable execution strategies that control how `cmd/2` processes actions:
- **Direct** — Immediate sequential execution (default)
- **FSM** — Finite state machine for state-driven workflows with transition guards

### Plugins (`Jido.Plugin`)
Composable capability modules that extend agents with reusable functionality. Each plugin encapsulates actions, schema-validated state, configuration, signal routing rules, lifecycle hooks, optional child processes, and cron schedules.

### Directives (`Jido.Agent.Directive`)
Typed effect descriptions emitted by `cmd/2` for the runtime to execute: Emit, Error, Spawn, SpawnAgent, StopChild, Schedule, Stop, Cron/CronCancel.

### Sensors (`Jido.Sensor`)
Pure behaviour modules that transform external events into Jido Signals. Stateless with `init/2` and `handle_event/2` callbacks.

### Thread (`Jido.Thread`)
Append-only log of interaction entries — the canonical record of "what happened" in a conversation or workflow.

### Memory (`Jido.Memory`)
An agent's mutable cognitive substrate organized as named spaces (world, tasks, custom).

### Persistence (`Jido.Persist`, `Jido.Storage`)
Hibernate/thaw lifecycle for agents with thread support and storage adapter behaviour.

### Observability (`Jido.Observe`, `Jido.Telemetry`)
Unified observability façade wrapping `:telemetry` events with span-based tracing.

### Discovery (`Jido.Discovery`)
Fast, persistent catalog of Jido components using `:persistent_term`.
