defmodule AgentJido.Specs.LongRunningReferenceProofTest do
  @moduledoc """
  Long-running-reference proof-inventory gate (jido-e08-t22).

  Acceptance: "It combines Schedule, persistence, and restart recovery."

  The runnable example itself — the reference agent, its persistence /
  supervisor / health modules, and its proof test (plus its recovery-boundary
  matrix and expected-observations gates) — was built under `jido-e07-t29`,
  `jido-e07-t32`, and `jido-e07-t33`. What this task closes is **publication as
  proof**: the integrated production case must be recorded in `specs/proof.md`
  so the reliability claim ("agents should fail safely and recover predictably")
  has direct, file-backed proof that the three concerns run together in one
  supervised agent.

  This gate keeps that publication honest, the same way
  `provider_fallback_proof_test.exs` keeps the provider-fallback row honest — a
  proof row that names an acceptance the asset does not meet, or that points at
  a file that does not exist, fails the gate:

    * `specs/proof.md` records the long-running-reference example as existing
      proof that states all three concerns of the acceptance (Schedule +
      persistence + restart recovery);
    * the inventory row points at a real demo and a real proof test (a renamed
      or deleted proof file fails the gate);
    * the proof test encodes all three concerns — a declared CRON schedule
      routed to `reference.cron`, a checkpoint that round-trips through
      hibernate/thaw, and a restart that resumes from that checkpoint.
  """
  use ExUnit.Case, async: true

  @repo_root Path.expand("../../../", __DIR__)
  @proof_path Path.expand("../../../specs/proof.md", __DIR__)
  @demo_dir "lib/agent_jido/demos/long_running_reference"
  @proof_test_path "test/agent_jido/demos/long_running_reference_test.exs"

  describe "publication in the proof inventory" do
    test "specs/proof.md records the long-running-reference example as existing proof" do
      row = reference_row()

      assert row != nil,
             "specs/proof.md must record the long-running-reference example as proof"

      assert String.contains?(row, "✅ exists"),
             "the long-running-reference proof row must be marked ✅ exists"

      # All three concerns of the acceptance must be named in the inventory
      # itself, so the reliability claim is not backed by a row that names only
      # one or two.
      assert row =~ ~r/schedule/i,
             "the long-running-reference proof row must state scheduling"

      assert row =~ ~r/persist/i,
             "the long-running-reference proof row must state persistence"

      assert row =~ ~r/restart/i,
             "the long-running-reference proof row must state restart recovery"
    end

    test "the inventory row points at a real demo and proof test" do
      row = reference_row()

      assert row != nil,
             "specs/proof.md must record the long-running-reference example as proof"

      # Every path named in the row must resolve — a row that points at a
      # missing file is treated as unproven (proof.md's own rule). The demo is
      # named as a directory (it is a multi-module app), so File.exists?/1 is
      # used rather than File.regular?/1.
      for path <- paths_in(row) do
        resolved = Path.expand(path, @repo_root)

        assert File.exists?(resolved),
               "long-running-reference proof row names a non-existent path: #{path}"
      end

      # The demo (its directory) and its proof test are the two assets that make
      # this runnable proof, so they are named explicitly (not just any files).
      assert String.contains?(row, @demo_dir),
             "the long-running-reference proof row must name the demo"

      assert String.contains?(row, @proof_test_path),
             "the long-running-reference proof row must name the proof test"
    end
  end

  describe "the proof encodes all three concerns of the acceptance" do
    test "schedule: a declared CRON schedule is routed to reference.cron" do
      proof_test = proof_test_source()

      assert proof_test =~ ~s("*/1 * * * *"),
             "the proof test must exercise the declared CRON schedule (*/1 * * * *)"

      assert proof_test =~ "reference.cron",
             "the proof test must route the schedule to reference.cron"

      assert proof_test =~ "cron_ticks",
             "the proof test must observe a scheduled tick advancing cron_ticks"
    end

    test "persistence: a checkpoint round-trips through hibernate/thaw" do
      proof_test = proof_test_source()

      assert proof_test =~ "Persistence.checkpoint",
             "the proof test must checkpoint state (Jido.Persist.hibernate)"

      assert proof_test =~ "Persistence.restore",
             "the proof test must restore a checkpoint (Jido.Persist.thaw)"

      assert proof_test =~ "seen_work",
             "the proof test must observe the checkpoint round-tripping state (seen_work)"
    end

    test "restart recovery: a restart resumes from the checkpoint" do
      proof_test = proof_test_source()

      # Supervision restarts a crashed process under the same id.
      assert proof_test =~ "await_restart",
             "the proof test must cover a supervised process restart"

      # A deployment restart resumes from a checkpoint rather than starting over.
      assert proof_test =~ ~r/resume/i,
             "the proof test must resume from a checkpoint across a restart"
    end
  end

  # --- helpers ---

  defp reference_row do
    proof = File.read!(@proof_path)

    # The long-running-reference row is the one table row that names it. Pull
    # the single line from the first `|` to the trailing `|`.
    case Regex.run(~r/\|.*Long-running scheduled worker.*\|/, proof) do
      [row | _] -> row
      nil -> nil
    end
  end

  defp paths_in(row) do
    # Paths in a proof.md table cell are backtick-wrapped and ` + `-separated,
    # so stop at whitespace, backtick, or pipe. The demo is named as a directory
    # (trailing slash), so this is more permissive than the file-extension scan
    # the provider-fallback gate uses.
    ~r{(?:lib|test|priv|specs)/[^\s`|]+}
    |> Regex.scan(row, capture: :first)
    |> List.flatten()
  end

  defp proof_test_source do
    File.read!(Path.expand(@proof_test_path, @repo_root))
  end
end
