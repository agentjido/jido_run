defmodule AgentJido.Specs.OperationalControlProofTest do
  @moduledoc """
  Operational-control proof metadata gate (jido-e12-t38).

  Every operational-control claim recorded in `specs/proof.md` must name its
  control point, configuration, test, limitation, owner, version, and
  validation date, and its `test` field must point at a file that exists. A
  claim that omits or empties any field cannot back restricted control,
  security, or compliance language (E12 exit criteria).
  """
  use ExUnit.Case, async: true

  @proof_path Path.expand("../../../specs/proof.md", __DIR__)
  @repo_root Path.expand("../../../", __DIR__)

  # Display label in proof.md -> internal field key. Order is the contract.
  @field_labels [
    {"Control point:", :control_point},
    {"Configuration:", :configuration},
    {"Test:", :test},
    {"Limitation:", :limitation},
    {"Owner:", :owner},
    {"Version:", :version},
    {"Validation date:", :validation_date}
  ]

  test "proof.md keeps a Control Proof Fields section naming the required schema" do
    proof = File.read!(@proof_path)

    section = control_proof_section(proof)

    assert section != nil,
           "specs/proof.md must keep a 'Control Proof Fields' section for operational-control claims"

    for label <- ~w(control point configuration test limitation owner version validation date) do
      assert String.contains?(String.downcase(section), label),
             "the Control Proof Fields schema must name the '#{label}' field"
    end
  end

  test "at least one operational-control claim is recorded" do
    claims = control_claims()

    assert claims != [],
           "specs/proof.md must record at least one operational-control claim with proof metadata"
  end

  test "every operational-control claim names all seven required proof fields" do
    for {claim, block} <- control_claims() do
      missing =
        Enum.reject(@field_labels, fn {label, _key} -> String.contains?(block, label) end)
        |> Enum.map(fn {label, _key} -> label end)

      assert missing == [],
             "operational-control claim #{inspect(claim)} is missing proof fields " <>
               "#{inspect(missing)}. Each claim must name its control point, configuration, " <>
               "test, limitation, owner, version, and validation date."

      for {label, _key} <- @field_labels do
        value = field_value(block, label)

        assert value != nil and String.trim(value) != "",
               "operational-control claim #{inspect(claim)} has an empty #{inspect(label)} field"
      end
    end
  end

  test "every operational-control claim points its test field at a real test file" do
    for {claim, block} <- control_claims() do
      test_field = field_value(block, "Test:") || ""
      referenced = Regex.scan(~r{`([^`]+\.exs)`}, test_field, capture: :all_but_first)

      assert referenced != [],
             "operational-control claim #{inspect(claim)} Test field must reference at " <>
               "least one `test/**/*.exs` file in backticks"

      for [path | _] <- referenced do
        resolved = Path.expand(path, @repo_root)

        assert File.regular?(resolved),
               "operational-control claim #{inspect(claim)} Test field references a " <>
                 "non-existent test file: #{path}"
      end
    end
  end

  # --- helpers ---

  defp control_proof_section(proof) do
    case Regex.run(~r/## Control Proof Fields.*?(?=\n## |\z)/s, proof) do
      [section | _] -> section
      nil -> nil
    end
  end

  defp control_claims do
    proof = File.read!(@proof_path)
    section = control_proof_section(proof) || ""

    section
    |> String.split(~r/^###\s+/m)
    |> Enum.drop(1)
    |> Enum.map(fn chunk ->
      case String.split(chunk, "\n", parts: 2) do
        [head] -> {String.trim(head), ""}
        [head, rest] -> {String.trim(head), rest}
      end
    end)
    |> Enum.reject(fn {claim, _block} -> claim == "" end)
  end

  defp field_value(block, label) do
    case Regex.run(~r/- \*\*#{Regex.escape(label)}\*\*\s*(.+)/, block) do
      [_, value] -> String.trim(value)
      nil -> nil
    end
  end
end
