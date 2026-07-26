defmodule AgentJido.Demos.OpsRemediation.Actions.DetectAnomalyAction do
  @moduledoc """
  Detects whether the ingested metric snapshot breaches any SLO threshold.

  Delegates to `AgentJido.Demos.OpsRemediation.Diagnostics`, which checks the
  real p95 latency, error-rate, and CPU thresholds and rolls the result up to a
  single `healthy` or `degraded` status. The detection is real -- it inspects
  the loaded numbers -- so a within-threshold snapshot stays healthy. No LLM is
  called.
  """

  use Jido.Action,
    name: "detect_anomaly",
    description: "Detects whether the metric snapshot breaches any SLO threshold"

  alias AgentJido.Demos.OpsRemediation.Diagnostics

  @impl true
  def run(_params, %{state: %{p95_latency_ms: p95, error_rate_pct: error, cpu_pct: cpu}}) do
    {:ok, %{status: Diagnostics.status(%{p95_latency_ms: p95, error_rate_pct: error, cpu_pct: cpu})}}
  end
end
