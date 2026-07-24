%{
  title: "Jido.AI Task Execution Workflow",
  description: "Deterministic task lifecycle demo using the shipped task-list actions and real `Jido.Exec.run/3` calls.",
  tags: ["primary", "showcase", "ai", "l2", "ai-tool-use", "tasks", "workflow", "jido_ai"],
  category: :ai,
  emoji: "✅",
  related_resources: [
    %{
      path: "/docs/learn/task-planning-and-execution",
      kind: "Tutorial",
      description: "Planning and task execution patterns in Jido systems.",
      include_livebook: true
    },
    %{
      type: :external,
      label: "task execution workflow demo",
      href: "https://github.com/agentjido/jido_ai/blob/main/lib/examples/scripts/demo/task_execution_workflow_demo.exs",
      kind: "Source",
      description: "Lifecycle demo using task-list actions."
    },
    %{
      type: :external,
      label: "task list tools",
      href: "https://github.com/agentjido/jido_ai/blob/main/lib/examples/tools/task_list.ex",
      kind: "Source",
      description: "The upstream tasklist actions used by this local demo."
    }
  ],
  source_files: [
    "lib/agent_jido/demos/task_execution/workflow.ex",
    "lib/agent_jido_web/examples/task_execution_workflow_live.ex"
  ],
  live_view_module: "AgentJidoWeb.Examples.TaskExecutionWorkflowLive",
  difficulty: :intermediate,
  status: :live,
  scenario_cluster: :ai_tool_use,
  wave: :l2,
  journey_stage: :evaluation,
  content_intent: :reference,
  capability_theme: :coordination_orchestration,
  evidence_surface: :runnable_example,
  demo_mode: :real,
  sort_order: 22,
  outcome: "Deterministic task lifecycle demo using the shipped task-list actions and real `Jido.Exec.run/3` calls.",
  packages: ["jido", "jido_ai", "req_llm"],
  package_maturity: "Beta",
  prerequisites: ["Elixir 1.18+", "OTP 27+", "Jido installed", "an LLM provider key"],
  expected_result: "The agent reasons over the prompt using the configured provider and key.",
  run_command: "Run the interactive demo on /examples/jido-ai-task-execution-workflow."
}
---

## What you'll learn

- How the shipped task list tools enforce a deterministic lifecycle (`pending -> in_progress -> done`)
- How to drive `tasklist_add_tasks`, `tasklist_next_task`, `tasklist_start_task`, `tasklist_complete_task`, and `tasklist_get_state`
- How to keep a workflow demo truthful with real `Jido.Exec.run/3` calls and no external services

## How this demo works

This page runs **real `Jido.Exec.run/3` calls** against the shipped task-list actions on every button press.

- `Seed Tasks` creates a fixed three-step release workflow in local memory.
- `Start Next Task` advances the next pending task into `in_progress`.
- `Complete Active Task` records a deterministic result and moves the task into `done`.
- `Run Full Workflow` repeats those transitions until `tasklist_get_state` reports `all_complete`.

No external providers, API keys, or network access are required for this demo.

## Pull the pattern into your own app

Keep the same `Jido.Exec.run/3` shape and swap the seeded tasks or surrounding UI to match your workflow.

- Reuse the same action sequence when you want deterministic task orchestration in a demo or internal tool.
- Replace the fixed seed tasks with your own project planning or release-management tasks.
- Persist the task list in your own agent or workflow state once you move beyond the local demo surface.
