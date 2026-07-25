defmodule AgentJido.Specs.ExpectedObservationsTest do
  @moduledoc """
  Expected-observations contract gate (`jido-e07-t32`).

  The long-running reference architecture fixes seven failure drills, "each
  ... must have an expected observation" (`specs/operations-reference-architecture.md`,
  "Failure drills"). The acceptance for this task is that **logs, state,
  telemetry, and recovery result are listed** for each one — and the "Main
  targets: Reference app README and guide" are where an operator reads them.

  This gate keeps both targets honest:

    * the reference app README (`lib/agent_jido/demos/long_running_reference/README.md`)
      and the spec's "Failure drills" guide each list all seven documented
      failures; and
    * each failure block lists all four observation categories — Logs, State,
      Telemetry, and Recovery — so the expected result is explicit, not implied.

  The seven failure names and the four category names are the contract: if
  either document drops a failure or a category, this gate fails. It does not
  pin wording, so the prose can stay readable.
  """

  use ExUnit.Case, async: true

  @spec_path Path.expand("../../../specs/operations-reference-architecture.md", __DIR__)
  @readme_path Path.expand("../../../lib/agent_jido/demos/long_running_reference/README.md", __DIR__)

  # The seven documented failures. Each entry pairs a readable name (for
  # failure messages) with a normalized substring (lower-cased, backticks
  # stripped) that identifies the failure's block in both documents. The
  # spec wraps `AgentServer` in backticks; the README does not — normalizing
  # lets one key match both.
  @failures [
    {"Tool error + retry decision", "tool error + retry decision"},
    {"AgentServer crash", "agentserver crash"},
    {"Application restart", "application restart"},
    {"Deployment restart", "deployment restart"},
    {"Duplicate Signal delivery", "duplicate signal delivery"},
    {"Provider timeout + fallback", "provider timeout + fallback"},
    {"Poison work / dead-letter", "poison work / dead-letter"}
  ]

  @categories ["Logs", "State", "Telemetry", "Recovery"]

  describe "the reference app README" do
    test "exists — it is where an operator reads the expected observations" do
      assert File.regular?(@readme_path),
             "the reference app README must exist (lib/agent_jido/demos/long_running_reference/README.md)"
    end

    test "lists one block per documented failure" do
      assert length(observation_blocks(readme(), ~r/^### /m)) == length(@failures),
             "the README must list one expected-observations block per documented failure"
    end

    test "every documented failure lists all four observation categories" do
      assert_each_failure_has_categories(observation_blocks(readme(), ~r/^### /m))
    end
  end

  describe "the architecture spec Failure drills guide" do
    test "lists one block per documented failure" do
      section = failure_drills_section(spec())

      assert length(observation_blocks(section, ~r/^\d+\.\s+\*\*/m)) == length(@failures),
             "the spec's Failure drills section must list one block per documented failure"
    end

    test "every documented failure lists all four observation categories" do
      section = failure_drills_section(spec())
      assert_each_failure_has_categories(observation_blocks(section, ~r/^\d+\.\s+\*\*/m))
    end
  end

  # --- helpers ---

  defp readme, do: File.read!(@readme_path)
  defp spec, do: File.read!(@spec_path)

  defp assert_each_failure_has_categories(blocks) do
    for {readable, key} <- @failures do
      block = Enum.find(blocks, fn b -> normalize(b) =~ key end)

      assert block != nil,
             "the documented failure #{inspect(readable)} is missing its expected-observations block"

      for category <- @categories do
        assert String.contains?(block, category),
               "the #{inspect(readable)} block is missing the #{category} observation"
      end
    end
  end

  # Splits `doc` into one block per heading that matches `heading_re`. Each
  # block runs from its heading to the next heading (or end of document), so a
  # category check is scoped to a single failure. Works on byte offsets
  # (binary_part/3) so multi-byte characters in the prose never split a block.
  defp observation_blocks(doc, heading_re) do
    indices =
      Regex.scan(heading_re, doc, return: :index)
      |> Enum.map(fn [{start, _len}] -> start end)

    doc_size = byte_size(doc)

    indices
    |> Enum.with_index()
    |> Enum.map(fn {start, i} ->
      finish = if(next = Enum.at(indices, i + 1), do: next, else: doc_size)
      binary_part(doc, start, finish - start)
    end)
  end

  defp failure_drills_section(spec) do
    case Regex.run(~r/^## Failure drills.*?(?=^## )/ms, spec) do
      [section | _] -> section
      nil -> ""
    end
  end

  defp normalize(text) do
    text |> String.downcase() |> String.replace("`", "")
  end
end
