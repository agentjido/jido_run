%{
  title: "Jido.AI Skills Runtime Foundations",
  description:
    "Real skill manifest loading, registry setup, prompt rendering, and builder-skill catalog walkthroughs with checked-in `SKILL.md` fixtures.",
  tags: ["primary", "showcase", "ai", "l2", "ai-tool-use", "skills", "runtime", "jido_ai"],
  category: :ai,
  emoji: "📚",
  related_resources: [
    %{
      path: "/docs/learn/multi-agent-orchestration",
      kind: "Tutorial",
      description: "Skill-aware orchestration patterns for agents.",
      include_livebook: true
    },
    %{
      type: :external,
      label: "skills runtime foundations demo",
      href: "https://github.com/agentjido/jido_ai/blob/main/lib/examples/scripts/demo/skills_runtime_foundations_demo.exs",
      kind: "Source",
      description: "Manifest, registry, and prompt rendering checks."
    },
    %{
      type: :external,
      label: "skills system guide",
      href: "https://github.com/agentjido/jido_ai/blob/main/guides/developer/skills_system.md",
      kind: "Guide",
      description: "Loader, registry, and prompt APIs for file-backed and module-backed skills."
    }
  ],
  source_files: [
    "lib/agent_jido/demos/skills_runtime_foundations/calculator_skill.ex",
    "lib/agent_jido/demos/skills_runtime_foundations/runtime_demo.ex",
    "lib/agent_jido_web/examples/skills_runtime_foundations_live.ex",
    "priv/ecosystem/jido_skill.md",
    "priv/skills/builder-action-scaffold/SKILL.md",
    "priv/skills/builder-agent-scaffold/SKILL.md",
    "priv/skills/builder-plugin-scaffold/SKILL.md",
    "priv/skills/builder-adapter-package/SKILL.md",
    "priv/skills/builder-ecosystem-page-author/SKILL.md",
    "priv/skills/builder-example-tutorial-author/SKILL.md",
    "priv/skills/builder-package-review/SKILL.md",
    "priv/skills/skills-runtime-foundations/demo-code-review/SKILL.md",
    "priv/skills/skills-runtime-foundations/demo-release-notes/SKILL.md"
  ],
  live_view_module: "AgentJidoWeb.Examples.SkillsRuntimeFoundationsLive",
  difficulty: :intermediate,
  status: :live,
  scenario_cluster: :ai_tool_use,
  wave: :l2,
  journey_stage: :evaluation,
  content_intent: :reference,
  capability_theme: :ai_intelligence,
  evidence_surface: :runnable_example,
  demo_mode: :real,
  sort_order: 23,
  outcome: "Real skill manifest loading, registry setup, prompt rendering, and builder-skill catalog walkthroughs with checked-in `SKILL.md` fixtures.",
  packages: ["jido", "jido_ai", "req_llm"],
  package_maturity: "Beta",
  prerequisites: ["Elixir 1.18+", "OTP 27+", "Jido installed", "an LLM provider key"],
  expected_result: "The agent reasons over the prompt using the configured provider and key.",
  run_command: "Run the interactive demo on /examples/jido-ai-skills-runtime-foundations."
}
---

## What you'll learn

- How `Jido.AI.Skill.Loader.load/1` parses checked-in `SKILL.md` files into runtime manifests
- How `Jido.AI.Skill.Registry.load_from_paths/1` and `Jido.AI.Skill.Registry.register/1` populate one deterministic registry
- How `Jido.AI.Skill.Prompt.render/2` turns those registered skills into reusable prompt instructions
- Where the builder-skill catalog lives under `priv/skills/builder-*/SKILL.md`
- How the same builder skills can support `Jido.AI`, `jido_skill`, and Codex-oriented contributor workflows
- How one real workbench task for `jido_skill` is assembled from checked-in builder skills

## How this demo stays truthful

This page runs **real skills runtime code**.

- One skill is defined as an Elixir module with `use Jido.AI.Skill`.
- Two skills are loaded from checked-in `priv/skills/.../SKILL.md` files.
- Seven builder skills are loaded from checked-in `priv/skills/builder-*/SKILL.md` files.
- The demo uses those builder skills to render a real contributor workflow for refreshing the `jido_skill` ecosystem package coverage in this repo.
- The demo renders prompts and workflow plans only. It does not call external services or mutate package repos.

No API keys, LLM providers, or network access are required for this example.

## Builder catalog included here

The checked-in builder catalog currently includes:

- `builder-action-scaffold`
- `builder-agent-scaffold`
- `builder-plugin-scaffold`
- `builder-adapter-package`
- `builder-ecosystem-page-author`
- `builder-example-tutorial-author`
- `builder-package-review`

The catalog is intentionally split across package-repo and workbench-repo boundaries:

- package repos own implementation modules, tests, changelog updates, and release work
- this workbench owns ecosystem pages, examples, tutorials, and contributor-facing guidance

## Pull the pattern into your own app

Keep the same runtime steps in your own project:

- define stable module-backed skills for core workflows
- add file-backed `SKILL.md` assets when you want editable runtime instructions
- register those skills into the runtime registry
- render the combined prompt text once your agent or workflow needs it
- keep boundary notes inside the skill metadata so package-repo work and workbench follow-up stay explicit
