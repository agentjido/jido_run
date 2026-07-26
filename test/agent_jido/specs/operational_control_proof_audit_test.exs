defmodule AgentJido.Specs.OperationalControlProofAuditTest do
  @moduledoc """
  Quarterly operational-control proof audit (jido-e12-t49).

  Acceptance condition: *Owners verify current behavior, versions, limits, and
  links* — each quarter.

  The operational-control proof lives in `specs/proof.md` (the "Control Proof
  Fields" section, schema enforced by the sibling jido-e12-t38 proof gate and
  jido-e12-t44 release gate). Each claim's validation date records when its
  owner last verified it. `AgentJido.OperationalControlProof.audit_queue/1` is
  the quarterly audit queue — the operational-control counterpart of the 90-day
  critical review queue (`AgentJido.Pages.critical_review_queue/1`, jido-e12-t15).
  When a claim's validation date drifts past a quarter, it becomes assigned work
  attributed to its owner, who re-verifies behavior, versions, limits, and links.

  This contract locks:
    * the proof parser (`claims/0`);
    * the four-dimension verification (`verification/1`) — with negative controls
      proving each dimension fails independently;
    * the quarterly freshness predicate (`stale?/2`);
    * the audit queue (`audit_queue/1`) — assigned owner work, deterministic.
  """

  use ExUnit.Case, async: true

  alias AgentJido.Ecosystem
  alias AgentJido.OperationalControlProof, as: Proof

  # --- parser ---------------------------------------------------------------

  describe "claims/0 (jido-e12-t49)" do
    test "records every operational-control claim with its seven proof fields" do
      claims = Proof.claims()

      assert claims != [],
             "specs/proof.md must record at least one operational-control claim"

      for claim <- claims do
        for key <-
              ~w(claim control_point configuration test limitation owner version validation_date)a do
          assert Map.has_key?(claim, key),
                 "claim #{inspect(claim.claim)} is missing the #{key} field"

          assert claim[key] != nil and String.trim(claim[key]) != "",
                 "claim #{inspect(claim.claim)} has an empty #{key} field"
        end

        # The validation date must be a real ISO date — it drives the audit.
        assert {:ok, _} = Date.from_iso8601(claim.validation_date),
               "claim #{inspect(claim.claim)} validation_date is not an ISO date: " <>
                 inspect(claim.validation_date)
      end
    end

    test "claims_from/1 parses a synthetic Control Proof Fields section" do
      proof = """
      # Jido Proof Inventory

      ## Control Proof Fields (`jido-e12` T38)

      Every operational-control claim names its proof fields.

      ### Synthetic claim
      - **Control point:** a linked process.
      - **Configuration:** `restart: :permanent`.
      - **Test:** `test/agent_jido/demos/controlled_agent_test.exs`.
      - **Limitation:** process only, not state.
      - **Owner:** Platform owner.
      - **Version:** jido 2.3.2 (Stable).
      - **Validation date:** 2026-07-24.

      ## After
      """

      [claim] = Proof.claims_from(proof)

      assert claim.claim == "Synthetic claim"
      assert claim.owner == "Platform owner"
      assert claim.version =~ "jido"
      assert claim.validation_date == "2026-07-24"
    end

    test "claims_from/1 returns [] when there is no Control Proof Fields section" do
      assert Proof.claims_from("# Nothing\n\nto see here\n") == []
    end
  end

  # --- four-dimension verification -----------------------------------------

  describe "verification/1 (jido-e12-t49: behavior, versions, limits, links)" do
    @good_claim %{
      claim: "Good claim",
      control_point: "a linked process",
      configuration: "restart: :permanent",
      test: "`test/agent_jido/demos/controlled_agent_test.exs` and `test/agent_jido/demos/controlled_agent_persistence_test.exs`",
      limitation: "process only, not state",
      owner: "Platform owner",
      version: "jido 2.3.2 (Stable)",
      validation_date: "2026-07-24"
    }

    test "a well-formed claim passes all four dimensions" do
      v = Proof.verification(@good_claim)

      assert v.behavior, "control point + configuration recorded"
      assert v.versions, "version basis is a released, supported package"
      assert v.limits, "limitation recorded"
      assert v.links, "every referenced test file resolves"

      # Actionable detail is carried for the owner.
      assert Enum.any?(v.version_basis, & &1.approved)
      assert Enum.all?(v.test_links, fn {_, resolved?} -> resolved? end)
    end

    test "behavior fails when control point or configuration is missing" do
      for bad <- [%{@good_claim | control_point: ""}, %{@good_claim | configuration: "   "}] do
        v = Proof.verification(bad)
        refute v.behavior, "an owner cannot verify behavior with no control point/configuration"
        # Other dimensions are unaffected.
        assert v.versions and v.limits and v.links
      end
    end

    test "versions fails when the basis names an unreleased or unsupported package" do
      offender = Enum.find(Ecosystem.all_packages(), &(not Ecosystem.released?(&1)))
      assert offender != nil, "registry must carry an unreleased package for this control"

      v = Proof.verification(%{@good_claim | version: "#{offender.id} #{offender.hex_status}"})
      refute v.versions, "an unreleased package cannot carry a public claim (jido-e12-t44)"

      assert Enum.any?(v.version_basis, fn e -> e.package == offender.id end),
             "the offending package is named in the version basis detail"
    end

    test "versions fails when the basis names no registered package" do
      v = Proof.verification(%{@good_claim | version: "some-mystery-package 9.9.9 (Stable)"})
      refute v.versions, "a version basis naming no registered package is unverifiable"
      assert v.version_basis == []
    end

    test "limits fails when the limitation is missing" do
      v = Proof.verification(%{@good_claim | limitation: ""})
      refute v.limits, "an owner cannot verify limits with no limitation recorded"
    end

    test "links fails when a referenced test file does not resolve" do
      v =
        Proof.verification(%{
          @good_claim
          | test: "`test/agent_jido/demos/controlled_agent_test.exs` and `test/does/not/exist.exs`"
        })

      refute v.links, "a broken test link is exactly what the owner must catch"
      assert {"test/does/not/exist.exs", false} in v.test_links
    end

    test "links fails when the test field references no *.exs file" do
      v = Proof.verification(%{@good_claim | test: "see the demos directory"})
      refute v.links, "a test field with no resolvable reference cannot prove the claim"
      assert v.test_links == []
    end

    test "every recorded control claim currently passes all four dimensions" do
      # Loud, current-state control: today the operational-control proof is
      # clean on behavior, versions, limits, and links — so an owner auditing
      # this quarter finds nothing to fix. This is calendar-independent; it only
      # changes when specs/proof.md changes, at which point the failing dimension
      # is the work item.
      for claim <- Proof.claims() do
        v = Proof.verification(claim)

        assert v.behavior,
               "claim #{inspect(claim.claim)} behavior unverified (control point/configuration)"

        assert v.versions,
               "claim #{inspect(claim.claim)} version basis not released + supported"

        assert v.limits,
               "claim #{inspect(claim.claim)} limits unverified (limitation missing)"

        assert v.links,
               "claim #{inspect(claim.claim)} has an unresolved test link"
      end
    end
  end

  # --- quarterly freshness predicate ---------------------------------------

  describe "stale?/2 (jido-e12-t49: each quarter)" do
    @validated ~D[2026-07-24]
    @claim %{validation_date: Date.to_iso8601(@validated)}

    test "default window is one quarter (90 days)" do
      assert Proof.default_audit_days() == 90
    end

    test "a freshly validated claim is not stale" do
      refute Proof.stale?(@claim, today: @validated)
      refute Proof.stale?(@claim, today: Date.add(@validated, 90))
    end

    test "a claim validated more than a quarter ago is stale" do
      assert Proof.stale?(@claim, today: Date.add(@validated, 91))
    end

    test "a missing or malformed validation date is always stale" do
      assert Proof.stale?(%{validation_date: ""}, today: @validated)
      assert Proof.stale?(%{validation_date: "last quarter"}, today: @validated)
      assert Proof.stale?(%{}, today: @validated)
    end

    test "the audit_after_days opt moves the boundary" do
      recent = %{validation_date: Date.to_iso8601(Date.add(@validated, 1))}

      refute Proof.stale?(recent, today: Date.add(@validated, 30))
      assert Proof.stale?(recent, today: Date.add(@validated, 30), audit_after_days: 10)
    end
  end

  # --- audit queue: assigned owner work ------------------------------------

  describe "audit_queue/1 (jido-e12-t49)" do
    @claims Proof.claims()

    test "is empty when every claim was validated within the quarter" do
      # Fresh at each claim's own validation date — the deterministic baseline
      # the audit measures drift from.
      for claim <- @claims do
        today = Date.from_iso8601!(claim.validation_date)

        assert Proof.audit_queue(today: today, claims: @claims) == [],
               "a claim validated today must not already be on the audit queue"
      end
    end

    test "repopulates for every claim once the quarter elapses" do
      # Push `today` past the latest validation date in the proof. Every claim
      # is then due for re-verification this quarter — the audit firing.
      latest =
        @claims
        |> Enum.map(&Date.from_iso8601!(&1.validation_date))
        |> Enum.max(Date)

      queue = Proof.audit_queue(today: Date.add(latest, 91), claims: @claims)

      assert length(queue) == length(@claims),
             "expected every operational-control claim on the quarterly audit queue"
    end

    test "every queue entry is assigned owner work carrying the four dimensions" do
      latest =
        @claims
        |> Enum.map(&Date.from_iso8601!(&1.validation_date))
        |> Enum.max(Date)

      queue = Proof.audit_queue(today: Date.add(latest, 120), claims: @claims)

      for entry <- queue do
        # The five documented assigned-work keys.
        assert Map.keys(entry) |> Enum.sort() ==
                 [:claim, :days_since_validation, :owner, :validation_date, :verification]

        # Attributed to the claim's owner — the person who must re-verify.
        assert entry.owner == entry.claim.owner
        assert entry.owner != "", "an audit entry must name an accountable owner"

        assert is_nil(entry.validation_date) or is_binary(entry.validation_date)
        assert is_nil(entry.days_since_validation) or entry.days_since_validation >= 0

        # The four dimensions the owner re-verifies.
        v = entry.verification

        assert Map.keys(v) |> Enum.sort() ==
                 [:behavior, :limits, :links, :test_links, :version_basis, :versions]

        # The entry is genuinely stale (that is why it is on the queue).
        assert Proof.stale?(entry.claim, today: Date.add(latest, 120))
      end
    end

    test "is deterministic under a fixed :today" do
      latest =
        @claims
        |> Enum.map(&Date.from_iso8601!(&1.validation_date))
        |> Enum.max(Date)

      today = Date.add(latest, 95)

      one = Proof.audit_queue(today: today, claims: @claims) |> Enum.map(& &1.claim.claim)
      two = Proof.audit_queue(today: today, claims: @claims) |> Enum.map(& &1.claim.claim)

      assert one == two
    end

    test "a claim whose proof has rotted still surfaces its failing dimensions" do
      # The audit does not just track the calendar: when a claim's proof rots
      # (a broken link, an unsupported version), the queue entry carries the
      # failing dimension so the owner knows what to fix this quarter.
      latest =
        @claims
        |> Enum.map(&Date.from_iso8601!(&1.validation_date))
        |> Enum.max(Date)

      rotten = [
        %{
          claim: "Rotten claim",
          control_point: "a process",
          configuration: "permanent",
          test: "`test/does/not/exist.exs`",
          limitation: "process only",
          owner: "Platform owner",
          version: "jido 2.3.2 (Stable)",
          validation_date: Date.to_iso8601(latest)
        }
      ]

      [entry] = Proof.audit_queue(today: Date.add(latest, 95), claims: rotten)

      assert entry.owner == "Platform owner"
      assert entry.verification.links == false
      assert entry.verification.behavior == true
    end
  end
end
