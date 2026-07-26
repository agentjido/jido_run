defmodule AgentJido.Specs.ControlledAgentApplicationResponsibilityTest do
  @moduledoc """
  Application-responsibility note on the controlled-Agent example page
  (`jido-e08-t45`).

  Acceptance: *the page identifies external authentication, identity storage,
  retention, access control, and compliance duties.*

  The integrated example proves the control path inside Jido (the fail-closed
  hook, the supervised lifecycle, the correlated trace). The duties that frame
  that path live outside Jido, at the application/platform boundary. This test
  locks the public example page's `## Application responsibilities` note so the
  five duties the acceptance names cannot be dropped or weakened without failing
  here. It mirrors the claim-boundary model on the security-and-governance page,
  which is the canonical home for the same distinction.
  """

  use ExUnit.Case, async: true

  # Path is relative to the repo root.
  @example_page "priv/examples/controlled-agent.md"

  # The `## Application responsibilities` section: the heading and its body up to
  # the next `##` heading (or end of document).
  @section_re ~r/^##[[:space:]]+Application responsibilities\b.*?(?=^##[[:space:]]|\z)/ims

  # The five duties the acceptance condition names, each locked by its own regex
  # so a missing or renamed duty points at exactly what was lost.
  @duties [
    {"external authentication", ~r/\bexternal authentication\b/i},
    {"identity storage", ~r/\bidentity storage\b/i},
    {"retention", ~r/\bretention\b/i},
    {"access control", ~r/\baccess control\b/i},
    {"compliance duties", ~r/\bcompliance duties\b/i}
  ]

  test "the controlled-Agent example page has an Application responsibilities section (jido-e08-t45)" do
    section = section(File.read!(repo_path(@example_page)))

    assert section != nil,
           "#{@example_page} must include an `## Application responsibilities` section " <>
             "that identifies the duties the application (not Jido) owns"
  end

  for {label, re} <- @duties do
    test "the Application responsibilities note identifies: #{label}" do
      {label, re} = unquote(Macro.escape({label, re}))
      section = section(File.read!(repo_path(unquote(@example_page))))

      assert section != nil,
             "#{unquote(@example_page)} must include an `## Application responsibilities` " <>
               "section before its duties can be checked"

      assert Regex.match?(re, section),
             "#{unquote(@example_page)} Application responsibilities note must identify the " <>
               "#{label} duty as an application/platform responsibility " <>
               "(matching #{inspect(re.source)})"
    end
  end

  defp repo_path(relative) do
    Path.expand("../../../" <> relative, __DIR__)
  end

  defp section(body) do
    case Regex.run(@section_re, body) do
      [section | _] -> section
      nil -> nil
    end
  end
end
