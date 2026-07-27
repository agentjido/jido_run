defmodule AgentJido.Specs.ThreatControlModelReviewTest do
  @moduledoc """
  Threat-and-control model review after a material architecture change
  (jido-e12-t50).

  Acceptance condition: *A changed trust boundary creates a documentation and
  proof review.*

  The threat-and-control model lives in `specs/operations-reference-architecture.md`
  — its documented trust boundaries. Each boundary carries a recorded content
  signature and last-reviewed date in
  `specs/audits/trust-boundary-baseline.md`. `AgentJido.ThreatControlModel` is
  the event-triggered counterpart of the quarterly operational-control proof
  audit (`AgentJido.OperationalControlProof`, jido-e12-t49) and the quarterly
  message review (`AgentJido.MessageReview`, jido-e12-t36): those fire on the
  calendar; this fires when a boundary's documented prose changes.

  This contract locks:
    * the documented boundary set (`boundaries/0`);
    * the signature extractor (`signature/1`, `signatures/1`);
    * the baseline parser (`baseline_from/1`);
    * the change predicate (`changed?/2`);
    * the review queue (`review_queue/1`) — each changed boundary creates BOTH a
      documentation review and a proof review (the acceptance);
    * the baseline regenerator (`to_baseline_markdown/1`) — round-trips and
      resets the change trigger.
  """

  use ExUnit.Case, async: true

  alias AgentJido.OperationalControlProof
  alias AgentJido.ThreatControlModel, as: Model

  # A synthetic reference architecture exercising every boundary heading at its
  # real level, with a peer heading after each so section extraction terminates.
  @architecture """
  # Reference Architecture

  ## Recovery boundaries
  process, app, node, and deployment restarts differ by what dies and what survives.

  ## Controlled-agent extension
  the nine-element controlled-agent design.

  ### What stays outside Jido
  authentication, identity, audit, durable retention, and compliance stay outside jido.

  ### Authentication boundary
  jido carries and honors a principal but never verifies one.

  ## Threat and control model
  | asset | threat | control |
  |---|---|---|
  | tools | misuse | allowlist |

  ## Explicit non-goals
  not tamper-evident history, no downtime.

  ## After
  """

  # Every claim the synthetic boundaries map to.
  @claims [
    %{claim: "Supervised lifecycle"},
    %{claim: "Fail-closed authorization"},
    %{claim: "Causal history"},
    %{claim: "Correlated telemetry"},
    %{claim: "Cost/quota control"}
  ]

  # --- documented boundary set ----------------------------------------------

  describe "boundaries/0 (jido-e12-t50)" do
    test "records every documented trust boundary with its heading and proof claims" do
      boundaries = Model.boundaries()

      ids = Enum.map(boundaries, & &1.id)

      assert ids == [:authentication, :recovery, :outside_jido, :threat_control, :non_goals],
             "the documented trust boundaries are fixed"

      for boundary <- boundaries do
        assert is_atom(boundary.id)
        assert is_binary(boundary.name) and boundary.name != ""
        assert boundary.level in 1..6
        assert is_list(boundary.proof_claims) and boundary.proof_claims != []
      end
    end

    test "every boundary heading is present in the reference architecture" do
      # Loud, current-state control: each boundary's section is findable in the
      # real architecture document, so a signature is actually computed (not the
      # empty string). This only changes when a heading is renamed, at which
      # point the heading text in boundaries/0 is the work item.
      for boundary <- Model.boundaries() do
        sig = Model.signature(boundary)

        assert sig != "",
               "boundary #{inspect(boundary.name)} heading not found in the architecture"
      end
    end

    test "every mapped proof claim resolves to a real operational-control claim" do
      # A boundary's proof review points at claims in specs/proof.md. Every
      # mapped name must be a real recorded claim, or the review would send the
      # reviewer to a claim that does not exist.
      known = OperationalControlProof.claims() |> MapSet.new(& &1.claim)

      for boundary <- Model.boundaries(),
          claim <- boundary.proof_claims do
        assert MapSet.member?(known, claim),
               "boundary #{inspect(boundary.name)} maps to unknown proof claim #{inspect(claim)}"
      end
    end
  end

  # --- signature extraction -------------------------------------------------

  describe "signature/1 and signatures/1 (jido-e12-t50)" do
    test "a boundary signature is the normalized prose of its section" do
      sigs = Model.signatures(architecture: @architecture)

      assert sigs[:authentication] =~ "jido carries and honors a principal but never verifies one"
      assert sigs[:recovery] =~ "process, app, node, and deployment restarts differ"
      assert sigs[:outside_jido] =~ "authentication, identity, audit"
      assert sigs[:threat_control] =~ "tools"
      assert sigs[:non_goals] =~ "not tamper-evident history"
    end

    test "signatures are case- and whitespace-insensitive in the body" do
      # Heading names are matched verbatim (so a rename is a real change), but
      # the body is normalized: case and whitespace drift do not flip a
      # signature, only a wording change does.
      loud =
        String.replace(
          @architecture,
          "jido carries and honors a principal but never verifies one.",
          "JIDO   carries\tand honors a principal but never verifies ONE."
        )

      assert Model.signatures(architecture: @architecture)[:authentication] ==
               Model.signatures(architecture: loud)[:authentication]
    end

    test "a section stops at the next peer heading, including its sub-headings" do
      # The recovery section (level 2) includes its own prose but stops before
      # the next level-2 section; the authentication section (level 3) stops at
      # the next level-2 section that follows it.
      sigs = Model.signatures(architecture: @architecture)

      # The threat-control table leaked out of recovery? It must not.
      refute sigs[:recovery] =~ "allowlist"
      # Authentication must not swallow the threat-control table.
      refute sigs[:authentication] =~ "allowlist"
    end

    test "a missing heading yields an empty signature" do
      sigs = Model.signatures(architecture: "# Nothing here\n")
      assert sigs[:authentication] == ""
    end
  end

  # --- baseline parser ------------------------------------------------------

  describe "baseline_from/1 (jido-e12-t50)" do
    test "parses a rendered baseline back into signatures and dates" do
      rendered = Model.to_baseline_markdown(architecture: @architecture, last_reviewed: ~D[2026-01-02])
      parsed = Model.baseline_from(rendered)

      assert Map.keys(parsed) |> Enum.sort() ==
               [:authentication, :non_goals, :outside_jido, :recovery, :threat_control]

      assert parsed[:authentication].last_reviewed == ~D[2026-01-02]
      assert parsed[:authentication].signature =~ "jido carries and honors a principal"
    end

    test "ignores baseline sections that are not documented boundaries" do
      rendered =
        Model.to_baseline_markdown(architecture: @architecture, last_reviewed: ~D[2026-01-02]) <>
          "\n## Future boundary\n- **Signature:** x\n- **Last reviewed:** 2026-01-02\n"

      parsed = Model.baseline_from(rendered)

      assert Map.keys(parsed) |> Enum.sort() ==
               [:authentication, :non_goals, :outside_jido, :recovery, :threat_control]
    end

    test "a malformed last-reviewed date parses to nil" do
      rendered =
        Model.to_baseline_markdown(architecture: @architecture, last_reviewed: ~D[2026-01-02])
        |> String.replace("2026-01-02", "last quarter")

      parsed = Model.baseline_from(rendered)
      assert parsed[:authentication].last_reviewed == nil
    end
  end

  # --- change predicate -----------------------------------------------------

  describe "changed?/2 (jido-e12-t50: the trigger)" do
    test "an unchanged boundary is not changed" do
      baseline = Model.to_baseline_markdown(architecture: @architecture, last_reviewed: ~D[2026-01-02])

      for boundary <- Model.boundaries() do
        refute Model.changed?(boundary, architecture: @architecture, baseline: baseline),
               "an unchanged boundary must not be flagged as changed"
      end
    end

    test "a boundary whose documented prose changed is changed" do
      baseline = Model.to_baseline_markdown(architecture: @architecture, last_reviewed: ~D[2026-01-02])

      edited =
        String.replace(
          @architecture,
          "jido carries and honors a principal but never verifies one.",
          "jido now authenticates the principal itself."
        )

      auth = Enum.find(Model.boundaries(), &(&1.id == :authentication))

      assert Model.changed?(auth, architecture: edited, baseline: baseline),
             "a changed authentication boundary is the material architecture change"

      # An unchanged boundary is still unchanged alongside the changed one.
      recovery = Enum.find(Model.boundaries(), &(&1.id == :recovery))
      refute Model.changed?(recovery, architecture: edited, baseline: baseline)
    end

    test "a boundary with no recorded baseline is changed" do
      auth = Enum.find(Model.boundaries(), &(&1.id == :authentication))

      assert Model.changed?(auth, architecture: @architecture, baseline: ""),
             "a new or never-reviewed boundary is changed (no recorded baseline)"
    end
  end

  # --- review queue: documentation + proof review (the acceptance) ----------

  describe "review_queue/1 (jido-e12-t50)" do
    test "is empty when no boundary has changed" do
      baseline = Model.to_baseline_markdown(architecture: @architecture, last_reviewed: ~D[2026-01-02])

      assert Model.review_queue(
               architecture: @architecture,
               baseline: baseline,
               claims: @claims
             ) == []
    end

    test "a changed trust boundary creates a documentation AND proof review" do
      baseline = Model.to_baseline_markdown(architecture: @architecture, last_reviewed: ~D[2026-01-02])

      edited =
        String.replace(
          @architecture,
          "authentication, identity, audit, durable retention, and compliance stay outside jido.",
          "jido now owns authentication and durable retention."
        )

      queue =
        Model.review_queue(architecture: edited, baseline: baseline, claims: @claims)

      # Only the changed boundary (outside_jido) is on the queue.
      assert length(queue) == 1
      [entry] = queue
      assert entry.boundary.id == :outside_jido

      # --- the documentation review ---
      doc = entry.documentation_review
      assert Map.keys(doc) |> Enum.sort() == [:instruction, :target]
      assert doc.target =~ "operations-reference-architecture"
      assert doc.instruction =~ "threat-and-control model"

      # --- the proof review ---
      proof = entry.proof_review
      assert Map.keys(proof) |> Enum.sort() == [:claims, :instruction, :missing_claims, :target]
      assert proof.target =~ "proof.md"
      assert proof.instruction =~ "seven proof fields"
      # The boundary's mapped claims are carried, and all resolve against @claims.
      assert proof.claims == entry.boundary.proof_claims
      assert proof.missing_claims == []
    end

    test "the proof review flags a mapped claim that no longer exists in the proof" do
      # Empty baseline: every boundary is changed (new/never reviewed) and so
      # surfaces on the queue. With an empty claim set, every mapped claim is
      # missing — exactly what a reviewer must catch before re-verifying.
      queue =
        Model.review_queue(
          architecture: @architecture,
          baseline: "",
          claims: []
        )

      assert length(queue) == length(Model.boundaries())

      for entry <- queue do
        assert entry.proof_review.missing_claims == entry.boundary.proof_claims
      end
    end

    test "a boundary with no recorded baseline is reviewed as new or never reviewed" do
      [entry] =
        Model.review_queue(
          architecture: @architecture,
          baseline: "",
          claims: @claims
        )
        |> Enum.filter(&(&1.boundary.id == :authentication))

      assert entry.reason =~ "no recorded baseline"
      assert is_nil(entry.baseline_signature)
      assert is_nil(entry.last_reviewed)
    end

    test "every queue entry carries the documented review keys" do
      queue =
        Model.review_queue(
          architecture: @architecture,
          baseline: "",
          claims: @claims
        )

      for entry <- queue do
        assert Map.keys(entry) |> Enum.sort() ==
                 [
                   :baseline_signature,
                   :boundary,
                   :current_signature,
                   :documentation_review,
                   :last_reviewed,
                   :proof_review,
                   :reason
                 ]

        assert entry.current_signature != ""
        assert is_binary(entry.reason)
      end
    end

    test "review_due?/1 mirrors the queue" do
      baseline = Model.to_baseline_markdown(architecture: @architecture, last_reviewed: ~D[2026-01-02])

      refute Model.review_due?(architecture: @architecture, baseline: baseline, claims: @claims)

      assert Model.review_due?(architecture: @architecture, baseline: "", claims: @claims)
    end
  end

  # --- baseline regeneration ------------------------------------------------

  describe "to_baseline_markdown/1 (jido-e12-t50: reset the trigger)" do
    test "round-trips: rendered baseline parses back to the current signatures" do
      sigs = Model.signatures(architecture: @architecture)

      rendered = Model.to_baseline_markdown(architecture: @architecture, last_reviewed: ~D[2026-01-02])
      parsed = Model.baseline_from(rendered)

      for {id, current} <- sigs do
        assert parsed[id].signature == current,
               "regenerated baseline signature for #{id} must match the current signature"
      end
    end

    test "applying a regenerated baseline resets the change trigger" do
      baseline = Model.to_baseline_markdown(architecture: @architecture, last_reviewed: ~D[2026-01-02])

      assert Model.review_queue(architecture: @architecture, baseline: baseline, claims: @claims) == []
    end
  end

  # --- current state (real files) -------------------------------------------

  describe "current state (real files)" do
    test "no trust boundary is currently changed — the baseline matches the architecture" do
      # Loud, current-state control: today the recorded baseline matches the
      # reference architecture, so no review is due. This changes only when the
      # architecture edits a boundary, at which point the changed boundary (with
      # its documentation and proof review) is the work item — and the fix is to
      # run the review, then refresh specs/audits/trust-boundary-baseline.md via
      # to_baseline_markdown/1.
      assert Model.review_queue(claims: OperationalControlProof.claims()) == []
      refute Model.review_due?(claims: OperationalControlProof.claims())
    end
  end
end
