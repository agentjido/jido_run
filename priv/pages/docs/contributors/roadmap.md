%{
  title: "Roadmap",
  description: "Current milestone, next milestone, and active epics shaping the Jido ecosystem.",
  category: :docs,
  legacy_paths: [],
  tags: [:docs, :contributors, :roadmap],
  order: 15,
  menu_label: "Roadmap"
}
---

This page is about sequencing and emphasis. Use [Package Support Levels](/docs/contributors/package-support-levels) for maintenance commitments and [Ecosystem Atlas](/docs/contributors/ecosystem-atlas) for current package ownership and status.

## Major Milestones

| Milestone | Status | Lead | Goal |
| --- | --- | --- | --- |
| Post-release consolidation | `Current` | Jido team | Absorb feedback from the recent major release, close follow-up gaps, and settle the ecosystem into a cleaner operating shape. |
| Ship the next wave of packages | `Next` | Jido team | Move the next public package set to Hex and make the broader ecosystem easier to adopt end to end. |
| Durability and persistence | `Upcoming` | Mike Hostetler | Build the durability story for persisting Jido agents and their runtime state. |
| Observability and UI | `Upcoming` | Jido team | Bring current UI and observability work into a clearer operator experience. |

## Current Milestone

`Post-release consolidation` is the current focus. The priority is healthy post-release work: process feedback, tighten rough edges, clarify package boundaries, and reduce ambiguity created by rapid ecosystem growth.

- absorb release feedback from users and the community
- fix high-value follow-up issues and documentation gaps
- clarify package positioning and support expectations
- turn release momentum into stability and clarity

## Next Milestone

`Ship the next wave of packages` is the next major push. The immediate emphasis is making more of the ecosystem publicly consumable without requiring contributors or adopters to track private context.

- ship the `jido_chat` and `jido_messaging` stack
- ship the `jido_harness` family and CLI adapter stack
- ship integration and runtime packages that are already close to release shape

## Planned packages

Some packages are planned but not yet released or tested. They are future work and do not support any current operational-control claim until they ship.

- **`jido_identity`** — a separate package that would factor identity storage and IAM out of core Jido. It is planned future work, not yet released or tested; until it ships, identity storage, authentication, and IAM stay an application and platform responsibility. See the [Security and governance](/docs/operations/security-and-governance) identity boundary for what the current operational-control proof does and does not include.

## Active Epics

### Durability and Persistence

This is Mike Hostetler's primary personal epic. The goal is to make persistence a first-class part of the platform: durable agent state, state that survives runtime sessions, and a coherent long-term storage story across the ecosystem.

### Observability and UI

This epic combines `jido_live_dashboard` and `jido_studio` into a clearer observability and UI direction so runtime inspection, debugging, and operator workflows are easier in practice.

## How to Read This Page

- Roadmap priority is not the same thing as support level. A `Stable` package can be in steady maintenance while a `Beta` package gets more day-to-day focus.
- Roadmap priority is not the same thing as package ownership. Ownership stays with the package lead listed in the [Ecosystem Atlas](/docs/contributors/ecosystem-atlas).
- Use the roadmap to answer "what is moving now," not "what does Stable mean."

## Next Steps

- [Ecosystem Atlas](/docs/contributors/ecosystem-atlas) - see which public packages sit inside each focus area
- [Contributing](/docs/contributors/contributing) - find the current contribution lanes
- [Package Support Levels](/docs/contributors/package-support-levels) - separate roadmap timing from support commitments
