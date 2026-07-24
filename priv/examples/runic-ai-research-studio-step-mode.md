%{
  title: "Runic AI Research Studio Step Mode",
  description: "Step-wise execution of the Studio workflow with real `runic.step` and `runic.resume` behavior.",
  tags: ["primary", "showcase", "ai", "l2", "ai-tool-use", "runic", "workflow"],
  category: :ai,
  emoji: "🪜",
  related_resources: [
    %{
      path: "/docs/learn/reasoning-strategies-compared",
      kind: "Concept",
      description: "Compare strategy execution styles and observability expectations.",
      include_livebook: true
    },
    %{
      type: :external,
      label: "jido_runic step demo source",
      href: "https://github.com/agentjido/jido_runic/blob/main/lib/examples/studio_step_demo.exs",
      kind: "Source",
      description: "Step-mode demo script from upstream package."
    },
    %{
      type: :external,
      label: "orchestrator run_step implementation",
      href: "https://github.com/agentjido/jido_runic/blob/main/lib/examples/studio/orchestrator_agent.ex",
      kind: "Source",
      description: "Strategy integration for per-step callbacks and annotated graph output."
    }
  ],
  source_files: [
    "lib/agent_jido/demos/runic_research_studio/fixtures.ex",
    "lib/agent_jido/demos/runic_research_studio/actions.ex",
    "lib/agent_jido/demos/runic_research_studio/orchestrator_agent.ex",
    "lib/agent_jido/demos/runic_research_studio/runtime_demo.ex",
    "lib/agent_jido_web/examples/runic_research_studio_step_mode_live.ex"
  ],
  live_view_module: "AgentJidoWeb.Examples.RunicResearchStudioStepModeLive",
  difficulty: :intermediate,
  status: :live,
  scenario_cluster: :ai_tool_use,
  wave: :l2,
  journey_stage: :evaluation,
  content_intent: :tutorial,
  capability_theme: :ai_intelligence,
  evidence_surface: :runnable_example,
  demo_mode: :real,
  sort_order: 15,
  outcome: "Step-wise execution of the Studio workflow with real `runic.step` and `runic.resume` behavior.",
  packages: ["jido", "jido_ai", "req_llm"],
  package_maturity: "Beta",
  prerequisites: ["Elixir 1.18+", "OTP 27+", "Jido installed", "an LLM provider key"],
  expected_result: "The agent reasons over the prompt using the configured provider and key.",
  run_command: "Run the interactive demo on /examples/runic-ai-research-studio-step-mode."
}
---

## What you'll learn

- How to run the Studio DAG in `:step` mode instead of auto-complete mode
- How per-step callbacks expose dispatch/completion, output keys, and graph status
- How to pause, step, and resume a real deterministic Runic workflow without requiring provider credentials

## Core idea

Step mode pauses between nodes and emits a structured history snapshot at each transition:

```text
runic.set_mode(:step) -> runic.feed(topic) -> step loop -> runic.step / runic.resume
```

This page uses the actual step-mode command flow, not a replayed fixture timeline. Each click advances or resumes the shared deterministic Runic backend used by the studio auto-mode example.

## Upstream command

```bash
mix run lib/examples/studio_step_demo.exs
```

## Demo note

This interactive page uses deterministic local actions, but the `runic.step` and `runic.resume` transitions are real strategy transitions rather than a simulated replay.
