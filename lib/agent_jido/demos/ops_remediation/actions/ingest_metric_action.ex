defmodule AgentJido.Demos.OpsRemediation.Actions.IngestMetricAction do
  @moduledoc """
  Loads a named metric scenario into agent state for the operations observer.

  Selects one of the healthy, latency, errors, or saturation fixtures by the
  `which` parameter. A fresh load clears any prior status, diagnosis,
  remediation, and verification so a new observation starts cleanly.
  """

  use Jido.Action,
    name: "ingest_metric",
    description: "Loads a fixture system metric snapshot into agent state"

  alias AgentJido.Demos.OpsRemediation.Fixtures

  @impl true
  def run(%{which: which}, _context)
      when which in [:healthy, :latency, :errors, :saturation] do
    {:ok, metric_state(Fixtures.fetch(which))}
  end

  def run(_params, _context) do
    {:ok, metric_state(Fixtures.fetch(:healthy))}
  end

  defp metric_state(%{p95_latency_ms: p95, error_rate_pct: error, cpu_pct: cpu}) do
    %{
      p95_latency_ms: p95,
      error_rate_pct: error,
      cpu_pct: cpu,
      status: "",
      diagnosis: "",
      remediation: "",
      verification: ""
    }
  end
end
