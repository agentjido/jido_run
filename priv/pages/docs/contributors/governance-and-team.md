%{
  title: "Governance and team structure",
  description: "How Jido makes decisions, assigns package ownership, and organizes cross-cutting teams.",
  category: :docs,
  legacy_paths: [],
  tags: [:docs, :contributors, :governance, :team],
  order: 25,
  menu_label: "Governance & Team"
}
---

Jido uses a lightweight [BDFL](https://en.wikipedia.org/wiki/Benevolent_dictator_for_life) model with explicit repository ownership. The goal is clear responsibility, not bureaucracy: one final decision maker for ecosystem direction, named stewards for repositories, and small cross-cutting teams that can support the whole project.

## Governance Model

Mike Hostetler is the [BDFL](https://en.wikipedia.org/wiki/Benevolent_dictator_for_life) of Jido. In practice, that means Mike is responsible for:

- overall direction of the ecosystem
- package placement and structural decisions
- package standards and contributor policy
- appointing, confirming, or replacing repository owners and team leads
- making final decisions when there is disagreement or ambiguity

## Repository Ownership

Each public repository should have one clearly named owner or tech lead. That roster lives in the [Ecosystem Atlas](/docs/contributors/ecosystem-atlas).

The owner or tech lead is responsible for:

- day-to-day stewardship of the package
- pull request and issue responsiveness
- keeping package docs reasonably current
- coordinating with ecosystem standards and direction

Owners do not need to do all the work themselves, but there should be one clearly accountable person for each repository.

## Cross-Cutting Teams

Jido also has cross-cutting teams that can help across repositories without owning every package directly.

| Group | Lead | Scope |
| --- | --- | --- |
| Jido ecosystem | Mike Hostetler | Final direction, package placement, standards, appointments, and final decisions |
| Repository owners / tech leads | One person per repository | Day-to-day stewardship of a specific package |
| Documentation team | `TBD` | Website, package docs, tutorials, examples, and contributor-facing docs |
| Community team | `TBD` | Community presence, social media, curation, and helping people connect to the ecosystem |

## How Owners and Teams Relate

- Package owners remain responsible for the health of their own repositories.
- The documentation team can improve docs across packages without owning those packages.
- The community team can support the ecosystem without owning code repositories.
- Mike provides the final coordination layer when boundaries are unclear.

## Inactive Ownership

Ownership is volunteer work and not a permanent lock-in. If an owner steps away or becomes inactive, Mike can:

- serve as interim owner
- appoint or recruit a new owner
- move the package back under direct stewardship
- archive the package if that is the right outcome

The main requirement is clarity about who is actively stewarding what.

## Next Steps

- [Ecosystem Atlas](/docs/contributors/ecosystem-atlas) - see the current package-owner roster
- [Contributing](/docs/contributors/contributing) - understand how contributors grow into stewardship
- [Community](/community) - find the social and collaboration entry point
