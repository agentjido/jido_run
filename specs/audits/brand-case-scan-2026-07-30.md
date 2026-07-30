# Jido brand-case scan — 2026-07-30

Task: `jido-e03-t24`

## Scope

The scan covers all published records returned by `AgentJido.Pages.all_pages/0`.
It checks source prose for the lowercase word `jido`.

The scan removes these valid lowercase contexts before it checks prose:

- Frontmatter and metadata
- Fenced and inline code
- Package links to ecosystem, Hex, HexDocs, or agentjido GitHub pages
- URLs and HTML tags

## Result

The first scan found one ambiguous plain-text package reference in
`/docs/operations/telemetry-and-traces`. It now formats `jido` as inline code
and identifies it as the core package.

The final scan found zero lowercase brand uses in published prose.

## Release check

```bash
MIX_ENV=test mix test test/agent_jido/brand_case_lint_test.exs
```
