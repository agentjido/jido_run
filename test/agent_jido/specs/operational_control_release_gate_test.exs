defmodule AgentJido.Specs.OperationalControlReleaseGateTest do
  @moduledoc """
  Operational-control release gate (jido-e12-t44).

  Acceptance: *Only the approved version and support level can satisfy a public
  claim.*

  Every operational-control claim recorded in `specs/proof.md` names its proof
  basis in a `Version:` field (the schema enforced by the sibling jido-e12-t38
  gate). A package named there is what the claim depends on, so this gate refuses
  to let an **unreleased** package (no published Hex version) or an
  **unsupported** package (Experimental support level) satisfy a public claim.
  Each claim must instead be carried by at least one released package at an
  approved support level (Stable or Beta).

  The released/approved classification is read from the live release catalog
  (`AgentJido.Ecosystem`), so the gate fails the moment a claim is retargeted at
  a package the catalog does not back.
  """
  use ExUnit.Case, async: true

  alias AgentJido.Ecosystem
  alias AgentJido.Ecosystem.SupportLevel

  @proof_path Path.expand("../../../specs/proof.md", __DIR__)

  describe "the release catalog classifies packages for public claims" do
    test "released?/1 is true only for packages with a published Hex version" do
      # A package published to Hex carries a version in hex_status.
      assert Ecosystem.released?(Ecosystem.get_package!("jido")) == true
      assert Ecosystem.released?(Ecosystem.get_package!("req_llm")) == true

      # An unreleased package carries "unreleased" and cannot satisfy a claim.
      unreleased = Enum.find(Ecosystem.all_packages(), &(not Ecosystem.released?(&1)))

      assert unreleased != nil, "registry must carry at least one unreleased package"
      assert Ecosystem.released?(unreleased) == false
      assert Ecosystem.released?(unreleased.id) == false
    end

    test "approved?/1 accepts Stable and Beta and rejects Experimental" do
      assert SupportLevel.approved?(:stable) == true
      assert SupportLevel.approved?(:beta) == true
      assert SupportLevel.approved?(:experimental) == false
      assert SupportLevel.approved?(nil) == false

      assert SupportLevel.approved_levels() == [:stable, :beta]
    end
  end

  describe "every operational-control claim's Version basis is released and supported" do
    test "no claim depends on an unreleased or unsupported package" do
      for {claim, version_field} <- control_claim_versions(),
          pkg <- packages_named_in(version_field) do
        assert Ecosystem.released?(pkg),
               "operational-control claim #{inspect(claim)} depends on an unreleased " <>
                 "package `#{pkg.id}` (hex_status: #{inspect(pkg.hex_status)}). Only a " <>
                 "released package — one with a published Hex version — can satisfy a " <>
                 "public claim (jido-e12-t44)."

        assert SupportLevel.approved?(pkg.support_level),
               "operational-control claim #{inspect(claim)} depends on an unsupported " <>
                 "package `#{pkg.id}` (support_level: #{inspect(pkg.support_level)}). " <>
                 "Only a Stable or Beta support level can satisfy a public claim " <>
                 "(jido-e12-t44)."
      end
    end

    test "each claim is carried by at least one approved package" do
      # The acceptance is "only the approved version and support level can
      # satisfy": not merely "no bad package", but every claim must actually be
      # satisfied by a released, supported package.
      for {claim, version_field} <- control_claim_versions() do
        named = packages_named_in(version_field)

        assert named != [],
               "operational-control claim #{inspect(claim)} Version field names no " <>
                 "registered package"

        approved =
          Enum.filter(named, fn pkg ->
            Ecosystem.released?(pkg) and SupportLevel.approved?(pkg.support_level)
          end)

        assert approved != [],
               "operational-control claim #{inspect(claim)} must be satisfied by at least " <>
                 "one released, supported package. Named: #{inspect(Enum.map(named, & &1.id))}"
      end
    end
  end

  describe "the gate blocks a Version basis that depends on a bad package" do
    # Negative controls proving the gate rejects a dirty Version basis, not just
    # that the current proof.md happens to be clean.
    test "flags the unreleased jido_otel basis that motivated this gate" do
      # The exact Correlated-telemetry Version basis before jido-e12-t44. jido
      # (released, supported) cannot rescue it: naming unreleased jido_otel as a
      # satisfying basis is itself the violation this gate blocks.
      dirty = "jido 2.3.2 (Stable); jido_otel Experimental."

      assert violates_release_basis?(dirty),
             "the gate must flag a Version basis that names unreleased jido_otel"
    end

    test "flags any unreleased package named in a Version basis" do
      offender = Enum.find(Ecosystem.all_packages(), &(not Ecosystem.released?(&1)))

      assert offender != nil
      assert violates_release_basis?("#{offender.id} 0.1.0 (Experimental).")
    end

    test "passes a clean Version basis carried by a released, supported package" do
      carrier =
        Enum.find(Ecosystem.all_packages(), fn pkg ->
          Ecosystem.released?(pkg) and SupportLevel.approved?(pkg.support_level)
        end)

      assert carrier != nil
      refute violates_release_basis?("#{carrier.id} #{carrier.hex_status} (Stable).")
    end
  end

  # --- helpers ---

  defp control_claim_versions do
    proof = File.read!(@proof_path)

    case Regex.run(~r/## Control Proof Fields.*?(?=\n## |\z)/s, proof) do
      nil -> []
      [section | _] -> control_section_versions(section)
    end
  end

  # Splits the Control Proof Fields section into (claim, body) pairs — mirroring
  # the sibling jido-e12-t38 gate — and pulls each Version field.
  defp control_section_versions(section) do
    section
    |> String.split(~r/^###\s+/m)
    |> Enum.drop(1)
    |> Enum.map(fn chunk ->
      case String.split(chunk, "\n", parts: 2) do
        [head] -> {String.trim(head), ""}
        [head, rest] -> {String.trim(head), rest}
      end
    end)
    |> Enum.reject(fn {claim, _} -> claim == "" end)
    |> Enum.map(fn {claim, body} -> {claim, version_field(body)} end)
  end

  defp version_field(block) do
    case Regex.run(~r/- \*\*Version:\*\*\s*(.+)/, block) do
      [_, value] -> String.trim(value)
      nil -> ""
    end
  end

  # The registry packages whose id appears as a whole word in a Version field —
  # i.e. the packages the claim's version basis depends on. `\b` treats `_` as a
  # word character, so `jido` does not match inside `jido_ai` or `jido_signal`.
  defp packages_named_in(version_field) do
    Enum.filter(Ecosystem.all_packages(), fn pkg ->
      version_field =~ ~r/\b#{Regex.escape(pkg.id)}\b/
    end)
  end

  # Pure predicate over an arbitrary Version-basis string: true when any package
  # named in it is unreleased or unsupported. Used by the negative controls.
  defp violates_release_basis?(version_field) do
    Enum.any?(packages_named_in(version_field), fn pkg ->
      not Ecosystem.released?(pkg) or not SupportLevel.approved?(pkg.support_level)
    end)
  end
end
