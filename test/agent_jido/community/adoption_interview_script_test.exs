defmodule AgentJido.Community.AdoptionInterviewScriptTest do
  @moduledoc """
  E11-T16: the adoption interview script asks about the four things that turn
  an adopter anecdote into evidence or a doc fix.

  The E11-T16 acceptance condition is that interviews ask about first success,
  package choice, failures, and missing docs. The canonical script lives in
  `specs/templates/adoption-interview-script.md`; this test pins that the
  script carries all four required question blocks so the condition cannot be
  edited away without a failing test. It mirrors the template-lint pattern in
  `AgentJido.GuidesControlBoundaryTest`.
  """
  use ExUnit.Case, async: true

  @script_path Path.expand("../../../specs/templates/adoption-interview-script.md", __DIR__)

  # Each of the four required interview topics, matched loosely so an author
  # can phrase the surrounding question naturally while the topic is enforced.
  # Each maps to one clause of the E11-T16 acceptance condition.
  @required_topics [
    {"first success", ~r/first success/i},
    {"package choice", ~r/package choice/i},
    {"failures", ~r/failures/i},
    {"missing docs", ~r/missing docs/i}
  ]

  describe "the adoption interview script asks about the four required topics (jido-e11-t16)" do
    test "the script file exists" do
      assert File.exists?(@script_path),
             "expected specs/templates/adoption-interview-script.md to exist"
    end

    test "the script asks about every required topic" do
      script = File.read!(@script_path)

      for {label, re} <- @required_topics do
        assert Regex.match?(re, script),
               "the adoption interview script must ask about #{label} " <>
                 "(matching #{inspect(re.source)})"
      end
    end
  end
end
