defmodule AgentJido.Demos.ControlledAgentStack do
  @moduledoc """
  The controlled-Agent dependency set as one supported combination
  (`jido-e09-t50`).

  The recommended-stacks spec names a Controlled-Agent stack — core Jido and its
  control packages composed for governed, inspectable agent work
  (`jido-e09-t39/t40`). The operational-control capability matrix
  (`AgentJido.Ecosystem.ControlMatrix`, `jido-e09-t49`) is the single source of
  truth for which packages participate: its package columns. This module names
  that set as one dependency combination and gives it the tested integrated run
  the spec's stack requirements call for ("a tested minimal example with the
  stated versions") — the same shape the three home stacks carry in
  `AgentJido.Demos.StackExamples`.

  Acceptance condition (E09-T50): *the documented versions install and run the
  integrated example together.* `packages/0` is the combination — sourced from
  the matrix so it never drifts — and `run/0` runs the integrated controlled
  agent end to end. The Compatibility CI test
  (`controlled_agent_stack_test.exs`) asserts both halves: every documented
  version installs (published packages load at their stated Hex major; unreleased
  packages pin a public GitHub repo), and the integrated example runs with that
  set.

  The integrated run is the controlled-agent reference demo — a real supervised
  `Jido.AgentServer` running `AgentJido.Demos.ControlledAgent` through its ingress
  gate and fail-closed authorization hook. It directly exercises the core control
  packages (`jido` lifecycle and plugin hooks, `jido_action` contract,
  `jido_signal` routing and correlation); the matrix's other columns (`jido_ai`
  policy/quota, `ash_jido` and `jido_otel` integration boundaries) are the
  mutually-compatible set the stack composes, proven by the matrix and the
  focused demos rather than re-run here. No claim is made that the integrated
  example invokes every column — only that the documented set installs together
  and the example runs against it.
  """

  alias AgentJido.Demos.ControlledAgent.CorrelatedTrace
  alias AgentJido.Ecosystem.ControlMatrix

  @doc """
  The controlled-Agent dependency set: the control packages that participate in
  the controlled-Agent stack, in matrix display order.

  Sourced from `ControlMatrix.package_columns/0` so the combination is the same
  set the operational-control matrix compares — never a second hand-maintained
  list that can drift from it.
  """
  @spec packages :: [String.t()]
  def packages do
    Enum.map(ControlMatrix.package_columns(), & &1.key)
  end

  @doc """
  Runs the integrated controlled-agent example end to end (`jido-e09-t50`).

  Drives the reference controlled agent through one allowed and one denied unit
  of `work.approve` work via `CorrelatedTrace`, so a single call proves the
  combination runs: the allowed principal's Action runs and advances state, and
  the denied principal's Action is rejected at the fail-closed hook with no
  effect. Returns a map carrying both outcomes.

  Deterministic and side-effect free — no API key, network, or runtime is
  required — so the whole path runs in a normal `mix test` process.
  """
  @spec run :: map()
  def run do
    {:ok, allowed} = CorrelatedTrace.run(principal: "alice", request: "req-stack-1")
    denied = CorrelatedTrace.run!(principal: "mallory", request: "req-stack-2")

    %{
      allowed: %{
        principal: allowed.principal,
        policy_result: allowed.policy_result,
        effect: allowed.effect
      },
      denied: %{
        principal: denied.principal,
        policy_result: denied.policy_result,
        effect: denied.effect
      }
    }
  end
end
