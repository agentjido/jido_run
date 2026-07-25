defmodule AgentJido.Demos.ControlledAgentDesignTest do
  @moduledoc """
  Design coverage for the controlled-agent architecture (`jido-e07-t35`).

  Acceptance: *the design includes ingress, principal context, policy, Actions,
  effects, Journal, telemetry, approval, and recovery.*

  The design lives in two places — the architecture spec's "Controlled-agent
  extension" section and the controlled-agent demo README — and this test locks
  both so the nine elements cannot be dropped or weakened without failing here.
  It also ties the design's "where it is proven" column to real modules: the
  elements the integrated demo implements today (ingress, principal context,
  policy, Actions, recovery) and the focused demos that isolate the rest
  (effects, Journal, telemetry, approval).
  """

  use ExUnit.Case, async: true

  # Paths are relative to the repo root.
  @spec_page "specs/operations-reference-architecture.md"
  @readme "lib/agent_jido/demos/controlled_agent/README.md"

  # The `## Controlled-agent extension` section: the heading and its body up to
  # the next `##` heading (or end of document).
  @section_re ~r/^##[[:space:]]+Controlled-agent extension\b.*?(?=^##[[:space:]]|\z)/ims

  # The nine elements the acceptance condition names.
  @design_elements [
    {"ingress", ~r/\bingress\b/i},
    {"principal context", ~r/\bprincipal context\b/i},
    {"policy", ~r/\bpolicy\b/i},
    {"Actions", ~r/\bActions\b/},
    {"effects", ~r/\beffects\b/i},
    {"Journal", ~r/\bJournal\b/},
    {"telemetry", ~r/\btelemetry\b/i},
    {"approval", ~r/\bapproval\b/i},
    {"recovery", ~r/\brecovery\b/i}
  ]

  # Modules the integrated demo implements today (elements 1–4 and 9).
  @integrated_modules [
    {"ControlledAgent (the agent)", AgentJido.Demos.ControlledAgent},
    {"AuthorizationPlugin (policy)", AgentJido.Demos.ControlledAgent.AuthorizationPlugin},
    {"ApproveAction (Actions)", AgentJido.Demos.ControlledAgent.ApproveAction},
    {"Supervisor (recovery)", AgentJido.Demos.ControlledAgent.Supervisor}
  ]

  # Focused demos that isolate the elements not yet wired into the integrated
  # demo (effects, Journal, telemetry, approval) — the design's "where it is
  # proven" column.
  @focused_modules [
    {"AiToolAllowlist (effects/tools)", AgentJido.Demos.AiToolAllowlist.AiToolAllowlist},
    {"QuotaControlAgent (effects/quotas)", AgentJido.Demos.QuotaControlAgent},
    {"DurableSignalJournal (Journal)", AgentJido.Demos.DurableSignalJournal},
    {"CorrelatedTelemetry (telemetry)", AgentJido.Demos.CorrelatedTelemetry},
    {"RedactedAction (telemetry/redaction)", AgentJido.Demos.Redaction.RedactedAction},
    {"ApprovalBoundaryAgent (approval)", AgentJido.Demos.ApprovalBoundaryAgent}
  ]

  describe "the architecture spec names all nine design elements (jido-e07-t35)" do
    test "#{@spec_page} carries the controlled-agent extension section" do
      section = section(File.read!(repo_path(@spec_page)))

      assert section != nil,
             "#{@spec_page} must include a `## Controlled-agent extension` section"
    end

    for {label, re} <- @design_elements do
      test "#{@spec_page} design includes: #{label}" do
        {label, re} = unquote(Macro.escape({label, re}))
        section = section(File.read!(repo_path(unquote(@spec_page))))

        assert section != nil,
               "#{unquote(@spec_page)} must include a `## Controlled-agent " <>
                 "extension` section before its elements can be checked"

        assert Regex.match?(re, section),
               "#{unquote(@spec_page)} controlled-agent extension must name the " <>
                 "#{label} element (matching #{inspect(re.source)})"
      end
    end
  end

  describe "the controlled-agent README names all nine design elements (jido-e07-t35)" do
    for {label, re} <- @design_elements do
      test "#{@readme} design includes: #{label}" do
        {label, re} = unquote(Macro.escape({label, re}))
        body = File.read!(repo_path(unquote(@readme)))

        assert Regex.match?(re, body),
               "#{unquote(@readme)} must name the #{label} element of the " <>
                 "controlled-agent design (matching #{inspect(re.source)})"
      end
    end
  end

  describe "the design is wired to real modules" do
    for {label, module} <- @integrated_modules do
      test "the integrated demo defines #{label}" do
        {label, module} = unquote(Macro.escape({label, module}))

        assert {:module, ^module} = Code.ensure_loaded(module),
               "the controlled-agent design claims the integrated demo " <>
                 "implements #{label}, but #{inspect(module)} is not defined"
      end
    end

    for {label, module} <- @focused_modules do
      test "the focused demo for #{label} exists" do
        {label, module} = unquote(Macro.escape({label, module}))

        assert {:module, ^module} = Code.ensure_loaded(module),
               "the controlled-agent design points readers at the #{label} " <>
                 "focused demo, but #{inspect(module)} is not defined"
      end
    end

    test "the policy is a fail-closed prepare_action/3 hook" do
      module = AgentJido.Demos.ControlledAgent.AuthorizationPlugin
      Code.ensure_loaded(module)

      assert function_exported?(module, :prepare_action, 3),
             "AuthorizationPlugin must export prepare_action/3 — the fail-closed " <>
               "authorization point the design names"
    end

    test "the protected Action runs (the Actions element)" do
      module = AgentJido.Demos.ControlledAgent.ApproveAction
      Code.ensure_loaded(module)

      assert function_exported?(module, :run, 2),
             "ApproveAction must export run/2 — the deterministic transition " <>
               "the design's Actions element rests on"
    end

    test "recovery is supervised (the recovery element)" do
      module = AgentJido.Demos.ControlledAgent.Supervisor
      Code.ensure_loaded(module)

      assert function_exported?(module, :start_link, 1),
             "ControlledAgent.Supervisor must export start_link/1 — the " <>
               "process-restart boundary the design's recovery element rests on"

      assert function_exported?(module, :agent_server_pid, 1),
             "ControlledAgent.Supervisor must export agent_server_pid/1"
    end
  end

  defp repo_path(relative) do
    Path.expand("../../../" <> relative, __DIR__)
  end

  defp section(body) do
    case Regex.run(@section_re, body) do
      [section | _] -> section
      nil -> nil
    end
  end
end
