%{
  title: "Add operational controls",
  description: "The optional onboarding path for authorization, policy, durable history, and telemetry - picked up once your first agent is running.",
  menu_label: "Add operational controls",
  category: :docs,
  order: 45,
  tags: [:docs, :getting_started, :operations, :controls],
  draft: false,
  last_validated: "2026-07-24",
  tested_with: %{jido: "2.3.2", jido_ai: "2.2.0", req_llm: "1.17.1"}
}
---

## An optional path that follows your first agent

[Your first agent](/docs/getting-started/first-agent) defines typed state and actions, and [Your first LLM agent](/docs/getting-started/first-llm-agent) adds model-backed reasoning. **Nothing on this page is required to run a basic agent.** Supervision, typed and validated actions, and the Signal dispatch model are built in, so the agent you already built activates and runs without any of the controls below.

Pick this lane up once your first agent works and you need to govern what it can do before it ships - who may call which action, what a tool is allowed to do, what survives a restart, and what an operator can see. Take only the pieces your system needs; every step here is optional.

## What "operational controls" means here

Operational control is a Jido benefit, not a claim that Jido is a complete governance or compliance platform. Jido gives you explicit control points; your application and platform own the policy decisions, the authenticated identity, and the durable evidence. The [Security and governance](/docs/operations/security-and-governance) page maps each point below to what Jido supplies versus what you own.

The lane is organized around the control surfaces a production agent touches:

- **Principal and tenant context.** Agent, Signal, request, run, and tool-call IDs are correlation metadata, not authenticated principals. Your application supplies the verified identity and tenant; Jido carries that context on the incoming Signal and propagates it through actions.
- **Fail-closed authorization.** The `prepare_action/3` plugin hook runs before an action executes. Implement it to deny a protected action when the required principal or tenant context is missing. It is fail-closed by design - a protected action never runs just because no hook is configured.
- **AI tool and effect policy.** Through `jido_ai` plugins you can set tool allowlists, effect policies, prompt policies, and request or token quotas. A disallowed tool or effect is rejected before it runs.
- **Correlated telemetry with redaction.** Jido emits telemetry and correlated spans for understanding your system. Define redaction rules so secrets, prompts, and principal data stay out of logs, telemetry, and error output. Telemetry is for observation - it is not an audit log.
- **Optional durable history.** When you need causal history that survives a restart, choose a durable Signal Journal adapter and a retention policy. The default is not durable; nothing is retained until you choose an adapter, and what survives a restart is decided by that choice - the default keeps nothing, while a durable adapter keeps recorded signals across a journal restart.

## How to take this lane

This page is the onboarding entry point for the control path. The control surfaces above are documented today; a single end-to-end controlled-Agent reference - one application that carries principal and causal context from ingress through an allowed and a denied action - is being published on the [Operations](/docs/operations) path.

Work the lane in this order, naming what Jido supplies and what your application owns at each step:

1. Read [Security and governance](/docs/operations/security-and-governance) for the full claim boundaries and control-point list.
2. Carry principal and tenant context on your incoming Signal so an operator can follow one unit of work across components.
3. Implement `prepare_action/3` to reject one protected action, then permit an approved path. The [production readiness checklist](/docs/operations/production-readiness-checklist) states the fail-closed expectation.
4. Choose a Signal Journal adapter and see what survives a restart. The default is not durable - a recorded signal is gone after a restart - so decide what must survive, then add a [Persistence](/docs/concepts/persistence) or Signal Journal adapter for that slice of state. The tested example behind this step contrasts the default with a durable adapter to show exactly what a restart keeps and drops.
5. Add telemetry spans and redaction rules before you expose the agent to real traffic.

## What this lane does not do

- **It does not add authentication.** Authentication is an application or platform boundary in front of Jido; Jido carries the context you give it.
- **It does not make telemetry tamper-evident.** Durable, tamper-evident audit history needs a configured Journal and a storage layer you operate.
- **It does not block basic activation.** Every step here is optional. The core agent runs without any of it.

## Next steps

- [Your first agent](/docs/getting-started/first-agent) - the working agent this lane builds on.
- [Security and governance](/docs/operations/security-and-governance) - the full control-point map and claim boundaries.
- [Operations](/docs/operations) - supervision, persistence, recovery, and the controlled-Agent reference path.
- [Production readiness checklist](/docs/operations/production-readiness-checklist) - the pre-launch gate these controls plug into.
