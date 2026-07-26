defmodule AgentJido.Specs.PublicExampleProofMapTest do
  @moduledoc """
  Public-example proof-inventory gate (jido-e08-t32).

  Acceptance: "Each major claim points to at least one example."

  Every example surfaced publicly (`status: :live`) must be recorded in the
  `Public Example Proof Map` section of `specs/proof.md`, and each major
  positioning/control claim (P1–P4, Cross-cutting AI, Control) must point to at
  least one of those examples. The map is the single registry that ties a public
  example to the claim it proves: a newly published live example with no map row,
  a claim with no backing example, or an orphan row that backs nothing fails the
  gate.

  The live set is read from `AgentJido.Examples`, so the gate fails the moment a
  new public example ships without being added to the proof inventory.

  Claim tokens (backtick-wrapped in the map's `Backs` column):

    * `P1`     — Pillar 1: Reliability by Architecture
    * `P2`     — Pillar 2: Multi-Agent Coordination you can reason about
    * `P3`     — Pillar 3: Production Operations and Observability
    * `P4`     — Pillar 4: Composable Ecosystem / incremental adoption
    * `Cross`  — Cross-cutting AI intelligence
    * `Control` — Operational-control claims
  """
  use ExUnit.Case, async: true

  alias AgentJido.Examples

  @proof_path Path.expand("../../../specs/proof.md", __DIR__)

  # Every major positioning/control claim the proof inventory must cover.
  @major_claims ["P1", "P2", "P3", "P4", "Cross", "Control"]

  test "proof.md keeps a Public Example Proof Map section" do
    section = public_example_section()

    assert section != nil,
           "specs/proof.md must keep a 'Public Example Proof Map' section (jido-e08-t32)"
  end

  test "every public (live) example is recorded in the proof map" do
    section = public_example_section()

    assert section != nil,
           "specs/proof.md must keep a 'Public Example Proof Map' section (jido-e08-t32)"

    # A row is anchored by the example's source path, so a slug that appears only
    # in prose (not as a mapped row) would not count here.
    missing =
      Examples.all_examples()
      |> Enum.map(& &1.slug)
      |> Enum.reject(fn slug -> row_for?(section, slug) end)

    assert missing == [],
           "every public example must be recorded in the proof map. " <>
             "Missing slugs: #{inspect(Enum.sort(missing))}"
  end

  test "the proof map names only public examples (no renamed or removed slugs)" do
    live_slugs = Examples.all_examples() |> Enum.map(& &1.slug) |> MapSet.new()

    stale =
      public_example_section()
      |> mapped_example_slugs()
      |> Enum.reject(&MapSet.member?(live_slugs, &1))

    assert stale == [],
           "proof map records examples that are no longer public: #{inspect(Enum.sort(stale))}"
  end

  test "each major claim points to at least one example" do
    coverage = claim_coverage()

    uncovered =
      @major_claims
      |> Enum.reject(fn claim -> Map.get(coverage, claim, []) != [] end)

    assert uncovered == [],
           "every major claim must point to at least one example in the proof map. " <>
             "Claims with no backing example: #{inspect(uncovered)}"
  end

  test "every mapped example backs at least one major claim" do
    section = public_example_section()

    backed =
      claim_coverage()
      |> Map.values()
      |> List.flatten()
      |> Enum.uniq()

    orphans = Enum.reject(mapped_example_slugs(section), &(&1 in backed))

    assert orphans == [],
           "every mapped example must back at least one major claim. " <>
             "Orphan rows: #{inspect(Enum.sort(orphans))}"
  end

  # --- helpers ---

  defp public_example_section do
    proof = File.read!(@proof_path)

    # Stop at the next H2 (`## `). H3 subheadings (`### `) inside the section do
    # not terminate it, because `## ` requires a space right after the second `#`.
    case Regex.run(~r/## Public Example Proof Map.*?(?=\n## |\z)/s, proof) do
      [section | _] -> section
      nil -> nil
    end
  end

  # A map row is a markdown table line that names the example source file. This
  # excludes the header, separator, legend, and prose.
  defp map_rows(section) do
    section
    |> String.split("\n", trim: true)
    |> Enum.filter(fn line ->
      String.starts_with?(line, "|") and String.contains?(line, "priv/examples/")
    end)
  end

  defp row_for?(section, slug) do
    Enum.any?(map_rows(section), &String.contains?(&1, "priv/examples/#{slug}.md"))
  end

  defp mapped_example_slugs(section) do
    section
    |> map_rows()
    |> Enum.flat_map(fn row ->
      Regex.run(~r{priv/examples/([a-z0-9-]+)\.md}, row, capture: :all_but_first) || []
    end)
    |> Enum.uniq()
  end

  # claim -> list of example slugs that back it, derived from the table rows.
  defp claim_coverage do
    public_example_section()
    |> map_rows()
    |> Enum.reduce(%{}, fn row, acc ->
      slug =
        case Regex.run(~r{priv/examples/([a-z0-9-]+)\.md}, row, capture: :all_but_first) do
          [slug | _] -> slug
          nil -> nil
        end

      # Only backtick-wrapped alphanumeric tokens are claim tokens; the source
      # path is backtick-wrapped too but contains `/`, `-`, and `.`, so it does
      # not match `[A-Za-z0-9]+` between the backticks.
      claims =
        ~r/`([A-Za-z0-9]+)`/
        |> Regex.scan(row, capture: :all_but_first)
        |> List.flatten()
        |> Enum.uniq()
        |> Enum.filter(&(&1 in @major_claims))

      case slug do
        nil -> acc
        slug -> Enum.reduce(claims, acc, fn claim, acc -> Map.update(acc, claim, [slug], &[slug | &1]) end)
      end
    end)
    |> Map.new(fn {claim, slugs} -> {claim, Enum.reverse(Enum.uniq(slugs))} end)
  end
end
