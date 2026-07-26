defmodule AgentJido.Demos.CodingAssistantAgentTest do
  use ExUnit.Case, async: true

  alias AgentJido.Demos.CodingAssistant
  alias AgentJido.Demos.CodingAssistant.Fixtures

  describe "CodingAssistant.new/0" do
    test "starts with empty source, findings, and patch" do
      agent = CodingAssistant.new()

      assert agent.state.source == ""
      assert agent.state.findings == ""
      assert agent.state.patch == ""
    end
  end

  describe "read_source/1" do
    test "loads the fixture parser source into agent state" do
      agent = CodingAssistant.new()
      {agent, _directives} = CodingAssistant.read_source(agent)

      assert agent.state.source == Fixtures.parser_source()
      # A fresh read clears any prior analysis.
      assert agent.state.findings == ""
      assert agent.state.patch == ""
    end
  end

  describe "analyze/1" do
    test "detects the String.trim/1 nil-handling defect for real" do
      {agent, _} =
        CodingAssistant.new()
        |> CodingAssistant.read_source()
        |> then(fn {a, _} -> CodingAssistant.analyze(a) end)

      # The analysis is a real scan of the fixture, not a canned finding.
      assert agent.state.findings =~ "String.trim/1 raises on nil"
      assert agent.state.findings =~ ~r/line \d+/
      # Analyzing clears any stale patch.
      assert agent.state.patch == ""
    end

    test "reports no findings on empty source" do
      {agent, _} = CodingAssistant.new() |> then(fn a -> CodingAssistant.analyze(a) end)

      assert agent.state.findings == ""
    end
  end

  describe "propose_patch/1" do
    test "builds a nil guard and a unit test from the loaded source" do
      {agent, _} =
        CodingAssistant.new()
        |> CodingAssistant.read_source()
        |> then(fn {a, _} -> CodingAssistant.propose_patch(a) end)

      assert agent.state.patch =~ "Guard nil input before trim/1"
      assert agent.state.patch =~ "case input do"
      assert agent.state.patch =~ "nil -> nil"
      assert agent.state.patch =~ ~r/test.*nil.*input/is
    end

    test "reports no work when no source is loaded" do
      # A source with no trim call sites reports no patch, honestly. A fresh
      # agent has empty source, so it takes the clean-source branch.
      {agent, _} = CodingAssistant.propose_patch(CodingAssistant.new())
      assert agent.state.patch =~ "No nil-handling defects detected"
    end
  end

  describe "full read -> analyze -> patch workflow" do
    test "the three typed actions compose into a coding-agent workflow" do
      {agent, _} =
        CodingAssistant.new()
        |> CodingAssistant.read_source()
        |> then(fn {a, _} -> CodingAssistant.analyze(a) end)
        |> then(fn {a, _} -> CodingAssistant.propose_patch(a) end)

      assert agent.state.source =~ "String.trim(input)"
      assert agent.state.findings =~ "String.trim/1 raises on nil"
      assert agent.state.patch =~ "nil -> nil"
    end
  end
end
