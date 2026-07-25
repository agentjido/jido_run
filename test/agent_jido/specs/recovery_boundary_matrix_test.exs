defmodule AgentJido.Specs.RecoveryBoundaryMatrixTest do
  @moduledoc """
  Recovery-boundary matrix contract gate (`jido-e07-t33`).

  Acceptance — quoted: "Each recovery boundary has an automated or repeatable
  test." The four boundaries the task names are process, application, node, and
  deployment restart. This gate keeps the matrix honest in three places:

    * the reference app test (`test/agent_jido/demos/long_running_reference_test.exs`)
      defines a tagged automated test for every boundary — a boundary that loses
      its test fails the gate;
    * the architecture spec (`specs/operations-reference-architecture.md`,
      "Recovery boundaries") documents all four; and
    * the reference app README documents all four.

  The four boundary names and their test tags are the contract: if a boundary
  loses its test or its row in either document, the gate fails. It does not pin
  wording, so the prose stays readable.
  """

  use ExUnit.Case, async: true

  @test_path Path.expand("../demos/long_running_reference_test.exs", __DIR__)
  @spec_path Path.expand("../../../specs/operations-reference-architecture.md", __DIR__)
  @readme_path Path.expand("../../../lib/agent_jido/demos/long_running_reference/README.md", __DIR__)

  # One entry per recovery boundary: the readable name (the matrix row label and
  # the documented boundary) paired with the ExUnit tag that marks its automated
  # test in the reference app.
  @boundaries [
    %{name: "Process", tag: :supervision},
    %{name: "Application", tag: :persistence},
    %{name: "Node", tag: :node_restart},
    %{name: "Deployment", tag: :deployment}
  ]

  describe "the reference app test" do
    test "exists — it is the proof for every recovery boundary" do
      assert File.regular?(@test_path),
             "the reference app test must exist (test/agent_jido/demos/long_running_reference_test.exs)"
    end

    test "defines one tagged automated test per recovery boundary" do
      source = File.read!(@test_path)

      for %{name: name, tag: tag} <- @boundaries do
        assert source =~ ~s/@tag :#{tag}/,
               "the #{name} recovery boundary has no automated test: missing `@tag :#{tag}` in the reference app test"
      end
    end

    test "the four boundaries are distinct — no tag is shared" do
      tags = Enum.map(@boundaries, & &1.tag)

      assert length(Enum.uniq(tags)) == length(tags),
             "each recovery boundary must map to its own test tag"
    end
  end

  describe "the architecture spec Recovery boundaries matrix" do
    test "documents all four recovery boundaries" do
      section = recovery_section(spec())

      assert byte_size(section) > 0,
             "specs/operations-reference-architecture.md must have a Recovery boundaries section"

      for %{name: name} <- @boundaries do
        assert section =~ "| #{name} |",
               "the spec's Recovery boundaries matrix is missing the #{name} row"
      end
    end

    test "names the node boundary's durable store — what bridges a node loss" do
      section = recovery_section(spec())

      assert section =~ ~r/durable/i,
             "the node recovery boundary must name the durable (disk-backed) store that bridges it"
    end
  end

  describe "the reference app README Recovery boundaries matrix" do
    test "documents all four recovery boundaries" do
      section = recovery_section(readme())

      assert byte_size(section) > 0,
             "the reference app README must have a Recovery boundaries section"

      for %{name: name} <- @boundaries do
        assert section =~ "| #{name} |",
               "the README's Recovery boundaries matrix is missing the #{name} row"
      end
    end
  end

  # --- helpers ---

  defp spec, do: File.read!(@spec_path)
  defp readme, do: File.read!(@readme_path)

  # Extracts the `## Recovery boundaries` section: from its heading to the next
  # `## ` heading (or end of document). Returns "" when the section is absent.
  defp recovery_section(doc) do
    case Regex.run(~r/^## Recovery boundaries.*?(?=^## )/ms, doc) do
      [section | _] -> section
      nil -> ""
    end
  end
end
