%{
  title: "Support Triage Agent",
  description: "A real Jido agent that classifies an inbound support message, gauges its urgency, and drafts a routed reply -- no LLM required.",
  tags: ["primary", "showcase", "core", "l1", "support", "ticket", "triage"],
  category: :core,
  emoji: "🎧",
  related_resources: [
    %{
      path: "/docs/getting-started/first-agent",
      kind: "Guide",
      description: "Define typed state and run your first command.",
      include_livebook: true
    },
    %{
      path: "/docs/concepts/actions",
      kind: "Concept",
      description: "Understand the action contracts this agent runs."
    },
    %{
      path: "/docs/concepts/signals",
      kind: "Concept",
      description: "See how typed Signals route each step of the triage."
    }
  ],
  source_files: [
    "lib/agent_jido/demos/support_triage/support_triage_agent.ex",
    "lib/agent_jido/demos/support_triage/classifier.ex",
    "lib/agent_jido/demos/support_triage/fixtures.ex",
    "lib/agent_jido/demos/support_triage/actions/load_message_action.ex",
    "lib/agent_jido/demos/support_triage/actions/classify_intent_action.ex",
    "lib/agent_jido/demos/support_triage/actions/assess_urgency_action.ex",
    "lib/agent_jido/demos/support_triage/actions/respond_action.ex",
    "lib/agent_jido_web/examples/support_triage_agent_live.ex"
  ],
  live_view_module: "AgentJidoWeb.Examples.SupportTriageAgentLive",
  difficulty: :beginner,
  status: :live,
  scenario_cluster: :core_mechanics,
  wave: :l1,
  journey_stage: :evaluation,
  content_intent: :tutorial,
  capability_theme: :runtime_foundations,
  evidence_surface: :runnable_example,
  demo_mode: :real,
  sort_order: 5,
  outcome: "A real Jido agent that classifies an inbound support message, gauges its urgency, and drafts a routed reply -- no LLM required.",
  packages: ["jido"],
  package_maturity: "Beta",
  prerequisites: ["Elixir 1.18+", "OTP 27+", "Jido installed"],
  expected_result: "Classify detects billing, bug, or how-to intent; Assess flags an angry or deadline-driven message as high urgency; Respond routes to billing, engineering, or self-serve and drafts a reply.",
  run_command: "Run the interactive demo on /examples/support-triage-agent."
}
---

## What you'll learn

- How to shape a customer-support triage workflow on the Jido runtime: load, classify intent, assess urgency, respond.
- How to encode each step as a typed, validated Action an agent runs through `cmd/2`.
- How to keep a support demo fully deterministic -- real keyword and pattern matching, no LLM, no API key.

## How it runs

This example runs a real `AgentJido.Demos.SupportTriage` agent. Load one of the
fixture customer messages (a billing question, a bug report, or a how-to
question), then run the three typed actions in turn:

- `ClassifyIntent` scores the message against real billing, bug, and how-to
  signal phrases and picks the best match -- a message with none of the signals
  classifies as `unknown` instead of guessing.
- `AssessUrgency` flags a message as high urgency from real signals -- a
  deadline, a blocking outage, or an angry tone (urgency markers or
  three-plus exclamation marks); a calm message stays at normal urgency.
- `Respond` drafts a routed reply from the prior steps -- a billing message
  routes to a billing queue (priority when urgent) and references the captured
  invoice, a bug routes to engineering (P1 when urgent), a how-to routes to
  self-serve, and an unrecognized message routes to general.

No LLM provider is called. The classification, urgency, and reply are
deterministic pattern matching on the message text, so you can run it without
an API key -- and swap a real reasoning strategy in later using the same agent
shape.
