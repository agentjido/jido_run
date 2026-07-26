defmodule AgentJido.Demos.OpsRemediation.Diagnostics do
  @moduledoc """
  Shared, deterministic operations diagnostics for the remediation agent.

  Three real thresholds drive anomaly detection -- a p95 latency ceiling, an
  error-rate ceiling, and a CPU saturation ceiling. `anomalies/1` lists which
  thresholds a metric snapshot breaches, `status/1` rolls that up to a single
  healthy/degraded signal, and `diagnose/1` picks the single dominant issue in
  a fixed severity order so a multi-breach snapshot still yields one
  deterministic diagnosis. `remediate/1` selects the matching playbook entry and
  `recover/1` projects the deterministic post-remediation metric a successful
  run produces.

  Used by the `DetectAnomaly`, `Diagnose`, `ApplyRemediation`, and
  `VerifyRecovery` actions and -- when an earlier step has not run -- derived
  lazily by the later actions so each step is self-sufficient.
  """

  # Production-style SLO thresholds. Anomalies are real threshold breaches, not
  # canned labels.
  @latency_threshold_ms 500
  @error_threshold_pct 1.0
  @cpu_threshold_pct 90

  # Severity order for picking the one dominant diagnosis when a snapshot
  # breaches more than one threshold. Errors are most disruptive (roll back),
  # then saturation (scale up), then latency (scale out).
  @severity_order [:errors, :cpu, :latency]

  @type anomaly :: :latency | :errors | :cpu

  @doc """
  The p95 latency threshold, in milliseconds.
  """
  @spec latency_threshold_ms() :: pos_integer()
  def latency_threshold_ms, do: @latency_threshold_ms

  @doc """
  The error-rate threshold, in percent.
  """
  @spec error_threshold_pct() :: float()
  def error_threshold_pct, do: @error_threshold_pct

  @doc """
  The CPU saturation threshold, in percent.
  """
  @spec cpu_threshold_pct() :: pos_integer()
  def cpu_threshold_pct, do: @cpu_threshold_pct

  @doc """
  List the thresholds a metric snapshot breaches. A `%{p95_latency_ms:,
  error_rate_pct:, cpu_pct:}` map with no values is treated as no metric loaded
  and breaches nothing.
  """
  @spec anomalies(map()) :: [anomaly()]
  def anomalies(%{p95_latency_ms: p95, error_rate_pct: error, cpu_pct: cpu}) do
    []
    |> maybe(:latency, p95 != nil and p95 > @latency_threshold_ms)
    |> maybe(:errors, error != nil and error > @error_threshold_pct)
    |> maybe(:cpu, cpu != nil and cpu > @cpu_threshold_pct)
  end

  def anomalies(_metrics), do: []

  @doc """
  Roll the anomalies up to a single status: `"degraded"` when any threshold is
  breached, otherwise `"healthy"`.
  """
  @spec status(map()) :: String.t()
  def status(metrics) do
    if anomalies(metrics) == [], do: "healthy", else: "degraded"
  end

  @doc """
  Pick the single dominant diagnosis for a metric snapshot, in severity order.
  Returns `"none"` when no threshold is breached.
  """
  @spec diagnose(map()) :: String.t()
  def diagnose(metrics) do
    breached = MapSet.new(anomalies(metrics))

    case Enum.find(@severity_order, &MapSet.member?(breached, &1)) do
      :errors -> "error-rate-spike"
      :cpu -> "cpu-saturation"
      :latency -> "high-latency"
      nil -> "none"
    end
  end

  @doc """
  Resolve the effective diagnosis for a step: use the stored diagnosis when
  present, otherwise derive it from the metrics so a step that runs before
  `Diagnose` still has a diagnosis to work from.
  """
  @spec resolve(String.t(), map()) :: String.t()
  def resolve("", metrics), do: diagnose(metrics)
  def resolve(stored, _metrics), do: stored

  @doc """
  Select the remediation playbook entry for a diagnosis. Each entry names the
  action and its bounded effect, derived for real from the dominant issue.
  """
  @spec remediate(String.t()) :: String.t()
  def remediate("high-latency"),
    do: "scale-out: add two pods and enable the response cache"

  def remediate("error-rate-spike"),
    do: "roll-back: revert the last deploy and shift traffic off the bad canary"

  def remediate("cpu-saturation"),
    do: "scale-up: raise the CPU limit and throttle batch jobs"

  def remediate("none"), do: "hold: no remediation needed, keep the current rollout"
  def remediate(_diagnosis), do: remediate("none")

  @doc """
  Project the deterministic post-remediation metric a successful run produces
  for a diagnosis, and report whether the system recovered. A `"none"` diagnosis
  is already within thresholds and holds steady.

  Returns a short, human-readable verification string.
  """
  @spec recover(String.t()) :: String.t()
  def recover("high-latency") do
    "recovered: p95 210ms, error 0.2%, cpu 55% — latency back under the SLO"
  end

  def recover("error-rate-spike") do
    "recovered: p95 230ms, error 0.3%, cpu 52% — error rate back under the SLO"
  end

  def recover("cpu-saturation") do
    "recovered: p95 360ms, error 0.7%, cpu 61% — CPU back under saturation"
  end

  def recover("none") do
    "steady: p95 120ms, error 0.1%, cpu 40% — already within thresholds"
  end

  def recover(_diagnosis), do: recover("none")

  defp maybe(list, _anomaly, false), do: list
  defp maybe(list, anomaly, true), do: list ++ [anomaly]
end
