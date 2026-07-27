%{
  description: "Find the right docs for what you're building - from first steps to production operations with Jido.",
  title: "Documentation",
  category: :docs,
  legacy_paths: ["/docs/overview"],
  tags: [:docs, :navigation],
  order: 1
}
---

Everything you need to build and run multi-agent systems with Jido - from your first agent to production deployment.

## Find what you need

**Want to build your first agent?**
Start with [Getting Started](/docs/getting-started) for installation, setup, and your first working agent.

**Want to learn step by step?**
Work through [Learn](/docs/learn) for progressive tutorials that build on each other.

**Need to understand how Jido thinks?**
Read [Concepts](/docs/concepts) for the mental model - agents, actions, workflows, signals, and how they fit together.

**Have a specific task to implement?**
Check [Guides](/docs/guides) for focused patterns like tool integration, state management, and multi-agent coordination.

**Contributing across the ecosystem?**
Go to [Contributors](/docs/contributors) for contributor-facing package standards, shared checklists, and release workflow expectations.

**Looking for exact APIs or config?**
Go to [Reference](/docs/reference) for complete API docs, configuration options, and architecture details.

**Preparing for or running production?**
Follow the production path below, or open [Operations](/docs/operations) for the full architecture and worked examples.

## Production path

When you are shipping to production or already running there, work through the long-running agent path in order. Each step links to its Operations page; the path resolves to one run that proves the whole thing.

1. **[Define what recovery means](/docs/operations/supervision-and-failure-boundaries)** - OTP supervision restarts a crashed `AgentServer` and bounds failure scope.
2. **[Keep state across restart](/docs/operations/deployment-restart)** - decide what survives a process, application, and deployment restart, with a worked example.
3. **[Handle failure modes](/docs/operations/retries-timeouts-and-provider-failure)** - separate retry, timeout, and fallback for tool, HTTP, and model failures.
4. **[Schedule and observe](/docs/operations/telemetry-and-traces)** - add scheduling or event input, then telemetry and traces.
5. **[Check health and deploy](/docs/operations/health-checks-and-readiness)** - define process, dependency, and work health, and verify after every deploy.

The full proof path resolves to one run: the [Controlled Agent](/examples/controlled-agent) example watches one supervised agent prove the complete control path - who initiated work, what was allowed, what happened, and how failure was handled - in a single run. [Operations](/docs/operations) opens each surface of that path at length.

## New to Jido?

Head to [Getting Started](/docs/getting-started). You'll have a running agent in minutes and a clear path forward from there.

## Next steps

- [Getting Started](/docs/getting-started) - install Jido and build your first agent
- [Concepts](/docs/concepts) - understand the primitives before you go deep
- [Operations](/docs/operations) - the long-running agent path with a worked example at each step
- [Controlled Agent](/examples/controlled-agent) - one supervised run that proves the complete control path
- [Contributors](/docs/contributors) - package standards and contributor workflow
- [Ecosystem](/ecosystem) - explore the full package landscape
