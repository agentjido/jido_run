%{
  description: "Guardrails for permissions, policy controls, and auditable operation.",
  title: "Security and governance",
  category: :docs,
  legacy_paths: ["/docs/security-and-governance", "/docs/reference/security-and-governance"],
  tags: [:docs, :operations],
  order: 371,
  last_validated: "2026-07-24",
  control_types: [
    :identity_context,
    :authorization,
    :policy,
    :history,
    :observation,
    :approval,
    :redaction
  ],
  control_intent: :evaluate,
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

## Correlation IDs are not authentication

A correlation ID lets an operator follow one unit of work across components. It is never a credential, and it never grants or proves access. The identifiers Jido stamps or carries are correlation metadata, not authenticated principals:

- **Agent ID** — names an agent's lifecycle and profile state so you can find it in telemetry and Journal records.
- **Signal ID** — together with its `trace_id`, `span_id`, and `causation_id`, lets you follow one signal from ingress through its actions and effects.
- **Request, run, and tool-call IDs** — correlate an LLM request and each step of work back to the signal that caused it.

None of these authenticate anyone. Verifying a human or service identity — and the IAM and credential issuance behind it — is an application or platform boundary in front of Jido, not something Jido performs.

The same rule covers a **user ID** or **tenant ID** your application attaches to a Signal. Jido carries that context and propagates it through actions, but it does **not** verify it. A `user_id` or `tenant_id` on a Signal is a claim about who the work is for, supplied and verified at the boundary in front of Jido — treat it as propagated context, not as proof the caller is that user or tenant. Wire `prepare_action/3` to deny a protected action when the required principal or tenant context is missing.

An ID lets you follow work; only an authenticated principal — verified at the application or platform boundary — authorizes it.

## Control points to wire up

- **Authorization:** implement `prepare_action/3` to deny protected Actions before they run when required principal or tenant context is missing. This is a fail-closed extension point, not a built-in RBAC product.
- **AI controls:** configure tool allowlists, effect policies, prompt policies, and request/token quotas through `jido_ai` plugins. A disallowed tool or effect is rejected before execution. The request/token quota side is covered in [Rate Limits and Cost Budgets](/docs/operations/rate-limits-and-cost-budgets).
- **Context propagation:** carry principal, tenant, request, and causation context on the incoming Signal and propagate it through Actions and effects so an operator can follow one unit of work.
- **Durable history:** when you need causal history that survives restart, configure a durable Signal Journal adapter and a retention policy. The default is not durable. The retention window, access control, sensitive fields, and deletion process for that history are all application-owned — see [Journal retention, access, and deletion](/docs/operations/journal-retention-access-and-deletion).
- **Redaction:** define redaction rules for secrets, prompts, tool arguments, results, and principal data in logs, telemetry, Journal entries, and error output.

## Integration posture

Jido integrates with your existing systems; it does not replace them. Plan for an authentication/identity boundary in front of Jido, an authorization policy source your plugins consult, a storage layer for durable history, and a SIEM/telemetry backend for export. Ash-based applications can preserve Ash actor, tenant, and authorization context via `ash_jido`; the host Ash application still enforces authorization.

## What to avoid claiming

Do not state that Jido is "secure by default," "compliance-ready," an "enterprise governance" system, or provides a "complete audit trail" without separate, reviewed proof. These phrases are on the restricted-claim list in `specs/style-voice.md`.

## Next steps

- Confirm every control point is wired up with the [Production Readiness Checklist](/docs/operations/production-readiness-checklist).
- Practice responding when a control fires using the [Incident playbooks](/docs/operations/incident-playbooks).
- Build the controls end to end from the [Operational controls](/docs/getting-started/operational-controls) onboarding lane.
