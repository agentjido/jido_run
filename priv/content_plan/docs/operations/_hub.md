%{
  priority: :critical,
  status: :outline,
  title: "Operations Hub",
  repos: ["jido"],
  tags: [:docs, :operations, :navigation, :hub],
  audience: :intermediate,
  content_type: :guide,
  destination_collection: :pages,
  destination_route: "/docs/operations",
  ecosystem_packages: ["jido"],
  learning_outcomes: ["Navigate production operations guides by topic",
   "Find the right operations guide for current production challenge"],
  order: 1,
  prerequisites: ["docs/concepts/agent-runtime"],
  purpose: "Section root that organizes production operations, reliability, and security guides",
  related: ["docs/operations/production-readiness-checklist", "docs/operations/security-and-governance",
   "docs/operations/incident-playbooks"],
  prompt_overrides: %{
    document_intent: "Create the operations section hub that organizes production ops and reliability guides.",
    required_sections: ["Overview", "Operations Guide Index"],
    must_include: ["One-line description of each operations guide",
     "Clear grouping by operational concern"],
    must_avoid: ["Duplicating content from individual guides", "Long prose"],
    required_links: ["/docs/operations/production-readiness-checklist", "/docs/operations/security-and-governance",
     "/docs/operations/incident-playbooks"],
    min_words: 200,
    max_words: 500,
    minimum_code_blocks: 0,
    diagram_policy: "none",
    section_density: "minimal",
    max_paragraph_sentences: 2
  }
}
---
## Content Brief

Section root for Operations. Organizes production operations, reliability, and security guides for running Jido agents in production.

### Validation Criteria

- Each operations guide has a one-line description and link
- Guides are grouped by operational concern (readiness, security, incidents, recovery)
- Hub helps users quickly find the right guide for their production challenge
