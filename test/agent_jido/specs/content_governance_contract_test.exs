defmodule AgentJido.Specs.ContentGovernanceContractTest do
  use ExUnit.Case, async: true

  @governance_path Path.expand("../../../specs/content-governance.md", __DIR__)
  @specs_readme_path Path.expand("../../../specs/README.md", __DIR__)

  test "content governance defines ST-CONT-001 publish DoD hard gate" do
    governance = File.read!(@governance_path)

    assert governance =~ "## 11) Canonical Content Publish Definition of Done (ST-CONT-001)"
    assert governance =~ "**Proof alignment requirement.**"
    assert governance =~ "**Placeholder prohibition.**"
    assert governance =~ "**Route/content sync requirement.**"
    assert governance =~ "**Draft-flag removal gate criteria.**"
  end

  test "minimum checks are specified before draft flag removal" do
    governance = File.read!(@governance_path)

    assert governance =~ "### Minimum checks before changing `draft: true` to `draft: false`"
    assert governance =~ "Verify no placeholder markers remain"
    assert governance =~ "Verify all internal links and CTAs resolve"
    assert governance =~ "Verify claims are proof-backed"
    assert governance =~ "Record reviewer sign-off and date"
  end

  test "freshness checklist and cadence are documented and discoverable in specs index" do
    governance = File.read!(@governance_path)
    specs_readme = File.read!(@specs_readme_path)

    assert governance =~ "## 12) Freshness Checklist and Release Cadence (ST-CONT-001)"
    assert governance =~ "### Freshness checklist (required each release window)"
    assert governance =~ "### Release cadence process"

    assert specs_readme =~ "canonical ST-CONT-001 publish hard gate"
  end

  test "quarterly operational-control proof audit is a named cadence step (jido-e12-t49)" do
    governance = File.read!(@governance_path)

    # Acceptance: owners re-verify behavior, versions, limits, and links each
    # quarter. The cadence must name the audit, the four dimensions, owner
    # attribution, the validation-date trigger, and the executable queue.
    assert governance =~ "Quarterly operational-control proof audit"

    assert governance =~ "behavior"
    assert governance =~ "versions"
    assert governance =~ "limits"
    assert governance =~ "links"

    assert governance =~ "owner"
    assert governance =~ "Validation date"
    assert governance =~ "AgentJido.OperationalControlProof.audit_queue/1"
  end

  test "quarterly message review is a named cadence step (jido-e12-t36)" do
    governance = File.read!(@governance_path)

    # Acceptance: position, package roles, proof, and audience are reviewed
    # together each quarter. The cadence must name the four dimensions, the
    # "reviewed together" coherence rule, and the executable review.
    assert governance =~ "Quarterly message review"

    assert governance =~ "position"
    assert governance =~ "package roles"
    assert governance =~ "proof"
    assert governance =~ "audience"

    assert governance =~ "reviewed together"
    assert governance =~ "AgentJido.MessageReview.review_queue/1"
    assert governance =~ "reviewed_together?/1"
  end

  test "trust-boundary change review is a named event-triggered review (jido-e12-t50)" do
    governance = File.read!(@governance_path)

    # Acceptance: a changed trust boundary creates a documentation and proof
    # review. The governance must name the trigger (a changed trust boundary),
    # both reviews (documentation + proof), the baseline, and the executable.
    assert governance =~ "Trust-boundary change review"
    assert governance =~ "material architecture change"
    assert governance =~ "trust boundary"

    assert governance =~ "Documentation review"
    assert governance =~ "Proof review"

    assert governance =~ "specs/audits/trust-boundary-baseline.md"
    assert governance =~ "AgentJido.ThreatControlModel.review_queue/1"
    assert governance =~ "review_due?/1"
  end

  test "governance contract captures publish gate criteria and review evidence" do
    governance = File.read!(@governance_path)

    assert governance =~ "ST-CONT-001"
    assert governance =~ "Proof alignment requirement."
    assert governance =~ "Route/content sync requirement."
    assert governance =~ "Record reviewer sign-off and date"
  end
end
