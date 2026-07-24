%{
  title: "Schedule Directive Agent",
  description: "Focused example for delayed scheduling, bounded retries, and CRON-based recurring signals.",
  tags: ["scheduling", "directives", "cron", "coordination", "l1"],
  category: :production,
  emoji: "⏱",
  related_resources: [
    %{
      path: "/docs/concepts/directives",
      kind: "Concept",
      description: "Understand Schedule and other directive types."
    },
    %{
      path: "/docs/learn/first-workflow",
      kind: "Guide",
      description: "Compose multi-step control flow with signals.",
      include_livebook: true
    },
    %{
      path: "/docs/operations/production-readiness-checklist",
      kind: "Operations",
      description: "Checklist for runtime-safe automation."
    }
  ],
  source_files: [
    "lib/agent_jido/demos/schedule_directive/schedule_directive_agent.ex",
    "lib/agent_jido/demos/schedule_directive/actions/start_timer_action.ex",
    "lib/agent_jido/demos/schedule_directive/actions/start_retry_action.ex",
    "lib/agent_jido/demos/schedule_directive/actions/handle_retry_action.ex",
    "lib/agent_jido_web/examples/schedule_directive_agent_live.ex"
  ],
  live_view_module: "AgentJidoWeb.Examples.ScheduleDirectiveAgentLive",
  difficulty: :beginner,
  status: :live,
  scenario_cluster: :coordination,
  wave: :l1,
  journey_stage: :operationalization,
  content_intent: :tutorial,
  capability_theme: :coordination_orchestration,
  evidence_surface: :runnable_example,
  demo_mode: :real,
  sort_order: 27,
  outcome: "An agent that schedules delayed and recurring work via Schedule directives and bounded retries.",
  packages: ["jido"],
  package_maturity: "Beta",
  prerequisites: ["Elixir 1.18+", "OTP 27+", "Jido installed"],
  expected_result: "Scheduled work fires and retries complete within the configured budget; no API key required.",
  run_command: "Run the interactive demo on /examples/schedule-directive-agent, or: mix test test/agent_jido/demos/schedule_directive_agent_test.exs"
}
---

## What you'll learn

- How `%Directive.Schedule{}` drives delayed work.
- How to implement bounded retries without loops.
- How to define CRON schedules directly on the agent.

## How it works

The demo combines two scheduling layers:

- **Directive schedule** for immediate delayed transitions (`start_timer`, `start_retry`).
- **CRON schedules** declared in `use Jido.Agent` for recurring runtime signals.

You can also trigger `cron.tick` and `cron.hourly` manually to verify behavior instantly.
