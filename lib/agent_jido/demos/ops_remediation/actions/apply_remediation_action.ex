defmodule AgentJido.Demos.OpsRemediation.Actions.ApplyRemediationAction do
  @moduledoc """
  Applies the remediation playbook entry for the diagnosed issue.

  The remediation is derived for real from the prior steps: a high-latency
  diagnosis scales out, an error-rate spike rolls back, CPU saturation scales
  up, and a clean snapshot holds steady. The diagnosis is resolved from the
  stored value, or derived from the metrics when an earlier step has not run
  yet, so this step is self-sufficient. No LLM is called.
  """

  use Jido.Action,
    name: "apply_remediation",
    description: "Applies the playbook remediation for the diagnosed issue"

  alias AgentJido.Demos.OpsRemediation.Diagnostics

  @impl true
  def run(_params, %{state: state}) do
    %{p95_latency_ms: p95, error_rate_pct: error, cpu_pct: cpu, diagnosis: diagnosis} = state

    metrics = %{p95_latency_ms: p95, error_rate_pct: error, cpu_pct: cpu}

    effective_diagnosis = Diagnostics.resolve(diagnosis, metrics)

    {:ok, %{diagnosis: effective_diagnosis, remediation: Diagnostics.remediate(effective_diagnosis)}}
  end
end
