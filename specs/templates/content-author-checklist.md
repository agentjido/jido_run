# Content Author Checklist

Status: Template (`jido-e12` E12-T32). Use this for every new public page or
substantive copy change. It restates the rules in `specs/positioning.md` §11
and `specs/style-voice.md` so new content starts compliant.

## Before you write

- [ ] State the category as "the Elixir framework for long-running agent systems" (not "runtime"/"platform"/"infrastructure").
- [ ] Name the audience: Elixir engineers first.
- [ ] Decide the proof level you can support (design intent / tested behavior / benchmark / production evidence).

## Claims

- [ ] No restricted claims without an approved proof reference: self-healing, no downtime, uptime guarantees, observe everything, secure by default, compliance-ready, enterprise governance, complete audit trail.
- [ ] "production-grade/ready/proven" only with named evidence.
- [ ] "autonomous" only with defined scope, controls, and stop conditions.
- [ ] Qualifiers (reliable, durable, scale, safe, etc.) name the tested behavior or package maturity.
- [ ] "control" names the exact type: lifecycle / capability / authorization / quota / trace / recovery.
- [ ] Telemetry is not an audit log. Agent/Signal/request IDs are correlation, not authenticated principals.

## Surfaces and parity

- [ ] Every internal link resolves (the link audit is at 0; keep it there).
- [ ] No unresolved `{{...}}` placeholders in public Markdown.
- [ ] Machine-facing summaries (`.md`, `llms.txt`) match the human-facing copy.
- [ ] Required packages, keys, and prerequisites are stated before the first code block.

## Metadata

- [ ] `last_validated`, `tested_with`, and owner are set for executable content.
- [ ] The page ends with a "What to do next" block (e.g. "Next steps" / "What to try next") so no reader hits a dead end.

## Before merge

- [ ] `mix format --check-formatted`, `mix compile --warnings-as-errors`, `mix credo --min-priority higher`, `mix test` are green.
- [ ] The automated content gates (link/claim/placeholder/livebook/provider-model/sitemap/skills) pass.
