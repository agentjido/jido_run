defmodule AgentJido.Demos.ControlledAgentAuthenticationBoundaryTest do
  @moduledoc """
  Authentication-as-boundary coverage for the controlled-agent reference path
  (`jido-e07-t36`).

  Acceptance: *Jido does not appear to authenticate a user or service by
  itself.* The architecture diagram and guide must draw authentication as an
  application/platform boundary in front of Jido, and the demo's authorization
  hook must not read like a login. This test locks the diagram, the guide copy,
  and the hook's contract so the boundary cannot be dropped or blurred without
  failing here.
  """

  use ExUnit.Case, async: true

  alias AgentJido.Demos.ControlledAgent.AuthorizationPlugin
  alias Jido.Signal

  # Paths are relative to the repo root.
  @spec_page "specs/operations-reference-architecture.md"
  @readme "lib/agent_jido/demos/controlled_agent/README.md"
  @plugin_source "lib/agent_jido/demos/controlled_agent/authorization_plugin.ex"

  # The `## Controlled-agent extension` section: the heading and its body up to
  # the next `##` heading (or end of document).
  @section_re ~r/^##[[:space:]]+Controlled-agent extension\b.*?(?=^##[[:space:]]|\z)/ims

  # The acceptance phrasing the task pins down.
  @does_not_authenticate ~r/does not authenticate/i

  # The three identity-handling stages the boundary splits into.
  @stages [
    {"authenticate", ~r/\bauthenticat(e|ed|ion)/i},
    {"carry", ~r/\bcarries?\b/i},
    {"authorize", ~r/\bauthoriz(e|es|ation)/i}
  ]

  describe "the architecture spec draws authentication as a boundary (jido-e07-t36)" do
    test "the controlled-agent extension has an Authentication boundary subsection" do
      section = section(File.read!(repo_path(@spec_page)))

      assert section != nil,
             "#{@spec_page} must include a `## Controlled-agent extension` section"

      assert Regex.match?(~r/^###[[:space:]]+Authentication boundary\b/im, section),
             "#{@spec_page} must include a `### Authentication boundary` subsection " <>
               "inside the controlled-agent extension"
    end

    test "the section carries the architecture diagram" do
      section = section(File.read!(repo_path(@spec_page)))

      assert Regex.match?(~r/```mermaid/, section),
             "#{@spec_page} must include a mermaid diagram in the controlled-agent " <>
               "extension that draws authentication as a boundary in front of Jido"
    end

    test "the section states the acceptance condition" do
      section = section(File.read!(repo_path(@spec_page)))

      assert Regex.match?(@does_not_authenticate, section),
             "#{@spec_page} must state that Jido does not authenticate a user or " <>
               "service by itself"
    end

    for {label, re} <- @stages do
      test "the section names the #{label} stage" do
        {label, re} = unquote(Macro.escape({label, re}))
        section = section(File.read!(repo_path(unquote(@spec_page))))

        assert Regex.match?(re, section),
               "#{unquote(@spec_page)} must name the #{label} stage of the " <>
                 "authentication boundary (matching #{inspect(re.source)})"
      end
    end
  end

  describe "the controlled-agent README draws authentication as a boundary (jido-e07-t36)" do
    test "it has an Authentication boundary section" do
      body = File.read!(repo_path(@readme))

      assert Regex.match?(~r/^##[[:space:]]+Authentication boundary\b/im, body),
             "#{@readme} must include a `## Authentication boundary` section"
    end

    test "it carries the architecture diagram" do
      body = File.read!(repo_path(@readme))

      assert Regex.match?(~r/```mermaid/, body),
             "#{@readme} must include a mermaid diagram showing authentication " <>
               "as a boundary in front of Jido"
    end

    test "it states the acceptance condition" do
      body = File.read!(repo_path(@readme))

      assert Regex.match?(@does_not_authenticate, body),
             "#{@readme} must state that Jido does not authenticate a user or " <>
               "service by itself"
    end

    for {label, re} <- @stages do
      test "it names the #{label} stage" do
        {label, re} = unquote(Macro.escape({label, re}))
        body = File.read!(repo_path(unquote(@readme)))

        assert Regex.match?(re, body),
               "#{unquote(@readme)} must name the #{label} stage of the " <>
                 "authentication boundary (matching #{inspect(re.source)})"
      end
    end
  end

  describe "the authorization hook is authorization, not authentication (jido-e07-t36)" do
    test "the hook's moduledoc says it does not authenticate" do
      source = File.read!(repo_path(@plugin_source))

      assert Regex.match?(@does_not_authenticate, source),
             "#{@plugin_source} must state that the hook does not authenticate"

      assert Regex.match?(~r/\bauthorization\b/i, source),
             "#{@plugin_source} must name the hook an authorization decision"

      assert Regex.match?(~r/already-authenticated|supplied by the boundary/i, source),
             "#{@plugin_source} must state the principal is already authenticated " <>
               "and supplied by the boundary in front of Jido"
    end

    test "the hook decides on the supplied principal only — it never authenticates" do
      context = %{config: %{allowed: ["alice"]}}
      allowed = Signal.new!("work.approve", %{}, source: "alice")
      unknown = Signal.new!("work.approve", %{}, source: "mallory")

      # The decision is the allowlist (authorization). There is no credential
      # to verify: a supplied principal is allowed or denied, nothing more.
      assert {:ok, _} = AuthorizationPlugin.prepare_action(allowed, %{}, context)

      assert {:error, :unauthorized} =
               AuthorizationPlugin.prepare_action(unknown, %{}, context)
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
