defmodule AgentJido.Specs.FailureDrillTest do
  @moduledoc """
  Failure-drill script contract gate (jido-e07-t31).

  "One command runs the documented failures" is the acceptance for this proof
  package, and that command is `scripts/failure_drill.sh`. This gate keeps the
  script honest against the long-running reference architecture
  (`specs/operations-reference-architecture.md`, "Failure drills"):

    * the script exists and is executable — it is the single documented entry
      point an operator runs;
    * it names exactly the seven documented failures, in spec order, and each
      drill points at a real test file (a renamed proof test fails the gate);
    * the script's drill labels stay in sync with the spec's "Failure drills"
      section, so the spec and the proof package cannot drift apart; and
    * it runs the long-running reference application (the "Main target:
      Reference app") as the integration that exercises the documented
      failures together.

  The script re-invokes `mix test`, so it is exercised directly rather than
  from inside this test process. Per-drill regression coverage lives in
  `test/agent_jido/demos/`.
  """
  use ExUnit.Case, async: true

  @repo_root Path.expand("../../../", __DIR__)
  @script_path Path.expand("../../../scripts/failure_drill.sh", __DIR__)
  @spec_path Path.expand("../../../specs/operations-reference-architecture.md", __DIR__)

  # "spec number":"spec name":"test path"
  @drill_line ~r/"(\d+):(.+?):\s*(test\/[^"]+\.exs)"/
  @reference_line ~r/^REFERENCE_APP="(test\/[^"]+)"/m

  describe "the failure-drill entry point" do
    test "scripts/failure_drill.sh exists and is executable" do
      assert File.regular?(@script_path),
             "scripts/failure_drill.sh must exist — it is the one command that runs the documented failures"

      mode = File.stat!(@script_path).mode

      assert Bitwise.band(mode, 0o111) != 0,
             "scripts/failure_drill.sh must be executable so it runs as one command"
    end
  end

  describe "the documented failures" do
    test "the script names exactly the seven documented failures, each at a real test file" do
      drills = drills()

      assert length(drills) == 7,
             "the spec fixes seven documented failures; the script names #{length(drills)}: #{inspect(drills)}"

      assert Enum.map(drills, & &1.number) == ~w(1 2 3 4 5 6 7),
             "the documented failures must run in spec order"

      for %{label: label, path: path} <- drills do
        resolved = Path.expand(path, @repo_root)

        assert File.regular?(resolved),
               "documented failure #{inspect(label)} points at a non-existent test file: #{path}"
      end
    end

    test "the script's drill labels match the spec's Failure drills section, in order" do
      spec_labels = spec_drill_labels()
      script_labels = Enum.map(drills(), & &1.label)

      assert length(spec_labels) == 7,
             "specs/operations-reference-architecture.md must list seven documented failures"

      assert script_labels == spec_labels,
             "the script's documented-failure labels drifted from the spec.\n" <>
               "script: #{inspect(script_labels)}\nspec:   #{inspect(spec_labels)}"
    end

    test "the script runs the long-running reference application as the integration" do
      reference = reference_app_path()

      assert reference != nil,
             "the script must run the long-running reference application (Main target: Reference app)"

      resolved = Path.expand(reference, @repo_root)

      assert File.regular?(resolved),
             "the script's reference-application test does not exist: #{reference}"
    end
  end

  # --- helpers ---

  defp script, do: File.read!(@script_path)

  defp drills do
    for [_, number, label, path] <- Regex.scan(@drill_line, script()) do
      %{number: number, label: normalize(label), path: String.trim(path)}
    end
  end

  defp reference_app_path do
    case Regex.run(@reference_line, script()) do
      [_, path] -> path
      nil -> nil
    end
  end

  defp spec_drill_labels do
    section = failure_drills_section(File.read!(@spec_path))

    for [_, raw] <- Regex.scan(~r/^\d+\.\s+\*\*(.+?):\*\*/m, section) do
      normalize(raw)
    end
  end

  defp failure_drills_section(spec) do
    case Regex.run(~r/^## Failure drills.*?(?=^## )/ms, spec) do
      [section | _] -> section
      nil -> ""
    end
  end

  # The spec uses markdown emphasis (e.g. `**`AgentServer`**` crash) that the
  # script's plain labels do not — strip it so the two can be compared.
  defp normalize(text) do
    text |> String.replace("`", "") |> String.trim()
  end
end
