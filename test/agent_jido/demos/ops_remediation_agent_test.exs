defmodule AgentJido.Demos.OpsRemediationAgentTest do
  use ExUnit.Case, async: true

  alias AgentJido.Demos.OpsRemediation
  alias AgentJido.Demos.OpsRemediation.Fixtures

  describe "OpsRemediation.new/0" do
    test "starts with zero metrics and empty status, diagnosis, remediation, and verification" do
      agent = OpsRemediation.new()

      assert agent.state.p95_latency_ms == 0
      assert agent.state.error_rate_pct == 0.0
      assert agent.state.cpu_pct == 0
      assert agent.state.status == ""
      assert agent.state.diagnosis == ""
      assert agent.state.remediation == ""
      assert agent.state.verification == ""
    end
  end

  describe "ingest/2" do
    test "loads the named scenario and resets the workflow" do
      agent = OpsRemediation.new()
      {agent, _} = OpsRemediation.ingest(agent, :latency)

      scenario = Fixtures.fetch(:latency)

      assert agent.state.p95_latency_ms == scenario.p95_latency_ms
      assert agent.state.error_rate_pct == scenario.error_rate_pct
      assert agent.state.cpu_pct == scenario.cpu_pct
      # A fresh load clears any prior workflow output.
      assert agent.state.status == ""
      assert agent.state.diagnosis == ""
      assert agent.state.remediation == ""
      assert agent.state.verification == ""
    end

    test "loads each scenario by name" do
      for which <- [:healthy, :latency, :errors, :saturation] do
        {agent, _} = OpsRemediation.ingest(OpsRemediation.new(), which)
        scenario = Fixtures.fetch(which)

        assert agent.state.p95_latency_ms == scenario.p95_latency_ms
        assert agent.state.cpu_pct == scenario.cpu_pct
      end
    end
  end

  describe "detect/1" do
    test "flags a latency spike, error spike, and saturation as degraded" do
      for which <- [:latency, :errors, :saturation] do
        {agent, _} =
          OpsRemediation.new()
          |> OpsRemediation.ingest(which)
          |> then(fn {a, _} -> OpsRemediation.detect(a) end)

        # The status is real -- derived from an actual threshold breach.
        assert agent.state.status == "degraded"
      end
    end

    test "keeps a healthy snapshot healthy" do
      {agent, _} =
        OpsRemediation.new()
        |> OpsRemediation.ingest(:healthy)
        |> then(fn {a, _} -> OpsRemediation.detect(a) end)

      assert agent.state.status == "healthy"
    end

    test "detects an empty (unloaded) snapshot as healthy" do
      {agent, _} = OpsRemediation.new() |> then(fn a -> OpsRemediation.detect(a) end)

      assert agent.state.status == "healthy"
    end
  end

  describe "diagnose/1" do
    test "diagnoses each anomaly fixture as its single dominant issue" do
      for {which, expected} <- [
            latency: "high-latency",
            errors: "error-rate-spike",
            saturation: "cpu-saturation"
          ] do
        {agent, _} =
          OpsRemediation.new()
          |> OpsRemediation.ingest(which)
          |> then(fn {a, _} -> OpsRemediation.diagnose(a) end)

        # The diagnosis is a real severity-ranked threshold match, not a label.
        assert agent.state.diagnosis == expected
      end
    end

    test "diagnoses a healthy snapshot as none" do
      {agent, _} =
        OpsRemediation.new()
        |> OpsRemediation.ingest(:healthy)
        |> then(fn {a, _} -> OpsRemediation.diagnose(a) end)

      assert agent.state.diagnosis == "none"
    end

    test "diagnoses an empty (unloaded) snapshot as none" do
      {agent, _} = OpsRemediation.new() |> then(fn a -> OpsRemediation.diagnose(a) end)

      assert agent.state.diagnosis == "none"
    end
  end

  describe "remediate/1" do
    test "applies the scale-out playbook for a latency spike" do
      {agent, _} =
        OpsRemediation.new()
        |> OpsRemediation.ingest(:latency)
        |> then(fn {a, _} -> OpsRemediation.remediate(a) end)

      assert agent.state.remediation =~ "scale-out"
      assert agent.state.diagnosis == "high-latency"
    end

    test "applies the roll-back playbook for an error spike" do
      {agent, _} =
        OpsRemediation.new()
        |> OpsRemediation.ingest(:errors)
        |> then(fn {a, _} -> OpsRemediation.remediate(a) end)

      assert agent.state.remediation =~ "roll-back"
      assert agent.state.diagnosis == "error-rate-spike"
    end

    test "applies the scale-up playbook for CPU saturation" do
      {agent, _} =
        OpsRemediation.new()
        |> OpsRemediation.ingest(:saturation)
        |> then(fn {a, _} -> OpsRemediation.remediate(a) end)

      assert agent.state.remediation =~ "scale-up"
      assert agent.state.diagnosis == "cpu-saturation"
    end

    test "holds steady for a healthy snapshot" do
      {agent, _} =
        OpsRemediation.new()
        |> OpsRemediation.ingest(:healthy)
        |> then(fn {a, _} -> OpsRemediation.remediate(a) end)

      assert agent.state.remediation =~ "hold"
      assert agent.state.diagnosis == "none"
    end

    test "is self-sufficient: remediates with no prior detect or diagnose step" do
      {agent, _} =
        OpsRemediation.new()
        |> OpsRemediation.ingest(:errors)
        |> then(fn {a, _} -> OpsRemediation.remediate(a) end)

      # Remediate derives the diagnosis lazily, so it still selects the right playbook.
      assert agent.state.diagnosis == "error-rate-spike"
      assert agent.state.remediation =~ "roll-back"
    end
  end

  describe "verify/1" do
    test "confirms recovery after a latency remediation" do
      {agent, _} =
        OpsRemediation.new()
        |> OpsRemediation.ingest(:latency)
        |> then(fn {a, _} -> OpsRemediation.verify(a) end)

      assert agent.state.verification =~ "recovered"
      assert agent.state.verification =~ "latency back under the SLO"
    end

    test "reports steady for a healthy snapshot" do
      {agent, _} =
        OpsRemediation.new()
        |> OpsRemediation.ingest(:healthy)
        |> then(fn {a, _} -> OpsRemediation.verify(a) end)

      assert agent.state.verification =~ "steady"
    end

    test "is self-sufficient: verifies with no prior remediation step" do
      {agent, _} =
        OpsRemediation.new()
        |> OpsRemediation.ingest(:saturation)
        |> then(fn {a, _} -> OpsRemediation.verify(a) end)

      # Verify derives the diagnosis and remediation lazily.
      assert agent.state.diagnosis == "cpu-saturation"
      assert agent.state.remediation =~ "scale-up"
      assert agent.state.verification =~ "recovered"
    end
  end

  describe "full ingest -> detect -> diagnose -> remediate -> verify workflow" do
    test "the five typed actions compose into an operations-remediation pipeline" do
      {agent, _} =
        OpsRemediation.new()
        |> OpsRemediation.ingest(:errors)
        |> then(fn {a, _} -> OpsRemediation.detect(a) end)
        |> then(fn {a, _} -> OpsRemediation.diagnose(a) end)
        |> then(fn {a, _} -> OpsRemediation.remediate(a) end)
        |> then(fn {a, _} -> OpsRemediation.verify(a) end)

      assert agent.state.status == "degraded"
      assert agent.state.diagnosis == "error-rate-spike"
      assert agent.state.remediation =~ "roll-back"
      assert agent.state.verification =~ "recovered"
    end
  end
end
