defmodule AgentJido.Demos.OpsRemediation.Actions.DiagnoseAction do
  @moduledoc """
  Diagnoses the single dominant issue in the metric snapshot.

  Delegates to `AgentJido.Demos.OpsRemediation.Diagnostics`, which lists the
  breached thresholds and picks the one dominant diagnosis in a fixed severity
  order (errors, then saturation, then latency). The selection is real -- it
  ranks actual threshold breaches -- so a within-threshold snapshot diagnoses
  as `none` instead of always finding a fault. No LLM is called.
  """

  use Jido.Action,
    name: "diagnose",
    description: "Diagnoses the dominant issue from the breached thresholds"

  alias AgentJido.Demos.OpsRemediation.Diagnostics

  @impl true
  def run(_params, %{state: %{p95_latency_ms: p95, error_rate_pct: error, cpu_pct: cpu}}) do
    {:ok, %{diagnosis: Diagnostics.diagnose(%{p95_latency_ms: p95, error_rate_pct: error, cpu_pct: cpu})}}
  end
end
