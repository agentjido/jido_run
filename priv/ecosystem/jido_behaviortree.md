%{
  name: "jido_behaviortree",
  title: "Jido BehaviorTree",
  graph_label: "Jido BehaviorTree",
  version: "1.0.0",
  tagline: "Full-featured behavior tree engine for Jido agent decision-making",
  license: "Apache-2.0",
  visibility: :public,
  category: :tools,
  atlas_facet: :workflow,
  tier: 2,
  tags: [:behavior_tree, :ai, :decision_making, :strategy],
  hex_url: "https://hex.pm/packages/jido_behaviortree",
  hexdocs_url: "https://hexdocs.pm/jido_behaviortree",
  github_url: "https://github.com/agentjido/jido_behaviortree",
  github_org: "agentjido",
  github_repo: "jido_behaviortree",
  tech_lead: "@mikehostetler",
  maturity: :stable,
  support_level: :stable,
  hex_status: "unreleased",
  api_stability: "unstable — expect breaking changes",
  stub: false,
  support: :best_effort,
  limitations: [
    "Not published to Hex — available only via GitHub dependency",
    "Version listed as 1.0.0 but not published; treat as pre-release",
    "Limited production usage"
  ],
  ecosystem_deps: ["jido"],
  key_features: [
    "Complete behavior tree execution engine with tick-based traversal and stateful node execution",
    "9 built-in node types — Sequence, Selector, Inverter, Succeeder, Failer, Repeat, Action, Wait, SetBlackboard",
    "Direct Jido Action integration — execute any Action module as a leaf node",
    "Blackboard pattern for decoupled inter-node communication",
    "GenServer-based Agent for persistent multi-tick execution with manual and automatic modes",
    "AI/LLM tool compatibility — convert behavior trees to OpenAI function-calling format",
    "Jido Agent Strategy implementation for strategy-driven agent workflows",
    "Context-aware execution threading agent state and directives through the tree",
    "Full telemetry and observability via Jido.Observe spans",
    "Custom node creation via the Node behaviour with Zoi schema-based structs"
  ],
  landing_summary: "Full-featured behavior tree engine for Jido agent decision-making",
  landing_use_when: ["You want ready-made tool Actions for an agent."],
  landing_not_for: ["You need tools this package does not provide."]
}
---
## Overview

Jido BehaviorTree is a full-featured behavior tree engine built natively for the Jido agent ecosystem. It provides a composable, tick-based execution model where complex AI decision-making logic is assembled from simple, reusable node primitives — sequences, selectors, decorators, and leaf actions. Unlike standalone behavior tree libraries, Jido BehaviorTree integrates directly with Jido Actions and the Jido Agent strategy system, allowing behavior trees to drive autonomous agent workflows with first-class state management, effect handling, and telemetry.

The package bridges the gap between traditional game-AI behavior trees and modern agentic systems. Trees can be executed standalone, managed by a GenServer-based agent for stateful multi-tick workflows, or plugged directly into a Jido Agent as an execution strategy.

## Purpose

Jido BehaviorTree serves as the decision-making strategy layer for Jido agents. It provides a structured, deterministic way to compose complex agent behaviors from simple building blocks — functioning as a standalone engine, a Jido Agent Strategy, and an AI tool bridge via the Skill wrapper.

## Major Components

### Core Engine
Main public API for creating trees, executing ticks, starting agents, and wrapping trees as skills. Includes Tree structure management, Node behaviour with telemetry spans, Status type system, Tick execution context, and Blackboard shared data store.

### Composite Nodes
Sequence (execute children in order, fail on first failure) and Selector (try children until one succeeds). Both support resumption from running children across ticks.

### Decorator Nodes
Inverter (flip success/failure), Succeeder (always succeed), Failer (always fail), and Repeat (repeat N times).

### Leaf Nodes
Action (execute a Jido Action with blackboard parameter resolution), Wait (time-based delay), and SetBlackboard (set key-value pairs).

### Execution & Integration
GenServer-based Agent for persistent multi-tick execution, Skill wrapper for AI/LLM tool compatibility, and Jido Agent Strategy implementation for strategy-driven workflows.
