%{
  description: "Response workflows for runtime incidents and recovery validation.",
  title: "Incident playbooks",
  category: :docs,
  legacy_paths: ["/docs/incident-playbooks", "/docs/reference/incident-playbooks"],
  tags: [:docs, :operations],
  order: 380,
  draft: false
}
---
# Incident Playbooks

Short, repeatable response procedures for the failure modes long-running agent systems hit. Each playbook assumes Jido telemetry and correlation IDs are wired up so you can follow a request from ingress to effect.

## Model or provider outage

1. **Detect:** telemetry shows rising provider errors or timeouts; quotas may trip.
2. **Contain:** the provider-failure path applies bounded retries and your defined fallback (a cheaper model, a cached result, or a safe default). It does not retry without limit.
3. **Investigate:** follow the affected request/run IDs through telemetry to confirm the failure is provider-side, not a tool or Action error.
4. **Recover:** once the provider recovers, confirm the fallback path has switched back and no work was duplicated (idempotency keys).

## Crash loop

1. **Detect:** supervisor restart intensity is exceeded; the `AgentServer` is not staying up.
2. **Contain:** review the restart strategy and the crash reason. A restart fixes process health, not bad state — if persisted or input state is corrupt, restart alone will loop.
3. **Investigate:** read the crash log and the last Action/Signal that ran before the crash.
4. **Recover:** correct the offending state or code, then restart. If the agent restores state from a store, verify the store holds valid state.

## Bad tool output

1. **Detect:** an Action returns a result that downstream logic or a human flags as wrong.
2. **Contain:** typed Action schemas catch malformed output; effect policies can block downstream effects.
3. **Investigate:** use the tool-call ID and trace to see the inputs and the tool result.
4. **Recover:** fix the tool or its inputs. If the effect already ran, use the durable Signal Journal and idempotency to reconcile or replay safely.

## State corruption

1. **Detect:** agent state is inconsistent with expected transitions.
2. **Contain:** stop the affected `AgentServer`. Do not let corrupt state drive further effects.
3. **Investigate:** compare current state against the causal Signal history and persisted state.
4. **Recover:** restore from a known-good state source. Decide explicitly what is reconstructed versus discarded.

## Queue growth and backpressure

1. **Detect:** Signals or tasks back up; mailbox, bus, or provider limits approach.
2. **Contain:** backpressure and queue limits shed or slow work rather than failing the whole node.
3. **Investigate:** identify the slow consumer (a tool, a provider, a downstream effect).
4. **Recover:** scale or throttle the consumer; confirm poison work is moved to a dead-letter path for inspection rather than retried forever.

## After an incident

Capture the request/run/Signal IDs that describe the incident, the control that contained it, and any gap where a control was missing. Turn real incidents into regression tests where possible.

## Next steps

- Confirm the controls these playbooks assume are wired up with the [Production Readiness Checklist](/docs/operations/production-readiness-checklist).
- Map authorization, redaction, and durable-history duties in [Security and governance](/docs/operations/security-and-governance).
- Make sure the [telemetry and correlation IDs](/docs/reference/telemetry-and-observability) each playbook follows are capturing the request/run/Signal chain.
