defmodule AgentJido.Demos.SupportTriageAgentTest do
  use ExUnit.Case, async: true

  alias AgentJido.Demos.SupportTriage
  alias AgentJido.Demos.SupportTriage.Fixtures

  describe "SupportTriage.new/0" do
    test "starts with empty message, intent, urgency, and response" do
      agent = SupportTriage.new()

      assert agent.state.incoming_message == ""
      assert agent.state.intent == ""
      assert agent.state.urgency == ""
      assert agent.state.response == ""
    end
  end

  describe "load_message/2" do
    test "loads the named fixture and resets the triage" do
      agent = SupportTriage.new()
      {agent, _} = SupportTriage.load_message(agent, :billing)

      assert agent.state.incoming_message == Fixtures.fetch(:billing)
      # A fresh load clears any prior triage output.
      assert agent.state.intent == ""
      assert agent.state.urgency == ""
      assert agent.state.response == ""
    end

    test "loads each fixture by name" do
      for which <- [:billing, :bug, :howto, :thanks] do
        {agent, _} = SupportTriage.load_message(SupportTriage.new(), which)
        assert agent.state.incoming_message == Fixtures.fetch(which)
      end
    end
  end

  describe "classify/1" do
    test "classifies the billing, bug, and how-to fixtures for real" do
      for {which, expected} <- [billing: "billing", bug: "bug", howto: "how-to"] do
        {agent, _} =
          SupportTriage.new()
          |> SupportTriage.load_message(which)
          |> then(fn {a, _} -> SupportTriage.classify(a) end)

        # The classification is a real keyword-scored match, not a canned label.
        assert agent.state.intent == expected
      end
    end

    test "classifies a message with none of the signals as unknown" do
      {agent, _} =
        SupportTriage.new()
        |> SupportTriage.load_message(:thanks)
        |> then(fn {a, _} -> SupportTriage.classify(a) end)

      assert agent.state.intent == "unknown"
    end

    test "classifies an empty message as unknown" do
      {agent, _} = SupportTriage.new() |> then(fn a -> SupportTriage.classify(a) end)

      assert agent.state.intent == "unknown"
    end
  end

  describe "assess/1" do
    test "flags an angry, deadline-driven bug report as high urgency" do
      {agent, _} =
        SupportTriage.new()
        |> SupportTriage.load_message(:bug)
        |> then(fn {a, _} -> SupportTriage.assess(a) end)

      # The urgency is real -- detected from the deadline marker and the angry tone.
      assert agent.state.urgency == "high"
    end

    test "keeps a calm billing question at normal urgency" do
      {agent, _} =
        SupportTriage.new()
        |> SupportTriage.load_message(:billing)
        |> then(fn {a, _} -> SupportTriage.assess(a) end)

      assert agent.state.urgency == "normal"
    end

    test "assesses an empty message as normal" do
      {agent, _} = SupportTriage.new() |> then(fn a -> SupportTriage.assess(a) end)

      assert agent.state.urgency == "normal"
    end
  end

  describe "respond/1" do
    test "routes a billing message to the billing queue and references the invoice" do
      {agent, _} =
        SupportTriage.new()
        |> SupportTriage.load_message(:billing)
        |> then(fn {a, _} -> SupportTriage.respond(a) end)

      assert agent.state.response =~ "Queue: billing"
      # The captured invoice number is referenced in the routed reply.
      assert agent.state.response =~ "invoice INV-9921"
    end

    test "routes a bug report to the priority engineering queue at high urgency" do
      {agent, _} =
        SupportTriage.new()
        |> SupportTriage.load_message(:bug)
        |> then(fn {a, _} -> SupportTriage.respond(a) end)

      assert agent.state.response =~ "Queue: engineering-p1"
      assert agent.state.response =~ "Urgency: high"
    end

    test "routes a how-to question to self-serve" do
      {agent, _} =
        SupportTriage.new()
        |> SupportTriage.load_message(:howto)
        |> then(fn {a, _} -> SupportTriage.respond(a) end)

      assert agent.state.response =~ "Queue: self-serve"
    end

    test "routes an unrecognized message to general" do
      {agent, _} =
        SupportTriage.new()
        |> SupportTriage.load_message(:thanks)
        |> then(fn {a, _} -> SupportTriage.respond(a) end)

      assert agent.state.response =~ "Queue: general"
    end

    test "is self-sufficient: responds with no prior classify or assess step" do
      {agent, _} =
        SupportTriage.new()
        |> SupportTriage.load_message(:billing)
        |> then(fn {a, _} -> SupportTriage.respond(a) end)

      # Respond derives intent and urgency lazily, so it still routes correctly.
      assert agent.state.intent == "billing"
      assert agent.state.urgency == "normal"
      assert agent.state.response =~ "Queue: billing"
    end
  end

  describe "full load -> classify -> assess -> respond workflow" do
    test "the four typed actions compose into a support-triage pipeline" do
      {agent, _} =
        SupportTriage.new()
        |> SupportTriage.load_message(:bug)
        |> then(fn {a, _} -> SupportTriage.classify(a) end)
        |> then(fn {a, _} -> SupportTriage.assess(a) end)
        |> then(fn {a, _} -> SupportTriage.respond(a) end)

      assert agent.state.intent == "bug"
      assert agent.state.urgency == "high"
      assert agent.state.response =~ "Queue: engineering-p1"
    end
  end
end
