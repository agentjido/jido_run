defmodule AgentJido.Demos.OpsRemediation do
  @moduledoc """
  A deterministic operations-remediation agent.

  It demonstrates a watch → diagnose → remediate → verify operations workflow
  on the real Jido runtime: ingest a system metric snapshot with a typed
  `IngestMetric` action, detect an anomaly with a typed `DetectAnomaly` action,
  diagnose the dominant issue with a typed `Diagnose` action, apply the matching
  playbook entry with a typed `ApplyRemediation` action, and verify recovery
  with a typed `VerifyRecovery` action. No LLM provider is called -- the
  detection, diagnosis, remediation, and verification are real threshold and
  playbook logic on the metric numbers, so the demo is fully deterministic and
  needs no API key.
  """

  use Jido.Agent,
    name: "ops_remediation_agent",
    description: "Watches a system metric, diagnoses the dominant issue, applies a remediation playbook, and verifies recovery",
    schema: [
      p95_latency_ms: [type: :integer, default: 0],
      error_rate_pct: [type: :float, default: 0.0],
      cpu_pct: [type: :integer, default: 0],
      status: [type: :string, default: ""],
      diagnosis: [type: :string, default: ""],
      remediation: [type: :string, default: ""],
      verification: [type: :string, default: ""]
    ],
    signal_routes: [
      {"ops.ingest", AgentJido.Demos.OpsRemediation.Actions.IngestMetricAction},
      {"ops.detect", AgentJido.Demos.OpsRemediation.Actions.DetectAnomalyAction},
      {"ops.diagnose", AgentJido.Demos.OpsRemediation.Actions.DiagnoseAction},
      {"ops.remediate", AgentJido.Demos.OpsRemediation.Actions.ApplyRemediationAction},
      {"ops.verify", AgentJido.Demos.OpsRemediation.Actions.VerifyRecoveryAction}
    ]

  alias AgentJido.Demos.OpsRemediation.Actions.{
    ApplyRemediationAction,
    DetectAnomalyAction,
    DiagnoseAction,
    IngestMetricAction,
    VerifyRecoveryAction
  }

  @doc """
  Loads a named metric scenario into agent state.

  `which` selects the fixture (`:healthy`, `:latency`, `:errors`, or
  `:saturation`); a fresh load clears any prior status, diagnosis, remediation,
  and verification.
  """
  @spec ingest(Jido.Agent.t(), :healthy | :latency | :errors | :saturation | atom()) ::
          Jido.Agent.cmd_result()
  def ingest(agent, which) do
    cmd(agent, {IngestMetricAction, %{which: which}})
  end

  @doc """
  Detects whether the loaded metric breaches any SLO threshold.
  """
  @spec detect(Jido.Agent.t()) :: Jido.Agent.cmd_result()
  def detect(agent) do
    cmd(agent, DetectAnomalyAction)
  end

  @doc """
  Diagnoses the single dominant issue from the breached thresholds.
  """
  @spec diagnose(Jido.Agent.t()) :: Jido.Agent.cmd_result()
  def diagnose(agent) do
    cmd(agent, DiagnoseAction)
  end

  @doc """
  Applies the remediation playbook entry for the diagnosed issue.
  """
  @spec remediate(Jido.Agent.t()) :: Jido.Agent.cmd_result()
  def remediate(agent) do
    cmd(agent, ApplyRemediationAction)
  end

  @doc """
  Verifies the system recovered after the remediation ran.
  """
  @spec verify(Jido.Agent.t()) :: Jido.Agent.cmd_result()
  def verify(agent) do
    cmd(agent, VerifyRecoveryAction)
  end
end
