%{
  title: "Jido Browser Docs Scout Agent",
  description: "Copy-pasteable Jido.Browser example showing plugin-backed browser sessions, deterministic docs navigation, content extraction, and screenshots.",
  tags: ["primary", "showcase", "simulated", "ai", "browser", "jido_browser", "copy-pasteable"],
  category: :ai,
  emoji: "🌐",
  related_resources: [
    %{
      path: "/ecosystem/jido_browser",
      kind: "Package",
      description: "Jido Browser package overview, installation links, and capability summary."
    },
    %{
      path: "/docs/learn/ai-agent-with-tools",
      kind: "Tutorial",
      description: "How tool-enabled agents fit into larger Jido workflows.",
      include_livebook: true
    },
    %{
      type: :external,
      label: "jido_browser plugin source",
      href: "https://github.com/agentjido/jido_browser/blob/main/lib/jido_browser/plugin.ex",
      kind: "Source",
      description: "The plugin mounted by this example agent."
    },
    %{
      type: :external,
      label: "jido_browser README",
      href: "https://github.com/agentjido/jido_browser/blob/main/README.md",
      kind: "Docs",
      description: "Current package setup, adapters, and installation guidance."
    }
  ],
  source_files: [
    "lib/agent_jido/demos/browser_docs_scout/browser_docs_scout_agent.ex",
    "lib/agent_jido/demos/browser_docs_scout/browser_actions.ex",
    "lib/agent_jido/demos/browser_docs_scout/simulated_adapter.ex",
    "lib/agent_jido_web/examples/browser_docs_scout_agent_live.ex"
  ],
  live_view_module: "AgentJidoWeb.Examples.BrowserDocsScoutAgentLive",
  difficulty: :intermediate,
  status: :live,
  scenario_cluster: :ai_tool_use,
  wave: :l2,
  journey_stage: :evaluation,
  content_intent: :tutorial,
  capability_theme: :ai_intelligence,
  evidence_surface: :runnable_example,
  demo_mode: :simulated,
  sort_order: 20,
  outcome: "Copy-pasteable Jido.Browser example showing plugin-backed browser sessions, deterministic docs navigation, content extraction, and screenshots.",
  packages: ["jido", "jido_ai", "req_llm"],
  package_maturity: "Beta",
  prerequisites: ["Elixir 1.18+", "OTP 27+", "Jido installed", "an LLM provider key"],
  expected_result: "The agent reasons over the prompt using the configured provider and key.",
  run_command: "Run the interactive demo on /examples/jido-ai-browser-web-workflow."
}
---

## What you'll learn

- How to mount `Jido.Browser.Plugin` on a plain `Jido.Agent`
- How to keep browser-enabled demos deterministic with a simulated adapter
- How to carry browser session context across a 3-turn walkthrough without refetching the first URL
- How to navigate a docs page, extract markdown, follow a link, and capture a screenshot
- How to swap the simulated adapter for `Jido.Browser.Adapters.Vibium` or `Jido.Browser.Adapters.Web`
- How to fall back safely to the simulated adapter until a live browser backend is installed

## Deterministic site demo vs live browser flow

This page runs **real `Jido.Browser` integration code** against a local simulated adapter.
That keeps the example deterministic, testable, and browser-binary-free inside this repo.

No API keys or browser binaries are required for this site demo.
When you move this pattern into your own project, the agent, plugin, and wrapper actions stay the same and only the adapter changes.

The agent shape is still the one you would use in your own project:

```elixir
use Jido.Agent,
  plugins: [{Jido.Browser.Plugin, %{adapter: MyApp.BrowserAdapter, headless: true}}]
```

## Three-turn walkthrough

1. Open the plugin guide with `Jido.Browser.Actions.Navigate`
2. Extract markdown from the active page with `Jido.Browser.Actions.ExtractContent` without refetching the URL
3. Follow the testing guide link with `Jido.Browser.Actions.Click` while reusing the same browser session

The demo then captures a screenshot and lets you reset the session so you can replay the flow from a clean state.

## Pull this into your own project

Add the GitHub dependency used by this site:

```elixir
{:jido_browser, github: "agentjido/jido_browser", branch: "main"}
```

When you switch from the simulated adapter to a real browser backend in your own app, add the install step to your setup alias:

```elixir
defp aliases do
  [
    setup: ["deps.get", "jido_browser.install --if-missing"]
  ]
end
```

## Requirements and safe fallback

For a live browser backend in your own app, follow the `jido_browser` README and replace `AgentJido.Demos.BrowserDocsScout.SimulatedAdapter` with a real adapter:

- `Jido.Browser.Adapters.Vibium`
- `Jido.Browser.Adapters.Web`

If your browser backend is not installed yet, keep the simulated adapter wired in dev/test so the workflow stays deterministic while you finish local setup.

## Source layout

- Agent module: `AgentJido.Demos.BrowserDocsScoutAgent`
- Wrapper actions: `AgentJido.Demos.BrowserDocsScout.Actions.*`
- Simulated adapter: `AgentJido.Demos.BrowserDocsScout.SimulatedAdapter`
- Demo UI: `AgentJidoWeb.Examples.BrowserDocsScoutAgentLive`
