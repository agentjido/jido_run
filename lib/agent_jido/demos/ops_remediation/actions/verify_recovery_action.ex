defmodule AgentJido.Demos.OpsRemediation.Actions.VerifyRecoveryAction do
  @moduledoc """
  Verifies the system recovered after the remediation ran.

  Projects the deterministic post-remediation metric a successful run produces
  for the diagnosed issue and reports whether the system is back within
  thresholds. The diagnosis is resolved from the stored value, or derived from
  the metrics when an earlier step has not run yet, so this step is
  self-sufficient. No LLM is called.
  """

  use Jido.Action,
    name: "verify_recovery",
    description: "Verifies the system recovered after remediation"

  alias AgentJido.Demos.OpsRemediation.Diagnostics

  @impl true
  def run(_params, %{state: state}) do
    %{p95_latency_ms: p95, error_rate_pct: error, cpu_pct: cpu, diagnosis: diagnosis} = state

    metrics = %{p95_latency_ms: p95, error_rate_pct: error, cpu_pct: cpu}

    effective_diagnosis = Diagnostics.resolve(diagnosis, metrics)

    {:ok,
     %{
       diagnosis: effective_diagnosis,
       remediation: Diagnostics.remediate(effective_diagnosis),
       verification: Diagnostics.recover(effective_diagnosis)
     }}
  end
end
