%{
  name: "jido_browser",
  title: "Jido Browser",
  graph_label: "Jido Browser",
  version: "2.0.0",
  tagline: "Browser automation for AI agents with 26 composable actions",
  license: "Apache-2.0",
  visibility: :public,
  category: :tools,
  atlas_facet: :automation,
  tier: 2,
  tags: [:browser, :automation, :web, :scraping],
  hex_url: "https://hex.pm/packages/jido_browser",
  hexdocs_url: "https://hexdocs.pm/jido_browser",
  github_url: "https://github.com/agentjido/jido_browser",
  github_org: "agentjido",
  github_repo: "jido_browser",
  tech_lead: "@mikehostetler",
  elixir: "~> 1.17",
  maturity: :stable,
  support_level: :stable,
  hex_status: "2.0.0",
  api_stability: "stable — 2.0 shipped, with ongoing adapter and automation improvements in the 2.x line",
  stub: false,
  support: :maintained,
  limitations: [
    "Adapter behavior can vary across browser/runtime combinations",
    "Requires Chrome (Vibium adapter) or Firefox + Selenium (Web adapter) installed",
    "WebDriver BiDi support is adapter-dependent"
  ],
  ecosystem_deps: ["jido", "jido_action"],
  key_features: [
    "Adapter pattern with Vibium (Chrome/WebDriver BiDi) and Web (Firefox/Selenium) backends",
    "26 composable actions covering full browser automation",
    "LLM-optimized content extraction as structured JSON or clean markdown",
    "Screenshot capture with full-page scrolling support",
    "JavaScript evaluation for advanced page interaction",
    "Single-line agent setup via Plugin system",
    "Signal routing for browser.* event-driven workflows",
    "Cross-platform installer for macOS, Linux, and Windows"
  ],
  landing_summary: "Browser automation for AI agents with 26 composable actions",
  landing_use_when: ["You want ready-made tool Actions for an agent."],
  landing_not_for: ["You need tools this package does not provide."]
}
---
## Overview

Jido Browser provides browser automation capabilities purpose-built for AI agents in the Jido ecosystem. It wraps real browser engines behind a clean adapter pattern, giving agents the ability to navigate websites, interact with page elements, extract content as LLM-friendly markdown, take screenshots, and execute JavaScript — all through 26 composable Jido Actions.

## Purpose

Jido Browser is the web browsing extension for the Jido AI agent framework. It gives Jido agents first-class ability to browse the web — navigate pages, fill forms, click buttons, wait for dynamic content, capture screenshots, and extract page content in formats optimized for LLM consumption.

## Major Components

### Core API (`JidoBrowser`)
High-level facade for all browser operations: session management, navigation, element interaction, screenshots, content extraction, and JavaScript evaluation.

### Adapters
- **Vibium** — Default adapter using WebDriver BiDi protocol with automatic Chrome management
- **Web** — Alternative adapter using Firefox/Selenium with built-in HTML-to-Markdown conversion

### Plugin (`JidoBrowser.Plugin`)
Bundles all 26 browser actions with lifecycle management, signal routing for `browser.*` patterns, and configurable viewport/timeout/headless options.

### Actions (26 modules)
Session Lifecycle, Navigation, Interaction, Waiting, Element Queries, Content Extraction, and Advanced (JavaScript evaluation).
