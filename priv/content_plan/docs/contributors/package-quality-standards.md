%{
  priority: :critical,
  status: :outline,
  title: "Package Quality Standards",
  repos: ["jido", "req_llm", "llm_db", "jido_action", "jido_signal"],
  tags: [:docs, :contributors, :quality, :policy],
  audience: :intermediate,
  content_type: :reference,
  destination_collection: :pages,
  destination_route: "/docs/contributors/package-quality-standards",
  ecosystem_packages: ["jido", "req_llm", "llm_db", "jido_action", "jido_signal"],
  learning_outcomes: ["Audit a package against the shared Jido quality baseline",
   "Verify required repo structure, quality gates, and release workflow expectations",
   "Use a canonical checklist for contributor onboarding and PR review",
   "Apply worktree-safe git hook and release-tooling patterns"],
  order: 10,
  prerequisites: ["docs/contributors/_hub"],
  purpose: "Canonical contributor-facing checklist for Jido ecosystem package quality, CI, documentation coverage, and GitOps-style release readiness",
  related: ["docs/contributors/ecosystem-atlas", "docs/contributors/package-support-levels",
   "docs/reference/configuration", "docs/guides/testing-agents-and-actions", "ecosystem/overview"],
  source_files: ["GENERIC_PACKAGE_QA.md"],
  prompt_overrides: %{
    document_intent: "Create the canonical package standards page contributors and agents should use to verify Jido ecosystem package quality requirements.",
    required_sections: ["Fast Path Checklist", "How to use this page", "Package Structure", "Shared Building Blocks", "Quality Gates", "Release Workflow", "Contributor Checklists"],
    must_include: ["Short explanation that quality standards are distinct from support levels",
     "Explicit `mix quality` policy", "GitOps-style release workflow expectations",
     "`CHANGELOG.md` is generated from Git history during release and should not be modified in normal PRs",
     "Contributor checklists for new packages, first release, and ongoing maintenance",
     "Worktree-safe git hook guidance with explicit install rather than compile-time auto-install"],
    must_avoid: ["Package-specific implementation details that belong in per-repo docs"],
    required_links: ["/docs/contributors", "/docs/contributors/ecosystem-atlas",
     "/docs/contributors/package-support-levels", "/docs/reference", "/ecosystem"],
    min_words: 900,
    max_words: 2200,
    minimum_code_blocks: 3,
    diagram_policy: "none",
    section_density: "standard",
    max_paragraph_sentences: 3
  }
}
---
## Content Brief

Canonical checklist and standards page for public Jido ecosystem packages. This should be usable as both a contributor handoff document and an agent-verifiable policy page.

### Validation Criteria

- Includes a fast review path near the top
- Distinguishes quality standards from support level and package roster pages
- Covers repo structure, quality gates, docs coverage, CI, and release workflow
- States that `CHANGELOG.md` is generated from Git history during release and should not be edited in normal PRs
- Captures worktree-safe git hook and local tooling expectations
- States the canonical package policies clearly enough to link from PRs
- Includes actionable checklists, not just prose
