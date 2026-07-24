%{
  title: "Jido.AI Skills Multi-Agent Orchestration",
  description: "Real deterministic routing across arithmetic, conversion, and combined skill specialists.",
  tags: ["primary", "showcase", "ai", "l2", "ai-tool-use", "skills", "jido_ai", "multi-agent", "orchestration"],
  category: :ai,
  emoji: "🤝",
  related_resources: [
    %{
      path: "/docs/learn/multi-agent-orchestration",
      kind: "Tutorial",
      description: "Design and coordinate specialist agent behavior.",
      include_livebook: true
    },
    %{
      type: :external,
      label: "skills orchestration demo script",
      href: "https://github.com/agentjido/jido_ai/blob/main/lib/examples/scripts/demo/skills_multi_agent_orchestration_demo.exs",
      kind: "Source",
      description: "Three-question orchestration flow with semantic checks."
    },
    %{
      type: :external,
      label: "skills system guide",
      href: "https://github.com/agentjido/jido_ai/blob/main/guides/developer/skills_system.md",
      kind: "Guide",
      description: "Registry and prompt APIs used by the orchestration demo."
    }
  ],
  source_files: [
    "lib/agent_jido/demos/skills_multi_agent_orchestration/arithmetic_skill.ex",
    "lib/agent_jido/demos/skills_multi_agent_orchestration/conversion_specialist.ex",
    "lib/agent_jido/demos/skills_multi_agent_orchestration/endurance_planner_skill.ex",
    "lib/agent_jido/demos/skills_multi_agent_orchestration/orchestrator.ex",
    "lib/agent_jido_web/examples/skills_multi_agent_orchestration_live.ex",
    "priv/skills/skills-multi-agent-orchestration/demo-unit-converter/SKILL.md"
  ],
  live_view_module: "AgentJidoWeb.Examples.SkillsMultiAgentOrchestrationLive",
  difficulty: :advanced,
  status: :live,
  scenario_cluster: :ai_tool_use,
  wave: :l2,
  journey_stage: :evaluation,
  content_intent: :reference,
  capability_theme: :coordination_orchestration,
  evidence_surface: :runnable_example,
  demo_mode: :real,
  sort_order: 24,
  outcome: "Real deterministic routing across arithmetic, conversion, and combined skill specialists.",
  packages: ["jido", "jido_ai", "req_llm"],
  package_maturity: "Beta",
  prerequisites: ["Elixir 1.18+", "OTP 27+", "Jido installed", "an LLM provider key"],
  expected_result: "The agent reasons over the prompt using the configured provider and key.",
  run_command: "Run the interactive demo on /examples/jido-ai-skills-multi-agent-orchestration."
}
---

## What you'll learn

- How deterministic routing chooses one or more specialists based on question class
- How module-backed and file-backed skills work together in one orchestration pass
- How `Jido.AI.Skill.Prompt.render/2` can describe the exact skills selected for a request

## How this demo works

This page runs **real local orchestration code**.

- It registers two module-backed specialists and loads one checked-in `SKILL.md` file with `Jido.AI.Skill.Registry.load_from_paths/1`.
- The router chooses an arithmetic, conversion, or combined specialist set for each fixed request.
- Each specialist executes local deterministic helper code, so every response is repeatable and copy-pasteable.

No API keys, LLM providers, or network access are required for this example.

## Pull the pattern into your own app

- Keep specialist skills small and explicit so routing decisions stay legible.
- Use file-backed skills when you want editable runtime instructions for one specialist.
- Render the selected skill prompt before execution if you need an auditable orchestration trace.
