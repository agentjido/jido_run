%{
  description: "Guardrails for permissions, policy controls, and auditable operation.",
  title: "Security and Governance",
  category: :docs,
  legacy_paths: ["/docs/security-and-governance", "/docs/reference/security-and-governance"],
  tags: [:docs, :operations],
  order: 370,
  draft: false
}
---
# Security and Governance

Jido gives you explicit control points for governing agent work. It does not provide an IAM system, a compliance product, or a tamper-evident audit store. This page maps what Jido supplies to what your application and platform must own.

## Claim boundaries

Keep these distinctions visible to anyone evaluating Jido for governed environments.

| Concept | What Jido supplies | What the application/platform owns |
|---|---|---|
| Identity | Agent lifecycle/profile state and runtime correlation IDs (request, run, Signal, tool-call) | Authentication, verified human or service identity, IAM, credential issuance |
| Authorization | A fail-closed plugin hook (`prepare_action/3`) and AI tool/effect/prompt/quota policies | The policy decision, actor/tenant context, RBAC/ABAC enforcement |
| Audit | An optional durable Signal Journal when explicitly configured | Retention, access control, tamper evidence, export, compliance |
| Observability | Jido telemetry, correlated spans, optional OTel export | Durable audit evidence, incident response, SIEM integration |

Agent IDs, Signal IDs, and trace IDs are **correlation metadata**, not authenticated principals.

## Control points to wire up

- **Authorization:** implement `prepare_action/3` to deny protected Actions before they run when required principal or tenant context is missing. This is a fail-closed extension point, not a built-in RBAC product.
- **AI controls:** configure tool allowlists, effect policies, prompt policies, and request/token quotas through `jido_ai` plugins. A disallowed tool or effect is rejected before execution.
- **Context propagation:** carry principal, tenant, request, and causation context on the incoming Signal and propagate it through Actions and effects so an operator can follow one unit of work.
- **Durable history:** when you need causal history that survives restart, configure a durable Signal Journal adapter and a retention policy. The default is not durable.
- **Redaction:** define redaction rules for secrets, prompts, tool arguments, results, and principal data in logs, telemetry, Journal entries, and error output.

## Integration posture

Jido integrates with your existing systems; it does not replace them. Plan for an authentication/identity boundary in front of Jido, an authorization policy source your plugins consult, a storage layer for durable history, and a SIEM/telemetry backend for export. Ash-based applications can preserve Ash actor, tenant, and authorization context via `ash_jido`; the host Ash application still enforces authorization.

## What to avoid claiming

Do not state that Jido is "secure by default," "compliance-ready," an "enterprise governance" system, or provides a "complete audit trail" without separate, reviewed proof. These phrases are on the restricted-claim list in `specs/style-voice.md`.

## Next steps

- Confirm every control point is wired up with the [Production Readiness Checklist](/docs/operations/production-readiness-checklist).
- Practice responding when a control fires using the [Incident playbooks](/docs/operations/incident-playbooks).
- Build the controls end to end from the [Operational controls](/docs/getting-started/operational-controls) onboarding lane.
