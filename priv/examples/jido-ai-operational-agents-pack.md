%{
  title: "Jido.AI Operational Agents Pack",
  description: "Operational overview/index linking to deterministic workbench examples and upstream Jido.AI ops-agent sources.",
  tags: ["primary", "reference", "ai", "l2", "ops-governance", "jido_ai", "operations", "overview"],
  category: :ai,
  emoji: "🛠",
  related_resources: [
    %{
      path: "/docs/learn/multi-agent-orchestration",
      kind: "Tutorial",
      description: "Operational orchestration and specialization patterns.",
      include_livebook: true
    },
    %{
      type: :external,
      label: "api smoke test agent",
      href: "https://github.com/agentjido/jido_ai/blob/main/lib/examples/agents/api_smoke_test_agent.ex",
      kind: "Source",
      description: "ReAct-driven API endpoint testing and debugging."
    },
    %{
      type: :external,
      label: "issue triage agent",
      href: "https://github.com/agentjido/jido_ai/blob/main/lib/examples/agents/issue_triage_agent.ex",
      kind: "Source",
      description: "Secure token injection pattern and safe GitHub operations."
    },
    %{
      type: :external,
      label: "release notes agent",
      href: "https://github.com/agentjido/jido_ai/blob/main/lib/examples/agents/release_notes_agent.ex",
      kind: "Source",
      description: "Graph-of-Thoughts synthesis for release note generation."
    }
  ],
  source_files: [
    "lib/agent_jido/demos/operational_agents_pack/catalog.ex",
    "lib/agent_jido_web/examples/operational_agents_pack_live.ex"
  ],
  live_view_module: "AgentJidoWeb.Examples.OperationalAgentsPackLive",
  difficulty: :advanced,
  status: :live,
  scenario_cluster: :ops_governance,
  wave: :l2,
  journey_stage: :operationalization,
  content_intent: :reference,
  capability_theme: :operations_observability,
  evidence_surface: :docs_reference,
  demo_mode: :real,
  sort_order: 26,
  outcome: "Operational overview/index linking to deterministic workbench examples and upstream Jido.AI ops-agent sources.",
  packages: ["jido", "jido_ai", "req_llm"],
  package_maturity: "Beta",
  prerequisites: ["Elixir 1.18+", "OTP 27+", "Jido installed", "an LLM provider key"],
  expected_result: "The agent reasons over the prompt using the configured provider and key.",
  run_command: "Run the interactive demo on /examples/jido-ai-operational-agents-pack."
}
---

## What you'll learn

- How to break a broad operational pack into narrower deterministic examples
- How to choose which local workbench example best matches your ops workflow
- Where to go for upstream Jido.AI ops-agent sources that preserve the original API smoke, triage, and release-notes concepts

## What this page is

This page is an overview/index. It is not one runnable “operational pack” demo.

The demo tab now points to a dedicated operational index surface that links to real deterministic examples already in this repo. Use those linked pages when you want runnable proof, and use the upstream source links when you want the original Jido.AI operational agent implementations.

## Included workflows

- release or handoff workflow coordination
- scheduled follow-up and remediation
- durable state and restart-friendly operational flows

## Upstream source references

The original pack concepts are still preserved as source references:

- API smoke testing
- GitHub issue triage
- release notes synthesis

## Demo note

No simulator-backed “run this whole pack” trace remains on this page. The interactive tab is a navigable operational index, and the linked local examples are the deterministic runnable surfaces.
