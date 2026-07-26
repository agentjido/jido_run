%{
  title: "Coding Assistant",
  description: "A real Jido agent that reads fixture code, detects a nil-handling defect with a typed Action, and proposes a guarded patch -- no LLM required.",
  tags: ["primary", "showcase", "ai", "l1", "ai-tool-use", "coding"],
  category: :ai,
  emoji: "💻",
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
      path: "/docs/learn/ai-agent-with-tools",
      kind: "Tutorial",
      description: "Add an LLM reasoning loop on top of this agent shape.",
      include_livebook: true
    }
  ],
  source_files: [
    "lib/agent_jido/demos/coding_assistant/coding_assistant_agent.ex",
    "lib/agent_jido/demos/coding_assistant/fixtures.ex",
    "lib/agent_jido/demos/coding_assistant/actions/read_source_action.ex",
    "lib/agent_jido/demos/coding_assistant/actions/analyze_code_action.ex",
    "lib/agent_jido/demos/coding_assistant/actions/propose_patch_action.ex",
    "lib/agent_jido_web/examples/coding_assistant_live.ex"
  ],
  live_view_module: "AgentJidoWeb.Examples.CodingAssistantLive",
  difficulty: :beginner,
  status: :live,
  scenario_cluster: :ai_tool_use,
  wave: :l1,
  journey_stage: :evaluation,
  content_intent: :tutorial,
  capability_theme: :ai_intelligence,
  evidence_surface: :runnable_example,
  demo_mode: :real,
  sort_order: 3,
  outcome: "A real Jido agent that reads fixture code, detects a nil-handling defect via a typed Action, and proposes a guarded patch -- no LLM required.",
  packages: ["jido"],
  package_maturity: "Beta",
  prerequisites: ["Elixir 1.18+", "OTP 27+", "Jido installed"],
  expected_result: "Analyze flags the String.trim/1 nil-handling defect; Propose patch returns a nil guard and a unit test.",
  run_command: "Run the interactive demo on /examples/coding-assistant."
}
---

## What you'll learn

- How to shape a coding-agent workflow on the Jido runtime: read source, analyze, propose a patch.
- How to encode each step as a typed, validated Action an agent runs through `cmd/2`.
- How to keep a coding demo fully deterministic -- real static analysis, no LLM, no API key.

## How it runs

This example runs a real `AgentJido.Demos.CodingAssistant` agent. It reads a
fixture parser module, runs a typed `AnalyzeCode` action that scans the loaded
source for `String.trim/1` call sites (which raise on `nil`), and runs a typed
`ProposePatch` action that builds a nil-guarded replacement and a unit test from
the finding.

No LLM provider is called. The analysis is deterministic static scanning of the
fixture source, so you can run it without an API key -- and swap a real
reasoning strategy in later using the same agent shape.
