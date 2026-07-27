%{
  title: "Package support levels",
  description: "Canonical public support taxonomy for Jido ecosystem packages and what Stable, Beta, and Experimental mean operationally.",
  category: :docs,
  legacy_paths: [],
  tags: [:docs, :contributors, :support, :ecosystem],
  order: 5,
  menu_label: "Package Support Levels",
  doc_type: :reference,
  audience: :intermediate
}
---

This page defines Jido's public support levels. It exists so contributors, maintainers, and users can distinguish between packages the project is ready to stand behind operationally and packages that are still being shaped in public.

Use this page as the canonical policy reference when labeling ecosystem packages, writing roadmap copy, reviewing contributor docs, or deciding what a package page should claim about long-term support.

## Support Levels

| Level | Meaning | Project Commitment |
| --- | --- | --- |
| `Stable` | Public package intended for production use. APIs should move carefully and predictably. | We maintain dependencies, fix bugs and compatibility issues, keep documentation and examples usable, and continue improving the package without unnecessary churn. |
| `Beta` | Architecturally defined, usable, and close to release shape, but still gathering feedback before long-term guarantees are locked down. | We refine the package in public, respond to feedback, improve examples and onboarding, and accept that some APIs may still change as real usage arrives. |
| `Experimental` | Early work, active exploration, or research-oriented package design where the shape is not yet settled. | Anything can change. Experimental work may be rewritten, archived, or removed entirely if it does not prove out. |

## What This Label Is And Is Not

- A support level is a maintenance commitment, not a packaging status. A package can be `Stable` and still be `unreleased` on Hex while release work is finishing.
- A support level is not a roadmap priority. The roadmap answers what is moving now. The support label answers what kind of long-term commitment the project is making.
- Current package assignments live in the [Ecosystem Atlas](/docs/contributors/ecosystem-atlas), not on this policy page.

## Why These Levels Exist

Jido explores a lot of ideas in public. Some become long-term ecosystem commitments and some remain exploratory. These levels make that boundary explicit so people can distinguish between active experimentation and packages the project is prepared to support over time.

This page is intentionally about definitions, not package-by-package status. Roadmap sequencing and package assignments can change. The meaning of `Stable`, `Beta`, and `Experimental` should not.

## How To Use This Taxonomy

- Every public ecosystem package should carry one public `support_level` in site metadata.
- Ecosystem pages should use that metadata consistently instead of redefining the terms in local copy.
- Contributor-facing docs should link here when they need the canonical meaning of a support label.
- Package-specific commitments belong on ecosystem entries and roadmap material, not in this policy page.

## When To Use Each Label

- Use `Stable` when the project is prepared to maintain the package as part of the supported public ecosystem and move the API carefully.
- Use `Beta` when the package has a clear architectural direction and is being refined in public with room for release-shaping feedback.
- Use `Experimental` when the design is still exploratory and the project is not yet making a durability commitment.

## Operational Meaning

### `Stable` is a maintenance commitment

Declaring a package `Stable` means the project is taking on ongoing release management, compatibility upkeep, documentation quality, and user support responsibilities for that package.

### `Beta` is a public iteration commitment

Declaring a package `Beta` means the project is inviting real-world usage and feedback while final release boundaries are still being refined. It is a commitment to iterate in public, not a statement that the package is a rough prototype.

### `Experimental` is an exploration label

Declaring a package `Experimental` means the project is still testing whether the design deserves a durable commitment. It may evolve quickly, be reworked substantially, or disappear if it does not prove out.

## Next Steps

- [Ecosystem Atlas](/docs/contributors/ecosystem-atlas) - see which public packages currently carry each support label
- [Roadmap](/docs/contributors/roadmap) - separate current focus from support commitment
- [Package Quality Standards](/docs/contributors/package-quality-standards) - apply the package review bar alongside support taxonomy
