defmodule AgentJido.Demos.OpsRemediation.Fixtures do
  @moduledoc """
  Fixture system metric scenarios for the operations-remediation demo.

  Each fixture is a realistic point-in-time metric snapshot a production
  observer would surface: a p95 latency, an error rate, and a CPU reading.
  The agent's typed `DetectAnomaly`, `Diagnose`, `ApplyRemediation`, and
  `VerifyRecovery` actions operate on these numbers for real -- threshold
  checks and playbook selection, not a canned trace -- so the demo is fully
  deterministic and needs no LLM or network call.

  Each anomaly fixture breaches exactly one threshold so the diagnosis is an
  honest single dominant issue; the `healthy` fixture breaches none, so it
  exercises the no-remediation-needed branch instead of always finding a fault.
  """

  # %{which: => %{p95_latency_ms:, error_rate_pct:, cpu_pct:}}
  @scenarios %{
    healthy: %{p95_latency_ms: 120, error_rate_pct: 0.1, cpu_pct: 40},
    latency: %{p95_latency_ms: 1800, error_rate_pct: 0.2, cpu_pct: 65},
    errors: %{p95_latency_ms: 250, error_rate_pct: 6.0, cpu_pct: 50},
    saturation: %{p95_latency_ms: 400, error_rate_pct: 0.8, cpu_pct: 98}
  }

  @doc """
  A named metric scenario. Falls back to the healthy scenario for an unknown
  name so the loader always returns a coherent metric snapshot.
  """
  @spec fetch(:healthy | :latency | :errors | :saturation | atom()) :: map()
  def fetch(:healthy), do: Map.put(@scenarios[:healthy], :which, :healthy)
  def fetch(:latency), do: Map.put(@scenarios[:latency], :which, :latency)
  def fetch(:errors), do: Map.put(@scenarios[:errors], :which, :errors)
  def fetch(:saturation), do: Map.put(@scenarios[:saturation], :which, :saturation)
  def fetch(_which), do: fetch(:healthy)
end
