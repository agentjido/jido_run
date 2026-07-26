defmodule AgentJido.Specs.ProviderFallbackProofTest do
  @moduledoc """
  Provider-fallback proof-inventory gate (jido-e08-t21).

  Acceptance: "It shows bounded retry and a defined fallback."

  The runnable example itself — the demo module, its proof test, the operations
  page, and the page contract — was built under `jido-e07-t16`. What this task
  closes is **publication as proof**: the example must be recorded in
  `specs/proof.md` so the reliability claim ("agents fail safely and recover
  predictably") has direct, file-backed proof.

  This gate keeps that publication honest, the same way
  `operational_control_proof_test.exs` keeps control claims honest — a proof row
  that names an acceptance the asset does not meet, or that points at a file that
  does not exist, fails the gate:

    * `specs/proof.md` records the provider-fallback example as existing proof
      that states both halves of the acceptance (bounded retry + a defined
      fallback);
    * the inventory row points at a real demo module and a real proof test
      (a renamed or deleted proof file fails the gate);
    * the proof test encodes both halves — a bounded retry budget that exhausts
      at `max_attempts` (never unbounded) and a defined fallback rule
      (`source: :fallback`, and `:fail` as a valid rule).
  """
  use ExUnit.Case, async: true

  @repo_root Path.expand("../../../", __DIR__)
  @proof_path Path.expand("../../../specs/proof.md", __DIR__)
  @demo_path "lib/agent_jido/demos/provider_timeout_fallback/provider_timeout_fallback.ex"
  @proof_test_path "test/agent_jido/demos/provider_timeout_fallback_test.exs"

  describe "publication in the proof inventory" do
    test "specs/proof.md records the provider-fallback example as existing proof" do
      row = provider_row()

      assert row != nil,
             "specs/proof.md must record the provider-fallback example as proof"

      assert String.contains?(row, "✅ exists"),
             "the provider-fallback proof row must be marked ✅ exists"

      # Both halves of the acceptance must be named in the inventory itself, so
      # the reliability claim is not backed by a row that only mentions one.
      assert row =~ ~r/bounded/i,
             "the provider-fallback proof row must state bounded retry"

      assert row =~ ~r/fallback/i,
             "the provider-fallback proof row must state a defined fallback"
    end

    test "the inventory row points at a real demo module and proof test" do
      row = provider_row()

      assert row != nil,
             "specs/proof.md must record the provider-fallback example as proof"

      # Every file path named in the row must resolve — a row that points at a
      # missing file is treated as unproven (proof.md's own rule).
      for path <- paths_in(row) do
        resolved = Path.expand(path, @repo_root)

        assert File.regular?(resolved),
               "provider-fallback proof row names a non-existent file: #{path}"
      end

      # The demo module and its proof test are the two assets that make this
      # runnable proof, so they are named explicitly (not just any files).
      assert String.contains?(row, @demo_path),
             "the provider-fallback proof row must name the demo module"

      assert String.contains?(row, @proof_test_path),
             "the provider-fallback proof row must name the proof test"
    end
  end

  describe "the proof encodes both halves of the acceptance" do
    test "bounded retry: the budget exhausts at max_attempts and is never unbounded" do
      proof_test = proof_test_source()

      # The demo exposes the bounded budget as a named knob.
      assert proof_test =~ "max_attempts",
             "the proof test must exercise a bounded retry budget (max_attempts)"

      # The budget is observed to bound the loop: a persistent timeout is retried
      # only up to max_attempts, then stops — never unbounded.
      assert proof_test =~ ~r/never unbounded/i,
             "the proof test must assert the retry loop is bounded, not unbounded"

      assert proof_test =~ ~r/budget/i,
             "the proof test must name the retry budget"
    end

    test "a defined fallback: the result is tagged and failing is a valid rule" do
      proof_test = proof_test_source()

      # The fallback rule is observable: a recovered result is tagged so a caller
      # can tell a primary answer from a fallback answer.
      assert proof_test =~ "source: :fallback",
             "the proof test must assert the fallback tags its result (source: :fallback)"

      # "Fail the Signal" is a defined fallback rule too — the budget bounds the
      # blast radius; it does not promise success.
      assert proof_test =~ ":fail",
             "the proof test must cover :fail as a defined fallback rule"
    end
  end

  # --- helpers ---

  defp provider_row do
    proof = File.read!(@proof_path)

    # The provider-fallback row is the one table row that names it. Pull the
    # single line from the first `|` to the trailing `|`.
    case Regex.run(~r/\|.*Provider timeout and fallback.*\|/, proof) do
      [row | _] -> row
      nil -> nil
    end
  end

  defp paths_in(row) do
    # Paths in a proof.md table cell are backtick-wrapped and ` + `-separated,
    # so stop at whitespace, backtick, or pipe. Prefer the longest extension so
    # `...test.exs` is not truncated to `...test.ex`.
    ~r{(?:lib|test|priv|specs)/[^\s`|]+\.(?:exs|ex|md)}
    |> Regex.scan(row, capture: :first)
    |> List.flatten()
  end

  defp proof_test_source do
    File.read!(Path.expand(@proof_test_path, @repo_root))
  end
end
